# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit.verilog import VUnit

root = dirname(__file__)

ui = VUnit.from_argv()
lib = ui.add_library("lib")
lib.add_source_files(join(root, "*.sv"))

def add_uvm_test(bench, name, **kwargs):
    bench.add_config(name,
                     sim_options={
                         "rivierapro.vsim_flags": ["+TESTNAME=%s" % name],
                         "modelsim.vsim_flags": ["+TESTNAME=%s" % name]
                     },
                     **kwargs)

bench = lib.test_bench("tb_uvm")
add_uvm_test(bench, "foo")
add_uvm_test(bench, "bar")

ui.main()
