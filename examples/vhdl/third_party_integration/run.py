# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit

vu = VUnit.from_argv()
vu.add_library("lib").add_source_files(Path(__file__).parent / "test" / "*.vhd")
vu.main()
