# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Acceptance test of VUnit end to end functionality
"""


import unittest
from os.path import join, dirname
from vunit.test.common import has_simulator, check_report, create_vunit
from fnmatch import fnmatch


@unittest.skipUnless(has_simulator(), "Requires simulator")
class TestVunitEndToEnd(unittest.TestCase):
    """
    Acceptance test of VUnit end to end functionality using
    artificial test benches.
    """
    def setUp(self):
        # Spaces in path intentional to verify that it is supported
        self.output_path = join(dirname(__file__), "end to end out")
        self.report_file = join(self.output_path, "xunit.xml")

    def test_artificial_with_persistent(self):
        self._test_artificial(persistent_sim=True)

    def test_artificial(self):
        self._test_artificial(persistent_sim=False)

    def _test_artificial(self, persistent_sim):
        """
        Utility function to run and check the result of all test benches
        using either persistent or non-persistent simulator interface mode
        """
        self.run_ui_main(persistent_sim=persistent_sim)

        check_report(self.report_file, [
            ("passed", "lib.tb_pass"),
            ("failed", "lib.tb_fail"),
            ("failed", "lib.tb_no_finished_signal"),
            ("passed", "lib.tb_infinite_events"),
            ("failed", "lib.tb_fail_on_warning"),
            ("passed", "lib.tb_no_fail_on_warning"),
            ("passed", "lib.tb_two_architectures.pass"),
            ("failed", "lib.tb_two_architectures.fail"),
            ("passed", "lib.tb_with_vhdl_runner.pass"),
            ("passed", "lib.tb_with_vhdl_runner.Test with spaces"),
            ("failed", "lib.tb_with_vhdl_runner.fail"),
            ("failed", "lib.tb_with_vhdl_runner.Test that timeouts"),
            ("passed", "lib.tb_magic_paths"),
            ("passed", "lib.tb_no_fail_after_cleanup"),

            # @TODO verify that these are actually run in separate simulations
            ("passed", "lib.tb_same_sim_all_pass.Test 1"),
            ("passed", "lib.tb_same_sim_all_pass.Test 2"),
            ("passed", "lib.tb_same_sim_all_pass.Test 3"),

            ("passed", "lib.tb_same_sim_some_fail.Test 1"),
            ("failed", "lib.tb_same_sim_some_fail.Test 2"),
            ("skipped", "lib.tb_same_sim_some_fail.Test 3"),

            ("passed", "lib.tb_with_checks.Test passing check"),
            ("failed", "lib.tb_with_checks.Test failing check"),
            ("failed", "lib.tb_with_checks.Test non-stopping failing check")])

    def test_run_selected_tests_in_same_sim_test_bench(self):
        self.run_ui_main(["*same_sim_some_fail*Test 1*"])
        check_report(self.report_file, [
            ("passed", "lib.tb_same_sim_some_fail.Test 1")])

        self.run_ui_main(["*same_sim_some_fail*Test 2*"])
        check_report(self.report_file, [
            ("failed", "lib.tb_same_sim_some_fail.Test 2")])

        self.run_ui_main(["*same_sim_some_fail*Test 3*"])
        check_report(self.report_file, [
            ("passed", "lib.tb_same_sim_some_fail.Test 3")])

        self.run_ui_main(["*same_sim_some_fail*Test 2*",
                          "*same_sim_some_fail*Test 3*"])
        check_report(self.report_file, [
            ("failed", "lib.tb_same_sim_some_fail.Test 2"),
            ("skipped", "lib.tb_same_sim_some_fail.Test 3")])

    def test_compile_verilog(self):
        verilog_path = join(dirname(__file__), "verilog")
        ui = create_vunit(clean=True,
                          output_path=self.output_path,
                          xunit_xml=self.report_file,
                          compile_only=True)
        ui.add_library("lib")
        ui.add_source_files(join(verilog_path, "*.v"), "lib")
        ui.add_source_files(join(verilog_path, "*.sv"), "lib")
        try:
            ui.main()
        except SystemExit as ex:
            self.assertEqual(ex.code, 0)

    def create_ui(self, test_patterns=None, persistent_sim=True):
        """
        Create VUnit public interface instance
        """
        vhdl_path = join(dirname(__file__), "vhdl")
        ui = create_vunit(clean=True,
                          test_filter=make_test_filter(test_patterns),
                          output_path=self.output_path,
                          xunit_xml=self.report_file,
                          persistent_sim=persistent_sim)
        ui.add_library("lib")
        ui.add_source_files(join(vhdl_path, "*.vhd"), "lib")
        return ui

    def run_ui_main(self, test_patterns=None, persistent_sim=True):
        """
        Run vunit main function on tests with test_pattern using
        either persistent simulator mode or not
        """
        ui = self.create_ui(test_patterns, persistent_sim)
        try:
            ui.main()
        except SystemExit:
            del ui


def make_test_filter(patterns):
    """
    Return a test_filter function based on a list of wildcard pattern strings
    """
    def test_filter(name):
        if patterns is None:
            return True
        return any(fnmatch(name, pattern) for pattern in patterns)
    return test_filter
