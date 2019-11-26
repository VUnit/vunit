# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

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

from os.path import join, dirname
from vunit import VUnit

vu = VUnit.from_argv()
vu.add_verification_components()

src_path = join(dirname(__file__), "src")

vu.add_library("lib").add_source_files(
    [join(src_path, "*.vhd"), join(src_path, "**", "*.vhd")]
)

# vu.set_sim_option('modelsim.init_files.after_load',['runall_addwave.do'])

vu.main()
