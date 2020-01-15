# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
VHDL UART
---------

A more realistic test bench of an UART to show VUnit VHDL usage on a
typical module.
"""

from pathlib import Path
from vunit import VUnit

vu = VUnit.from_argv()
vu.add_osvvm()
vu.add_verification_components()

src_path = Path(__file__).parent / "src"

vu.add_library("uart_lib").add_source_files(src_path / "*.vhd")
vu.add_library("tb_uart_lib").add_source_files(src_path / "test" / "*.vhd")

vu.main()
