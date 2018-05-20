# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

vu = VUnit.from_argv()

vu.add_json4vhdl()

lib = vu.add_library("test")
lib.add_source_files(join(root, "src/test/*.vhd"))

import json
generics = json.loads(open(join(root, "src/test/data/data.json"), 'r').read())
vu.set_json_generic("tb_cfg", generics )

vu.main()
