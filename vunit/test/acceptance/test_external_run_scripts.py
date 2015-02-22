# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Verify that all external run scripts work correctly
"""


import unittest
from os.path import join, dirname
from vunit.test.common import has_simulator, check_report, simulator_is
from subprocess import call
import sys
from vunit import ROOT
from os import environ


# pylint: disable=too-many-public-methods
@unittest.skipUnless(has_simulator(), "Requires simulator")
class TestExternalRunScripts(unittest.TestCase):
    """
    Verify that example projects run correctly
    """

    @unittest.skipIf(simulator_is("ghdl"), "OSVVM 2015.03 does not work with GHDL")
    def test_uart_example_project(self):
        self.check(join(ROOT, "examples", "uart", "run.py"))

    @unittest.skipIf(simulator_is("ghdl"), "OSVVM 2015.03 does not work with GHDL")
    def test_preprocessed_uart_example_project(self):
        self.check(join(ROOT, "examples", "uart", "run_with_preprocessing.py"))

    def test_logging_example_project(self):
        self.check(join(ROOT, "examples", "logging", "compile.py"))

    def test_check_example_project(self):
        self.check(join(ROOT, "examples", "check", "compile.py"))

    def test_generate_tests_example_project(self):
        self.check(join(ROOT, "examples", "generate_tests", "run.py"))
        check_report(self.report_file,
                     [("passed", "lib.tb_generated.data_width=1,sign=False.Test 1"),
                      ("passed", "lib.tb_generated.data_width=1,sign=True.Test 1"),
                      ("passed", "lib.tb_generated.data_width=2,sign=False.Test 1"),
                      ("passed", "lib.tb_generated.data_width=2,sign=True.Test 1"),
                      ("passed", "lib.tb_generated.data_width=3,sign=False.Test 1"),
                      ("passed", "lib.tb_generated.data_width=3,sign=True.Test 1"),
                      ("passed", "lib.tb_generated.data_width=4,sign=False.Test 1"),
                      ("passed", "lib.tb_generated.data_width=4,sign=True.Test 1"),
                      ("passed", "lib.tb_generated.data_width=16,sign=True.Test 2")])

    @unittest.skipIf(simulator_is("ghdl"), "OSVVM 2015.03 does not work with GHDL")
    def test_array_example_project(self):
        self.check(join(ROOT, "examples", "array", "run.py"))

    def test_user_guide_example_project(self):
        self.check(join(ROOT, "examples", "user_guide", "run.py"), exit_code=1)
        check_report(self.report_file,
                     [("passed", "lib.tb_example"),
                      ("passed", "lib.tb_example_many.test_pass"),
                      ("failed", "lib.tb_example_many.test_fail")])

    @unittest.skipIf(simulator_is("ghdl"), "OSVVM 2015.03 does not work with GHDL")
    def test_osvvm_integration_example_project(self):
        self.check(join(ROOT, "examples", "osvvm_integration", "run.py"), exit_code=1)
        check_report(self.report_file,
                     [("passed", "lib.tb_alertlog_demo_global_with_comments.Test passing alerts"),
                      ("passed", "lib.tb_alertlog_demo_hierarchy_with_comments.Test passing alerts"),
                      ("passed", "lib.tb_alertlog_demo_global.Test passing alerts"),
                      ("passed", "lib.tb_alertlog_demo_hierarchy.Test passing alerts"),
                      ("failed", "lib.tb_alertlog_demo_global_with_comments.Test failing alerts"),
                      ("failed", "lib.tb_alertlog_demo_hierarchy_with_comments.Test failing alerts"),
                      ("failed", "lib.tb_alertlog_demo_global.Test failing alerts"),
                      ("failed", "lib.tb_alertlog_demo_hierarchy.Test failing alerts")])

    @unittest.skipIf(simulator_is("ghdl"), "OSVVM 2015.03 does not work with GHDL")
    def test_com_example_project(self):
        self.check(join(ROOT, "examples", "com", "run.py"))

    @unittest.skipIf(simulator_is("ghdl"), "OSVVM 2015.03 does not work with GHDL")
    def test_array_vhdl_2008(self):
        self.check(join(ROOT, "vhdl", "array", "run.py"))

    def test_check_vhdl_2008(self):
        self.check(join(ROOT, "vhdl", "check", "run.py"))

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_check_vhdl_2002(self):
        self.check(join(ROOT, "vhdl", "check", "run.py"),
                   vhdl_standard='2002')

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_check_vhdl_93(self):
        self.check(join(ROOT, "vhdl", "check", "run.py"),
                   vhdl_standard='93')

    def test_logging_vhdl_2008(self):
        self.check(join(ROOT, "vhdl", "logging", "run.py"))

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_logging_vhdl_2002(self):
        self.check(join(ROOT, "vhdl", "logging", "run.py"),
                   vhdl_standard='2002')

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_logging_vhdl_93(self):
        self.check(join(ROOT, "vhdl", "logging", "run.py"),
                   vhdl_standard='93')

    def test_run_vhdl_2008(self):
        self.check(join(ROOT, "vhdl", "run", "run.py"))

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_run_vhdl_2002(self):
        self.check(join(ROOT, "vhdl", "run", "run.py"),
                   vhdl_standard='2002')

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_run_vhdl_93(self):
        self.check(join(ROOT, "vhdl", "run", "run.py"),
                   vhdl_standard='93')

    def test_string_ops_vhdl_2008(self):
        self.check(join(ROOT, "vhdl", "string_ops", "run.py"))

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_string_ops_vhdl_2002(self):
        self.check(join(ROOT, "vhdl", "string_ops", "run.py"),
                   vhdl_standard='2002')

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_string_ops_vhdl_93(self):
        self.check(join(ROOT, "vhdl", "string_ops", "run.py"),
                   vhdl_standard='93')

    def test_dictionary_vhdl_2008(self):
        self.check(join(ROOT, "vhdl", "dictionary", "run.py"))

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_dictionary_vhdl_2002(self):
        self.check(join(ROOT, "vhdl", "dictionary", "run.py"),
                   vhdl_standard='2002')

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_dictionary_vhdl_93(self):
        self.check(join(ROOT, "vhdl", "dictionary", "run.py"),
                   vhdl_standard='93')

    def test_path_vhdl_2008(self):
        self.check(join(ROOT, "vhdl", "path", "run.py"))

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_path_vhdl_2002(self):
        self.check(join(ROOT, "vhdl", "path", "run.py"),
                   vhdl_standard='2002')

    @unittest.skipIf(simulator_is("ghdl"), "GHDL only supports 2008")
    def test_path_vhdl_93(self):
        self.check(join(ROOT, "vhdl", "path", "run.py"),
                   vhdl_standard='93')

    def test_com_vhdl_2008(self):
        self.check(join(ROOT, "vhdl", "com", "run.py"))

    def test_com_debug_vhdl_2008(self):
        self.check(join(ROOT, "vhdl", "com", "run.py"),
                   args=["--use-debug-codecs"])

    def setUp(self):
        self.output_path = join(dirname(__file__), "external_run_out")
        self.report_file = join(self.output_path, "xunit.xml")

    def check(self, run_file, args=None, vhdl_standard='2008', exit_code=0):
        """
        Run external run file and verify exit code
        """
        args = args if args is not None else []
        new_env = environ.copy()
        new_env["VUNIT_VHDL_STANDARD"] = vhdl_standard
        retcode = call([sys.executable, run_file,
                        "--clean",
                        "--output-path=%s" % self.output_path,
                        "--xunit-xml=%s" % self.report_file] + args,
                       env=new_env)
        self.assertEqual(retcode, exit_code)
