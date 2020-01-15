# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
Run
---

Demonstrates the VUnit run library.
"""

from pathlib import Path
from vunit import VUnit

root = Path(__file__).parent

vu = VUnit.from_argv()

lib = vu.add_library("lib")
lib.add_source_files(root / "*.vhd")
tb_with_lower_level_control = lib.entity("tb_with_lower_level_control")
tb_with_lower_level_control.scan_tests_from_file(root / "test_control.vhd")

vu.main()
