# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Pylint check
"""


import unittest
from subprocess import call
from vunit import ROOT
from os.path import join, dirname
import sys


class TestPylint(unittest.TestCase):
    """
    Check that there are no pylint errors or warnings
    """
    @staticmethod
    def test_pylint():
        ret = call([sys.executable, "-m", "pylint",
                    "--rcfile=" + join(dirname(__file__), "pylintrc"),
                    join(ROOT, "vunit")])
        assert (ret & ~(4 | 8 | 16)) == 0
