# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname, basename, abspath
import sys
from vunit.verilog import VUnit

vu = VUnit.from_argv()

root = dirname(__file__)

lib = vu.add_library("lib")

tb_list = lib.add_source_files(join(root, "test", "*.sv"))

vu.set_sim_option("modelsim.vsim_flags.gui", ["-novopt"])

vu.main()
