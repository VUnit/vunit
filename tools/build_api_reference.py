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

Set VUNIT_DOCS_SKIP_API=1 to skip the build (prints a warning, writes nothing, exits 0),
e.g. to build the rest of the documentation without vhdl-dump-ast installed.
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
    """Raised for every error of the API reference generator."""


# "package <name> is", not "package body", and not a package instantiation ("is new").
_PACKAGE_RE = re.compile(r"^[ \t]*package\s+(?!body\b)(\w+)\s+is\b\s*(new\b)?", re.MULTILINE)


def find_package_files(root):
    """(path, package name) of every package declaration in vunit/vhdl/**/src, except OSVVM, sorted by name."""
    vhdl_root = root / "vunit" / "vhdl"
    found = []
    for path in sorted(vhdl_root.glob("**/src/**/*.vhd")):
        if "osvvm" not in path.relative_to(vhdl_root).parts:
            text = path.read_text(encoding="utf-8")
            found += [(path, match.group(1)) for match in _PACKAGE_RE.finditer(text) if match.group(2) is None]
    return sorted(found, key=lambda item: item[1])


def check_vhdl_dump_ast_available():
    """Raise ApiReferenceError if vhdl-dump-ast is not on PATH."""
    if shutil.which("vhdl-dump-ast") is None:
        raise ApiReferenceError(
            "vhdl-dump-ast is required to build the API reference; install it with "
            "`cargo install vhdl-dump-ast --version 0.1.0 --locked` or set VUNIT_DOCS_SKIP_API=1"
        )


def check_vhdl_dump_ast_version():
    """Return the vhdl-dump-ast version, raising ApiReferenceError unless it is the syntax tree format pin."""
    proc = subprocess.run(["vhdl-dump-ast", "--version"], capture_output=True, text=True, check=False)
    version_line = (proc.stdout or "").strip()
    if version_line != VHDL_DUMP_AST_VERSION:
        raise ApiReferenceError(
            f"vhdl-dump-ast reports '{version_line}', expected '{VHDL_DUMP_AST_VERSION}'; "
            "the converter must be checked against the new syntax tree format"
        )
    return version_line


def run_vhdl_dump_ast(file_path):
    """The JSON syntax tree of file_path, as a string."""
    proc = subprocess.run(
        ["vhdl-dump-ast", str(file_path), "--trivia", "--no-pretty"], capture_output=True, text=True, check=False
    )
    if proc.returncode != 0:
        first_line = (proc.stderr or "").partition("\n")[0] or "(no output)"
        raise ApiReferenceError(f"vhdl-dump-ast failed for {file_path} (exit {proc.returncode}): {first_line}")
    return proc.stdout


def _normalize(tree):
    """
    Unwrap the {"Node": ...}/{"Token": ...} wrappers of a vhdl-dump-ast tree into
    nodes {"kind", "children"} and tokens {"kind", "text", "trivia", "line"}.
    A keyword token's kind is the keyword name, e.g. "Impure".
    """
    line = 1

    def walk(element):
        nonlocal line
        if "Token" not in element:
            node = element.get("Node", element)
            return {"kind": node["kind"], "children": [walk(child) for child in node.get("children", [])]}
        token = element["Token"]
        line += sum(_newlines(trivia) for trivia in token["leading_trivia"])
        kind = token["kind"]
        result = {
            "kind": kind.get("Keyword") if isinstance(kind, dict) else kind,
            "text": token["text"],
            "trivia": token["leading_trivia"],
            "line": line,
        }
        line += token["text"].count("\n")
        return result

    return walk(tree)


def _comment(trivia):
    """The text of a comment trivia entry, or "" for whitespace."""
    value = next((value for value in trivia.values() if isinstance(value, dict) and "value" in value), None)
    return bytes(value["value"]).decode(value.get("encoding", "utf-8"), errors="replace") if value else ""


def _newlines(trivia):
    return trivia["LineFeeds"] if "LineFeeds" in trivia else _comment(trivia).count("\n")


def _tokens(node):
    """The tokens under node (or node itself), in document order."""
    if "children" not in node:
        yield node
    else:
        for child in node["children"]:
            yield from _tokens(child)


def _find_all(node, *kinds):
    """All nodes of the given kinds under node (or node itself), in document order."""
    if "children" not in node:
        return []
    return ([node] if node["kind"] in kinds else []) + [
        found for child in node["children"] for found in _find_all(child, *kinds)
    ]


def _child(node, kind):
    """The first direct child of the given kind, or None (also for a None node)."""
    return next((child for child in node["children"] if child["kind"] == kind), None) if node else None


def _text(node, skip=0):
    """The source text of node (without its first skip children), whitespace and comments as single spaces."""
    if node is None:
        return None
    pieces = []
    for child in node["children"][skip:] if skip else [node]:
        for token in _tokens(child):
            pieces += [" ", token["text"]] if pieces and token["trivia"] else [token["text"]]
    return "".join(pieces)


def _names(node):
    """The identifier tokens of a declaration (from its identifier list, if it has one)."""
    return [child for child in (_child(node, "IdentifierList") or node)["children"] if child["kind"] == "Identifier"]


def _doc(node):
    """The block of "--" comments directly above node, not separated from it by a blank line, or None."""
    block = []
    for trivia in next(_tokens(node))["trivia"]:
        if "LineComment" in trivia:
            block.append(_comment(trivia)[2:].removeprefix(" "))
        elif _newlines(trivia) >= 2:
            block = []
    return "\n".join(block) if block else None


def _unhandled(node, file_path):
    return ApiReferenceError(
        f"Unhandled declaration kind '{node['kind']}' at {file_path}:{next(_tokens(node))['line']}"
    )


_MODES = ("In", "Out", "Inout", "Buffer", "Linkage")
_CLASSES = ("Constant", "Variable", "Signal", "File")
_OBJECT_CLASSES = {"SignalDeclaration": "signal", "VariableDeclaration": "shared variable", "FileDeclaration": "file"}


def _subprogram(decl):
    """The subprogram dict of a SubprogramDeclaration."""
    spec = decl["children"][0]
    function = spec["kind"] == "FunctionSpecification"
    name = next(child for child in spec["children"] if child["kind"] in ("Identifier", "StringLiteral"))
    parameters = []
    for parameter in _find_all(spec, "InterfaceObjectDeclaration", "InterfaceFileDeclaration"):
        keywords = {child["kind"] for child in parameter["children"]}
        file = parameter["kind"] == "InterfaceFileDeclaration"
        # VHDL defaults: mode "in" ("inout" for a file); class "constant" for mode "in", else "variable"
        mode = next((mode.lower() for mode in _MODES if mode in keywords), "inout" if file else "in")
        default_class = "file" if file else "constant" if mode == "in" else "variable"
        parameter_class = next((c.lower() for c in _CLASSES if c in keywords and not file), default_class)
        parameters += [
            {
                "name": identifier["text"],
                "class": parameter_class,
                "mode": mode,
                "type": _text(_child(parameter, "SubtypeIndication")),
                "default": _text(_child(parameter, "InitialValue"), skip=1),
            }
            for identifier in _names(parameter)
        ]
    return {
        "kind": "function" if function else "procedure",
        "name": name["text"].strip('"'),
        "operator": name["kind"] == "StringLiteral",
        "pure": "Impure" not in {child["kind"] for child in spec["children"]} if function else None,
        "line": name["line"],
        "doc": _doc(decl),
        "parameters": parameters,
        "return_type": _text(_child(spec, "Name")) if function else None,
    }


def _declarations(decl, file_path):
    """(package dict key, list of entries) for one declaration of a package."""
    kind, names, doc = decl["kind"], _names(decl), _doc(decl)
    subtype = _text(_child(decl, "SubtypeIndication"))
    if kind == "SubprogramDeclaration":
        return "subprograms", [_subprogram(decl)]
    if kind == "ConstantDeclaration":
        value = _text(_child(decl, "InitialValue"), skip=1)
        return "constants", [
            {"name": name["text"], "line": name["line"], "doc": doc, "type": subtype, "value": value} for name in names
        ]
    if kind in _OBJECT_CLASSES:
        return "objects", [
            {"name": name["text"], "class": _OBJECT_CLASSES[kind], "line": name["line"], "doc": doc, "type": subtype}
            for name in names
        ]
    entry = {"name": names[0]["text"], "line": names[0]["line"]} if names else {}
    if kind == "SubtypeDeclaration":
        return "subtypes", [{**entry, "doc": doc, "definition": subtype}]
    if kind == "AliasDeclaration":
        marks = _child(_child(decl, "Signature"), "TypeMarkList")
        signature = [_text(mark) for mark in marks["children"] if mark["kind"] == "Name"] if marks else []
        return "aliases", [
            {**entry, "target": _text(_child(decl, "Name")), "signature": signature, "return_type": None}
        ]
    if kind == "FullTypeDeclaration":
        return "types", [_type(decl, {**entry, "doc": doc}, file_path)]
    raise _unhandled(decl, file_path)


def _type(decl, entry, file_path):
    """The type dict of a FullTypeDeclaration, extending entry (its name, line and doc)."""
    definition = next((child for child in decl["children"] if "children" in child), None)
    definition_kind = definition and definition["kind"]
    if definition_kind == "RecordTypeDefinition":
        elements = [
            {"name": name["text"], "type": _text(_child(element, "SubtypeIndication"))}
            for element in _find_all(definition, "ElementDeclaration")
            for name in _names(element)
        ]
        return {**entry, "kind": "record", "elements": elements}
    if definition_kind == "EnumerationTypeDefinition":
        literals = (_child(definition, "EnumerationList") or {"children": []})["children"]
        literals = [literal["text"] for literal in literals if literal["kind"] in ("Identifier", "CharacterLiteral")]
        return {**entry, "kind": "enumeration", "literals": literals}
    if definition_kind == "ProtectedTypeDeclaration":
        members = (_child(definition, "ProtectedTypeDeclarativePart") or {"children": []})["children"]
        for member in members:
            if member["kind"] != "SubprogramDeclaration":
                raise _unhandled(member, file_path)
        return {**entry, "kind": "protected", "subprograms": [_subprogram(member) for member in members]}
    # Array, access and file types
    return {**entry, "kind": "other", "definition": _text(definition)}


def convert_package_file(tree, file_path, package_name, repo_relative_path):
    """The package dict of package_name in a vhdl-dump-ast syntax tree, or None if it is not declared there."""
    for package in _find_all(_normalize(tree), "PackageDeclaration"):
        preamble = _child(package, "PackagePreamble")
        name = _names(preamble)[0]
        if name["text"] != package_name:
            continue
        doc = _doc(preamble)
        result = {
            "library": LIBRARY_NAME,
            "name": package_name,
            "source": repo_relative_path,
            "line": name["line"],
            "private": package_name.endswith("_private_pkg"),
            "doc": None if "This Source Code Form" in (doc or "") else doc,  # not the license header
            **{key: [] for key in ("types", "subtypes", "constants", "objects", "subprograms", "aliases")},
        }
        for decl in (_child(package, "PackageDeclarativePart") or {"children": []})["children"]:
            if "children" in decl:
                key, entries = _declarations(decl, file_path)
                result[key] += entries
        return result
    return None


def check_completeness(json_package_names, expected_package_names):
    """Raise ApiReferenceError listing missing/extra names if the two sets differ."""
    found, expected = set(json_package_names), set(expected_package_names)
    if found != expected:
        raise ApiReferenceError(
            "Package set in the JSON differs from the package declarations found in the source files: "
            f"missing {sorted(expected - found)}, extra {sorted(found - expected)}"
        )


def build_vhdl_api(root, vunit_version):
    """The VHDL symbol table of every in-scope package, extracted with vhdl-dump-ast."""
    package_files = find_package_files(root)
    check_vhdl_dump_ast_available()
    generator = check_vhdl_dump_ast_version()
    packages = []
    for file_path, name in package_files:
        tree = json.loads(run_vhdl_dump_ast(file_path))
        package = convert_package_file(tree, file_path, name, file_path.relative_to(root).as_posix())
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


def _member_dict(name, member_kind, member, has_signature):
    """A Python API member dict; signature is None unless has_signature."""
    sig = str(inspect.signature(member)) if has_signature else None
    return {"name": name, "kind": member_kind, "signature": sig, "doc": inspect.getdoc(member)}


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
            if fget is not None and getattr(fget, "__qualname__", "").startswith(prefix):
                members.append(_member_dict(name, "property", member, False))
        elif inspect.isfunction(member) and member.__qualname__.startswith(prefix):
            members.append(_member_dict(name, "method", member, True))
    return members


def build_class_object(dotted, cls):
    """The Python API object for an autoclass target."""
    return {"name": dotted, "kind": "class", "doc": inspect.getdoc(cls), "members": _class_members(cls)}


def build_module_object(dotted, module, has_members):
    """The Python API object for an automodule target."""
    members = []
    if has_members:
        for name in sorted(vars(module)):
            member = vars(module)[name]
            if name.startswith("_") or getattr(member, "__module__", None) != module.__name__:
                continue
            if inspect.isclass(member):
                members.append(_member_dict(name, "class", member, False))
            elif inspect.isfunction(member):
                members.append(_member_dict(name, "function", member, True))
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
