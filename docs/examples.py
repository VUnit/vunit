#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

"""
Helper functions to generate content in examples.rst from docstrings in run.py files
"""

import sys
import inspect

from os import listdir, remove
from pathlib import Path
from subprocess import check_call

from io import StringIO
from contextlib import redirect_stdout
from textwrap import indent


ROOT = Path(__file__).parent.parent / "docs"


def examples(debug=False):
    """
    Traverses the examples directory and generates examples.rst with the docstrings
    """
    eg_path = ROOT.parent / "examples"
    for language, subdir in {"VHDL": "vhdl", "SystemVerilog": "verilog"}.items():
        print("\n".join([language, "~~~~~~~~~~~~~~~~~~~~~~~", "\n"]))
        for item in listdir(str(eg_path / subdir)):
            loc = eg_path / subdir / item
            if loc.is_dir():
                f = StringIO()
                with redirect_stdout(f):
                    _data = _get_eg_doc(
                        loc,
                        f"https://github.com/VUnit/vunit/tree/master/examples/{subdir!s}/{item!s}",
                    )
                if debug:
                    print(".. NOTE::")
                    print(indent(f.getvalue(), "  * "))
                if _data:
                    print(_data)


def _get_eg_doc(location: Path, ref):
    """
    Reads the docstring from a run.py file and rewrites the title to make it a ref
    """
    nstr = str(location.name)

    if not (location / "run.py").is_file():
        print("WARNING: Example subdir '" + nstr + "' does not contain a 'run.py' file. Skipping...")
        return None

    print("Generating '_main.py' from 'run.py' in '" + nstr + "'...")
    with (location / "run.py").open("r") as ifile:
        with (location / "_main.py").open("w") as ofile:
            ofile.writelines(["def _main():\n"])
            ofile.writelines(["".join(["    ", x]) for x in ifile])

    print("Extracting docs from '" + nstr + "'...")
    sys.path.append(str(location))
    from _main import _main  # pylint: disable=import-error,import-outside-toplevel

    eg_doc = inspect.getdoc(_main)
    del sys.modules["_main"]
    sys.path.remove(str(location))
    remove(str(location / "_main.py"))

    if not eg_doc:
        print("WARNING: 'run.py' file in example subdir '" + nstr + "' does not contain a docstring. Skipping...")
        return ""

    title = f"`{eg_doc.split('---', 1)[0][0:-1]!s} <{ref!s}/>`_"
    return "\n".join([title, "-" * len(title), eg_doc.split("---\n", 1)[1], "\n"])


if __name__ == "__main__":
    examples(True)
