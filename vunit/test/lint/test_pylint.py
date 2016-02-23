# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Pylint check
"""


import unittest
from subprocess import check_call
from os.path import join, dirname
import sys
from vunit import ROOT


class TestPylint(unittest.TestCase):
    """
    Check that there are no pylint errors or warnings
    """
    @staticmethod
    def test_pylint():
        check_call([sys.executable, "-m", "pylint",
                    "--rcfile=" + join(dirname(__file__), "pylintrc"),
                    join(ROOT, "vunit")])
