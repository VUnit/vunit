# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""Generate VUnit project scripts without interacting with a user interface."""

import json
import keyword
import os
import re
from pathlib import Path
from typing import NamedTuple

HDL_EXTENSIONS = {".vhd", ".vhdl", ".v", ".sv"}


class SourceLocation(NamedTuple):
    """A selected source path and its directory recursion mode."""

    path: Path
    recursive: bool = False


def hdl_files(location, recursive=False):
    """Discover supported files in a directory or at a file path."""
    candidates = (location.rglob("*") if recursive else location.iterdir()) if location.is_dir() else (location,)
    return sorted(item for item in candidates if item.is_file() and item.suffix.lower() in HDL_EXTENSIONS)


def validate_library(library, existing=()):
    """Validate a library name against previous selections."""
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", library) or library.lower() == "work":
        raise ValueError("Use a library name starting with a letter, followed by letters, numbers, or '_'; not 'work'.")
    if library.lower() in (name.lower() for name in existing):
        raise ValueError(f"Library name already entered: {library}")


def validate_root(root):
    """Validate the project destination without creating it."""
    if root.exists() and not root.is_dir():
        raise ValueError(f"Not a directory: {root}")
    if (root / "run.py").exists():
        raise ValueError(f"Will not overwrite existing {root / 'run.py'}")


def validate_sources(libraries):
    """Validate the selected source locations."""
    for locations in libraries.values():
        for source in locations:
            if not source.path.exists() or not hdl_files(source.path, source.recursive):
                raise ValueError(f"Source path missing or contains no supported HDL files: {source.path}")


def _python_path(path, root):
    """Generate a Python path expression relative to the project root."""
    try:
        relative = os.path.relpath(path, root)
    except ValueError:
        return f"Path({json.dumps(str(path), ensure_ascii=False)})"
    return "root" + "".join(f" / {json.dumps(part, ensure_ascii=False)}" for part in Path(relative).parts)


def _make_run_script(root, libraries):
    """Render the project script with per-library source locations."""
    files = {
        path
        for locations in libraries.values()
        for source in locations
        for path in hdl_files(source.path, source.recursive)
    }
    sections = ["from pathlib import Path\nfrom vunit import VUnit", "root = Path(__file__).resolve().parent"]
    project = ["vu = VUnit.from_argv()"]
    if any(path.suffix.lower() in {".vhd", ".vhdl"} for path in files):
        project.append("vu.add_vhdl_builtins()")
    if any(path.suffix.lower() in {".v", ".sv"} for path in files):
        project.append("vu.add_verilog_builtins()")
    sections.append("\n".join(project))

    used = {"root", "vu", "Path", "VUnit"}
    for library, locations in libraries.items():
        variable = library
        if keyword.iskeyword(variable) or variable in used:
            variable += "_lib"
            while variable in used or variable in libraries:
                variable += "_lib"
        used.add(variable)
        lines = [f"{variable} = vu.add_library({json.dumps(library, ensure_ascii=False)})"]
        for source in locations:
            path = _python_path(source.path, root)
            if source.path.is_dir():
                for suffix in sorted({item.suffix for item in hdl_files(source.path, source.recursive)}):
                    recursive = ' / "**"' if source.recursive else ""
                    lines.append(f'{variable}.add_source_files({path}{recursive} / {json.dumps("*" + suffix)})')
            else:
                lines.append(f"{variable}.add_source_file({path})")
        sections.append("\n".join(lines))
    sections.append("vu.main()")
    return "\n\n".join(sections) + "\n"


def _prepare(config):
    """Normalize and validate a project configuration."""
    root = Path(os.path.expandvars(str(config["root"]))).expanduser().resolve()
    validate_root(root)
    libraries = {}
    for library, entries in config["libraries"].items():
        validate_library(library, libraries)
        locations = []
        for entry in entries:
            path = Path(os.path.expandvars(str(entry["path"]))).expanduser()
            if not path.is_absolute():
                path = root / path
            locations.append(SourceLocation(path.resolve(), entry.get("recursive", False)))
        libraries[library] = locations
    if not libraries:
        raise ValueError("At least one library is required.")
    validate_sources(libraries)
    return root, libraries


def preview(config):
    """Validate and render a project without creating any files."""
    root, libraries = _prepare(config)
    return {"files": [{"path": str(root / "run.py"), "content": _make_run_script(root, libraries)}]}


def generate(config):
    """Create a project and return a JSON-serializable summary."""
    root, libraries = _prepare(config)
    content = _make_run_script(root, libraries)
    run_script = root / "run.py"
    root.mkdir(parents=True, exist_ok=True)
    with run_script.open("x", encoding="utf-8") as stream:
        stream.write(content)
    return {
        "command": "create_project",
        "files_created": [str(run_script)],
        "details": {
            "root": str(root),
            "libraries": {
                name: [{"path": str(source.path), "recursive": source.recursive} for source in locations]
                for name, locations in libraries.items()
            },
        },
    }
