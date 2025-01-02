# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Acceptance test of VUnit end to end functionality
"""

import unittest
from pathlib import Path
from os import environ
from subprocess import call
import sys
from tests.common import check_report
from vunit.sim_if.common import has_simulator, simulator_is

ROOT = Path(__file__).parent


@unittest.skipUnless(has_simulator(), "Requires simulator")
class TestVunitArtificial(unittest.TestCase):
    """
    Acceptance test of VUnit end to end functionality using
    artificial test benches.
    """

    def setUp(self):
        if simulator_is("activehdl"):
            self.output_path = str(ROOT / "artificial_out")
        else:
            # Spaces in path intentional to verify that it is supported
            self.output_path = str(ROOT / "artificial _out")

        self.report_file = str(Path(self.output_path) / "xunit.xml")
        self.artificial_run_vhdl = str(ROOT / "artificial" / "vhdl" / "run.py")
        self.artificial_run_verilog = str(ROOT / "artificial" / "verilog" / "run.py")

    @unittest.skipUnless(
        simulator_is("modelsim", "rivierapro"),
        "Only simulators with persistance functionality",
    )
    def test_artificial_modelsim_unique_sim(self):
        self._test_artificial(args=["--unique-sim"])

    def test_artificial(self):
        self._test_artificial()

    def test_artificial_elaborate_only(self):
        self.check(self.artificial_run_vhdl, exit_code=1, args=["--elaborate"])

        elab_expected_report = []
        for status, name in EXPECTED_REPORT:
            if name in ("lib.tb_elab_fail.all",):
                status = "failed"
            else:
                status = "passed"
            elab_expected_report.append((status, name))

        check_report(self.report_file, elab_expected_report)

        self.check(
            self.artificial_run_vhdl,
            exit_code=0,
            clean=False,
            args=["--elaborate", "lib.tb_pass.all"],
        )
        check_report(self.report_file, [("passed", "lib.tb_pass.all")])

        self.check(
            self.artificial_run_vhdl,
            exit_code=1,
            clean=False,
            args=["--elaborate", "lib.tb_elab_fail.all"],
        )
        check_report(self.report_file, [("failed", "lib.tb_elab_fail.all")])

    def _test_artificial(self, args=None):
        """
        Utility function to run and check the result of all test benches
        using either persistent or non-persistent simulator interface mode
        """
        self.check(self.artificial_run_vhdl, exit_code=1, args=args)
        check_report(self.report_file, EXPECTED_REPORT)

    def test_run_selected_tests_in_same_sim_test_bench_vhdl(self):
        self._test_run_selected_tests_in_same_sim_test_bench(self.artificial_run_vhdl)

    @unittest.skipUnless(simulator_is("modelsim"), "Only modelsim supports verilog")
    def test_run_selected_tests_in_same_sim_test_bench_verilog(self):
        self._test_run_selected_tests_in_same_sim_test_bench(self.artificial_run_verilog)

    def _test_run_selected_tests_in_same_sim_test_bench(self, run_file):
        """
        Run selected "same_sim" test in isolation
        """
        self.check(run_file, exit_code=0, clean=True, args=["*same_sim_some_fail*Test 1*"])
        check_report(self.report_file, [("passed", "lib.tb_same_sim_some_fail.Test 1")])

        self.check(run_file, exit_code=1, clean=False, args=["*same_sim_some_fail*Test 2*"])
        check_report(self.report_file, [("failed", "lib.tb_same_sim_some_fail.Test 2")])

        self.check(run_file, exit_code=0, clean=False, args=["*same_sim_some_fail*Test 3*"])
        check_report(self.report_file, [("passed", "lib.tb_same_sim_some_fail.Test 3")])

        self.check(
            run_file,
            exit_code=1,
            clean=False,
            args=["*same_sim_some_fail*Test 2*", "*same_sim_some_fail*Test 3*"],
        )
        check_report(
            self.report_file,
            [
                ("failed", "lib.tb_same_sim_some_fail.Test 2"),
                ("skipped", "lib.tb_same_sim_some_fail.Test 3"),
            ],
        )

    @unittest.skipUnless(simulator_is("modelsim"), "Only modelsim supports verilog")
    def test_artificial_verilog(self):
        self.check(self.artificial_run_verilog, exit_code=1)
        check_report(
            self.report_file,
            [
                ("passed", "lib.tb_other_file_tests.pass"),
                ("failed", "lib.tb_other_file_tests.fail"),
                ("passed", "lib.tb_magic_paths.Test magic paths are correct"),
                ("passed", "lib.tb_with_define.test 1"),
                ("failed", "lib.tb_fail_on_warning.fail"),
                ("failed", "lib.tb_fail_on_warning_from_python.fail"),
                ("failed", "lib.tb_fail_on_fatal_and_early_finish.fatal0"),
                ("failed", "lib.tb_fail_on_fatal_and_early_finish.fatal1"),
                ("failed", "lib.tb_fail_on_fatal_and_early_finish.finish0"),
                ("failed", "lib.tb_fail_on_fatal_and_early_finish.finish1"),
                ("passed", "lib2.tb_with_parameter_config.Test 0"),
                ("passed", "lib2.tb_with_parameter_config.cfg.Test 1"),
                ("passed", "lib2.tb_with_parameter_config.Test 2"),
                ("passed", "lib2.tb_with_parameter_config.cfg.Test 3"),
                ("passed", "lib2.tb_with_parameter_config.cfg.Test 4"),
                ("passed", "lib.tb_same_sim_all_pass.cfg.Test 1"),
                ("passed", "lib.tb_same_sim_all_pass.cfg.Test 2"),
                ("passed", "lib.tb_same_sim_all_pass.cfg.Test 3"),
                ("passed", "lib.tb_same_sim_some_fail.Test 1"),
                ("failed", "lib.tb_same_sim_some_fail.Test 2"),
                ("skipped", "lib.tb_same_sim_some_fail.Test 3"),
                ("passed", "lib.tb_same_sim_from_python_all_pass.cfg.Test 1"),
                ("passed", "lib.tb_same_sim_from_python_all_pass.cfg.Test 2"),
                ("passed", "lib.tb_same_sim_from_python_all_pass.cfg.Test 3"),
                ("passed", "lib.tb_same_sim_from_python_some_fail.Test 1"),
                ("failed", "lib.tb_same_sim_from_python_some_fail.Test 2"),
                ("skipped", "lib.tb_same_sim_from_python_some_fail.Test 3"),
                ("passed", "lib.tb_with_runner.pass"),
                ("failed", "lib.tb_with_runner.fail"),
            ],
        )

    # pylint: disable=too-many-arguments
    def check(self, run_file, args=None, clean=True, exit_code=0):
        """
        Run external run file and verify exit code
        """
        args = args if args is not None else []
        new_env = environ.copy()
        new_env["VUNIT_VHDL_STANDARD"] = "2008"
        if clean:
            args += ["--clean"]
        retcode = call(
            [
                sys.executable,
                run_file,
                "--output-path=%s" % self.output_path,
                "--xunit-xml=%s" % self.report_file,
            ]
            + args,
            env=new_env,
        )
        self.assertEqual(retcode, exit_code)

    def test_exit_0_flag(self):
        self.check(self.artificial_run_vhdl, exit_code=1, args=["lib.tb_fail.all"])
        self.check(self.artificial_run_vhdl, exit_code=0, args=["--exit-0", "lib.tb_fail.all"])


EXPECTED_REPORT = (
    ("passed", "lib.tb_other_file_tests.pass"),
    ("failed", "lib.tb_other_file_tests.fail"),
    ("passed", "lib.tb_pass.all"),
    ("failed", "lib.tb_fail.all"),
    ("passed", "lib.tb_infinite_events.all"),
    ("failed", "lib.tb_fail_on_warning.all"),
    ("failed", "lib.tb_fail_on_warning_from_python.all"),
    ("passed", "lib.tb_no_fail_on_warning.cfg1"),
    ("passed", "lib.tb_no_fail_on_warning.cfg2"),
    ("passed", "lib.tb_with_vhdl_runner.pass"),
    ("passed", "lib.tb_with_vhdl_runner.Test with spaces"),
    ("failed", "lib.tb_with_vhdl_runner.fail"),
    ("failed", "lib.tb_with_vhdl_runner.Test that timeouts"),
    ("passed", "lib.tb_magic_paths.all"),
    ("passed", "lib.tb_no_fail_after_cleanup.all"),
    ("failed", "lib.tb_elab_fail.all"),
    ("passed", "lib.tb_same_sim_all_pass.cfg.Test 1"),
    ("passed", "lib.tb_same_sim_all_pass.cfg.Test 2"),
    ("passed", "lib.tb_same_sim_all_pass.cfg.Test 3"),
    ("passed", "lib.tb_same_sim_some_fail.Test 1"),
    ("failed", "lib.tb_same_sim_some_fail.Test 2"),
    ("skipped", "lib.tb_same_sim_some_fail.Test 3"),
    ("passed", "lib.tb_same_sim_from_python_all_pass.cfg.Test 1"),
    ("passed", "lib.tb_same_sim_from_python_all_pass.cfg.Test 2"),
    ("passed", "lib.tb_same_sim_from_python_all_pass.cfg.Test 3"),
    ("passed", "lib.tb_same_sim_from_python_some_fail.Test 1"),
    ("failed", "lib.tb_same_sim_from_python_some_fail.Test 2"),
    ("skipped", "lib.tb_same_sim_from_python_some_fail.Test 3"),
    ("passed", "lib.tb_with_checks.Test passing check"),
    ("failed", "lib.tb_with_checks.Test failing check"),
    ("failed", "lib.tb_with_checks.Test non-stopping failing check"),
    ("passed", "lib2.tb_set_generic.all"),
    ("passed", "lib.tb_with_generic_config.Test 0"),
    ("passed", "lib.tb_with_generic_config.cfg.Test 1"),
    ("passed", "lib.tb_with_generic_config.Test 2"),
    ("passed", "lib.tb_with_generic_config.cfg.Test 3"),
    ("passed", "lib.tb_with_generic_config.cfg.Test 4"),
    ("passed", "lib.tb_no_generic_override.all"),
    ("passed", "lib.tb_ieee_warning.pass"),
    ("failed", "lib.tb_ieee_warning.fail"),
    (
        "failed",
        "lib.tb_assert_stop_level.Report warning when VHDL assert stop level = warning",
    ),
    (
        "failed",
        "lib.tb_assert_stop_level.Report error when VHDL assert stop level = warning",
    ),
    (
        "failed",
        "lib.tb_assert_stop_level.Report failure when VHDL assert stop level = warning",
    ),
    (
        "passed",
        "lib.tb_assert_stop_level.Report warning when VHDL assert stop level = error",
    ),
    (
        "failed",
        "lib.tb_assert_stop_level.Report error when VHDL assert stop level = error",
    ),
    (
        "failed",
        "lib.tb_assert_stop_level.Report failure when VHDL assert stop level = error",
    ),
    (
        "passed",
        "lib.tb_assert_stop_level.Report warning when VHDL assert stop level = failure",
    ),
    (
        "passed",
        "lib.tb_assert_stop_level.Report error when VHDL assert stop level = failure",
    ),
    (
        "failed",
        "lib.tb_assert_stop_level.Report failure when VHDL assert stop level = failure",
    ),
    (
        "passed",
        "lib.tb_with_vhdl_configuration.test 1",
    ),
    (
        "passed",
        "lib.tb_with_vhdl_configuration.cfg2.test 2",
    ),
    (
        "passed",
        "lib.tb_with_vhdl_configuration.cfg3.test 3",
    ),
)
