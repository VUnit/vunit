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
from vunit.test.common import has_simulator, check_report
from os import environ
from vunit import VUnit
from subprocess import call
import sys


@unittest.skipUnless(has_simulator(), "Requires simulator")
class TestVunitArtificial(unittest.TestCase):
    """
    Acceptance test of VUnit end to end functionality using
    artificial test benches.
    """
    def setUp(self):
        # Spaces in path intentional to verify that it is supported
        self.output_path = join(dirname(__file__), "artificial out")
        self.report_file = join(self.output_path, "xunit.xml")
        self.artificial_run = join(dirname(__file__), "artificial", "run.py")

    def test_artificial_with_persistent(self):
        self._test_artificial(persistent_sim=True)

    def test_artificial(self):
        self._test_artificial(persistent_sim=False)

    def test_artificial_elaborate_only(self):
        self.check(self.artificial_run,
                   exit_code=1,
                   args=["--elaborate"])
        check_report(self.report_file, [
            ("passed", "lib.tb_pass"),
            ("passed", "lib.tb_fail"),
            ("passed", "lib.tb_infinite_events"),
            ("passed", "lib.tb_fail_on_warning"),
            ("passed", "lib.tb_no_fail_on_warning"),
            ("passed", "lib.tb_two_architectures.pass"),
            ("passed", "lib.tb_two_architectures.fail"),
            ("passed", "lib.tb_with_vhdl_runner.pass"),
            ("passed", "lib.tb_with_vhdl_runner.Test with spaces"),
            ("passed", "lib.tb_with_vhdl_runner.fail"),
            ("passed", "lib.tb_with_vhdl_runner.Test that timeouts"),
            ("passed", "lib.tb_magic_paths"),
            ("passed", "lib.tb_no_fail_after_cleanup"),
            ("failed", "lib.tb_elab_fail"),

            ("passed", "lib.tb_same_sim_all_pass.Test 1"),
            ("passed", "lib.tb_same_sim_all_pass.Test 2"),
            ("passed", "lib.tb_same_sim_all_pass.Test 3"),

            ("passed", "lib.tb_same_sim_some_fail.Test 1"),
            ("passed", "lib.tb_same_sim_some_fail.Test 2"),
            ("passed", "lib.tb_same_sim_some_fail.Test 3"),

            ("passed", "lib.tb_with_checks.Test passing check"),
            ("passed", "lib.tb_with_checks.Test failing check"),
            ("passed", "lib.tb_with_checks.Test non-stopping failing check")])

        self.check(self.artificial_run,
                   exit_code=0,
                   clean=False,
                   args=["--elaborate", "lib.tb_pass"])
        check_report(self.report_file, [
            ("passed", "lib.tb_pass"),])

        self.check(self.artificial_run,
                   exit_code=1,
                   clean=False,
                   args=["--elaborate", "lib.tb_elab_fail"])
        check_report(self.report_file, [
            ("failed", "lib.tb_elab_fail"),])


    def _test_artificial(self, persistent_sim):
        """
        Utility function to run and check the result of all test benches
        using either persistent or non-persistent simulator interface mode
        """
        self.check(self.artificial_run,
                   exit_code=1,
                   persistent_sim=persistent_sim)
        check_report(self.report_file, [
            ("passed", "lib.tb_pass"),
            ("failed", "lib.tb_fail"),
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
            ("failed", "lib.tb_elab_fail"),

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
        self.check(self.artificial_run,
                   exit_code=0,
                   clean=False,
                   args=["*same_sim_some_fail*Test 1*"])
        check_report(self.report_file, [
            ("passed", "lib.tb_same_sim_some_fail.Test 1")])

        self.check(self.artificial_run,
                   exit_code=1,
                   clean=False,
                   args=["*same_sim_some_fail*Test 2*"])
        check_report(self.report_file, [
            ("failed", "lib.tb_same_sim_some_fail.Test 2")])

        self.check(self.artificial_run,
                   exit_code=0,
                   clean=False,
                   args=["*same_sim_some_fail*Test 3*"])
        check_report(self.report_file, [
            ("passed", "lib.tb_same_sim_some_fail.Test 3")])

        self.check(self.artificial_run,
                   exit_code=1,
                   clean=False,
                   args=["*same_sim_some_fail*Test 2*", "*same_sim_some_fail*Test 3*"])
        check_report(self.report_file, [
            ("failed", "lib.tb_same_sim_some_fail.Test 2"),
            ("skipped", "lib.tb_same_sim_some_fail.Test 3")])

    def test_compile_verilog(self):
        verilog_path = join(dirname(__file__), "verilog")
        ui = VUnit.from_argv(argv=["--clean",
                                   "--output-path=%s" % self.output_path,
                                   "--xunit-xml=%s" % self.report_file,
                                   "--compile"])
        ui.add_library("lib")
        ui.add_source_files(join(verilog_path, "*.v"), "lib")
        ui.add_source_files(join(verilog_path, "*.sv"), "lib")
        try:
            ui.main()
        except SystemExit as ex:
            self.assertEqual(ex.code, 0)

    # pylint: disable=too-many-arguments
    def check(self, run_file, args=None, persistent_sim=True, clean=True, exit_code=0):
        """
        Run external run file and verify exit code
        """
        args = args if args is not None else []
        new_env = environ.copy()
        new_env["VUNIT_VHDL_STANDARD"] = '2008'
        new_env["VUNIT_PERSISTENT_SIM"] = str(persistent_sim)
        if clean:
            args += ["--clean"]
        retcode = call([sys.executable, run_file,
                        "--output-path=%s" % self.output_path,
                        "--xunit-xml=%s" % self.report_file] + args,
                       env=new_env)
        self.assertEqual(retcode, exit_code)
