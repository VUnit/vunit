#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit

ROOT = Path(__file__).parent

VU = VUnit.from_argv()
VU.add_verilog_builtins()

LIB = VU.add_library("lib")
LIB.add_source_files(ROOT / "*.sv")
LIB.add_source_files(ROOT / "*.vams").set_compile_option("modelsim.vlog_flags", ["-ams"])

VU.main()
