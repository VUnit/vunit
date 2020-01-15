# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
Helper functions to generate examples.rst from docstrings in run.py files
"""

import sys
import inspect
from os.path import basename, dirname, isdir, isfile, join
from os import listdir, remove


ROOT = join(dirname(__file__), "..", "docs")


def examples():
    """
    Traverses the examples directory and generates examples.rst with the docstrings
    """
    eg_path = join(ROOT, "..", "examples")
    egs_fptr = open(join(ROOT, "examples.rst"), "w+")
    egs_fptr.write("\n".join([".. _examples:\n", "Examples", "========", "\n"]))
    for language, subdir in {"VHDL": "vhdl", "SystemVerilog": "verilog"}.items():
        egs_fptr.write("\n".join([language, "~~~~~~~~~~~~~~~~~~~~~~~", "\n"]))
        for item in listdir(join(eg_path, subdir)):
            loc = join(eg_path, subdir, item)
            if isdir(loc):
                _data = _get_eg_doc(
                    loc,
                    "https://github.com/VUnit/vunit/tree/master/examples/%s/%s"
                    % (subdir, item),
                )
                if _data:
                    egs_fptr.write(_data)


def _get_eg_doc(location, ref):
    """
    Reads the docstring from a run.py file and rewrites the title to make it a ref
    """
    if not isfile(join(location, "run.py")):
        print(
            "WARNING: Example subdir '"
            + basename(location)
            + "' does not contain a 'run.py' file. Skipping..."
        )
        return None

    print("Generating '_main.py' from 'run.py' in '" + basename(location) + "'...")
    with open(join(location, "run.py"), "r") as ifile:
        with open(join(location, "_main.py"), "w") as ofile:
            ofile.writelines(["def _main():\n"])
            ofile.writelines(["".join(["    ", x]) for x in ifile])

    print("Extracting docs from '" + basename(location) + "'...")
    sys.path.append(location)
    from _main import _main  # pylint: disable=import-error,import-outside-toplevel

    eg_doc = inspect.getdoc(_main)
    del sys.modules["_main"]
    sys.path.remove(location)
    remove(join(location, "_main.py"))

    if not eg_doc:
        print(
            "WARNING: 'run.py' file in example subdir '"
            + basename(location)
            + "' does not contain a docstring. Skipping..."
        )
        return ""

    title = "`%s <%s/>`_" % (eg_doc.split("---", 1)[0][0:-1], ref)
    return "\n".join([title, "-" * len(title), eg_doc.split("---\n", 1)[1], "\n"])
