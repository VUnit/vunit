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

vu = VUnit.from_argv()
vu.add_osvvm()
vu.add_array_util()

src_path = join(dirname(__file__), "src")

vu.add_library("lib").add_source_files(
    [join(src_path, "*.vhd"), join(src_path, "test", "*.vhd")]
)

vu.main()
