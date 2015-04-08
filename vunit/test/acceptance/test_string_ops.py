# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Run the string_ops test cases
"""


import unittest
from os.path import abspath, join, dirname
from vunit.ui import VUnit
from vunit.test.common import has_modelsim, assert_exit
from vunit import ROOT


@unittest.skipUnless(has_modelsim(), 'Requires modelsim')
class TestStringOps(unittest.TestCase):
    """
    Run the string_ops test cases
    """

    @staticmethod
    def run_sim(vhdl_standard):
        """
        Run the string_ops test cases using vhdl_standard
        """
        output_path = join(dirname(abspath(__file__)), 'string_ops_out')
        src_path = join(ROOT, "vhdl", "string_ops")

        ui = VUnit(clean=True,
                   output_path=output_path,
                   vhdl_standard=vhdl_standard,
                   compile_builtins=False)
        lib = ui.add_library("lib")
        ui.add_builtins("vunit_lib", mock_lang=True)
        lib.add_source_files(join(src_path, "test", "*.vhd"))
        assert_exit(ui.main, code=0)

    def test_string_ops_vhdl_93(self):
        self.run_sim('93')

    def test_string_ops_vhdl_2002(self):
        self.run_sim('2002')

    def test_string_ops_vhdl_2008(self):
        self.run_sim('2008')
