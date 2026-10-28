# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Run the yavs acceptance test bench
"""

from pathlib import Path
from vunit import VUnit

VU = VUnit.from_argv()
VU.add_vhdl_builtins()
VU.add_library("lib").add_source_files(Path(__file__).parent / "tb_yavs.vhd")
VU.main()
