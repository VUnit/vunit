# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit

vu = VUnit.from_argv()
vu.add_vhdl_builtins()

lib = vu.add_library("lib")
lib.add_source_files(Path(__file__).parent / "*.vhd")

tb = lib.test_bench("tb_example")
test = tb.test("test 2")

for value in range(3):
    test.add_config(name=f"{value}", generics=dict(value=value))

vu.set_sim_option("modelsim.three_step_flow", True)

vu.main()
