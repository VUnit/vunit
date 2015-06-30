# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

ui = VUnit.from_argv()
ui.add_osvvm()
ui.enable_location_preprocessing()
ui.enable_check_preprocessing()
ui.add_com()
shuffler_lib = ui.add_library('shuffler_lib')
shuffler_lib.add_source_files(join(dirname(__file__), 'src', '*.vhd'))

tb_shuffler_lib = ui.add_library('tb_shuffler_lib')
tb_shuffler_lib.add_source_files(join(dirname(__file__), 'test', '*.vhd'))
pkg = tb_shuffler_lib.package('msg_types_pkg')
pkg.generate_codecs(codec_package_name='msg_codecs_pkg')
ui.main()
