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
the documentation without vhdl-dump-ast installed.
"""

import inspect
import json
import os
import pkgutil
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent

VHDL_DUMP_AST_VERSION = "vhdl-dump-ast 0.1.0"
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
# Running vhdl-dump-ast
# ---------------------------------------------------------------------------


def check_vhdl_dump_ast_available():
    """Raise ApiReferenceError if "vhdl-dump-ast" is not on PATH."""
    if shutil.which("vhdl-dump-ast") is None:
        raise ApiReferenceError(
            "vhdl-dump-ast is required to build the API reference; install it with "
            "`cargo install vhdl-dump-ast --version 0.1.0 --locked` or set VUNIT_DOCS_SKIP_API=1"
        )


def check_vhdl_dump_ast_version():
    """
    Raise ApiReferenceError unless "vhdl-dump-ast --version" is exactly
    VHDL_DUMP_AST_VERSION (the format pin for the syntax tree shape this
    converter understands). Returns the version string.
    """
    proc = subprocess.run(["vhdl-dump-ast", "--version"], capture_output=True, text=True, check=False)
    version_line = (proc.stdout or "").strip()
    if version_line != VHDL_DUMP_AST_VERSION:
        raise ApiReferenceError(
            f"vhdl-dump-ast reports '{version_line}', expected '{VHDL_DUMP_AST_VERSION}'; "
            "the converter must be checked against the new syntax tree format"
        )
    return version_line


def run_vhdl_dump_ast(file_path):
    """
    Run "vhdl-dump-ast <file_path> --trivia --no-pretty" and return stdout
    (the JSON syntax tree) as a string, without ever writing it to disk.
    """
    proc = subprocess.run(
        ["vhdl-dump-ast", str(file_path), "--trivia", "--no-pretty"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        stderr_lines = proc.stderr.splitlines() if proc.stderr else []
        first_line = stderr_lines[0] if stderr_lines else "(no output)"
        raise ApiReferenceError(f"vhdl-dump-ast failed for {file_path} (exit {proc.returncode}): {first_line}")
    return proc.stdout


# ---------------------------------------------------------------------------
# Syntax tree helpers
#
# A node is either {"Node": {"kind": ..., "children": [...]}} or, only at
# the tree root, the bare {"kind": "DesignFile", "children": [...]}. A leaf
# is {"Token": {"kind": ..., "text": ..., "leading_trivia": [...]}}.
# ---------------------------------------------------------------------------


def is_token(element):
    """True if element is a {"Token": {...}} leaf."""
    return isinstance(element, dict) and "Token" in element


def token_of(element):
    """The inner {"kind", "text", "leading_trivia"} dict of a Token leaf."""
    return element["Token"]


def _raw(element):
    """The {"kind", "children"} dict of a Node, unwrapping {"Node": {...}} (or the bare root)."""
    if isinstance(element, dict) and "Node" in element:
        return element["Node"]
    return element


def kind(element):
    """The node kind (e.g. "SubprogramDeclaration"), or None for a Token."""
    raw = _raw(element)
    return raw.get("kind") if isinstance(raw, dict) else None


def children(element):
    """The direct children of a Node (Token leaves and/or further Nodes)."""
    raw = _raw(element)
    return raw.get("children", []) if isinstance(raw, dict) else []


def find_all(element, *wanted_kinds):
    """All descendant (or self) Nodes of the given kind(s), in document order."""
    wanted = set(wanted_kinds)
    found = []

    def walk(node):
        if kind(node) in wanted:
            found.append(node)
        for child in children(node):
            if not is_token(child):
                walk(child)

    walk(element)
    return found


def _tokens(element):
    """All Token leaves under element (or element itself), in document order."""
    if is_token(element):
        yield element
        return
    for child in children(element):
        yield from _tokens(child)


def _first_token(element):
    """The first Token leaf under element, in document order, or None."""
    for token in _tokens(element):
        return token
    return None


def text_of(*elements):
    """
    The source text of one or more subtrees: token texts joined, with a
    single space inserted wherever a token's leading trivia is non-empty
    (i.e. it was preceded by whitespace or a comment in the source).
    """
    pieces = []
    for element in elements:
        for token in _tokens(element):
            tok = token_of(token)
            if pieces and tok["leading_trivia"]:
                pieces.append(" ")
            pieces.append(tok["text"])
    return "".join(pieces)


def _keyword(token):
    """The keyword name of a Token (e.g. "Impure"), or None if it isn't a keyword token."""
    raw_kind = token_of(token)["kind"]
    return raw_kind.get("Keyword") if isinstance(raw_kind, dict) else None


def _direct_keywords(element):
    """The set of keyword names among element's direct Token children."""
    return {_keyword(c) for c in children(element) if is_token(c)} - {None}


def _identifier_tokens(identifier_list):
    """The Identifier Token leaves directly inside an IdentifierList (skipping commas)."""
    return [c for c in children(identifier_list) if is_token(c) and token_of(c)["kind"] == "Identifier"]


def _find_child(element, wanted_kind):
    """The first direct child Node of the given kind, or None."""
    for child in children(element):
        if kind(child) == wanted_kind:
            return child
    return None


# ---------------------------------------------------------------------------
# Line numbers
# ---------------------------------------------------------------------------


def _trivia_text(trivia_entry):
    """The decoded text of a comment-shaped trivia entry (e.g. LineComment), or ""."""
    for value in trivia_entry.values():
        if isinstance(value, dict) and "value" in value:
            data = bytes(value["value"])
            return data.decode(value.get("encoding", "utf-8"), errors="replace")
    return ""


def _trivia_newlines(trivia_entry):
    """How many line breaks a single trivia entry accounts for."""
    if "LineFeeds" in trivia_entry:
        return trivia_entry["LineFeeds"]
    if "Spaces" in trivia_entry or "HorizontalTabs" in trivia_entry:
        return 0
    # A comment or any other trivia kind this converter does not know about
    # by name: count embedded newlines in its decoded text, if it has one
    # (covers a hypothetical multi-line block comment).
    return _trivia_text(trivia_entry).count("\n")


def annotate_lines(tree):
    """
    Walk every token of the whole syntax tree once, in document order, and
    return a dict mapping id(token_dict) -> 1-based line number, computed
    from LineFeeds trivia (and newlines inside token text or comments).
    """
    lines = {}
    current_line = [1]

    def walk(element):
        if is_token(element):
            tok = token_of(element)
            for trivia in tok["leading_trivia"]:
                current_line[0] += _trivia_newlines(trivia)
            lines[id(tok)] = current_line[0]
            current_line[0] += tok["text"].count("\n")
            return
        for child in children(element):
            walk(child)

    walk(tree)
    return lines


def line_of(lines, token):
    """The line number of a Token leaf, from the dict built by annotate_lines."""
    return lines[id(token_of(token))]


# ---------------------------------------------------------------------------
# Doc comments
# ---------------------------------------------------------------------------

_LICENSE_MARKER = "This Source Code Form"


def _comment_text(trivia_list):
    """
    The contiguous block of "--" line comments directly before a token
    (i.e. the last run not broken by a blank line), stripped of "--" and
    one following space, joined with "\\n". None if there is no such block.
    """
    collected = []
    for entry in trivia_list:
        if "LineComment" in entry:
            body = _trivia_text(entry)[2:]
            if body.startswith(" "):
                body = body[1:]
            collected.append(body)
        elif _trivia_newlines(entry) >= 2:
            collected = []  # a blank line ends (and restarts) the block
    return "\n".join(collected) if collected else None


def leading_doc(element):
    """The doc comment directly above element's first token, or None."""
    first = _first_token(element)
    return _comment_text(token_of(first)["leading_trivia"]) if first is not None else None


def package_doc(preamble):
    """The package's own doc comment, or None (also None for the MPL license header)."""
    doc = leading_doc(preamble)
    if doc is not None and _LICENSE_MARKER in doc:  # pylint: disable=unsupported-membership-test
        return None
    return doc


# ---------------------------------------------------------------------------
# Declaration converters
# ---------------------------------------------------------------------------

_PARAMETER_CLASS_KEYWORDS = {"Constant": "constant", "Variable": "variable", "Signal": "signal", "File": "file"}
_MODE_KEYWORDS = {"In": "in", "Out": "out", "Inout": "inout", "Buffer": "buffer", "Linkage": "linkage"}


def convert_parameter(iod):
    """
    Convert one InterfaceObjectDeclaration/InterfaceFileDeclaration node to
    a list of parameter dicts (one per identifier).

    VHDL default rules for an omitted object class: "constant" when the
    (explicit or default) mode is "in", else "variable" -- except a file
    parameter, which is always class "file" and defaults to mode "inout".
    """
    keywords = _direct_keywords(iod)
    is_file_param = kind(iod) == "InterfaceFileDeclaration"
    mode = next((v for k, v in _MODE_KEYWORDS.items() if k in keywords), "inout" if is_file_param else "in")
    if is_file_param:
        param_class = "file"
    else:
        param_class = next(
            (v for k, v in _PARAMETER_CLASS_KEYWORDS.items() if k in keywords),
            "constant" if mode == "in" else "variable",
        )

    subtype_node = _find_child(iod, "SubtypeIndication")
    param_type = text_of(subtype_node) if subtype_node is not None else None

    default = None
    init_node = _find_child(iod, "InitialValue")
    if init_node is not None:
        default = text_of(*children(init_node)[1:])

    ident_list = _find_child(iod, "IdentifierList")
    return [
        {"name": token_of(tok)["text"], "class": param_class, "mode": mode, "type": param_type, "default": default}
        for tok in _identifier_tokens(ident_list)
    ]


def convert_subprogram_entry(decl, lines, _file_path):
    """Convert one top-level SubprogramDeclaration node to a list holding a single subprogram dict."""
    return [convert_subprogram(decl, lines)]


def convert_subprogram(decl, lines):
    """Convert one SubprogramDeclaration node (top-level or a protected type method) to a subprogram dict."""
    spec = children(decl)[0]
    func = kind(spec) == "FunctionSpecification"

    name_tok = next(c for c in children(spec) if is_token(c) and token_of(c)["kind"] in ("Identifier", "StringLiteral"))
    name_text = token_of(name_tok)["text"]
    operator = token_of(name_tok)["kind"] != "Identifier"
    name = name_text.strip('"') if operator else name_text

    pure = None if not func else "Impure" not in _direct_keywords(spec)

    parameters = []
    for iod in find_all(spec, "InterfaceObjectDeclaration", "InterfaceFileDeclaration"):
        parameters.extend(convert_parameter(iod))

    return_type = None
    if func:
        return_name = _find_child(spec, "Name")
        if return_name is not None:
            return_type = text_of(return_name)

    return {
        "kind": "function" if func else "procedure",
        "name": name,
        "operator": operator,
        "pure": pure,
        "line": line_of(lines, name_tok),
        "doc": leading_doc(decl),
        "parameters": parameters,
        "return_type": return_type,
    }


def convert_alias(decl, lines, _file_path=None):
    """Convert one AliasDeclaration node to a list holding a single alias dict."""
    direct = children(decl)
    name_tok = next(c for c in direct if is_token(c) and token_of(c)["kind"] == "Identifier")
    target_node = _find_child(decl, "Name")
    target = text_of(target_node) if target_node is not None else None

    signature = []
    return_type = None
    sig_node = _find_child(decl, "Signature")
    if sig_node is not None:
        type_mark_list = _find_child(sig_node, "TypeMarkList")
        if type_mark_list is not None:
            for child in children(type_mark_list):
                if kind(child) == "Name":
                    signature.append(text_of(child))
                elif kind(child) == "ReturnType":
                    return_name = _find_child(child, "Name")
                    if return_name is not None:
                        return_type = text_of(return_name)

    return [
        {
            "name": token_of(name_tok)["text"],
            "line": line_of(lines, name_tok),
            "target": target,
            "signature": signature,
            "return_type": return_type,
        }
    ]


def convert_constant(decl, lines, _file_path=None):
    """Convert one ConstantDeclaration node to a list of constant dicts (one per identifier)."""
    ident_list = _find_child(decl, "IdentifierList")
    subtype_node = _find_child(decl, "SubtypeIndication")
    const_type = text_of(subtype_node) if subtype_node is not None else None

    value = None
    init_node = _find_child(decl, "InitialValue")
    if init_node is not None:
        value = text_of(*children(init_node)[1:])

    doc = leading_doc(decl)
    return [
        {"name": token_of(tok)["text"], "line": line_of(lines, tok), "doc": doc, "type": const_type, "value": value}
        for tok in _identifier_tokens(ident_list)
    ]


def convert_subtype(decl, lines, _file_path=None):
    """Convert one SubtypeDeclaration node to a list holding a single subtype dict."""
    direct = children(decl)
    name_tok = next(c for c in direct if is_token(c) and token_of(c)["kind"] == "Identifier")
    subtype_node = _find_child(decl, "SubtypeIndication")
    return [
        {
            "name": token_of(name_tok)["text"],
            "line": line_of(lines, name_tok),
            "doc": leading_doc(decl),
            "definition": text_of(subtype_node) if subtype_node is not None else None,
        }
    ]


_OBJECT_CLASS = {"SignalDeclaration": "signal", "VariableDeclaration": "shared variable", "FileDeclaration": "file"}


def convert_object(decl, lines, _file_path=None):
    """Convert one Signal/Variable/File Declaration node to a list of object dicts (one per identifier)."""
    ident_list = _find_child(decl, "IdentifierList")
    subtype_node = _find_child(decl, "SubtypeIndication")
    obj_type = text_of(subtype_node) if subtype_node is not None else None
    obj_class = _OBJECT_CLASS[kind(decl)]
    doc = leading_doc(decl)
    return [
        {"name": token_of(tok)["text"], "class": obj_class, "line": line_of(lines, tok), "doc": doc, "type": obj_type}
        for tok in _identifier_tokens(ident_list)
    ]


def _convert_record_type(def_node, common):
    """Build a "record" type dict: {..., "elements": [{"name", "type"}, ...]}."""
    elements = []
    for element_decl in find_all(def_node, "ElementDeclaration"):
        ident_list = _find_child(element_decl, "IdentifierList")
        subtype_node = _find_child(element_decl, "SubtypeIndication")
        element_type = text_of(subtype_node) if subtype_node is not None else None
        for tok in _identifier_tokens(ident_list):
            elements.append({"name": token_of(tok)["text"], "type": element_type})
    return {**common, "kind": "record", "elements": elements}


def _convert_enumeration_type(def_node, common):
    """Build an "enumeration" type dict: {..., "literals": [name, ...]}."""
    enum_list = _find_child(def_node, "EnumerationList")
    literals = []
    if enum_list is not None:
        for child in children(enum_list):
            if is_token(child) and token_of(child)["kind"] in ("Identifier", "CharacterLiteral"):
                literals.append(token_of(child)["text"])
    return {**common, "kind": "enumeration", "literals": literals}


def _convert_protected_type(def_node, lines, common, file_path):
    """Build a "protected" type dict: {..., "subprograms": [...]} (its methods)."""
    subprograms = []
    decl_part = _find_child(def_node, "ProtectedTypeDeclarativePart")
    if decl_part is not None:
        for member in children(decl_part):
            if kind(member) != "SubprogramDeclaration":
                first = _first_token(member)
                where_line = line_of(lines, first) if first is not None else "?"
                raise ApiReferenceError(
                    f"Unhandled protected type member kind '{kind(member)}' at {file_path}:{where_line}"
                )
            subprograms.append(convert_subprogram(member, lines))
    return {**common, "kind": "protected", "subprograms": subprograms}


def convert_type(decl, lines, file_path):
    """Convert one FullTypeDeclaration node to a list holding a single type dict."""
    direct = children(decl)
    name_tok = next(c for c in direct if is_token(c) and token_of(c)["kind"] == "Identifier")
    common = {"name": token_of(name_tok)["text"], "line": line_of(lines, name_tok), "doc": leading_doc(decl)}

    def_node = next((c for c in direct if not is_token(c)), None)
    def_kind = kind(def_node)

    if def_kind == "RecordTypeDefinition":
        return [_convert_record_type(def_node, common)]
    if def_kind == "EnumerationTypeDefinition":
        return [_convert_enumeration_type(def_node, common)]
    if def_kind == "ProtectedTypeDeclaration":
        return [_convert_protected_type(def_node, lines, common, file_path)]

    # Array, access and file types (and anything else vhdl-dump-ast introduces):
    # kept as "other" with the raw source-text definition.
    return [{**common, "kind": "other", "definition": text_of(def_node) if def_node is not None else None}]


_KIND_HANDLERS = {
    "SubprogramDeclaration": ("subprograms", convert_subprogram_entry),
    "AliasDeclaration": ("aliases", convert_alias),
    "ConstantDeclaration": ("constants", convert_constant),
    "SubtypeDeclaration": ("subtypes", convert_subtype),
    "FullTypeDeclaration": ("types", convert_type),
    "SignalDeclaration": ("objects", convert_object),
    "VariableDeclaration": ("objects", convert_object),
    "FileDeclaration": ("objects", convert_object),
}


def convert_package(pkg_node, lines, file_path, repo_relative_path):
    """Convert one PackageDeclaration node to a package dict."""
    preamble = _find_child(pkg_node, "PackagePreamble")
    name_tok = next(c for c in children(preamble) if is_token(c) and token_of(c)["kind"] == "Identifier")
    name = token_of(name_tok)["text"]

    package = {
        "library": LIBRARY_NAME,
        "name": name,
        "source": repo_relative_path,
        "line": line_of(lines, name_tok),
        "private": name.endswith("_private_pkg"),
        "doc": package_doc(preamble),
        "types": [],
        "subtypes": [],
        "constants": [],
        "objects": [],
        "subprograms": [],
        "aliases": [],
    }

    decl_part = _find_child(pkg_node, "PackageDeclarativePart")
    for decl in children(decl_part) if decl_part is not None else []:
        if is_token(decl):
            continue
        handler = _KIND_HANDLERS.get(kind(decl))
        if handler is None:
            first = _first_token(decl)
            where_line = line_of(lines, first) if first is not None else "?"
            raise ApiReferenceError(f"Unhandled declaration kind '{kind(decl)}' at {file_path}:{where_line}")
        bucket, convert = handler
        package[bucket].extend(convert(decl, lines, file_path))

    return package


def convert_package_file(tree, file_path, package_name, repo_relative_path):
    """Find and convert the PackageDeclaration for package_name in a parsed syntax tree, or None."""
    lines = annotate_lines(tree)
    for pkg_node in find_all(tree, "PackageDeclaration"):
        preamble = _find_child(pkg_node, "PackagePreamble")
        name_tok = next(c for c in children(preamble) if is_token(c) and token_of(c)["kind"] == "Identifier")
        if token_of(name_tok)["text"] == package_name:
            return convert_package(pkg_node, lines, str(file_path), repo_relative_path)
    return None


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
    """Run vhdl-dump-ast on every in-scope package file and extract the full VHDL symbol table."""
    package_files = find_package_files(root)
    check_vhdl_dump_ast_available()
    generator = check_vhdl_dump_ast_version()

    packages = []
    for file_path, package_name in package_files:
        stdout = run_vhdl_dump_ast(file_path)
        tree = json.loads(stdout)
        package = convert_package_file(tree, file_path, package_name, file_path.relative_to(root).as_posix())
        if package is not None:
            packages.append(package)

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
