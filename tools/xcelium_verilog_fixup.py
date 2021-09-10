# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

"""
Perform necessary modifications to VUnit Verilog code to support
Cadence Xcelium
"""

import os
import re
from pathlib import Path


def replace_stop_by_finish(file_name):
    """
    Replace $stop by $finish
    """

    with Path(file_name).open("r", encoding="iso-8859-1") as fptr:
        text = fptr.read()

    text = text.replace("$stop(", "$finish(")

    with Path(file_name).open("w", encoding="iso-8859-1") as fptr:
        fptr.write(text)


def add_finish_after_error(file_name):
    """
    Add $finish after a $error
    """

    with Path(file_name).open("r", encoding="iso-8859-1") as fptr:
        text = fptr.read()

    text = re.sub(r"(\$error\(.*\))", "\\1; $finish(1)", text)

    with Path(file_name).open("w", encoding="iso-8859-1") as fptr:
        fptr.write(text)


def main():
    """
    Remove xcelium incompatabilities from source code
    """
    where = "../vunit/verilog"
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), where))
    for base, _, files in os.walk(root):
        for file_name in files:
            if file_name.endswith(".sv") or file_name.endswith(".svh"):
                replace_stop_by_finish(os.path.join(base, file_name))
                add_finish_after_error(os.path.join(base, file_name))


if __name__ == "__main__":
    main()
