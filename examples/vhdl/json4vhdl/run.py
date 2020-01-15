# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

"""
JSON-for-VHDL
-------------

Demonstrates the ``JSON-for-VHDL`` library which can be used to parse JSON content.
The content can be read from a file, or passed as a stringified generic.
This is an alternative to composite generics, that supports any depth in the content structure.
"""

from pathlib import Path
from vunit import VUnit, read_json, encode_json

test_path = Path(__file__).parent / "src" / "test"

vu = VUnit.from_argv()
vu.add_json4vhdl()

vu.add_library("test").add_source_files(test_path / "*.vhd")

tb_cfg = read_json(test_path / "data" / "data.json")
tb_cfg["dump_debug_data"] = False
vu.set_generic("tb_cfg", encode_json(tb_cfg))

vu.main()
