#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
SystemVerilog UART
------------------

A more realistic test bench of an UART to show VUnit SystemVerilog
usage on a typical module.
"""

from pathlib import Path
from vunit import VUnit

SRC_PATH = Path(__file__).parent / "src"

VU = VUnit.from_argv()
VU.add_verilog_builtins()

VU.add_library("uart_lib").add_source_files(SRC_PATH / "*.sv")
VU.add_library("tb_uart_lib").add_source_files(SRC_PATH / "test" / "*.sv")

VU.main()
