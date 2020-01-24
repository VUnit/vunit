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

TEST_PATH = Path(__file__).parent / "src" / "test"

VU = VUnit.from_argv()
VU.add_json4vhdl()

VU.add_library("test").add_source_files(TEST_PATH / "*.vhd")

TB_CFG = read_json(TEST_PATH / "data" / "data.json")
TB_CFG["dump_debug_data"] = False
VU.set_generic("tb_cfg", encode_json(TB_CFG))

VU.main()
