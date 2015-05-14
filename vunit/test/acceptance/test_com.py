# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Run the com VHDL package tests
"""


import unittest
from os.path import abspath, join, dirname
from vunit.test.common import has_simulator, create_vunit
from vunit import ROOT


@unittest.skipUnless(has_simulator(), 'Requires simulator')
class TestCom(unittest.TestCase):
    """
    Run the com VHDL package tests
    """

    def run_sim(self, vhdl_standard, use_debug_codecs=False):
        """
        Utility function to run the com test compiled with vhdl_standard
        """
        output_path = join(dirname(abspath(__file__)), 'com_out')
        src_path = join(ROOT, 'vhdl', 'com')

        vu = create_vunit(clean=True,
                          output_path=output_path,
                          vhdl_standard=vhdl_standard)
        vu.add_com(use_debug_codecs=use_debug_codecs)

        tb_com_lib = vu.add_library("tb_com_lib")
        tb_com_lib.add_source_files(join(src_path, 'test', '*.vhd'))
        pkg = tb_com_lib.package('custom_types_pkg')
        pkg.generate_codecs(codec_package_name='custom_codec_pkg', used_packages=['ieee.std_logic_1164'])

        try:
            vu.main()
        except SystemExit as ex:
            self.assertEqual(ex.code, 0)

    def test_com_vhdl_2008(self):
        self.run_sim('2008')

    def test_com_debug_vhdl_2008(self):
        self.run_sim('2008', True)
