# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Run the array VHDL package tests
"""


import unittest
from os.path import abspath, join, dirname
from vunit.test.common import has_simulator, create_vunit
from vunit import ROOT


@unittest.skipUnless(has_simulator(), 'Requires simulator')
class TestArray(unittest.TestCase):
    """
    Run the array VHDL package tests
    """

    def run_sim(self, vhdl_standard):
        """
        Utility function to run the array test compiled with vhdl_standard
        """
        output_path = join(dirname(abspath(__file__)), 'array_out')
        src_path = join(ROOT, 'vhdl', 'array')

        vu = create_vunit(clean=True,
                          output_path=output_path,
                          vhdl_standard=vhdl_standard)

        vu.add_library("lib")
        vu.add_array_util("lib")
        vu.add_source_files(join(src_path, "test", "*.vhd"), "lib")

        try:
            vu.main()
        except SystemExit as ex:
            self.assertEqual(ex.code, 0)

    def test_array_vhdl_2008(self):
        self.run_sim('2008')
