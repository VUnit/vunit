#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit, VUnitCLI
from io import StringIO
from multiprocessing import cpu_count
import sys
import re
from tools.doc_support import highlight_code, highlight_log, LogRegistry

root = Path(__file__).parent


def extract_snippets():
    for snippet in [
        "tb_minimal",
    ]:
        highlight_code(
            root / "tb_minimal.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "test_runner_with_test_cases",
    ]:
        highlight_code(
            root / "tb_with_test_cases.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "tb_running_test_case",
    ]:
        highlight_code(
            root / "tb_running_test_case.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "tb_with_lower_level_control",
    ]:
        highlight_code(
            root / "tb_with_lower_level_control.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "test_control",
    ]:
        highlight_code(
            root / "test_control.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "tb_run_all_in_same_sim",
    ]:
        highlight_code(
            root / "tb_run_all_in_same_sim.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "tb_with_watchdog",
    ]:
        highlight_code(
            root / "tb_with_watchdog.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "tb_stopping_failure",
    ]:
        highlight_code(
            root / "tb_stopping_failure.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "tb_fail_on_warning",
    ]:
        highlight_code(
            root / "tb_fail_on_warning.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "tb_stop_level",
    ]:
        highlight_code(
            root / "tb_stop_level.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "tb_standalone",
    ]:
        highlight_code(
            root / "tb_standalone.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "tb_magic_paths",
    ]:
        highlight_code(
            root / "tb_magic_paths.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "get_seed_and_runner_cfg",
        "get_seed_wo_runner_cfg",
        "get_uniform_seed",
    ]:
        highlight_code(
            root / "tb_seed.vhd",
            root / ".." / "img" / f"{snippet}.html",
            snippet,
        )


extract_snippets()

seed_option_path = root / "seed_option.txt"
seed_option_path.write_text('> python run.py "lib.tb_seed.Test that fails" --seed fb19f3cca859d69c')
highlight_log(seed_option_path, root / ".." / "img" / "seed_option.html")


def post_run(log_registry):
    def _post_run(results):
        log_registry.generate_logs()

    return _post_run


test_name_re = re.compile(r"Starting\s+(?P<test_case_name>.*?)$", re.MULTILINE | re.DOTALL)

cli = VUnitCLI()
args = cli.parse_args()

print(args.test_patterns)

if args.compile or args.list:
    test_patterns = ["*"]
elif args.test_patterns[0] != "*":
    test_patterns = [args.test_patterns]
else:
    test_patterns = [
        "lib.tb_minimal*",
        "lib.tb_with_test_cases*",
        "lib.tb_running_test_case*",
        "lib.tb_with_lower_level_control*",
        "lib.tb_with_watchdog*",
        "lib.tb_stopping_failure*",
        "lib.tb_stop_level*",
        "lib.tb_seed*",
        "lib.tb_magic_paths*",
    ]

for test_pattern in test_patterns:
    stringio = StringIO()
    _stdout = sys.stdout
    sys.stdout = stringio

    if isinstance(test_pattern, list):
        args.test_patterns = test_pattern
    else:
        args.test_patterns = [test_pattern]

    options = ""
    if test_pattern == "lib.tb_magic_paths*":
        args.verbose = True
        options += " -v"

    vu = VUnit.from_args(args=args)
    vu.add_vhdl_builtins()

    lib = vu.add_library("lib")
    lib.add_source_files(root / "*.vhd")
    tb_with_lower_level_control = lib.test_bench("tb_with_lower_level_control")
    tb_with_lower_level_control.scan_tests_from_file(root / "test_control.vhd")

    lib.test_bench("tb_seed").test("Test that fails").set_sim_option("seed", "fb19f3cca859d69c")

    log_registry = LogRegistry()

    vu.set_compile_option("rivierapro.vcom_flags", ["-dbg"])
    try:
        vu.main()  # post_run(log_registry))
    except SystemExit:
        std_out = stringio.getvalue()
        sys.stdout = _stdout
        print(std_out)

        if test_patterns != ["*"]:
            test_case_names = set()
            start_pos = None
            for match in test_name_re.finditer(std_out):
                if start_pos is None:
                    start_pos = match.start()
                test_case_name = match.group("test_case_name")
                test_case_name = ".".join(test_case_name.split(".")[1:2])
                test_case_names.add(test_case_name)
            std_out = std_out[start_pos:]
            test_case_names = list(test_case_names)
            test_case_names.sort()
            name = "_".join(test_case_names)
            if args.num_threads != 1:
                options += f" -p{args.num_threads or cpu_count()}"
            if len(test_case_names) == 1:
                (root / f"{name}_stdout.txt").write_text(f"> python run.py{options}\n" + std_out)
            else:
                (root / f"{name}_stdout.txt").write_text(
                    f"> python run.py{options} {' '.join(test_pattern)}\n" + std_out
                )
            highlight_log(
                root / f"{name}_stdout.txt",
                root / ".." / "img" / f"{name}_stdout.html",
            )
        elif args.list:
            (root / "list}_stdout.txt").write_text("> python run.py --list\n" + std_out)
            highlight_log(
                root / "list}_stdout.txt",
                root / ".." / "img" / "list.html",
            )
