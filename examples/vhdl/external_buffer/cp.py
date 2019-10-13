# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

from vunit import VUnit
from os import popen
from os.path import join, dirname

src_path = join(dirname(__file__), "src")

c_obj = join(src_path, "cp.o")
# Compile C application to an object
print(
    popen(" ".join(["gcc", "-fPIC", "-c", join(src_path, "cp.c"), "-o", c_obj])).read()
)

# Enable the external feature for strings
vu = VUnit.from_argv(vhdl_standard="2008", compile_builtins=False)
vu.add_builtins({"string": True})

lib = vu.add_library("lib")
lib.add_source_files(join(src_path, "tb_extcp_*.vhd"))

# Add the C object to the elaboration of GHDL
vu.set_sim_option("ghdl.elab_flags", ["-Wl," + c_obj])

vu.main()
