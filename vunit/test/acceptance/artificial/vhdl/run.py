# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2017, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

ui = VUnit.from_argv()
lib = ui.add_library("lib")
lib.add_source_files(join(root, "*.vhd"))


def configure_tb_with_generic_config(ui):
    """
    Configure tb_with_generic_config test bench
    """
    bench = lib.entity("tb_with_generic_config")
    tests = [bench.test("Test %i" % i) for i in range(5)]

    bench.set_generic("set_generic", "set-for-entity")

    tests[1].add_config("", generics=dict(config_generic="set-from-config"))

    tests[2].set_generic("set_generic", "set-for-test")

    tests[3].add_config("", generics=dict(set_generic="set-for-test",
                                          config_generic="set-from-config"))

    def post_check(output_path):
        with open(join(output_path, "post_check.txt"), "r") as fptr:
            return "Test 4 was here" in fptr.read()

    tests[4].add_config("",
                        generics=dict(set_generic="set-from-config",
                                      config_generic="set-from-config"),
                        post_check=post_check)


def configure_tb_same_sim_all_pass(ui):
    def post_check(output_path):
        with open(join(output_path, "post_check.txt"), "r") as fptr:
            return "Test 3 was here" in fptr.read()
    ent = ui.library("lib").entity("tb_same_sim_all_pass")
    ent.add_config("", generics=dict(), post_check=post_check)


def configure_tb_set_generic(ui):
    tb = ui.library("lib").entity("tb_set_generic")
    is_ghdl = ui._simulator_factory.select_simulator().name == "ghdl"
    tb.set_generic("is_ghdl", is_ghdl)
    tb.set_generic("true_boolean", True)
    tb.set_generic("false_boolean", False)
    tb.set_generic("negative_integer", -10000)
    tb.set_generic("positive_integer", 99999)
    if not is_ghdl:
        tb.set_generic("negative_real", -9999.9)
        tb.set_generic("positive_real", 2222.2)
        tb.set_generic("time_val", "4ns")
    tb.set_generic("str_val", "4ns")
    tb.set_generic("str_space_val", "1 2 3")
    tb.set_generic("str_quote_val", 'a"b')


def configure_tb_assert_stop_level(ui):
    tb = ui.library("lib").entity("tb_assert_stop_level")

    for level in ["warning", "error", "failure"]:
        tb.test("Test with VHDL assert stop level = %s" % level).set_sim_option("vhdl_assert_stop_level", level)
        tb.add_config(level, generics=dict(level=level))

configure_tb_with_generic_config(ui)
configure_tb_same_sim_all_pass(ui)
configure_tb_set_generic(ui)
configure_tb_assert_stop_level(ui)
lib.entity("tb_no_generic_override").set_generic("g_val", False)
lib.entity("tb_ieee_warning").test("pass").disable_ieee_warnings()
lib.entity("tb_other_file_tests").scan_tests_from_file(join(root, "other_file_tests.vhd"))
ui.main()
