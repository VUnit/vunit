# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
SystemVerilog parameterized example
------------------------

The VUnit SystemVerilog project parameterized Test Example.
"""

from os.path import join, dirname
from vunit.verilog import VUnit

root = dirname(__file__)

ui = VUnit.from_argv()
lib = ui.add_library("lib")
lib.add_source_files(join(root, "*.sv"))

param_test1 = lib.module("tb_param_example");
param_test1.add_config(
        name="param_test1",
        generics=dict(
            DESCRIPTION="This Test is Parameterized Test No.1",
            NUMBER=1)
        );

param_test2 = lib.module("tb_param_example");
param_test2.add_config(
        name="param_test2",
        generics=dict(
            DESCRIPTION="Parameterized Test2",
            NUMBER=2)
        );

if __name__ == '__main__':
    ui.main()
