# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit


ROOT = Path(__file__).parent

VU = VUnit.from_argv()
VU.add_verilog_builtins()

VU.add_library("lib").add_source_files(ROOT / "test" / "*.sv")
VU.set_sim_option("modelsim.vsim_flags.gui", ["-novopt"])

VU.main()
