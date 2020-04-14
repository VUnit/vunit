# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
Array and AXI4 Stream Verification Components
---------------------------------------------

Shows how to use ``integer_array_t``, ``axi_stream_master_t`` and ``axi_stream_slave_t``.
A CSV file is read, the content is sent in a row-major order to an AXI Stream buffer
(FIFO) and it is received back to be saved in a different file. Further information can
be found in the :ref:`verification component library user guide <vc_library>`,
in subsection :ref:`Stream <stream_vci>` and in
:vunit_file:`vhdl/verification_components/test/tb_axi_stream.vhd <vunit/vhdl/verification_components/test/tb_axi_stream.vhd>`.
"""

from pathlib import Path
from os import popen
from vunit import VUnit

VU = VUnit.from_argv()
VU.add_verification_components()

SRC_PATH = Path(__file__).parent / "src"

LIB = vu.add_library("lib")
LIB.add_source_files([SRC_PATH / "*.vhd", SRC_PATH / "**" / "*.vhd"])

# vu.set_sim_option('modelsim.init_files.after_load',['runall_addwave.do'])

C_NOBJ = join(src_path, "test", "stubs.o")
C_OBJ = join(src_path, "test", "main.o")
print(
    popen(
        "gcc -fPIC -rdynamic -c " + join(src_path, "**", "stubs.c") + " -o " + C_NOBJ
    ).read()
)
print(
    popen(
        "gcc -fPIC -rdynamic -c " + join(src_path, "**", "main.c") + " -o " + C_OBJ
    ).read()
)

for tb in lib.get_test_benches(pattern="*tb_py_*", allow_empty=False):
    tb.set_sim_option("ghdl.elab_flags", ["-Wl," + C_NOBJ], overwrite=False)

for tb in lib.get_test_benches(pattern="*tb_c_*", allow_empty=False):
    tb.set_sim_option("ghdl.elab_flags", ["-Wl," + C_OBJ], overwrite=False)

VU.main()
