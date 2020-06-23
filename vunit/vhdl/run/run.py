# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit

ROOT = Path(__file__).parent

UI = VUnit.from_argv()
UI.add_library("tb_run_lib").add_source_files(ROOT / "test" / "*.vhd")

UI.main()
