# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
Submodule support
-------------
This script shows how to import smaller submodules in a bigger design. 

The submodules contains a own run.py script in which the sources are defined.
With 'add_submodule' you can add the complete project into your top design.
Usecase could be a CPU design which uses some periphery which is managed in 
seperate projects.
"""

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

vu = VUnit.from_argv()

vu.add_json4vhdl()

lib = vu.add_library("lib")
lib.add_source_files(join(root, "src/*.vhd"))
lib.add_source_files(join(root, "tb/*.vhd"))

vu.add_submodule('src/adder/run.py')

if __name__ == '__main__':
    vu.main()
