#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Composite generics
------------------

See `Enable Your Simulator to Handle Complex Top-Level Generics <https://vunit.github.io/posts/2017_06_03_enable_your_simulator_to_handle_complex_top_level_generics/post.html>`_.
"""

from pathlib import Path
from vunit import VUnit


def encode(tb_cfg):
    return ", ".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])


VU = VUnit.from_argv()
VU.add_vhdl_builtins()

TB_LIB = VU.add_library("tb_lib")
TB_LIB.add_source_files(Path(__file__).parent / "test" / "*.vhd")

TEST = TB_LIB.test_bench("tb_composite_generics").test("Test 1")

TEST.add_config(
    name="VGA",
    generics=dict(encoded_tb_cfg=encode(dict(image_width=640, image_height=480, dump_debug_data=False))),
)

TEST.add_config(
    name="tiny",
    generics=dict(encoded_tb_cfg=encode(dict(image_width=4, image_height=3, dump_debug_data=True))),
)

VU.main()
