# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname, basename, abspath
import sys
from vunit.verilog import VUnit

vu = VUnit.from_argv()

root = dirname(__file__)

lib = vu.add_library("lib")

tb_list = lib.add_source_files(join(root, "test", "*.sv"))


vu.set_sim_option("modelsim.vsim_flags.gui", ["-novopt"])

#Uncomment these later when coverage reporting is added
#vu.set_sim_option("modelsim.vsim_flags", ["-assertcover"])

#lib.set_compile_option("modelsim.vcom_flags", ["+cover=bs"])
#lib.set_compile_option("modelsim.vlog_flags", ["+cover=bs"])
#lib.set_sim_option("enable_coverage", True)

def post_run(results):
    results.merge_coverage(
        file_name=join(root, "vunit_out", "mlc_coverage_data.ucdb"),
        args=["-quiet"]
    )


vu.main()
#TODO: Compile coverage report
#vu.main(post_run=post_run)
