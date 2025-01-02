#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Array
-----

Demonstrates the ``integer_array_t`` data type, which can be used to
handle dynamically sized 1D, 2D and 3D data as well as storing and
loading it from csv and raw files.
"""

from pathlib import Path
from vunit import VUnit

VU = VUnit.from_argv()
VU.add_vhdl_builtins()
VU.add_osvvm()

SRC_PATH = Path(__file__).parent / "src"

VU.add_library("lib").add_source_files([SRC_PATH / "*.vhd", SRC_PATH / "test" / "*.vhd"])

VU.set_compile_option("ghdl.a_flags", ["-frelaxed"])
VU.set_sim_option("ghdl.elab_flags", ["-frelaxed"])

VU.set_compile_option("nvc.a_flags", ["--relaxed"])

VU.main()
