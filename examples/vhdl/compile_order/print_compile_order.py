# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Example of how you can extract compilation order using VUnit
Note that you cannot run VUnit normally via this script
"""

from os.path import join
from vunit import VUnit
from project import create_project, ROOT

ui = VUnit.from_argv(argv=[])
create_project(ui)
source_files = ui.get_project_compile_order(target=join(ROOT, "compile_order_top.vhd"))

for source_file in source_files:
    print(source_file.library.name + ", " + source_file.name)
