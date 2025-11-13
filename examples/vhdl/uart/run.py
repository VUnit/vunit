#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
VHDL UART
---------

A more realistic test bench of an UART to show VUnit VHDL usage on a
typical module.
"""

from pathlib import Path
from vunit import VUnit
from subprocess import call


def post_run(results):
    results.merge_coverage(file_name="coverage_data")
    if VU.get_simulator_name() == "ghdl":
        if results._simulator_if._backend == "gcc":
            call(["gcovr", "coverage_data"])
        else:
            call(["gcovr", "-a", "coverage_data/gcovr.json"])
    elif VU.get_simulator_name() == "nvc":
        call(["nvc", "--cover-report", "coverage_data.ncdb", "-o", "output_coverage"])


VU = VUnit.from_argv()
VU.add_vhdl_builtins()
VU.add_osvvm()
VU.add_verification_components()

SRC_PATH = Path(__file__).parent / "src"

VU.add_library("uart_lib").add_source_files(SRC_PATH / "*.vhd")
VU.add_library("tb_uart_lib").add_source_files(SRC_PATH / "test" / "*.vhd")

VU.set_sim_option("enable_coverage", True)

VU.set_sim_option("nvc.elab_flags", ["--cover=branch,statement"])
VU.set_compile_option("rivierapro.vcom_flags", ["-coverage", "bs"])
VU.set_compile_option("rivierapro.vlog_flags", ["-coverage", "bs"])
VU.set_compile_option("modelsim.vcom_flags", ["+cover=bs"])
VU.set_compile_option("modelsim.vlog_flags", ["+cover=bs"])
VU.set_compile_option("enable_coverage", True)

VU.main(post_run=post_run)
