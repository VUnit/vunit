# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

ui = VUnit.from_argv()
lib_A = ui.add_library("lib_A")
lib_A.add_source_files(join(root, "buffer_A.vhd"))
lib_B = ui.add_library("lib_B")
lib_B.add_source_files(join(root, "buffer_A.vhd"))
lib = ui.add_library("lib")
lib.add_source_files(join(root, "your_buffer.vhd"))

dep_files=ui.get_implementation_subset([ui.get_source_file(join(root, "your_buffer.vhd"))])
for file in dep_files:
    print "=> " + file.library.name +", "+file.name
ui.main()
