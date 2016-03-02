# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)
ui = VUnit.from_argv()

# Testing of the runner is special the test bench does not have a runner_cfg
ui._tb_filter = lambda design_unit: design_unit.name.startswith("tb_")

lib = ui.add_library("tb_run_lib")
lib.add_source_files(join(root, 'test', '*.vhd'))
ui.main()
