# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit
from vivado_util import add_vivado_ip

ui = VUnit.from_argv()

root = dirname(__file__)
src_path = join(root, "src")

lib = ui.add_library("lib")
lib.add_source_files(join(src_path, "*.vhd"))

tb_lib = ui.add_library("tb_lib")
tb_lib.add_source_files(join(src_path, "test", "*.vhd"))

add_vivado_ip(ui,
              output_path=join(root, "vivado_libs"),
              project_file=join(root, "myproject", "myproject.xpr"))

ui.main()
