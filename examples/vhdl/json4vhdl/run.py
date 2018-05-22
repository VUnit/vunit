# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit, read_json, encode_json, add_array_lens

root = dirname(__file__)

vu = VUnit.from_argv()

vu.add_json4vhdl()

lib = vu.add_library("test")
lib.add_source_files(join(root, "src/test/*.vhd"))

tb_cfg = read_json(join(root, "src/test/data/data.json"))
tb_cfg["dump_debug_data"]=False
vu.set_generic("tb_cfg", encode_json(add_array_lens(tb_cfg)))

vu.main()
