# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

from subprocess import check_call
from shutil import which
from pathlib import Path
from vunit import VUnit

SRC_PATH = Path(__file__).parent / "src"

C_OBJ = SRC_PATH / "cp.o"
# Compile C application to an object
check_call([which("gcc"), "-fPIC", "-c", str(SRC_PATH / "cp.c"), "-o", str(C_OBJ)])

# Enable the external feature for strings
VU = VUnit.from_argv(vhdl_standard="2008", compile_builtins=False)
VU.add_builtins({"string": True})

LIB = VU.add_library("lib")
LIB.add_source_files(SRC_PATH / "tb_extcp_*.vhd")

# Add the C object to the elaboration of GHDL
VU.set_sim_option("ghdl.elab_flags", ["-Wl," + str(C_OBJ)])

VU.main()
