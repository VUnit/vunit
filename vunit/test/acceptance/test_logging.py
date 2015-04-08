# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

import unittest
from os.path import abspath, join, dirname

from vunit import ROOT
from vunit.ui import VUnit
from vunit.test.common import has_modelsim


@unittest.skipUnless(has_modelsim(), 'Requires modelsim')
class TestLogging(unittest.TestCase):
    def run_sim(self, vhdl_standard):
        output_path = join(dirname(abspath(__file__)), 'logging_out')
        vhdl_path = join(ROOT, 'vhdl', 'logging')
        ui = VUnit(clean=True,
                   output_path=output_path,
                   vhdl_standard=vhdl_standard,
                   compile_builtins=False)

        ui.add_builtins('vunit_lib', mock_lang=True)
        ui.enable_location_preprocessing()
        lib = ui.add_library('lib')
        lib.add_source_files(join(vhdl_path, "test", "tb_logging.vhd"))

        try:
            ui.main()
        except SystemExit as ex:
            self.assertEqual(ex.code, 0)

    def test_logging_vhdl_93(self):
        self.run_sim('93')

    def test_logging_vhdl_2002(self):
        self.run_sim('2002')

    def test_logging_vhdl_2008(self):
        self.run_sim('2008')
