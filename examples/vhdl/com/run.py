# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

prj = VUnit.from_argv()
prj.add_com()
prj.add_verification_components()
prj.add_osvvm()

lib = prj.add_library('lib')
lib.add_source_files(join(dirname(__file__), 'src', '*.vhd'))

tb_lib = prj.add_library('tb_lib')
tb_lib.add_source_files(join(dirname(__file__), 'test', '*.vhd'))

prj.main()
