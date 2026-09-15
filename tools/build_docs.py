#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Command line utility to build documentation/website
"""

from os import environ
from subprocess import check_call
from pathlib import Path
from sys import argv, executable
from tempfile import TemporaryDirectory

from llms_txt import TEXT_DIR_NAME, write_llms_files

ROOT = Path(__file__).parent.parent


def sphinx(builder, output_path, args):
    """
    Build the documentation with a Sphinx builder
    """
    check_call([executable, "-m", "sphinx"] + args + ["-TEWanb", builder, ROOT / "docs", output_path])


def main():
    """
    Build documentation/website, including a text version and llms.txt/llms-full.txt for AI agents
    """
    output_path = Path(argv[1])
    args = argv[2:]
    sphinx("html", output_path, args)
    with TemporaryDirectory() as doctrees:
        sphinx("text", output_path / TEXT_DIR_NAME, args + ["-d", doctrees])
    write_llms_files(output_path, api=environ.get("VUNIT_DOCS_SKIP_API") != "1")


if __name__ == "__main__":
    main()
