#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from csv import writer
from pathlib import Path
from random import choices
from vunit import VUnit
from tools.doc_support import highlight_code, highlight_log, LogRegistry

vu = VUnit.from_argv()
vu.add_verification_components()
vu.add_osvvm()

root = Path(__file__).parent

lib = vu.add_library("lib")
lib.add_source_files(root / "*.vhd")
lib.add_source_files(root / ".." / ".." / ".." / "data_types" / "src" / "vunit_events" / "incrementer.vhd")
lib.add_source_files(root / ".." / ".." / ".." / "data_types" / "src" / "vunit_events" / "incrementer_pkg.vhd")
lib.add_source_files(root / ".." / ".." / ".." / "data_types" / "src" / "vunit_events" / "event_pkg.vhd")

log_registry = LogRegistry()


def prepare_test(html_path, log_registry):
    def pre_config(output_path):
        if html_path:
            log_registry.register(Path(output_path) / "log.txt", html_path)

        for data_file_idx in range(3):
            with open(Path(output_path) / f"data{data_file_idx}.csv", "w") as data_file:
                csv_writer = writer(data_file)
                csv_writer.writerow(choices([i for i in range(256)], k=10))

        return True

    return pre_config


def extract_snippets():
    for snippet in [
        "test_runner",
    ]:
        highlight_code(
            root / "tb_phases.vhd",
            root / ".." / ".." / "img" / "vunit_phases" / f"{snippet}.html",
            snippet,
            highlights=["test_runner_setup", "test_suite", "run", "test_runner_cleanup"],
        )

    for snippet in [
        "test_runner_minimal",
    ]:
        highlight_code(
            root / "tb_phases_minimal.vhd",
            root / ".." / ".." / "img" / "vunit_phases" / f"{snippet}.html",
            snippet,
            highlights=["test_runner_setup", "test_suite", "run", "test_runner_cleanup"],
        )

    for snippet in [
        "dut_checker_with_event",
        "test_runner_with_event",
        "dut_checker_with_lock",
        "dut_checker_with_initial_unlock",
        "dut_checker_with_combined_if",
        "end_of_simulation_process",
    ]:
        highlight_code(
            root / "tb_phase_lock.vhd",
            root / ".." / ".." / "img" / "vunit_phases" / f"{snippet}.html",
            snippet,
            highlights=["get_entry_key", "lock", "unlock"],
        )


extract_snippets()

tb_phases = lib.test_bench("tb_phases")
tb_phases.set_pre_config(prepare_test(root / ".." / ".." / "img" / "vunit_phases" / "phases.html", log_registry))

tb_phases_minimal = lib.test_bench("tb_phases_minimal")
tb_phases_minimal.set_pre_config(
    prepare_test(root / ".." / ".." / "img" / "vunit_phases" / "phases_minimal.html", log_registry)
)

tb_phase_lock = lib.test_bench("tb_phase_lock")
for test_runner_variant, dut_checker_variant, enable_end_of_simulation_process in [
    (1, 1, False),
    (2, 2, False),
    (2, 3, False),
    (2, 4, False),
    (2, 3, True),
]:
    html_path = None
    if (test_runner_variant, dut_checker_variant, enable_end_of_simulation_process) == (2, 2, False):
        html_path = root / ".." / ".." / "img" / "vunit_phases" / "dut_checker_with_lock_log.html"
    elif (test_runner_variant, dut_checker_variant, enable_end_of_simulation_process) == (2, 3, False):
        html_path = root / ".." / ".." / "img" / "vunit_phases" / "dut_checker_with_initial_unlock_log.html"
    elif (test_runner_variant, dut_checker_variant, enable_end_of_simulation_process) == (2, 4, False):
        html_path = root / ".." / ".." / "img" / "vunit_phases" / "dut_checker_with_combined_if_log.html"
    elif (test_runner_variant, dut_checker_variant, enable_end_of_simulation_process) == (2, 3, True):
        html_path = root / ".." / ".." / "img" / "vunit_phases" / "end_of_simulation_process_log.html"

    tb_phase_lock.add_config(
        f"{test_runner_variant}+{dut_checker_variant}{'+eos' if enable_end_of_simulation_process else ''}",
        generics=dict(
            test_runner_variant=test_runner_variant,
            dut_checker_variant=dut_checker_variant,
            enable_end_of_simulation_process=enable_end_of_simulation_process,
        ),
        pre_config=prepare_test(html_path, log_registry),
    )


def post_run(log_registry):
    def _post_run(results):
        log_registry.generate_logs()

    return _post_run


vu.set_compile_option("rivierapro.vcom_flags", ["-dbg"])
vu.main(post_run(log_registry))
