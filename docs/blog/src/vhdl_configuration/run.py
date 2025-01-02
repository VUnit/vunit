#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

import sys
import itertools
from os import walk
from pathlib import Path
from io import StringIO
from vunit import VUnit, VUnitCLI
from tools.doc_support import highlight_code, highlight_log, LogRegistry

cli = VUnitCLI()
args = cli.parse_args()
root = Path(__file__).parent


def extract_snippets():
    for snippet in [
        "selecting_dut_with_generics",
    ]:
        highlight_code(
            root / "tb_selecting_dut_with_generics.vhd",
            root / ".." / ".." / "img" / "vhdl_configuration" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "create_vunit_configuration_for_selecting_dut",
        "create_vunit_configuration_for_selecting_dut_with_a_vhdl_configuration",
        "vhdl_configuration_on_a_test_case",
        "create_vunit_configuration_for_selecting_dut_and_runner_with_a_vhdl_configuration",
    ]:
        highlight_code(
            root / "run.py",
            root / ".." / ".." / "img" / "vhdl_configuration" / f"{snippet}.html",
            snippet,
            language="python",
        )

    for snippet in [
        "selecting_dut_with_vhdl_configuration",
    ]:
        highlight_code(
            root / "tb_selecting_dut_with_vhdl_configuration.vhd",
            root / ".." / ".." / "img" / "vhdl_configuration" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "test_runner_component_instantiation",
    ]:
        highlight_code(
            root / "tb_selecting_test_runner_with_vhdl_configuration.vhd",
            root / ".." / ".." / "img" / "vhdl_configuration" / f"{snippet}.html",
            snippet,
        )

    for snippet in ["test_reset_architecture_of_test_runner", "test_reset_configurations"]:
        highlight_code(
            root / "test_reset.vhd",
            root / ".." / ".." / "img" / "vhdl_configuration" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "test_runner_entity",
    ]:
        highlight_code(
            root / "test_runner.vhd",
            root / ".." / ".." / "img" / "vhdl_configuration" / f"{snippet}.html",
            snippet,
        )


extract_snippets()

testbenches = []
for _root, _dirs, files in walk(root):
    for f in files:
        if f.startswith("tb_") and f.endswith(".vhd"):
            testbenches.append(Path(f).stem)

test_patterns = [f"lib.{testbench}.*" for testbench in testbenches]
for testbench, test_pattern in zip(testbenches, test_patterns):
    args.test_patterns = [test_pattern]

    vu = VUnit.from_args(args=args)
    vu.add_vhdl_builtins()
    lib = vu.add_library("lib")
    lib.add_source_files(root / "*.vhd")

    # start_snippet create_vunit_configuration_for_selecting_dut
    tb = lib.test_bench("tb_selecting_dut_with_generics")

    for dut_arch, width in itertools.product(["rtl", "behavioral"], [8, 16]):
        tb.add_config(
            name=f"{dut_arch}_{width}",
            generics=dict(width=width, dff_arch=dut_arch),
        )
    # end_snippet create_vunit_configuration_for_selecting_dut

    # VHDL configurations are treated as a special case of the broader VUnit configuration
    # concept. As such the configuration can be extended beyond the capabilities of a
    # pure VHDL configuration. For example, by running with different generic values.

    # start_snippet create_vunit_configuration_for_selecting_dut_with_a_vhdl_configuration
    tb = lib.test_bench("tb_selecting_dut_with_vhdl_configuration")

    for dut_arch, width in itertools.product(["rtl", "behavioral"], [8, 16]):
        tb.add_config(
            name=f"{dut_arch}_{width}",
            generics=dict(width=width),
            vhdl_configuration_name=dut_arch,
        )
    # end_snippet create_vunit_configuration_for_selecting_dut_with_a_vhdl_configuration

    # A top-level VHDL configuration is bound to an entity, i.e. the testbench. However,
    # when handled as part of VUnit configurations it can also be applied to a
    # single test case

    # start_snippet vhdl_configuration_on_a_test_case
    tb.test("Test reset").add_config(name="rtl_32", generics=dict(width=32), vhdl_configuration_name="rtl")
    # end_snippet vhdl_configuration_on_a_test_case

    # If the test runner is placed in a component instantiated into the testbench, different architectures of that
    # component can implement different tests and VHDL configurations can be used to select what test to run.
    # This is the approach taken by a traditional OSVVM testbench. In VUnit, such a test becomes a VUnit configuration
    # selecting the associated VHDL configuration rather than a VUnit test case, but that is of less importance. Note that
    # this approach is limited in that the test runner architecture can't contain a test suite with explicit test cases
    # (run function calls) but only the test_runner_setup and test_runner_cleanup calls. Should you need multiple test
    # suites sharing the same test fixture (the DUT and the surrounding verification components), the proper approach
    # is to put each test suite in its own testbench and make the test fixture a component reused between the testbenches.
    # That approach do not require any VHDL configurations.

    # start_snippet create_vunit_configuration_for_selecting_dut_and_runner_with_a_vhdl_configuration
    tb = lib.test_bench("tb_selecting_test_runner_with_vhdl_configuration")

    for dut_arch, width, test_case_name in itertools.product(
        ["rtl", "behavioral"], [8, 16], ["test_reset", "test_state_change"]
    ):
        vhdl_configuration_name = f"{test_case_name}_{dut_arch}"
        tb.add_config(
            name=f"{vhdl_configuration_name}_{width}",
            generics=dict(width=width),
            vhdl_configuration_name=vhdl_configuration_name,
        )
    # end_snippet create_vunit_configuration_for_selecting_dut_and_runner_with_a_vhdl_configuration

    stringio = StringIO()
    _stdout = sys.stdout
    sys.stdout = stringio

    try:
        vu.main()
    except SystemExit:
        std_out = stringio.getvalue()
        sys.stdout = _stdout
        print(std_out)

        if args.list:
            (root / f"{testbench}_stdout.txt").write_text(f"> python run.py --list\n" + std_out)
            highlight_log(
                root / f"{testbench}_stdout.txt",
                root / ".." / ".." / "img" / "vhdl_configuration" / f"{testbench}_stdout.html",
            )
