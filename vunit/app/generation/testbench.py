# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""Generate a VUnit VHDL testbench without interacting with a user interface."""

import re
from pathlib import Path

from vunit.parsing.encodings import HDL_FILE_ENCODING
from vunit.vhdl_parser import VHDLEntity, VHDLReference, find_closing_delimiter, remove_comments

_IDENTIFIER = re.compile(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)*\Z", re.IGNORECASE)
_TOKEN = re.compile(r'"(?:[^"]|"")*"|\'[^\']\'|\\[^\\\r\n]+\\|[^"\'\\]+|.', re.DOTALL)
_LIBRARY_NAME = re.compile(r"\\[^\\\r\n]+\\|[a-z][a-z0-9_]*", re.IGNORECASE)


def _normalize(code):
    return "".join(
        token if token.startswith(('"', "'", "\\")) else re.sub(r"\bport(?=\s*\()", "\nport", token.lower())
        for token in _TOKEN.findall(code)
    )


def _mask_literals(code):
    """Shield literal contents from the VUnit parser's delimiter scanning."""
    replacements = {}
    tokens = []
    for token in _TOKEN.findall(code):
        if token.startswith('"'):
            placeholder = f'"vunit_literal_{len(replacements)}"'
        elif len(token) == 3 and token.startswith("'"):
            placeholder = f"'{chr(0xE000 + len(replacements))}'"
        else:
            tokens.append(token)
            continue
        replacements[placeholder] = token
        tokens.append(placeholder)
    return "".join(tokens), replacements


def _restore_literals(text, replacements):
    """Restore original literal contents without recursive substitutions."""
    if not replacements:
        return text
    pattern = re.compile("|".join(re.escape(placeholder) for placeholder in replacements))
    return pattern.sub(lambda match: replacements[match.group(0)], text)


def _names(element):
    """Expand a grouped interface declaration into individual names."""
    names = [name.strip() for name in element.identifier.split(",")]
    if any(not _IDENTIFIER.fullmatch(name) for name in names):
        raise ValueError(f"Unsupported interface identifier: {element.identifier}")
    return names


def _unique_name(base, used):
    """Choose an identifier that does not collide with existing names."""
    name = base
    while name.lower() in used:
        name += "_signal"
    used.add(name.lower())
    return name


def _context_clauses(prefix, replacements):
    """Recreate the source's library, use, and context clauses."""
    libraries = [
        f"library {name};"
        for clause in re.findall(r"\blibrary\s+([^;]+);", prefix, re.IGNORECASE)
        for name in _LIBRARY_NAME.findall(clause)
    ]
    uses = []
    for reference in VHDLReference.find(prefix):
        if reference.reference_type in {"package", "context"}:
            parts = [reference.library, reference.design_unit]
            if reference.name_within is not None:
                parts.append(reference.name_within)
            keyword = "use" if reference.reference_type == "package" else "context"
            uses.append(f"{keyword} {'.'.join(parts)};")
    return list(dict.fromkeys(_restore_literals(item.strip(), replacements) for item in libraries + uses))


def _entity_and_context(code):
    """Parse one supported entity and its preceding context clauses."""
    code, replacements = _mask_literals(_normalize(remove_comments(code)))
    entities = list(VHDLEntity.find(code))
    if len(entities) != 1:
        raise ValueError(f"Expected exactly one VHDL entity, found {len(entities)}")
    entity = entities[0]
    if not _IDENTIFIER.fullmatch(entity.identifier):
        raise ValueError(f"Unsupported entity identifier: {entity.identifier}")
    for element in entity.generics + entity.ports:
        element.subtype_indication.code = _restore_literals(element.subtype_indication.code, replacements)
        if element.init_value is not None:
            element.init_value = _restore_literals(element.init_value, replacements)

    start = re.search(rf"\bentity\s+{re.escape(entity.identifier)}\s+is\b", code)
    body = code[start.end() :]
    generic_match = re.search(r"\bgeneric\s*\(", body)
    if generic_match:
        contents = body[generic_match.end() :]
        end = find_closing_delimiter("\\(", "\\)", contents)
        if re.search(r"(?:^|;)\s*(?:package|type|(?:impure\s+)?function|procedure)\b", contents[: end - 1]):
            raise ValueError("Generic packages, types, and subprograms are not supported")

    return entity, _context_clauses(code[: start.start()], replacements)


def _interface_declarations(entity):
    """Create testbench declarations and mappings for an entity interface."""
    generic_names = [(generic, generic_name) for generic in entity.generics for generic_name in _names(generic)]
    used = {generic_name.lower() for _, generic_name in generic_names} | {"runner_cfg", "runner", "dut", "test_runner"}
    generic_map = []
    declarations = ["    runner_cfg : string"]
    for generic, generic_name in generic_names:
        testbench_name = _unique_name("dut_runner_cfg", used) if generic_name.lower() == "runner_cfg" else generic_name
        default = f" := {generic.init_value}" if generic.init_value is not None else ""
        declarations.append(f"    {testbench_name} : {generic.subtype_indication.code}{default}")
        generic_map.append((generic_name, testbench_name))

    signals = []
    port_map = []
    for port in entity.ports:
        for port_name in _names(port):
            signal_name = _unique_name(port_name, used)
            default = f" := {port.init_value}" if port.init_value is not None else ""
            signals.append(f"  signal {signal_name} : {port.subtype_indication.code}{default};")
            port_map.append((port_name, signal_name))

    return declarations, signals, generic_map, port_map


def _testbench_context(context, library):
    """Combine source and testbench clauses without duplicating declarations."""
    clauses = context + [f"library {library};", "library vunit_lib;", "context vunit_lib.vunit_context;"]
    clauses = [re.sub(r"^(use|context)\s+work\.", rf"\1 {library}.", clause, flags=re.IGNORECASE) for clause in clauses]
    unique = {}
    for clause in clauses:
        parts = re.split(r"(\\[^\\\r\n]+\\)", clause)
        key = "".join(part if part.startswith("\\") else part.casefold() for part in parts)
        unique.setdefault(key, clause)
    clauses = list(unique.values())
    lines = [clause for clause in clauses if clause.lower().startswith("library ")]
    lines += [clause for clause in clauses if not clause.lower().startswith("library ")]
    return lines


DEFAULT_TEST = "first_test"


def validate_tests(tests):
    """Validate explicitly specified test names and return them unchanged and in order.

    A name is accepted when VUnit discovers it exactly as written in ``run("name")``. VUnit scans for
    ``run("...")`` with a regular expression that does not understand VHDL's doubled quotation marks, so
    names containing ``"`` cannot be discovered correctly and are rejected. Control characters and characters
    outside the VHDL character set cannot be written in a VHDL string literal.
    """
    if isinstance(tests, str):
        raise ValueError("Tests must be a list of names, not a single string.")
    names = list(tests)
    seen = set()
    for name in names:
        if not isinstance(name, str) or not name.strip():
            raise ValueError("Test names must not be empty or whitespace only.")
        if '"' in name:
            raise ValueError(f"Invalid test name {name!r}: double quotation marks are not supported by VUnit.")
        if not name.isprintable() or any(ord(char) > 255 for char in name):
            raise ValueError(f"Invalid test name {name!r}: only printable characters from the VHDL character set.")
        if name in seen:
            raise ValueError(f"Duplicate test name: {name!r}")
        seen.add(name)
    return names


def _test_branches(tests):
    """Render the run() branches; without named tests a single placeholder test is created."""
    if not tests:
        return [
            f'      if run("{DEFAULT_TEST}") then',
            "        -- vunit: .todo",
            '        error("Tests have yet to be added");',
        ]
    lines = []
    for index, test in enumerate(tests):
        lines += [
            f'      {"elsif" if index else "if"} run("{test}") then',
            "        -- vunit: .todo",
            '        error("This test has yet to be implemented");',
        ]
    return lines


def _make_testbench(entity, context, name, library="work", tests=None):
    """Render a VUnit testbench around the parsed entity."""
    declarations, signals, generic_map, port_map = _interface_declarations(entity)
    lines = _testbench_context(context, library)
    lines += ["", f"entity {name} is", "  generic ("]
    lines += [";\n".join(declarations), "  );", "end entity;", "", f"architecture tb of {name} is"]
    lines += signals + [
        "begin",
        "  test_runner : process",
        "  begin",
        "    test_runner_setup(runner, runner_cfg);",
        "",
        "    while test_suite loop",
        *_test_branches(tests),
        "      end if;",
        "    end loop;",
        "",
        "    test_runner_cleanup(runner);",
        "  end process;",
        "",
        f"  dut : entity {library}.{entity.identifier}",
    ]
    for keyword, mappings in (("generic", generic_map), ("port", port_map)):
        if mappings:
            lines += [
                f"    {keyword} map (",
                ",\n".join(f"      {formal} => {actual}" for formal, actual in mappings),
                "    )",
            ]
    lines[-1] += ";"
    lines += ["end architecture;", ""]
    return "\n".join(lines)


def validate_source(source_path):
    """Parse and validate a VHDL source without writing files."""
    source = Path(source_path).expanduser()
    if source.suffix.lower() not in {".vhd", ".vhdl"}:
        raise ValueError("Only VHDL source files are supported.")
    return _entity_and_context(source.read_text(encoding=HDL_FILE_ENCODING))


def validate_testbench(testbench_path):
    """Validate the output path without creating it."""
    testbench = Path(testbench_path).expanduser()
    if testbench.suffix.lower() not in {".vhd", ".vhdl"} or not _IDENTIFIER.fullmatch(testbench.stem):
        raise ValueError("The testbench filename must be a VHDL identifier with a .vhd or .vhdl extension.")
    if testbench.exists():
        raise ValueError(f"Will not overwrite existing {testbench}")
    return testbench


def validate_library(library):
    """Validate the library containing the entity."""
    if not _IDENTIFIER.fullmatch(library):
        raise ValueError(f"Invalid source library name: {library}")
    return library


def _prepare(source_path, testbench_path, library="work", tests=None):
    """Validate the configuration and render the testbench without writing it."""
    validate_library(library)
    tests = validate_tests(tests or [])
    entity, context = validate_source(source_path)
    testbench = validate_testbench(testbench_path)
    if entity.identifier.lower() == testbench.stem.lower():
        raise ValueError("The testbench entity name must differ from the source entity name")
    return testbench, _make_testbench(entity, context, testbench.stem, library, tests), entity.identifier


def preview(config):
    """Validate and render a testbench without creating any files."""
    testbench, content, _ = _prepare(
        config["source"], config["testbench"], config.get("library", "work"), config.get("tests")
    )
    return {"files": [{"path": str(testbench), "content": content}]}


def generate(config):
    """Create a testbench and return a JSON-serializable summary."""
    library = config.get("library", "work")
    tests = config.get("tests") or []
    testbench, content, entity = _prepare(config["source"], config["testbench"], library, tests)
    testbench.parent.mkdir(parents=True, exist_ok=True)
    with testbench.open("x", encoding=HDL_FILE_ENCODING) as stream:
        stream.write(content)
    return {
        "command": "create_testbench",
        "files_created": [str(testbench)],
        "details": {
            "source": str(config["source"]),
            "library": library,
            "entity": entity,
        },
    }
