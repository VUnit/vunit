# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

ui = VUnit.from_argv()
lib = ui.add_library("lib")
lib.add_source_files(join(root, "*.vhd"))

lib.set_compile_option("rivierapro.vcom_flags", ["-coverage", "bs"])
lib.set_compile_option("rivierapro.vlog_flags", ["-coverage", "bs"])
lib.set_compile_option("modelsim.vcom_flags", ["+cover=bs"])
lib.set_compile_option("modelsim.vlog_flags", ["+cover=bs"])
lib.set_sim_option("enable_coverage", True)

def post_run(results):
    results.merge_coverage(file_name="coverage_data")

ui.main(post_run=post_run)
