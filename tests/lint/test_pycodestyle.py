# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
PEP8 check
"""

import unittest
from subprocess import check_call
import sys
from glob import glob
from pathlib import Path
from vunit import ROOT as RSTR

ROOT = Path(RSTR)


class TestPycodestyle(unittest.TestCase):
    """
    Test that all python code follows PEP8 Python coding standard
    """

    @staticmethod
    def test_pycodestyle():
        check_call(
            [
                sys.executable,
                "-m",
                "pycodestyle",
                "--show-source",
                "--show-pep8",
                "--max-line-length=120",
                # W503 mutually exclusive with W504
                # E722 bare except checked by pylint
                "--ignore=E402,W503,E722,E501,E203",
            ]
            + get_files_and_folders()
        )


def get_files_and_folders():
    """
    Return all files and folders which shall be arguments to pycodestyle and pylint
    """
    ret = [str(ROOT / "vunit")]
    ret += list(glob(str(ROOT / "*.py")))
    ret += list(glob(str(ROOT / "tools" / "*.py")))
    return ret
