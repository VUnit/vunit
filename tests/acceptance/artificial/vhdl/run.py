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
vu.add_vhdl_builtins()

lib = vu.add_library("lib")
lib2 = vu.add_library("lib2")

for file in glob(str(root / "*.vhd")):
    if "tb_set_generic" in file:
        lib2.add_source_files(file)
    elif "other_logging_framework" in file:
        continue
    else:
        lib.add_source_files(file)


def configure_tb_with_generic_config():
    """
    Configure tb_with_generic_config test bench
    """
    bench = lib.entity("tb_with_generic_config")
    tests = [bench.test("Test %i" % i) for i in range(5)]

    bench.set_generic("set_generic", "set-for-entity")

    tests[1].add_config("cfg", generics=dict(config_generic="set-from-config"))

    tests[2].set_generic("set_generic", "set-for-test")

    tests[3].add_config(
        "cfg",
        generics=dict(set_generic="set-for-test", config_generic="set-from-config"),
    )

    def post_check(output_path):
        with (Path(output_path) / "post_check.txt").open("r") as fptr:
            return "Test 4 was here" in fptr.read()

    tests[4].add_config(
        "cfg",
        generics=dict(set_generic="set-from-config", config_generic="set-from-config"),
        post_check=post_check,
    )


def configure_tb_same_sim_all_pass(ui):
    def post_check(output_path):
        with (Path(output_path) / "post_check.txt").open("r") as fptr:
            return "Test 3 was here" in fptr.read()

    ent = ui.library("lib").entity("tb_same_sim_all_pass")
    ent.add_config("cfg", post_check=post_check)
    ent = ui.library("lib").entity("tb_same_sim_from_python_all_pass")
    ent.add_config("cfg", post_check=post_check, attributes=dict(run_all_in_same_sim=True))


def configure_tb_set_generic(ui):
    libs = ui.get_libraries("lib2")
    lib2 = ui.library("lib2")
    tb = lib2.entity("tb_set_generic")
    is_ghdl = ui._simulator_class.name == "ghdl"
    tb.set_generic("is_ghdl", is_ghdl)
    lib2.set_generic("true_boolean", True)
    libs.set_generic("false_boolean", False)
    tb.set_generic("negative_integer", -10000)
    tb.set_generic("positive_integer", 99999)
    if not is_ghdl:
        tb.set_generic("negative_real", -9999.9)
        tb.set_generic("positive_real", 2222.2)
        tb.set_generic("time_val", "4ns")
    tb.set_generic("str_val", "4ns")
    tb.set_generic("str_space_val", "1 2 3")
    tb.set_generic("str_quote_val", 'a"b')
    str_long_num = 512
    tb.set_generic("str_long_num", str_long_num)
    tb.set_generic("str_long_val", "".join(["0123456789abcdef" for x in range(str_long_num)]))


def configure_tb_assert_stop_level(ui):
    tb = ui.library("lib").entity("tb_assert_stop_level")

    for vhdl_assert_stop_level in ["warning", "error", "failure"]:
        for report_level in ["warning", "error", "failure"]:
            test = tb.test("Report %s when VHDL assert stop level = %s" % (report_level, vhdl_assert_stop_level))
            test.set_sim_option("vhdl_assert_stop_level", vhdl_assert_stop_level)


def configure_tb_with_vhdl_configuration(ui):
    def make_post_check(expected_arch):
        def post_check(output_path):
            arch = (Path(output_path) / "result.txt").read_text()
            if arch[:-1] != expected_arch:
                raise RuntimeError(f"Error! Got {arch[: -1]}, expected {expected_arch}")

            return True

        return post_check

    tb = ui.library("lib").test_bench("tb_with_vhdl_configuration")
    test_2 = tb.test("test 2")
    test_3 = tb.test("test 3")

    tb.set_vhdl_configuration_name("cfg1")
    tb.set_post_check(make_post_check("arch1"))
    test_2.set_vhdl_configuration_name("cfg2")
    test_2.add_config(name="cfg2", post_check=make_post_check("arch2"))
    test_3.add_config(name="cfg3", post_check=make_post_check("arch3"), vhdl_configuration_name="cfg3")

def configure_tb_no_fail_on_warning(ui):
    tb = ui.library("lib").test_bench("tb_no_fail_on_warning")
    tb.add_config(name="cfg1", attributes=dict(fail_on_warning=False))
    tb.add_config(name="cfg2")

configure_tb_with_generic_config()
configure_tb_same_sim_all_pass(vu)
configure_tb_set_generic(vu)
configure_tb_assert_stop_level(vu)
configure_tb_with_vhdl_configuration(vu)
configure_tb_no_fail_on_warning(vu)
lib.entity("tb_no_generic_override").set_generic("g_val", False)
lib.entity("tb_ieee_warning").test("pass").set_sim_option("disable_ieee_warnings", True)
lib.entity("tb_other_file_tests").scan_tests_from_file(str(root / "other_file_tests.vhd"))
lib.entity("tb_same_sim_from_python_some_fail").set_attribute("run_all_in_same_sim", True)
lib.entity("tb_fail_on_warning_from_python").set_attribute("fail_on_warning", True)

vu.main()
