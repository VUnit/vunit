# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
Check that README.rst matches VUnit docstring
"""

import unittest
from warnings import simplefilter, catch_warnings
from pathlib import Path
from vunit import ROOT
from vunit.about import doc


class TestReadMe(unittest.TestCase):
    """
    Check that README.rst matches VUnit docstring
    """

    def test_that_readme_file_matches_vunit_docstring(self):
        with catch_warnings():
            simplefilter("ignore", category=DeprecationWarning)
            with Path(ROOT, "README.rst").open("rU") as readme:
                self.assertEqual(readme.read(), doc())
