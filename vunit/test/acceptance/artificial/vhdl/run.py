# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

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
            return fptr.read() == "Test 4 was here"

    tests[4].add_config("",
                        generics=dict(set_generic="set-from-config",
                                      config_generic="set-from-config"),
                        post_check=post_check)


def configure_tb_same_sim_all_pass(self):
    def post_check(output_path):
        with open(join(output_path, "post_check.txt"), "r") as fptr:
            return fptr.read() == "Test 3 was here"
    ent = ui.library("lib").entity("tb_same_sim_all_pass")
    ent.add_config("", generics=dict(), post_check=post_check)


configure_tb_with_generic_config(ui)
configure_tb_same_sim_all_pass(ui)
lib.entity("tb_ieee_warning").test("pass").disable_ieee_warnings()
ui.main()
