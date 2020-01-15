# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
External Buffer
---------------

`Interfacing with foreign languages (C) through VHPIDIRECT <https://ghdl.readthedocs.io/en/latest/using/Foreign.html>`_

An array of type ``uint8_t`` is allocated in a C application and some values
are written to the first ``1/3`` positions. Then, the VHDL simulation is
executed, where the (external) array/buffer is used.

In the VHDL testbenches, two vector pointers are created, each of them using
a different access mechanism (``extfunc`` or ``extacc``). One of them is used to copy
the first ``1/3`` elements to positions ``[1/3, 2/3)``, while incrementing each value
by one. The second one is used to copy elements from ``[1/3, 2/3)`` to ``[2/3, 3/3)``,
while incrementing each value by two.

When the simulation is finished, the C application checks whether data was successfully
copied/modified. The content of the buffer is printed both before and after the
simulation.
"""

from vunit import VUnit, ROOT
from subprocess import check_call
from pathlib import Path

src_path = Path(__file__).parent / "src"
ext_srcs = Path(ROOT) / "vunit" / "vhdl" / "data_types" / "src" / "external" / "ghdl"

# Compile C applications to an objects
c_iobj = src_path / "imain.o"
c_bobj = src_path / "bmain.o"

for val in [["int32_t", c_iobj], ["uint8_t", c_bobj]]:
    check_call(
        [
            "gcc",
            "-fPIC",
            "-DTYPE=" + val[0],
            "-I",
            ext_srcs,
            "-c",
            src_path / "main.c",
            "-o",
            val[1],
        ]
    )

# Enable the external feature for strings/byte_vectors and integer_vectors
vu = VUnit.from_argv(vhdl_standard="2008", compile_builtins=False)
vu.add_builtins({"string": True, "integer": True})

lib = vu.add_library("lib")
lib.add_source_files(src_path / "tb_ext_*.vhd")

# Add the C object to the elaboration of GHDL
for tb in lib.get_test_benches(pattern="*tb_ext*", allow_empty=False):
    tb.set_sim_option(
        "ghdl.elab_flags",
        ["-Wl," + str(c_bobj), "-Wl,-Wl,--version-script=" + str(ext_srcs / "grt.ver")],
        overwrite=True,
    )
for tb in lib.get_test_benches(pattern="*tb_ext*_integer*", allow_empty=False):
    tb.set_sim_option(
        "ghdl.elab_flags",
        ["-Wl," + str(c_iobj), "-Wl,-Wl,--version-script=" + str(ext_srcs / "grt.ver")],
        overwrite=True,
    )

vu.main()
