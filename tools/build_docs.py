#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Command line utility to build documentation/website
"""

import re
from subprocess import check_call
from pathlib import Path
from sys import argv, executable
from tempfile import TemporaryDirectory

ROOT = Path(__file__).parent.parent

# Pages that do not document how to use VUnit, left out of llms-full.txt
LLMS_FULL_EXCLUDED = ("about", "blog/", "contributing", "genindex", "license", "release_notes", "testimonials/")


def sphinx(builder, output_path, args):
    """
    Build the documentation with a Sphinx builder
    """
    check_call([executable, "-m", "sphinx"] + args + ["-TEWanb", builder, ROOT / "docs", output_path])


def write_llms_full_txt(text_path, output_file):
    """
    Concatenate the pages of a text build into one file for AI agents, the front page first
    """
    pages = []
    for path in Path(text_path).rglob("*.txt"):
        docname = path.relative_to(text_path).with_suffix("").as_posix()
        if any(docname == name or (name.endswith("/") and docname.startswith(name)) for name in LLMS_FULL_EXCLUDED):
            continue
        text = path.read_text(encoding="utf-8")
        title = text.splitlines()[0]
        pages.append((docname, f"# {title}\n\nSource: https://vunit.github.io/{docname}.html\n\n{text.rstrip()}\n"))

    pages.sort(key=lambda page: (page[0] != "index", page[0]))
    Path(output_file).write_text("\n".join(page for _, page in pages), encoding="utf-8")


# A package declaration, not a body or an instantiation
_PACKAGE_RE = re.compile(r"^[ \t]*package\s+(?!body\b)(\w+)\s+is\b(?!\s*new\b)", re.MULTILINE | re.IGNORECASE)
_LICENSE_RE = re.compile(r"\A(?:--[^\n]*\n)*?--[^\n]*Mozilla Public[^\n]*\n(?:--[^\n]*\n)*")


def vhdl_package_declarations(root=ROOT):
    """
    The declarations of the public vunit_lib packages, with their context and doc comments,
    as llms-full.txt pages. Most are not included by any documentation page.
    """
    vhdl_root = Path(root) / "vunit" / "vhdl"
    pages = []
    for path in sorted(vhdl_root.glob("**/src/**/*.vhd")):
        if "osvvm" in path.relative_to(vhdl_root).parts:
            continue
        text = path.read_text(encoding="utf-8")
        # The first package with the context and comments above it, the others from their declaration
        license_header = _LICENSE_RE.match(text)
        start = license_header.end() if license_header else 0
        for match in _PACKAGE_RE.finditer(text):
            start = match.start() if start is None else start
            name = match.group(1)
            end_re = re.compile(rf"^[ \t]*end(\s+package)?(\s+{name})?\s*;[^\n]*", re.MULTILINE | re.IGNORECASE)
            end = end_re.search(text, match.end()).end()
            if not name.endswith("_private_pkg"):
                source = path.relative_to(root).as_posix()
                pages.append(
                    (
                        name,
                        f"# VHDL package {name}\n\nSource: https://github.com/VUnit/vunit/blob/master/{source}\n\n"
                        f"{text[start:end].strip()}\n",
                    )
                )
            start = None
    return "\n".join(page for _, page in sorted(pages))


def main():
    """
    Build documentation/website, and all pages and VHDL package declarations as plain text in
    llms-full.txt for AI agents
    """
    output_path = Path(argv[1])
    args = argv[2:]
    sphinx("html", output_path, args)
    with TemporaryDirectory() as temp_path:
        text_path = Path(temp_path) / "text"
        sphinx("text", text_path, args + ["-d", str(Path(temp_path) / "doctrees")])
        write_llms_full_txt(text_path, output_path / "llms-full.txt")
    with (output_path / "llms-full.txt").open("a", encoding="utf-8") as fptr:
        fptr.write("\n" + vhdl_package_declarations())


if __name__ == "__main__":
    main()
