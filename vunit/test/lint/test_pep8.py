# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
PEP8 check
"""

import unittest
from subprocess import check_call
from vunit import ROOT
import sys


class TestPep8(unittest.TestCase):
    """
    Test that all python code follows PEP8 Python coding standard
    """
    @staticmethod
    def test_pep8():
        check_call([sys.executable, "-m", "pep8",
                    "--show-source",
                    "--show-pep8",
                    "--max-line-length=120",
                    "--ignore=E402",
                    ROOT])
