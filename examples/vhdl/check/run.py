# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2017, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

ui = VUnit.from_argv()

# Enable location preprocessing but exclude all but chec_false to make the
# example less bloated
ui.enable_location_preprocessing()
subprograms = list(ui._location_preprocessor._subprograms_with_arguments)
for s in subprograms:
    if s != 'check_false':
        ui._location_preprocessor.remove_subprogram(s)

ui.enable_check_preprocessing()

lib = ui.add_library("lib")
lib.add_source_files(join(dirname(__file__), "tb_example.vhd"))

ui.main()
