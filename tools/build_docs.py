#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Command line utility to build documentation/website
"""

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


def main():
    """
    Build documentation/website, and all pages as plain text in llms-full.txt for AI agents
    """
    output_path = Path(argv[1])
    args = argv[2:]
    sphinx("html", output_path, args)
    with TemporaryDirectory() as temp_path:
        text_path = Path(temp_path) / "text"
        sphinx("text", text_path, args + ["-d", str(Path(temp_path) / "doctrees")])
        write_llms_full_txt(text_path, output_path / "llms-full.txt")


if __name__ == "__main__":
    main()
