# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the dictionary VHDL package
"""


import unittest
from os.path import abspath, join, dirname
from vunit.test.common import has_simulator, assert_exit, create_vunit
from vunit import ROOT


@unittest.skipUnless(has_simulator(), 'Requires simulator')
class TestDictionary(unittest.TestCase):
    """
    Test the dictionary VHDL package
    """

    @staticmethod
    def run_sim(vhdl_standard):
        """
        Utility function to run the dictionary test compiled with vhdl_standard
        """
        output_path = join(dirname(abspath(__file__)), 'dictionary_out')
        src_path = join(ROOT, "vhdl", "dictionary")

        ui = create_vunit(clean=True,
                          output_path=output_path,
                          vhdl_standard=vhdl_standard,
                          compile_builtins=False)
        ui.add_builtins('vunit_lib', mock_log=True)
        lib = ui.add_library("lib")
        lib.add_source_files(join(src_path, "test", "*.vhd"))
        assert_exit(ui.main, code=0)

    def test_dictionary_vhdl_93(self):
        self.run_sim('93')

    def test_dictionary_vhdl_2002(self):
        self.run_sim('2002')

    def test_dictionary_vhdl_2008(self):
        self.run_sim('2008')
