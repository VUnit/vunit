#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit
from subprocess import call


def post_run(results):
    results.merge_coverage(file_name="coverage_data")
    if VU.get_simulator_name() == "ghdl":
        call(["gcovr", "coverage_data"])


VU = VUnit.from_argv()
VU.add_vhdl_builtins()

LIB = VU.add_library("lib")
LIB.add_source_files(Path(__file__).parent / "*.vhd")

LIB.set_sim_option("enable_coverage", True)

LIB.set_compile_option("rivierapro.vcom_flags", ["-coverage", "bs"])
LIB.set_compile_option("rivierapro.vlog_flags", ["-coverage", "bs"])
LIB.set_compile_option("modelsim.vcom_flags", ["+cover=bs"])
LIB.set_compile_option("modelsim.vlog_flags", ["+cover=bs"])
LIB.set_compile_option("enable_coverage", True)

VU.main(post_run=post_run)
