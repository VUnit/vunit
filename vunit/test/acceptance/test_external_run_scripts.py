# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Verify that all external run scripts work correctly
"""


import unittest
from os import environ
from os.path import join, dirname
from subprocess import call
import sys
from vunit import ROOT
from vunit.builtins import VHDL_PATH
from vunit.test.common import has_simulator, check_report, simulator_is


def simulator_supports_verilog():
    """
    Returns True if simulator supports Verilog
    """
    return simulator_is("modelsim")


# pylint: disable=too-many-public-methods
@unittest.skipUnless(has_simulator(), "Requires simulator")
class TestExternalRunScripts(unittest.TestCase):
    """
    Verify that example projects run correctly
    """

    def test_vhdl_uart_example_project(self):
        self.check(join(ROOT, "examples", "vhdl", "uart", "run.py"))

    def test_vhdl_preprocessed_uart_example_project(self):
        self.check(join(ROOT, "examples", "vhdl", "uart", "run_with_preprocessing.py"))

    @unittest.skipUnless(simulator_supports_verilog(), "Verilog")
    def test_verilog_uart_example_project(self):
        self.check(join(ROOT, "examples", "verilog", "uart", "run.py"))

    @unittest.skipUnless(simulator_supports_verilog(), "Verilog")
    def test_verilog_ams_example(self):
        self.check(join(ROOT, "examples", "verilog", "verilog_ams", "run.py"))
        check_report(self.report_file,
                     [("passed", "lib.tb_dut.Test that pass"),
                      ("failed", "lib.tb_dut.Test that fail")])

    def test_vhdl_logging_example_project(self):
        self.check(join(ROOT, "examples", "vhdl", "logging", "compile.py"), args=["--compile"])

    def test_vhdl_check_example_project(self):
        self.check(join(ROOT, "examples", "vhdl", "check", "compile.py"), args=["--compile"])

    def test_vhdl_generate_tests_example_project(self):
        self.check(join(ROOT, "examples", "vhdl", "generate_tests", "run.py"))
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

    def test_vhdl_array_example_project(self):
        self.check(join(ROOT, "examples", "vhdl", "array", "run.py"))

    def test_vhdl_user_guide_example_project(self):
        self.check(join(ROOT, "examples", "vhdl", "user_guide", "run.py"), exit_code=1)
        check_report(self.report_file,
                     [("passed", "lib.tb_example.all"),
                      ("passed", "lib.tb_example_many.test_pass"),
                      ("failed", "lib.tb_example_many.test_fail")])

    @unittest.skipUnless(simulator_supports_verilog(), "Verilog")
    def test_verilog_user_guide_example_project(self):
        self.check(join(ROOT, "examples", "verilog", "user_guide", "run.py"), exit_code=1)
        check_report(self.report_file,
                     [("passed", "lib.tb_example.Test that a successful test case passes"),
                      ("failed", "lib.tb_example.Test that a failing test case actually fails"),
                      ("failed", "lib.tb_example.Test that a test case that takes too long time fails with a timeout")])

    def test_vhdl_osvvm_integration_example_project(self):
        self.check(join(ROOT, "examples", "vhdl", "osvvm_integration", "run.py"), exit_code=1)
        check_report(self.report_file,
                     [("passed", "lib.tb_alertlog_demo_global_with_comments.Test passing alerts"),
                      ("passed", "lib.tb_alertlog_demo_hierarchy_with_comments.Test passing alerts"),
                      ("passed", "lib.tb_alertlog_demo_global.Test passing alerts"),
                      ("passed", "lib.tb_alertlog_demo_hierarchy.Test passing alerts"),
                      ("failed", "lib.tb_alertlog_demo_global_with_comments.Test failing alerts"),
                      ("failed", "lib.tb_alertlog_demo_hierarchy_with_comments.Test failing alerts"),
                      ("failed", "lib.tb_alertlog_demo_global.Test failing alerts"),
                      ("failed", "lib.tb_alertlog_demo_hierarchy.Test failing alerts")])

    def test_vhdl_com_example_project(self):
        self.check(join(ROOT, "examples", "vhdl", "com", "run.py"))

    def test_array_vhdl_2008(self):
        self.check(join(VHDL_PATH, "array", "run.py"))

    def test_check_vhdl_2008(self):
        self.check(join(VHDL_PATH, "check", "run.py"))

    def test_check_vhdl_2002(self):
        self.check(join(VHDL_PATH, "check", "run.py"),
                   vhdl_standard='2002')

    def test_check_vhdl_93(self):
        self.check(join(VHDL_PATH, "check", "run.py"),
                   vhdl_standard='93')

    def test_logging_vhdl_2008(self):
        self.check(join(VHDL_PATH, "logging", "run.py"))

    def test_logging_vhdl_2002(self):
        self.check(join(VHDL_PATH, "logging", "run.py"),
                   vhdl_standard='2002')

    def test_logging_vhdl_93(self):
        self.check(join(VHDL_PATH, "logging", "run.py"),
                   vhdl_standard='93')

    def test_run_vhdl_2008(self):
        self.check(join(VHDL_PATH, "run", "run.py"))

    def test_run_vhdl_2002(self):
        self.check(join(VHDL_PATH, "run", "run.py"),
                   vhdl_standard='2002')

    def test_run_vhdl_93(self):
        self.check(join(VHDL_PATH, "run", "run.py"),
                   vhdl_standard='93')

    def test_string_ops_vhdl_2008(self):
        self.check(join(VHDL_PATH, "string_ops", "run.py"))

    def test_string_ops_vhdl_2002(self):
        self.check(join(VHDL_PATH, "string_ops", "run.py"),
                   vhdl_standard='2002')

    def test_string_ops_vhdl_93(self):
        self.check(join(VHDL_PATH, "string_ops", "run.py"),
                   vhdl_standard='93')

    def test_dictionary_vhdl_2008(self):
        self.check(join(VHDL_PATH, "dictionary", "run.py"))

    def test_dictionary_vhdl_2002(self):
        self.check(join(VHDL_PATH, "dictionary", "run.py"),
                   vhdl_standard='2002')

    def test_dictionary_vhdl_93(self):
        self.check(join(VHDL_PATH, "dictionary", "run.py"),
                   vhdl_standard='93')

    def test_path_vhdl_2008(self):
        self.check(join(VHDL_PATH, "path", "run.py"))

    def test_path_vhdl_2002(self):
        self.check(join(VHDL_PATH, "path", "run.py"),
                   vhdl_standard='2002')

    def test_path_vhdl_93(self):
        self.check(join(VHDL_PATH, "path", "run.py"),
                   vhdl_standard='93')

    def test_com_vhdl_2008(self):
        self.check(join(VHDL_PATH, "com", "run.py"))

    def test_com_debug_vhdl_2008(self):
        self.check(join(VHDL_PATH, "com", "run.py"),
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
