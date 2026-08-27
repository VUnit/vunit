#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

"""
SystemVerilog UART
------------------

A more realistic test bench of an UART to show VUnit SystemVerilog
usage on a typical module.
"""

from pathlib import Path
from vunit import VUnit

SRC_PATH = Path(__file__).parent / "src"
VHDL_SRC_PATH = Path(__file__).parent / "../../vhdl/uart/src"
VU = VUnit.from_argv()
VU.add_verilog_builtins()
VU.add_vhdl_builtins()

uart_lib = VU.add_library("uart_lib")
uart_lib.add_source_files(SRC_PATH / "*.sv")
uart_lib.add_source_files(VHDL_SRC_PATH / "*.vhd")

VU.add_library("tb_uart_lib").add_source_files(SRC_PATH / "test" / "*.sv")

VU.set_sim_option("modelsim.vsim_flags", ["-suppress", "3839"])

VU.main()
