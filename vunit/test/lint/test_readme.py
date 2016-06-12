# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Check that README.rst matches VUnit docstring
"""

import unittest
from os.path import join
from vunit import ROOT
from vunit.about import doc


class TestReadMe(unittest.TestCase):
    """
    Check that README.rst matches VUnit docstring
    """

    def test_that_readme_file_matches_vunit_docstring(self):
        with open(join(ROOT, 'README.rst')) as readme:
            self.assertEqual(readme.read(), doc())
