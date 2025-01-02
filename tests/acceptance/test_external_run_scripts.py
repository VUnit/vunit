# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Verify that all external run scripts work correctly
"""

from unittest import TestCase
from pytest import mark
from pathlib import Path
from os import environ
from subprocess import call
import sys
from tests.common import check_report
from vunit import ROOT as RSTR
from vunit.builtins import VHDL_PATH
from vunit.sim_if.common import has_simulator, simulator_is, simulator_check

ROOT = Path(RSTR)


def simulator_supports_verilog():
    """
    Returns True if simulator supports Verilog
    """
    return simulator_is("modelsim", "incisive")


# pylint: disable=too-many-public-methods
@mark.skipif(not has_simulator(), reason="Requires simulator")
class TestExternalRunScripts(TestCase):
    """
    Verify that example projects run correctly
    """

    @mark.skipif(not simulator_supports_verilog(), reason="Requires a Verilog simulator")
    def test_verilog_user_guide_example_project(self):
        self.check(ROOT / "examples/verilog/user_guide/run.py", exit_code=1)
        check_report(
            self.report_file,
            [
                ("passed", "lib.tb_example_basic.all"),
                ("passed", "lib.tb_example.Test that a successful test case passes"),
                (
                    "failed",
                    "lib.tb_example.Test that a failing test case actually fails",
                ),
                (
                    "failed",
                    "lib.tb_example.Test that a test case that takes too long time fails with a timeout",
                ),
            ],
        )

    @mark.skipif(not simulator_supports_verilog(), reason="Requires a Verilog simulator")
    def test_verilog_uart_example_project(self):
        self.check(ROOT / "examples/verilog/uart/run.py")

    @mark.skipif(not simulator_supports_verilog(), reason="Requires a Verilog simulator")
    @mark.xfail(reason="Requires AMS")
    def test_verilog_ams_example(self):
        self.check(ROOT / "examples/verilog/verilog_ams/run.py")
        check_report(
            self.report_file,
            [
                ("passed", "lib.tb_dut.Test that pass"),
                ("failed", "lib.tb_dut.Test that fail"),
            ],
        )

    def test_vhdl_uart_example_project(self):
        self.check(ROOT / "examples/vhdl/uart/run.py")

    def test_vhdl_logging_example_project(self):
        self.check(ROOT / "examples/vhdl/logging/run.py")

    def test_vhdl_run_example_project(self):
        self.check(ROOT / "examples/vhdl/run/run.py", exit_code=1)
        check_report(
            self.report_file,
            [
                ("passed", "lib.tb_with_watchdog.Test to_string for boolean"),
                ("passed", "lib.tb_with_watchdog.Test that needs longer timeout"),
                ("passed", "lib.tb_standalone.Test to_string for boolean"),
                ("passed", "lib.tb_with_test_cases.Test to_string for integer"),
                ("passed", "lib.tb_with_test_cases.Test to_string for boolean"),
                ("passed", "lib.tb_with_lower_level_control.Test something"),
                ("passed", "lib.tb_with_lower_level_control.Test something else"),
                ("passed", "lib.tb_running_test_case.Test scenario A"),
                ("passed", "lib.tb_running_test_case.Test scenario B"),
                ("passed", "lib.tb_running_test_case.Test something else"),
                ("passed", "lib.tb_minimal.all"),
                ("passed", "lib.tb_magic_paths.all"),
                ("failed", "lib.tb_with_watchdog.Test that stalls"),
                (
                    "failed",
                    "lib.tb_with_watchdog.Test that stalling processes can inform why they caused a timeout",
                ),
                (
                    "failed",
                    "lib.tb_counting_errors.Test that fails multiple times but doesn't stop",
                ),
                (
                    "failed",
                    "lib.tb_standalone.Test that fails on VUnit check procedure",
                ),
                ("failed", "lib.tb_many_ways_to_fail.Test that fails on an assert"),
                (
                    "failed",
                    "lib.tb_many_ways_to_fail.Test that crashes on boundary problems",
                ),
                (
                    "failed",
                    "lib.tb_many_ways_to_fail.Test that fails on VUnit check procedure",
                ),
            ],
        )

    def test_vhdl_third_party_integration_example_project(self):
        self.check(
            ROOT / "examples/vhdl/third_party_integration/run.py",
            exit_code=1,
        )
        check_report(
            self.report_file,
            [
                ("passed", "lib.tb_external_framework_integration.Test that pass"),
                (
                    "failed",
                    "lib.tb_external_framework_integration.Test that stops the simulation on first error",
                ),
                (
                    "failed",
                    "lib.tb_external_framework_integration.Test that doesn't stop the simulation on error",
                ),
            ],
        )

    def test_vhdl_check_example_project(self):
        self.check(ROOT / "examples/vhdl/check/run.py")

    @mark.skipif(
        simulator_check(lambda simclass: not simclass.supports_coverage()),
        reason="This simulator/backend does not support coverage",
    )
    def test_vhdl_coverage_example_project(self):
        self.check(ROOT / "examples/vhdl/coverage/run.py")

    def test_vhdl_generate_tests_example_project(self):
        self.check(ROOT / "examples/vhdl/generate_tests/run.py")
        check_report(
            self.report_file,
            [
                ("passed", "lib.tb_generated.data_width=1,sign=False.Test 1"),
                ("passed", "lib.tb_generated.data_width=1,sign=True.Test 1"),
                ("passed", "lib.tb_generated.data_width=2,sign=False.Test 1"),
                ("passed", "lib.tb_generated.data_width=2,sign=True.Test 1"),
                ("passed", "lib.tb_generated.data_width=3,sign=False.Test 1"),
                ("passed", "lib.tb_generated.data_width=3,sign=True.Test 1"),
                ("passed", "lib.tb_generated.data_width=4,sign=False.Test 1"),
                ("passed", "lib.tb_generated.data_width=4,sign=True.Test 1"),
                ("passed", "lib.tb_generated.data_width=16,sign=True.Test 2"),
            ],
        )

    def test_vhdl_composite_generics_example_project(self):
        self.check(ROOT / "examples/vhdl/composite_generics/run.py")
        check_report(
            self.report_file,
            [
                ("passed", "tb_lib.tb_composite_generics.VGA.Test 1"),
                ("passed", "tb_lib.tb_composite_generics.tiny.Test 1"),
            ],
        )

    def test_vhdl_configuration_example_project(self):
        self.check(ROOT / "examples/vhdl/vhdl_configuration/run.py")
        check_report(
            self.report_file,
            [
                ("passed", "lib.tb_selecting_dut_with_vhdl_configuration.behavioral_16.Test reset"),
                ("passed", "lib.tb_selecting_dut_with_vhdl_configuration.rtl_16.Test state change"),
                ("passed", "lib.tb_selecting_dut_with_vhdl_configuration.rtl_32.Test reset"),
                ("passed", "lib.tb_selecting_dut_with_vhdl_configuration.rtl_8.Test state change"),
                ("passed", "lib.tb_selecting_dut_with_vhdl_configuration.behavioral_8.Test state change"),
                ("passed", "lib.tb_selecting_dut_with_vhdl_configuration.rtl_8.Test reset"),
                ("passed", "lib.tb_selecting_dut_with_vhdl_configuration.behavioral_16.Test state change"),
                ("passed", "lib.tb_selecting_dut_with_vhdl_configuration.behavioral_8.Test reset"),
                ("passed", "lib.tb_selecting_dut_with_vhdl_configuration.rtl_16.Test reset"),
                ("passed", "lib.tb_selecting_test_runner_with_vhdl_configuration.test_reset_rtl_8"),
                ("passed", "lib.tb_selecting_test_runner_with_vhdl_configuration.test_reset_rtl_16"),
                ("passed", "lib.tb_selecting_test_runner_with_vhdl_configuration.test_state_change_rtl_16"),
                ("passed", "lib.tb_selecting_test_runner_with_vhdl_configuration.test_reset_behavioral_16"),
                ("passed", "lib.tb_selecting_test_runner_with_vhdl_configuration.test_state_change_rtl_8"),
                ("passed", "lib.tb_selecting_test_runner_with_vhdl_configuration.test_state_change_behavioral_8"),
                ("passed", "lib.tb_selecting_test_runner_with_vhdl_configuration.test_state_change_behavioral_16"),
                ("passed", "lib.tb_selecting_test_runner_with_vhdl_configuration.test_reset_behavioral_8"),
            ],
        )

    @mark.xfail(
        not (simulator_is("ghdl") or simulator_is("nvc")),
        reason="Support complex JSON strings as generic",
    )
    def test_vhdl_json4vhdl_example_project(self):
        self.check(ROOT / "examples/vhdl/json4vhdl/run.py")

    def test_vhdl_array_example_project(self):
        self.check(ROOT / "examples/vhdl/array/run.py")

    @mark.xfail(
        not simulator_is("ghdl"),
        reason="Only simulators with PSL functionality",
    )
    def test_vhdl_array_axis_vcs_example_project(self):
        self.check(ROOT / "examples/vhdl/array_axis_vcs/run.py")

    def test_vhdl_axi_dma_example_project(self):
        self.check(ROOT / "examples/vhdl/axi_dma/run.py")

    def test_vhdl_osvvm_log_integration(self):
        self.check(ROOT / "examples/vhdl/osvvm_log_integration/run.py", exit_code=1)
        check_report(
            self.report_file,
            [("failed", "lib.tb_example.all")],
        )

    @mark.skipif(
        simulator_check(lambda simclass: not simclass.supports_vhdl_contexts()),
        reason="This simulator/backend does not support VHDL contexts",
    )
    def test_vhdl_user_guide_example_project(self):
        self.check(ROOT / "examples/vhdl/user_guide/run.py", exit_code=1)
        check_report(
            self.report_file,
            [
                ("passed", "lib.tb_example.all"),
                ("passed", "lib.tb_example_many.test_pass"),
                ("failed", "lib.tb_example_many.test_fail"),
            ],
        )

    def test_vhdl_user_guide_93_example_project(self):
        self.check(
            ROOT / "examples/vhdl/user_guide/vhdl1993/run.py",
            exit_code=1,
        )
        check_report(
            self.report_file,
            [
                ("passed", "lib.tb_example.all"),
                ("passed", "lib.tb_example_many.test_pass"),
                ("failed", "lib.tb_example_many.test_fail"),
            ],
        )

    def test_vhdl_com_example_project(self):
        self.check(ROOT / "examples/vhdl/com/run.py")

    def test_data_types_vhdl_2008(self):
        self.check(VHDL_PATH / "data_types/run.py")

    def test_data_types_vhdl_2002(self):
        self.check(VHDL_PATH / "data_types/run.py", vhdl_standard="2002")

    def test_data_types_vhdl_93(self):
        self.check(VHDL_PATH / "data_types/run.py", vhdl_standard="93")

    def test_random_vhdl_2008(self):
        self.check(VHDL_PATH / "random/run.py")

    def test_check_vhdl_2008(self):
        self.check(VHDL_PATH / "check/run.py")

    def test_check_vhdl_2002(self):
        self.check(VHDL_PATH / "check/run.py", vhdl_standard="2002")

    def test_check_vhdl_93(self):
        self.check(VHDL_PATH / "check/run.py", vhdl_standard="93")

    def test_logging_vhdl_2008(self):
        self.check(VHDL_PATH / "logging/run.py")

    def test_logging_vhdl_2002(self):
        self.check(VHDL_PATH / "logging/run.py", vhdl_standard="2002")

    def test_logging_vhdl_93(self):
        self.check(VHDL_PATH / "logging/run.py", vhdl_standard="93")

    def test_run_vhdl_2008(self):
        self.check(VHDL_PATH / "run/run.py")

    def test_run_vhdl_2002(self):
        self.check(VHDL_PATH / "run/run.py", vhdl_standard="2002")

    def test_run_vhdl_93(self):
        self.check(VHDL_PATH / "run/run.py", vhdl_standard="93")

    def test_string_ops_vhdl_2008(self):
        self.check(VHDL_PATH / "string_ops/run.py")

    def test_string_ops_vhdl_2002(self):
        self.check(VHDL_PATH / "string_ops/run.py", vhdl_standard="2002")

    def test_string_ops_vhdl_93(self):
        self.check(VHDL_PATH / "string_ops/run.py", vhdl_standard="93")

    def test_dictionary_vhdl_2008(self):
        self.check(VHDL_PATH / "dictionary/run.py")

    def test_dictionary_vhdl_2002(self):
        self.check(VHDL_PATH / "dictionary/run.py", vhdl_standard="2002")

    def test_dictionary_vhdl_93(self):
        self.check(VHDL_PATH / "dictionary/run.py", vhdl_standard="93")

    def test_path_vhdl_2008(self):
        self.check(VHDL_PATH / "path/run.py")

    def test_path_vhdl_2002(self):
        self.check(VHDL_PATH / "path/run.py", vhdl_standard="2002")

    def test_path_vhdl_93(self):
        self.check(VHDL_PATH / "path/run.py", vhdl_standard="93")

    def test_com_vhdl_2008(self):
        self.check(VHDL_PATH / "com/run.py")

    def setUp(self):
        self.output_path = str(Path(__file__).parent / "external_run_out")
        self.report_file = str(Path(self.output_path) / "xunit.xml")

    def check(self, run_file: Path, args=None, vhdl_standard="2008", exit_code=0):
        """
        Run external run file and verify exit code
        """
        args = args if args is not None else []
        new_env = environ.copy()
        new_env["VUNIT_VHDL_STANDARD"] = vhdl_standard
        retcode = call(
            [
                sys.executable,
                str(run_file),
                "--clean",
                "--output-path=%s" % self.output_path,
                "--xunit-xml=%s" % self.report_file,
            ]
            + args,
            env=new_env,
        )
        self.assertEqual(retcode, exit_code)
