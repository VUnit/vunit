# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit
from vunit import ROOT

ui = VUnit.from_argv()
ui.enable_check_preprocessing()
lib = ui.add_library("lib")
lib.add_source_files(join(dirname(__file__), "check_example.vhd"))
common_path = join(ROOT, 'vhdl', 'common', 'test')
lib.add_source_files(join(common_path, "test_type_methods_api.vhd"))
lib.add_source_files(join(common_path, "test_types200x.vhd"))
lib.add_source_files(join(common_path, "test_type_methods200x.vhd"))
ui.main()
