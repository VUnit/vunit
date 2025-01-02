# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from glob import glob
from vunit import VUnit


root = Path(__file__).parent

vu = VUnit.from_argv()
vu.add_verilog_builtins()

lib = vu.add_library("lib")
lib2 = vu.add_library("lib2")

for file in glob(str(root / "*.sv")):
    if "tb_with_parameter_config" in file:
        lib2.add_source_files(file, defines={"DEFINE_FROM_RUN_PY": ""})
    else:
        lib.add_source_files(file, defines={"DEFINE_FROM_RUN_PY": ""})


def configure_tb_with_parameter_config():
    """
    Configure tb_with_parameter_config test bench
    """
    lib2.set_parameter("lib_parameter", "set-for-lib")
    libs = vu.get_libraries("lib2")
    libs.set_parameter("libs_parameter", "set-for-libs")
    bench = lib2.module("tb_with_parameter_config")
    tests = [bench.test("Test %i" % i) for i in range(5)]

    bench.set_parameter("set_parameter", "set-for-module")

    tests[1].add_config("cfg", parameters=dict(config_parameter="set-from-config"))

    tests[2].set_parameter("set_parameter", "set-for-test")

    tests[3].add_config(
        "cfg",
        parameters=dict(set_parameter="set-for-test", config_parameter="set-from-config"),
    )

    def post_check(output_path):
        with (Path(output_path) / "post_check.txt").open("r") as fptr:
            return fptr.read() == "Test 4 was here"

    tests[4].add_config(
        "cfg",
        parameters=dict(set_parameter="set-from-config", config_parameter="set-from-config"),
        post_check=post_check,
    )


def configure_tb_same_sim_all_pass(ui):
    def post_check(output_path):
        with (Path(output_path) / "post_check.txt").open("r") as fptr:
            return fptr.read() == "Test 3 was here"

    module = ui.library("lib").module("tb_same_sim_all_pass")
    module.add_config("cfg", post_check=post_check)
    module = ui.library("lib").module("tb_same_sim_from_python_all_pass")
    module.add_config("cfg", post_check=post_check, attributes=dict(run_all_in_same_sim=True))
   
configure_tb_with_parameter_config()
configure_tb_same_sim_all_pass(vu)
lib.module("tb_same_sim_from_python_some_fail").set_attribute("run_all_in_same_sim", True)
lib.module("tb_other_file_tests").scan_tests_from_file(str(root / "other_file_tests.sv"))
lib.module("tb_fail_on_warning_from_python").set_attribute("fail_on_warning", True)

vu.main()
