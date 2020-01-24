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

from subprocess import check_call
from shutil import which
from pathlib import Path
from vunit import VUnit, ROOT

SRC_PATH = Path(__file__).parent / "src"
EXT_SRCS = Path(ROOT) / "vunit" / "vhdl" / "data_types" / "src" / "external" / "ghdl"

# Compile C applications to an objects
C_IOBJ = SRC_PATH / "imain.o"
C_BOBJ = SRC_PATH / "bmain.o"

for val in [["int32_t", C_IOBJ], ["uint8_t", C_BOBJ]]:
    check_call(
        [
            which("gcc"),
            "-fPIC",
            "-DTYPE=" + val[0],
            "-I",
            EXT_SRCS,
            "-c",
            SRC_PATH / "main.c",
            "-o",
            val[1],
        ]
    )

# Enable the external feature for strings/byte_vectors and integer_vectors
VU = VUnit.from_argv(vhdl_standard="2008", compile_builtins=False)
VU.add_builtins({"string": True, "integer": True})

LIB = VU.add_library("lib")
LIB.add_source_files(SRC_PATH / "tb_ext_*.vhd")

# Add the C object to the elaboration of GHDL
for tb in LIB.get_test_benches(pattern="*tb_ext*", allow_empty=False):
    tb.set_sim_option(
        "ghdl.elab_flags",
        ["-Wl," + str(C_BOBJ), "-Wl,-Wl,--version-script=" + str(EXT_SRCS / "grt.ver")],
        overwrite=True,
    )
for tb in LIB.get_test_benches(pattern="*tb_ext*_integer*", allow_empty=False):
    tb.set_sim_option(
        "ghdl.elab_flags",
        ["-Wl," + str(C_IOBJ), "-Wl,-Wl,--version-script=" + str(EXT_SRCS / "grt.ver")],
        overwrite=True,
    )

VU.main()
