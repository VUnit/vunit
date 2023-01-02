#!/usr/bin/env python3

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

from csv import writer
from pathlib import Path
from random import choices
from vunit import VUnit

from tools.doc_support import highlight_code, highlight_log
import re

# start_snippet wait_statement_preprocessor
from vunit.ui.preprocessor import Preprocessor


class WaitStatementPreprocessor(Preprocessor):
    """A preprocessor is a class with a run method that transforms code. It is based on the Preprocessor class."""

    def __init__(self, order):
        """The order argument to the constructor controls the order in which preprocessors are applied.
        Lowest number first."""

        # Call constructor of base class
        super().__init__(order)

        # Regular expression finding wait statements on the form
        # wait [on sensitivity_list] [until condition] [for timeout];
        self._wait_re = re.compile(
            r"wait(\s+on\s+(?P<sensitivity_list>.*?))?(\s+until\s+(?P<condition>.*?))?(\s+for\s+(?P<timeout>.*?))?;",
            re.MULTILINE | re.DOTALL | re.IGNORECASE,
        )

    def run(self, code, file_name):
        """The run method must take the code string and the file_name as arguments."""

        # Only process testbenches
        if "runner_cfg" not in code:
            return code

        # Find all wait statements and sort them in reverse order of appearance to simplify processing
        wait_statements = list(self._wait_re.finditer(code))
        wait_statements.sort(key=lambda wait_statement: wait_statement.start(), reverse=True)

        for wait_statement in wait_statements:
            modified_wait_statement = "wait"

            # If the wait statement has an explicit sensitivity list (on ...), then vunit_error must be added to that
            sensitivity_list = wait_statement.group("sensitivity_list")
            if sensitivity_list is not None:
                new_sensitivity_list = f"{sensitivity_list}, vunit_error"
                modified_wait_statement += f" on {new_sensitivity_list}"

            # Add log_active to an existing condition clause (until ...) or create one if not present
            original_wait_statement = wait_statement.group(0)
            log_message = f'decorate("while waiting on ""{original_wait_statement}""")'
            condition = wait_statement.group("condition")
            if condition is None:
                new_condition = f"log_active(vunit_error, {log_message})"
            elif "vunit_error" in condition:
                continue  # Don't touch a wait statement already triggering on vunit_error
            else:
                new_condition = f"({condition}) or log_active(vunit_error, {log_message})"

            modified_wait_statement += f" until {new_condition}"

            # The time clause (for ...) is not modified
            timeout = wait_statement.group("timeout")
            if timeout is not None:
                modified_wait_statement += f" for {timeout}"

            modified_wait_statement += ";"

            # Replace original wait statement
            code = code[: wait_statement.start()] + modified_wait_statement + code[wait_statement.end() :]

        return code


# end_snippet wait_statement_preprocessor


class LogRegistry:
    def __init__(self):
        self._paths = dict()

    def register(self, log_path, html_path):
        self._paths[log_path] = html_path

    def generate_logs(self):
        for log_path, html_path in self._paths.items():
            print(f"Generating {html_path} from {log_path}")
            highlight_log(Path(log_path), Path(html_path))


vu = VUnit.from_argv()
vu.add_osvvm()
vu.add_verification_components()
vu.enable_location_preprocessing()

if True:
    # The preprocessor used differs from the one documented in the blog since we do not want the preprocessor to
    # run for all examples (test cases).
    class RestrictedWaitStatementPreprocessor(WaitStatementPreprocessor):
        def __init__(self, order):
            super().__init__(order)
            self._wait_re = re.compile(
                r"(?<=preprocess_this : )wait(\s+on\s+(?P<sensitivity_list>.*?))?(\s+until\s+(?P<condition>.*?))?(\s+for\s+(?P<timeout>.*?))?;",
                re.MULTILINE | re.DOTALL | re.IGNORECASE,
            )

    vu.add_preprocessor(RestrictedWaitStatementPreprocessor(order=1001))
else:  # For blog
    # start_snippet add_preprocessor
    vu = VUnit.from_argv()
    vu.enable_location_preprocessing()  # order = 1000 if no other value is provided
    vu.add_preprocessor(WaitStatementPreprocessor(order=1001))
    # end_snippet add_preprocessor

root = Path(__file__).parent

lib = vu.add_library("lib")
lib.add_source_files(root / "*.vhd")

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
        "wait_on_signal_event",
        "wait_on_signal_transaction",
        "notify_with_boolean_event",
        "listening_to_vhdl_events",
        "listening_to_vhdl_transactions",
        "notify_with_toggling_event",
    ]:
        highlight_code(
            root / "tb_traditional.vhd",
            root / ".." / ".." / "img" / "vunit_events" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "test_runner_process",
        "dut_checker",
        "done_event",
        "wait_done_event",
        "log_active",
        "custom_logger",
        "custom_message",
        "decorated_message",
        "vunit_error",
        "check_latency",
        "notify_if_fail",
    ]:
        highlight_code(
            root / "tb_event.vhd",
            root / ".." / ".." / "img" / "vunit_events" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "event_creation",
        "dut_checker_logger",
    ]:
        highlight_code(
            root / "event_pkg.vhd",
            root / ".." / ".." / "img" / "vunit_events" / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "wait_statement_preprocessor",
        "add_preprocessor",
    ]:
        highlight_code(
            Path(__file__), root / ".." / ".." / "img" / "vunit_events" / f"{snippet}.html", snippet, language="Python"
        )

    for snippet in [
        "n_samples_field",
    ]:
        highlight_code(
            root / "incrementer_pkg.vhd",
            root / ".." / ".." / "img" / "vunit_events" / f"{snippet}.html",
            snippet,
        )


def post_run(log_registry):
    def _post_run(results):
        log_registry.generate_logs()

    return _post_run


extract_snippets()

tb_event = lib.test_bench("tb_event")

for test_runner_variant, dut_checker_variant, inject_dut_bug in [
    (1, 1, False),
    (2, 2, False),
    (2, 2, True),
    (2, 3, True),
    (2, 4, True),
    (2, 5, True),
    (2, 6, True),
    (3, 7, False),
    (4, 7, False),
]:
    if (test_runner_variant, dut_checker_variant, inject_dut_bug) == (2, 2, False):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "is_active_msg.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug) == (2, 2, True):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "timeout_due_to_bug.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug) == (2, 3, True):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_after_log_active.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug) == (2, 4, True):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_with_dut_checker_logger.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug) == (2, 5, True):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_with_custom_message.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug) == (2, 6, True):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_with_decorated_message.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug) == (3, 7, False):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_for_check_latency.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug) == (4, 7, False):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_for_check_latency_with_vunit_error.html"
    else:
        html_path = None

    tb_event.add_config(
        f"{test_runner_variant}+{dut_checker_variant}{'+bug' if inject_dut_bug else ''}",
        generics=dict(
            test_runner_variant=test_runner_variant,
            dut_checker_variant=dut_checker_variant,
            inject_dut_bug=inject_dut_bug,
        ),
        pre_config=prepare_test(html_path, log_registry),
    )

tb_traditional = lib.test_bench("tb_traditional")
tb_traditional.test("Test with non-toggling event signal and an event listener").set_pre_config(
    prepare_test(root / ".." / ".." / "img" / "vunit_events" / "non_toggling_event_log.html", log_registry)
)
tb_traditional.test("Test with toggling event signal").set_pre_config(
    prepare_test(root / ".." / ".." / "img" / "vunit_events" / "toggling_event_log.html", log_registry)
)

vu.set_compile_option("rivierapro.vcom_flags", ["-dbg"])
vu.main(post_run(log_registry))
