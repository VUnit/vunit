#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

"""
Run
---

Demonstrates the VUnit run library.
"""

from pathlib import Path
from vunit import VUnit

ROOT = Path(__file__).parent

VU = VUnit.from_argv()
VU.add_vhdl_builtins()

LIB = VU.add_library("lib")
LIB.add_source_files(ROOT / "*.vhd")
LIB.entity("tb_with_lower_level_control").scan_tests_from_file(ROOT / "test_control.vhd")

VU.main()
