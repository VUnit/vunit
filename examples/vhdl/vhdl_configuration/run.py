#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit
from vunit.json4vhdl import encode_json, b16encode

vu = VUnit.from_argv()
vu.add_vhdl_builtins()
lib = vu.add_library("lib")
lib.add_source_files(Path(__file__).parent / "*.vhd")
lib.add_source_files(Path(__file__).parent / "handling_generics_limitation" / "*.vhd")

# VHDL configurations are detected automatically and are treated as a special
# case of the broader VUnit configuration concept. As such the configuration
# can be extended beyond the capabilities of a pure VHDL configuration. For example,
# by adding a pre_config or post_check function hooks. The exception is generics since VHDL
# doesn't allow generics to be combined with configurations.
# Workarounds for this limitation can be found in the handling_generics_limitation directory

# Get the VHDL-defined configurations from test or testbench objects using a pattern matching
# configurations of interest.
tb = lib.test_bench("tb_selecting_dut_with_vhdl_configuration")
configs = tb.get_configs("dff_*")


# Remember to run the run script with the -v flag to see the message from the dummy post_check
def make_hook(msg):
    def hook(output_path):
        print(msg)

        return True

    return hook


configs.set_post_check(make_hook("Common post_check"))

# You can also loop over the matching configurations
for config in configs:
    config.set_pre_config(make_hook(f"pre_config for {config.name}"))

# The testbenches in the handling_generics_limitation directory are examples of how the generics
# limitation of VHDL configurations can be worked around. This allow us to create configurations
# with different settings for the DUT width generic

# This testbench replaces VHDL configurations with generate statements
tb = lib.test_bench("tb_selecting_dut_with_generate_statement")
for width in [8, 32]:
    for arch in ["rtl", "behavioral"]:
        tb.add_config(name=f"dut_{arch}_width={width}", generics=dict(dut_arch=arch, width=width))

# Instead of having a testbench containing a shared test fixture
# and then use VHDL configurations to select different test runners implementing
# different tests one can flip things upside down. Each test become a separate
# top-level testbench and the shared test fixture is placed in a separate entity
# imported by each tetbench.
for tb_name in ["tb_reset", "tb_state_change"]:
    tb = lib.test_bench(tb_name)
    for width in [8, 32]:
        tb.add_config(name=f"width={width}", generics=dict(width=width))

vu.main()
