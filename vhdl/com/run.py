# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

# Make vunit python module importable
from os.path import join, dirname, basename
import sys
path_to_vunit = join(dirname(__file__), '..', '..')
sys.path.append(path_to_vunit)
#  -------

from vunit import VUnit

ui = VUnit.from_argv()

src_path = join(dirname(__file__), "src")

com_lib = ui.add_library('com_lib')
com_lib.add_source_files(join(dirname(__file__), 'src', '*.vhd'))

tb_com_lib = ui.add_library('tb_com_lib')
tb_com_lib.add_source_files(join(dirname(__file__), 'test', 'tb_com.vhd'))

ui.main()
