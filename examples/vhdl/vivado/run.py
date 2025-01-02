# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Vivado IP
---------

Demonstrates compiling and performing behavioral simulation of
Vivado IPs with VUnit.
"""

from pathlib import Path
from vunit import VUnit
from vivado_util import add_vivado_ip

ROOT = Path(__file__).parent
SRC_PATH = ROOT / "src"

VU = VUnit.from_argv()
VU.add_vhdl_builtins()

VU.add_library("lib").add_source_files(SRC_PATH / "*.vhd")
VU.add_library("tb_lib").add_source_files(SRC_PATH / "test" / "*.vhd")

add_vivado_ip(
    VU,
    output_path=ROOT / "vivado_libs",
    project_file=ROOT / "myproject" / "myproject.xpr",
)

VU.main()
