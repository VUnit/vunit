#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit

vu = VUnit.from_argv()
vu.add_vhdl_builtins()
lib = vu.add_library("lib")
root = Path(__file__).parent
lib.add_source_files(root / "*.vhd")

# VHDL configurations are treated as a special case of the broader VUnit configuration
# concept. As such the configuration can be extended beyond the capabilities of a
# pure VHDL configuration. For example, by running with different generic values.
tb = lib.test_bench("tb_selecting_dut_with_vhdl_configuration")

for dut_architecture in ["rtl", "behavioral"]:
    for width in [8, 16]:
        tb.add_config(
            name=f"{dut_architecture}_{width}",
            generics=dict(width=width),
            vhdl_configuration_name=dut_architecture,
        )

# A top-level VHDL configuration is bound to an entity, i.e. the testbench. However,
# when handled as part of VUnit configurations it can also be applied to a
# single test case
tb.test("Test reset").add_config(name="rtl_32", generics=dict(width=32), vhdl_configuration_name="rtl")


# If the test runner is placed in a component instantiated into the testbench, different architectures of that
# component can implement different tests and VHDL configurations can be used to select what test to run.
# This is the approach taken by a traditional OSVVM testbench. In VUnit, such a test becomes a VUnit configuration
# selecting the associated VHDL configuration rather than a VUnit test case, but that is of less importance. Note that
# this approach is limited in that the test runner architecture can't contain a test suite with explicit test cases
# (run function calls) but only the test_runner_setup and test_runner_cleanup calls. Should you need multiple test
# suites sharing the same test fixture (the DUT and the surrounding verification components), the proper approach
# is to put each test suite in its own testbench and make the test fixture a component reused between the testbenches.
# That approach do not require any VHDL configurations.
tb = lib.test_bench("tb_selecting_test_runner_with_vhdl_configuration")
for test_case_name in ["test_reset", "test_state_change"]:
    for dut_architecture in ["rtl", "behavioral"]:
        vhdl_configuration_name = f"{test_case_name}_{dut_architecture}"
        for width in [8, 16]:
            tb.add_config(
                name=f"{vhdl_configuration_name}_{width}",
                generics=dict(width=width),
                vhdl_configuration_name=vhdl_configuration_name,
            )

vu.main()
