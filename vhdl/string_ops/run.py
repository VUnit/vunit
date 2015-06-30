# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)
common_path = join(root, "..", "common", "test")

ui = VUnit.from_argv()
lib = ui.add_library("lib")
lib.add_source_files(join(root, "test", "*.vhd"))
lib.add_source_files(join(common_path, "test_type_methods_api.vhd"))

if ui.vhdl_standard in ('2002', '2008'):
    lib.add_source_files(join(common_path, "test_types200x.vhd"))
    lib.add_source_files(join(common_path, "test_type_methods200x.vhd"))
elif ui.vhdl_standard == '93':
    lib.add_source_files(join(common_path, "test_types93.vhd"))
    lib.add_source_files(join(common_path, "test_type_methods93.vhd"))

ui.main()
