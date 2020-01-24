# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from glob import glob
from vunit import VUnit

ROOT = Path(__file__).parent

VU = VUnit.from_argv()
LIB = VU.library("vunit_lib")
for fname in glob(str(ROOT / "test" / "*.vhd")):
    if Path(fname).name.endswith("2008p.vhd") and VU.vhdl_standard not in [
        "2008",
        "2019",
    ]:
        continue
    LIB.add_source_file(fname)

VU.main()
