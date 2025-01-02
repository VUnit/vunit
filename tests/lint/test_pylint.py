# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Pylint check
"""


import unittest
from subprocess import check_call
from pathlib import Path
import sys
from tests.lint.test_pycodestyle import get_files_and_folders


class TestPylint(unittest.TestCase):
    """
    Check that there are no pylint errors or warnings
    """

    @staticmethod
    def test_pylint():
        check_call(
            [
                sys.executable,
                "-m",
                "pylint",
                "--rcfile=" + str(Path(__file__).parent / "pylintrc"),
            ]
            + get_files_and_folders()
        )
