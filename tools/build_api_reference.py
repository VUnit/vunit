#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Command line utility to build the machine-readable VHDL and Python API
reference: <docs build dir>/api/vunit_lib.json and <docs build dir>/api/python.json.

Usage: python tools/build_api_reference.py <docs build dir>

Set VUNIT_DOCS_SKIP_API=1 to skip the build entirely (prints a warning,
writes nothing, exits 0). This is the supported way to build the rest of
the documentation without GHDL installed.
"""

import inspect
import json
import os
import pkgutil
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).parent.parent

XML_ROOT_VERSION = "0.13"
VHDL_STANDARD = "2008"
LIBRARY_NAME = "vunit_lib"


class ApiReferenceError(Exception):
    """
    Raised for every error condition of the API reference generator.
    The message names what failed and where, per the design spec's
    error-handling table.
    """


# ---------------------------------------------------------------------------
# VHDL package scope
# ---------------------------------------------------------------------------

# "package <name> is", not "package body ...", optionally followed by "new"
# (a package instantiation, which has no declarations of its own).
_PACKAGE_RE = re.compile(r"^[ \t]*package\s+(?!body\b)(\w+)\s+is\b\s*(new\b)?", re.MULTILINE)


def find_package_files(root):
    """
    Return a sorted list of (absolute Path, package name) for every VHDL
    package declaration file in scope: vunit/vhdl/**/src/**/*.vhd,
    excluding vunit/vhdl/osvvm/**, that contains "package <name> is" not
    followed by "new".
    """
    vhdl_root = root / "vunit" / "vhdl"
    found = []
    for path in sorted(vhdl_root.glob("**/src/**/*.vhd")):
        if "osvvm" in path.relative_to(vhdl_root).parts:
            continue
        text = path.read_text(encoding="utf-8")
        for match in _PACKAGE_RE.finditer(text):
            if match.group(2) is not None:
                continue
            found.append((path, match.group(1)))
    return sorted(found, key=lambda item: item[1])


# ---------------------------------------------------------------------------
# Compiling
# ---------------------------------------------------------------------------


def check_ghdl_available():
    """Raise ApiReferenceError if "ghdl" is not on PATH."""
    if shutil.which("ghdl") is None:
        raise ApiReferenceError(
            "GHDL is required to build the API reference; install GHDL or set VUNIT_DOCS_SKIP_API=1"
        )


def ghdl_version_line():
    """The first line of "ghdl --version", e.g. "GHDL 6.0.0 (...) [...]"."""
    proc = subprocess.run(["ghdl", "--version"], capture_output=True, text=True, check=False)
    return proc.stdout.splitlines()[0].strip() if proc.stdout else ""


def compile_vunit_libraries(output_path):
    """
    Compile vunit_lib and osvvm with GHDL, using VUnit's own Python API,
    into output_path. Returns the "<output_path>/ghdl/libraries" directory.
    """
    os.environ["VUNIT_SIMULATOR"] = "ghdl"

    from vunit import VUnit  # pylint: disable=import-outside-toplevel

    vunit_obj = VUnit.from_argv(["--output-path", str(output_path), "--compile", "-q"])
    vunit_obj.add_vhdl_builtins()
    vunit_obj.add_verification_components()
    vunit_obj.add_random()
    vunit_obj.add_osvvm()

    try:
        vunit_obj.main()
    except SystemExit as exc:
        if exc.code not in (0, None):
            raise ApiReferenceError(
                f"VUnit compile failed with exit code {exc.code}; see the compile output above"
            ) from exc

    return Path(output_path) / "ghdl" / "libraries"


# ---------------------------------------------------------------------------
# Per-file XML extraction
# ---------------------------------------------------------------------------


def run_file_to_xml(file_path, vunit_lib_dir, osvvm_dir):
    """
    Run "ghdl --file-to-xml" on file_path and return stdout (the XML) as a
    string, without ever writing it to disk.
    """
    cmd = [
        "ghdl",
        "--file-to-xml",
        "--std=08",
        "--work=vunit_lib",
        f"--workdir={vunit_lib_dir}",
        f"-P{osvvm_dir}",
        f"-P{vunit_lib_dir}",
        str(file_path),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        stderr_lines = proc.stderr.splitlines() if proc.stderr else []
        first_error = next((ln for ln in stderr_lines if "error:" in ln), None)
        if first_error is None:
            first_error = stderr_lines[0] if stderr_lines else "(no output)"
        raise ApiReferenceError(f"ghdl --file-to-xml failed for {file_path}: {first_error}")
    return proc.stdout


def parse_xml_root(xml_text):
    """
    Parse the GHDL XML dump and check its root version.
    """
    root = ElementTree.fromstring(xml_text)
    version = root.get("version")
    if version != XML_ROOT_VERSION:
        raise ApiReferenceError(
            f"XML root version is '{version}', expected '{XML_ROOT_VERSION}'; "
            "the converter must be checked against the new GHDL XML format"
        )
    return root


def find_package_element(xml_root, file_path, package_name):
    """
    Find the "library_unit" element for the package declared in file_path,
    or None if not found (the completeness check catches a missing package).
    """
    file_str = str(file_path)
    for element in xml_root.iter("library_unit"):
        if (
            element.get("kind") == "package_declaration"
            and element.get("file") == file_str
            and element.get("identifier") == package_name
        ):
            return element
    return None


# ---------------------------------------------------------------------------
# Source text: line/column resolution and delimiter-bounded slicing
# ---------------------------------------------------------------------------


class SourceText:
    """
    A VHDL source file's text, with helpers to resolve GHDL's 1-based
    line/col (columns use tab stops of 8, like a terminal) to an absolute
    character offset, and to slice source text starting at such a position
    up to the first unbracketed delimiter.
    """

    def __init__(self, text):
        """text: the whole source file, as read from disk."""
        self.text = text
        self.lines = text.split("\n")
        offsets = []
        acc = 0
        for line in self.lines:
            offsets.append(acc)
            acc += len(line) + 1
        self._line_offsets = offsets

    @staticmethod
    def _col_to_index(line_text, col):
        """0-based character index in line_text for a 1-based GHDL column (tab stops of 8)."""
        current_col = 1
        for idx, char in enumerate(line_text):
            if current_col == col:
                return idx
            if char == "\t":
                current_col = ((current_col - 1) // 8 + 1) * 8 + 1
            else:
                current_col += 1
        return len(line_text)

    def offset(self, line, col):
        """Absolute 0-based character offset in self.text for a 1-based (line, col)."""
        return self._line_offsets[line - 1] + self._col_to_index(self.lines[line - 1], col)

    def slice_from(self, line, col, file_path, decl_line, allow_assign):
        """
        Slice starting at (line, col) up to the first delimiter at bracket
        depth 0 outside string and character literals: ":=" (only when
        allow_assign), ";" or ")". Whitespace is collapsed to single spaces.
        """
        text = self.text
        depth = 0
        i = self.offset(line, col)
        pieces = []
        piece_start = i
        while i < len(text):
            after = self._skip_literal(text, i)
            if after is not None:
                if text.startswith("--", i):
                    # A comment neither delimits nor belongs to the slice
                    pieces.append(text[piece_start:i])
                    piece_start = after
                i = after
                continue
            char = text[i]
            if depth == 0 and (char in ";)" or (allow_assign and text.startswith(":=", i))):
                pieces.append(text[piece_start:i])
                return re.sub(r"\s+", " ", " ".join(pieces)).strip()
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            i += 1
        raise ApiReferenceError(f"No closing delimiter found for slice at {file_path}:{decl_line}")

    @staticmethod
    def _skip_literal(text, i):
        """
        The index after the comment, string literal or character literal starting at
        index i of text, or None when none starts there.
        """
        if text.startswith("--", i):
            newline = text.find("\n", i)
            return len(text) if newline == -1 else newline
        if text[i] == '"':
            i += 1
            while i < len(text):
                if text[i] == '"':
                    if text.startswith('"', i + 1):
                        # A doubled quote within the literal
                        i += 2
                        continue
                    return i + 1
                i += 1
            return len(text)
        if text[i] == "'" and i + 2 < len(text) and text[i + 2] == "'":
            return i + 3
        return None


_LICENSE_MARKER = "This Source Code Form"


def comment_block_above(source, first_line):
    """
    The contiguous block of "--" lines directly above first_line, stripped
    of "--" and one following space, joined with "\\n". None if there is no
    such block.
    """
    collected = []
    line_no = first_line - 1
    while 1 <= line_no <= len(source.lines):
        stripped = source.lines[line_no - 1].strip()
        if stripped.startswith("--"):
            collected.append(stripped)
            line_no -= 1
        else:
            break
    if not collected:
        return None
    collected.reverse()
    out = []
    for comment in collected:
        body = comment[2:]
        if body.startswith(" "):
            body = body[1:]
        out.append(body)
    return "\n".join(out)


def subprogram_first_line(source, decl_line):
    """
    A subprogram's declaration starts on the line holding "function" or
    "procedure", which is normally decl_line (GHDL's line/col point at the
    identifier, on that same line) -- unless a preceding line holds only
    "pure" or "impure", in which case that line is the true first line.
    """
    prev = decl_line - 1
    if prev >= 1 and source.lines[prev - 1].strip() in ("pure", "impure"):
        return prev
    return decl_line


def package_doc(source, decl_line):
    """The package's own doc comment, or None (also None for the MPL license header)."""
    doc = comment_block_above(source, decl_line)
    if doc is not None and _LICENSE_MARKER in doc:
        return None
    return doc


# ---------------------------------------------------------------------------
# XML element -> dict conversion
# ---------------------------------------------------------------------------

_IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

_PARAMETER_CLASS = {
    "interface_constant_declaration": "constant",
    "interface_variable_declaration": "variable",
    "interface_signal_declaration": "signal",
    "interface_file_declaration": "file",
}

_OBJECT_CLASS = {
    "signal_declaration": "signal",
    "variable_declaration": "shared variable",
    "file_declaration": "file",
}


def _min_position(element, file_str):
    """
    The earliest (line, col) among element and all its descendants that
    carry their own line/col in file_str.

    GHDL constant-folds some expressions (e.g. a "positive'high" default
    is folded to an integer_literal) and then reports the *folded*
    element's own line/col at the attribute name ("high"), not at the
    start of the written expression ("positive'high"). The true start is
    still there, on a descendant (here the attribute's prefix "positive"),
    so scanning the whole subtree for the earliest position recovers it.
    """
    best = None
    line = element.get("line")
    col = element.get("col")
    if line is not None and col is not None and element.get("file") == file_str:
        best = (int(line), int(col))
    for child in element:
        child_best = _min_position(child, file_str)
        if child_best is not None and (best is None or child_best < best):
            best = child_best
    return best


def _slice_element(source, element, file_path, decl_line, allow_assign):
    """Slice source text starting at element's (recovered) position, or None if it has none."""
    position = _min_position(element, file_path)
    if position is None:
        return None
    return source.slice_from(position[0], position[1], file_path, decl_line, allow_assign=allow_assign)


def _name_text(name_element):
    """
    The (possibly dotted) name of a simple_name or selected_name element,
    e.g. "push" or "work.push".
    """
    identifier = name_element.get("identifier", "")
    # GHDL's <prefix> element carries its own kind/identifier directly (it
    # *is* the name node for the prefix, e.g. simple_name "work"), not a
    # wrapper around a further child.
    prefix = name_element.find("prefix")
    if prefix is None:
        return identifier
    return f"{_name_text(prefix)}.{identifier}"


def convert_parameter(element, source, file_path, decl_line):
    """Convert one interface_*_declaration XML element to a parameter dict."""
    kind = element.get("kind")
    param_class = _PARAMETER_CLASS.get(kind)
    if param_class is None:
        raise ApiReferenceError(f"Unhandled parameter kind '{kind}' at {file_path}:{decl_line}")

    # Implicit predefined operators (e.g. "=" synthesized for every type)
    # have parameters with a "type" reference but no textual
    # subtype_indication, since they were never written in source.
    type_el = element.find("subtype_indication")
    param_type = None
    if type_el is not None:
        param_type = _slice_element(source, type_el, file_path, decl_line, allow_assign=True)

    default = None
    default_el = element.find("default_value")
    if default_el is not None:
        default = _slice_element(source, default_el, file_path, decl_line, allow_assign=False)

    return {
        "name": element.get("identifier"),
        "class": param_class,
        "mode": element.get("mode"),
        "type": param_type,
        "default": default,
    }


def convert_subprogram(element, source, file_path):
    """
    Convert one function_declaration/procedure_declaration XML element to a
    subprogram dict.
    """
    kind_raw = element.get("kind")
    kind = "function" if kind_raw == "function_declaration" else "procedure"
    identifier = element.get("identifier")
    decl_line = int(element.get("line"))

    parameters = []
    chain = element.find("interface_declaration_chain")
    if chain is not None:
        for param_el in chain.findall("el"):
            parameters.append(convert_parameter(param_el, source, file_path, decl_line))

    return_type = None
    if kind == "function":
        return_type_el = element.find("return_type_mark")
        if return_type_el is not None:
            return_type = return_type_el.get("identifier")

    pure = None if kind == "procedure" else (element.get("pure_flag") == "true")

    return {
        "kind": kind,
        "name": identifier,
        "operator": _IDENTIFIER_RE.match(identifier) is None,
        "pure": pure,
        "line": decl_line,
        "parameters": parameters,
        "return_type": return_type,
        "doc": comment_block_above(source, subprogram_first_line(source, decl_line)),
    }


def convert_alias(element, *_):
    """Convert one non_object_alias_declaration/object_alias_declaration XML element to an alias dict."""
    decl_line = int(element.get("line"))
    name_el = element.find("name")
    target = _name_text(name_el) if name_el is not None else None

    signature_el = element.find("alias_signature")
    signature = []
    return_type = None
    if signature_el is not None:
        type_marks_list = signature_el.find("type_marks_list")
        if type_marks_list is not None:
            signature = [mark.get("identifier") for mark in type_marks_list.findall("el")]
        return_type_mark = signature_el.find("return_type_mark")
        if return_type_mark is not None:
            return_type = return_type_mark.get("identifier")

    return {
        "name": element.get("identifier"),
        "line": decl_line,
        "target": target,
        "signature": signature,
        "return_type": return_type,
    }


def convert_constant(element, source, file_path):
    """Convert one constant_declaration XML element to a constant dict."""
    decl_line = int(element.get("line"))
    type_el = element.find("subtype_indication")
    const_type = _slice_element(source, type_el, file_path, decl_line, allow_assign=True)
    value = None
    value_el = element.find("default_value")
    if value_el is not None:
        value = _slice_element(source, value_el, file_path, decl_line, allow_assign=False)
    return {
        "name": element.get("identifier"),
        "line": decl_line,
        "doc": comment_block_above(source, decl_line),
        "type": const_type,
        "value": value,
    }


def convert_subtype(element, source, file_path):
    """Convert one subtype_declaration XML element to a subtype dict."""
    decl_line = int(element.get("line"))
    type_el = element.find("subtype_indication")
    definition = _slice_element(source, type_el, file_path, decl_line, allow_assign=True)
    return {
        "name": element.get("identifier"),
        "line": decl_line,
        "doc": comment_block_above(source, decl_line),
        "definition": definition,
    }


def convert_object(element, source, file_path):
    """Convert one signal/shared-variable/file declaration XML element to an object dict."""
    decl_line = int(element.get("line"))
    type_el = element.find("subtype_indication")
    obj_type = _slice_element(source, type_el, file_path, decl_line, allow_assign=True)
    return {
        "name": element.get("identifier"),
        "class": _OBJECT_CLASS[element.get("kind")],
        "line": decl_line,
        "doc": comment_block_above(source, decl_line),
        "type": obj_type,
    }


def _convert_record_type(type_def, source, file_path, decl_line, common):
    """Build a "record" type dict: {..., "elements": [{"name", "type"}, ...]}."""
    elements = []
    elements_list = type_def.find("elements_declaration_list")
    if elements_list is not None:
        for element_el in elements_list.findall("el"):
            element_type_el = element_el.find("subtype_indication")
            elements.append(
                {
                    "name": element_el.get("identifier"),
                    "type": _slice_element(source, element_type_el, file_path, decl_line, allow_assign=True),
                }
            )
    return {**common, "kind": "record", "elements": elements}


def _convert_enumeration_type(type_def, common):
    """Build an "enumeration" type dict: {..., "literals": [name, ...]}."""
    literal_list = type_def.find("enumeration_literal_list")
    literals = [literal.get("identifier") for literal in literal_list.findall("el")] if literal_list is not None else []
    return {**common, "kind": "enumeration", "literals": literals}


def _convert_protected_type(type_def, source, file_path, common):
    """Build a "protected" type dict: {..., "subprograms": [...]} (its methods)."""
    subprograms = []
    chain = type_def.find("declaration_chain")
    if chain is not None:
        for member_el in chain.findall("el"):
            if member_el.get("kind") in ("function_declaration", "procedure_declaration"):
                subprograms.append(convert_subprogram(member_el, source, file_path))
    return {**common, "kind": "protected", "subprograms": subprograms}


def convert_type(element, source, file_path):
    """Convert one type_declaration XML element to a type dict."""
    decl_line = int(element.get("line"))
    common = {"name": element.get("identifier"), "line": decl_line, "doc": comment_block_above(source, decl_line)}
    type_def = element.find("type_definition")
    def_kind = type_def.get("kind") if type_def is not None else None

    if def_kind == "record_type_definition":
        return _convert_record_type(type_def, source, file_path, decl_line, common)
    if def_kind == "enumeration_type_definition":
        return _convert_enumeration_type(type_def, common)
    if def_kind == "protected_type_declaration":
        return _convert_protected_type(type_def, source, file_path, common)

    # Array, access and file types (and anything else GHDL introduces):
    # kept as "other" with the raw source-text definition.
    definition = _slice_element(source, type_def, file_path, decl_line, allow_assign=True)
    return {**common, "kind": "other", "definition": definition}


_KIND_HANDLERS = {
    "function_declaration": ("subprograms", convert_subprogram),
    "procedure_declaration": ("subprograms", convert_subprogram),
    # non_object_alias_declaration covers subprogram and type aliases;
    # object_alias_declaration covers aliases of a signal/variable/
    # constant (e.g. "alias null_byte_vector_ptr is null_string_ptr").
    # Both share the same shape (a "name", and an optional
    # "alias_signature" for subprograms only) so both go through the same
    # converter into "aliases".
    "non_object_alias_declaration": ("aliases", convert_alias),
    "object_alias_declaration": ("aliases", convert_alias),
    "constant_declaration": ("constants", convert_constant),
    "subtype_declaration": ("subtypes", convert_subtype),
    "type_declaration": ("types", convert_type),
    "signal_declaration": ("objects", convert_object),
    "variable_declaration": ("objects", convert_object),
    "file_declaration": ("objects", convert_object),
}


def convert_package(package_el, source, file_path, repo_relative_path):
    """Convert one package_declaration XML element to a package dict."""
    decl_line = int(package_el.get("line"))
    name = package_el.get("identifier")
    file_str = str(file_path)

    package = {
        "library": LIBRARY_NAME,
        "name": name,
        "source": repo_relative_path,
        "line": decl_line,
        "private": name.endswith("_private_pkg"),
        "doc": package_doc(source, decl_line),
        "types": [],
        "subtypes": [],
        "constants": [],
        "objects": [],
        "subprograms": [],
        "aliases": [],
    }

    chain = package_el.find("declaration_chain")
    if chain is None:
        return package

    for element in chain.findall("el"):
        if element.get("file") != file_str:
            continue
        kind = element.get("kind")
        if kind == "anonymous_type_declaration":
            continue
        handler = _KIND_HANDLERS.get(kind)
        if handler is None:
            raise ApiReferenceError(f"Unhandled declaration kind '{kind}' at {file_str}:{element.get('line')}")
        bucket, convert = handler
        package[bucket].append(convert(element, source, file_str))

    return package


# ---------------------------------------------------------------------------
# Completeness check
# ---------------------------------------------------------------------------


def check_completeness(json_package_names, expected_package_names):
    """Raise ApiReferenceError listing missing/extra names if the two sets differ."""
    found = set(json_package_names)
    expected = set(expected_package_names)
    missing = sorted(expected - found)
    extra = sorted(found - expected)
    if missing or extra:
        raise ApiReferenceError(
            "Package set in the JSON differs from the package declarations found in the source files: "
            f"missing {missing}, extra {extra}"
        )


# ---------------------------------------------------------------------------
# VHDL API top-level build
# ---------------------------------------------------------------------------


def build_vhdl_api(root, vunit_version):
    """Compile vunit_lib with GHDL and extract the full VHDL symbol table."""
    package_files = find_package_files(root)
    check_ghdl_available()
    # ghdl_version_line() already reads e.g. "GHDL 6.0.0 (...) [Dunoon edition]"
    generator = f"{ghdl_version_line()} --file-to-xml"

    with tempfile.TemporaryDirectory(prefix="vunit-api-compile-") as compile_out:
        libraries_dir = compile_vunit_libraries(compile_out)
        packages = []
        for file_path, package_name in package_files:
            xml = run_file_to_xml(file_path, libraries_dir / "vunit_lib", libraries_dir / "osvvm")
            package_el = find_package_element(parse_xml_root(xml), file_path, package_name)
            if package_el is not None:
                source = SourceText(file_path.read_text(encoding="utf-8"))
                packages.append(convert_package(package_el, source, file_path, file_path.relative_to(root).as_posix()))

    check_completeness((pkg["name"] for pkg in packages), (name for _, name in package_files))
    packages.sort(key=lambda pkg: pkg["name"])

    return {
        "schema_version": 1,
        "vunit_version": vunit_version,
        "vhdl_standard": VHDL_STANDARD,
        "generator": generator,
        "packages": packages,
    }


# ---------------------------------------------------------------------------
# Python API
# ---------------------------------------------------------------------------

_DIRECTIVE_RE = re.compile(r"^\.\.\s+(auto\w+)::\s*(\S+)", re.MULTILINE)


def _has_members_option(text, after_pos):
    """True if a ":members:" option line follows the directive ending at after_pos."""
    for line in text[after_pos:].split("\n")[1:]:
        if line.strip() == "":
            break
        if not line[:1].isspace():
            break
        if line.strip().startswith(":members:"):
            return True
    return False


def find_python_targets(root):
    """
    Return a list of (directive, dotted_path, has_members) for every
    autoclass/autofunction/automodule directive under docs/**/*.rst.
    """
    targets = []
    for rst_path in sorted((root / "docs").glob("**/*.rst")):
        text = rst_path.read_text(encoding="utf-8")
        for match in _DIRECTIVE_RE.finditer(text):
            directive, target = match.groups()
            target = target.rstrip("()")
            targets.append((directive, target, _has_members_option(text, match.end())))
    return targets


def import_dotted(dotted):
    """Import the object with the dotted name of an autodoc target, e.g. "a.b.C"."""
    try:
        return pkgutil.resolve_name(dotted)
    except (ImportError, AttributeError) as exc:
        raise ApiReferenceError(f"Could not import Python autodoc target '{dotted}': {exc}") from exc


def _class_members(cls):
    """Public methods and properties defined directly on cls (not inherited)."""
    prefix = cls.__qualname__ + "."
    members = []
    for name in sorted(dir(cls)):
        if name.startswith("_"):
            continue
        member = getattr(cls, name)
        if isinstance(member, property):
            fget = member.fget
            if fget is None or not getattr(fget, "__qualname__", "").startswith(prefix):
                continue
            members.append({"name": name, "kind": "property", "signature": None, "doc": inspect.getdoc(member)})
        elif inspect.isfunction(member):
            if not member.__qualname__.startswith(prefix):
                continue
            members.append(
                {
                    "name": name,
                    "kind": "method",
                    "signature": str(inspect.signature(member)),
                    "doc": inspect.getdoc(member),
                }
            )
    return members


def build_class_object(dotted, cls):
    """The Python API object for an autoclass target."""
    return {
        "name": dotted,
        "kind": "class",
        "doc": inspect.getdoc(cls),
        "members": _class_members(cls),
    }


def build_module_object(dotted, module, has_members):
    """The Python API object for an automodule target."""
    members = []
    if has_members:
        for name in sorted(vars(module)):
            if name.startswith("_"):
                continue
            member = vars(module)[name]
            if inspect.isclass(member) and member.__module__ == module.__name__:
                members.append({"name": name, "kind": "class", "signature": None, "doc": inspect.getdoc(member)})
            elif inspect.isfunction(member) and member.__module__ == module.__name__:
                members.append(
                    {
                        "name": name,
                        "kind": "function",
                        "signature": str(inspect.signature(member)),
                        "doc": inspect.getdoc(member),
                    }
                )
        if not members:
            raise ApiReferenceError(f"No public objects found for Python autodoc target '{dotted}'")
    return {"name": dotted, "kind": "module", "doc": inspect.getdoc(module), "members": members}


def build_python_api(root, vunit_version):
    """Collect the Python API objects for every autodoc target under docs/."""
    objects = []
    for directive, dotted, has_members in find_python_targets(root):
        obj = import_dotted(dotted)
        if directive == "autoclass":
            objects.append(build_class_object(dotted, obj))
        elif directive == "automodule":
            objects.append(build_module_object(dotted, obj, has_members))
        else:
            raise ApiReferenceError(f"Unsupported autodoc directive '{directive}' for '{dotted}' in docs/")

    objects.sort(key=lambda item: item["name"])
    return {"schema_version": 1, "vunit_version": vunit_version, "objects": objects}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=1, sort_keys=False, ensure_ascii=False) + "\n", encoding="utf-8")


def build(docs_dir, root=ROOT):
    """Build both API JSON files into <docs_dir>/api/."""
    from vunit.about import version  # pylint: disable=import-outside-toplevel

    vunit_version = version()
    vhdl_api = build_vhdl_api(root, vunit_version)
    python_api = build_python_api(root, vunit_version)

    api_dir = Path(docs_dir) / "api"
    _write_json(api_dir / "vunit_lib.json", vhdl_api)
    _write_json(api_dir / "python.json", python_api)


def main(argv=None):
    """CLI entry point: build_api_reference.py <docs build dir>."""
    argv = sys.argv[1:] if argv is None else argv

    if os.environ.get("VUNIT_DOCS_SKIP_API") == "1":
        print(
            "WARNING: VUNIT_DOCS_SKIP_API=1, skipping the API reference build (no api/*.json written)",
            file=sys.stderr,
        )
        return 0

    if len(argv) != 1:
        print("usage: build_api_reference.py <docs build dir>", file=sys.stderr)
        return 1

    try:
        build(argv[0])
    except ApiReferenceError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
