# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from glob import glob
from vunit import VUnit

ROOT = Path(__file__).parent

VU = VUnit.from_argv()
VU.add_vhdl_builtins()

LIB = VU.library("vunit_lib")
LIB.add_source_files(ROOT / ".." / "logging" / "test" / "test_support_pkg.vhd")
for fname in glob(str(ROOT / "test" / "*.vhd")):
    if Path(fname).name.endswith("2008p.vhd") and VU.vhdl_standard not in [
        "2008",
        "2019",
    ]:
        continue
    LIB.add_source_file(fname)

VU.set_sim_option("nvc.heap_size", "256m")

VU.main()
