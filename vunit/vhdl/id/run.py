# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit

root = Path(__file__).parent

ui = VUnit.from_argv()
lib = ui.add_library("lib")
lib.add_source_files(root / "test" / "*.vhd")
lib.add_source_files(root / ".." / "logging" / "test" / "test_support_pkg.vhd")

ui.main()
