# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

from vunit import VUnit
from subprocess import check_call
from pathlib import Path

src_path = Path(__file__).parent / "src"

c_obj = src_path / "cp.o"
# Compile C application to an object
check_call(["gcc", "-fPIC", "-c", str(src_path / "cp.c"), "-o", str(c_obj)])

# Enable the external feature for strings
vu = VUnit.from_argv(vhdl_standard="2008", compile_builtins=False)
vu.add_builtins({"string": True})

lib = vu.add_library("lib")
lib.add_source_files(str(src_path / "tb_extcp_*.vhd"))

# Add the C object to the elaboration of GHDL
vu.set_sim_option("ghdl.elab_flags", ["-Wl," + str(c_obj)])

vu.main()
