# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit.verilog import VUnit

ROOT = Path(__file__).parent

VU = VUnit.from_argv()
LIB = VU.add_library("lib")
LIB.add_source_files(ROOT / "*.sv", defines={"DEFINE_FROM_RUN_PY": ""})


def configure_tb_with_parameter_config():
    """
    Configure tb_with_parameter_config test bench
    """
    bench = LIB.module("tb_with_parameter_config")
    tests = [bench.test("Test %i" % i) for i in range(5)]

    bench.set_parameter("set_parameter", "set-for-module")

    tests[1].add_config("cfg", parameters=dict(config_parameter="set-from-config"))

    tests[2].set_parameter("set_parameter", "set-for-test")

    tests[3].add_config(
        "cfg",
        parameters=dict(
            set_parameter="set-for-test", config_parameter="set-from-config"
        ),
    )

    def post_check(output_path):
        with (Path(output_path) / "post_check.txt").open("r") as fptr:
            return fptr.read() == "Test 4 was here"

    tests[4].add_config(
        "cfg",
        parameters=dict(
            set_parameter="set-from-config", config_parameter="set-from-config"
        ),
        post_check=post_check,
    )


def configure_tb_same_sim_all_pass(ui):
    def post_check(output_path):
        with (Path(output_path) / "post_check.txt").open("r") as fptr:
            return fptr.read() == "Test 3 was here"

    module = ui.library("lib").module("tb_same_sim_all_pass")
    module.add_config("cfg", post_check=post_check)


configure_tb_with_parameter_config()
configure_tb_same_sim_all_pass(VU)
LIB.module("tb_other_file_tests").scan_tests_from_file(
    str(ROOT / "other_file_tests.sv")
)
VU.main()
