# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

ui = VUnit.from_argv()
ui.add_com()
tb_com_lib = ui.add_library("tb_com_lib")
tb_com_lib.add_source_files(join(root, 'test', '*.vhd'))
pkg = tb_com_lib.package('custom_types_pkg')
pkg.generate_codecs(codec_package_name='custom_codec_pkg', used_packages=['ieee.std_logic_1164', 'constants_pkg',
                                                                          'tb_com_lib.more_constants_pkg'])
ui.main()
