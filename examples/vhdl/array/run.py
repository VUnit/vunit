# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
Array
-----

Demonstrates the ``array_t`` data type of ``array_pkg.vhd`` which
can be used to handle dynamically sized 1D, 2D and 3D data as well
as storing and loading it from csv and raw files.
"""

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

ui = VUnit.from_argv()
ui.add_osvvm()
ui.add_array_util()
lib = ui.add_library("lib")
lib.add_source_files(join(root, "src", "*.vhd"))
lib.add_source_files(join(root, "src", "test", "*.vhd"))

if __name__ == '__main__':
    ui.main()
