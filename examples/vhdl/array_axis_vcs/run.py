#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Array and AXI4 Stream Verification Components
---------------------------------------------

Shows how to use ``integer_array_t``, ``axi_stream_master_t`` and ``axi_stream_slave_t``.
A CSV file is read, the content is sent in a row-major order to an AXI Stream buffer
(FIFO) and it is received back to be saved in a different file. Further information can
be found in the :ref:`verification component library user guide <vc_user_guide>`,
in subsection :ref:`Stream <stream_vci>` and in
:vunit_file:`vhdl/verification_components/test/tb_axi_stream.vhd <vunit/vhdl/verification_components/test/tb_axi_stream.vhd>`.
"""

from pathlib import Path
from vunit import VUnit

VU = VUnit.from_argv()
VU.add_vhdl_builtins()
VU.add_verification_components()

SRC_PATH = Path(__file__).parent / "src"

VU.add_library("lib").add_source_files([SRC_PATH / "*.vhd", SRC_PATH / "**" / "*.vhd"])

VU.set_sim_option("modelsim.init_file.gui", "runall_addwave.do")

VU.main()
