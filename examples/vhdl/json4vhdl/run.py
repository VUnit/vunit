#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
JSON-for-VHDL
-------------

Demonstrates the ``JSON-for-VHDL`` library which can be used to parse JSON content.
The content can be read from a file, or passed as a stringified generic.
This is an alternative to composite generics, that supports any depth in the content structure.
"""

from pathlib import Path
from vunit import VUnit
from vunit.json4vhdl import read_json, encode_json, b16encode

TEST_PATH = Path(__file__).parent / "src" / "test"

VU = VUnit.from_argv()
VU.add_vhdl_builtins()
VU.add_json4vhdl()

LIB = VU.add_library("test")
LIB.add_source_files(TEST_PATH / "*.vhd")

TB_CFG = read_json(TEST_PATH / "data" / "data.json")
TB_CFG["dump_debug_data"] = False
JSON_STR = encode_json(TB_CFG)
JSON_FILE = Path("data") / "data.json"

TB = LIB.get_test_benches()[0]

TB.get_tests("stringified*")[0].set_generic("tb_cfg", JSON_STR)
TB.get_tests("b16encoded stringified*")[0].set_generic("tb_cfg", b16encode(JSON_STR))
TB.get_tests("JSON file*")[0].set_generic("tb_cfg", JSON_FILE)
TB.get_tests("b16encoded JSON file*")[0].set_generic("tb_cfg", b16encode(str(TEST_PATH / JSON_FILE)))

VU.main()
