# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
Submodule support
-------------

This is only a small example and shows how a complete vunit design can be 
imported at once. Intended use case could be a seperately managed periphery
which gets imported in a bigger top design like a CPU or complete vhdl librarys.
"""

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

vu = VUnit.from_argv()

vu.add_json4vhdl()

lib = vu.add_library("adder")
lib.add_source_files(join(root, "src/*.vhd"))

if __name__ == '__main__':
    vu.main()
