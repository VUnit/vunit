# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname, basename
from vunit import VUnit
from glob import glob

root = dirname(__file__)

ui = VUnit.from_argv()
lib = ui.library("vunit_lib")
for file_name in glob(join(root, "test", "*")):
    if basename(file_name).endswith("2008.vhd") and ui.vhdl_standard != "2008":
        continue
    if basename(file_name) == "tb_codec-2008.vhd" and ui.vhdl_standard != "2008":
        continue
    lib.add_source_file(file_name)

ui.main()
