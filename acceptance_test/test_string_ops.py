# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

import unittest
from os.path import abspath, join, dirname
from vunit.ui import VUnit
from common import has_modelsim

@unittest.skipUnless(has_modelsim(), 'Requires modelsim')
class TestStringOps(unittest.TestCase):
    def run_sim(self, vhdl_standard):
        output_path = join(dirname(abspath(__file__)), 'string_ops_out')
        vhdl_path = join(dirname(abspath(__file__)), '..', 'vhdl')

        ui = VUnit(clean=True, 
                   output_path=output_path,
                   vhdl_standard=vhdl_standard,
                   compile_builtins=False)
        ui.add_library("lib")
        ui.add_builtins("vunit_lib", mock_lang=True)
        ui.add_source_files(join(vhdl_path, "string_ops", "test", "*.vhd"), "lib")

        try:
            ui.main()
        except SystemExit as e:            
            self.assertEqual(e.code, 0)

    def test_string_ops_vhdl_93(self):
        self.run_sim('93')

    def test_string_ops_vhdl_2002(self):
        self.run_sim('2002')

    def test_string_ops_vhdl_2008(self):
        self.run_sim('2008')



    
