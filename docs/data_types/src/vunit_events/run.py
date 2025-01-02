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
        # Any preceding text (prefix) is also picked-up. It will be examined later to exclude some special cases.
        self._wait_re = re.compile(
            r"(?P<prefix>^[^\r\n]*?)(?P<wait>wait)(\s+on\s+(?P<sensitivity_list>.*?))?(\s+until\s+(?P<condition>.*?))?(\s+for\s+(?P<timeout>.*?))?;",
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
            prefix = wait_statement.group("prefix")
            if prefix:
                # Ignore commented wait statements and wait-looking statements in strings (not foolproof)
                if ("--" in prefix) or ('"' in prefix):
                    continue
                # Remove any preceding statements but keep labels
                prefix = prefix.split(";")[-1].lstrip()

            modified_wait_statement = "wait"

            # If the wait statement has an explicit sensitivity list (on ...), then vunit_error must be added to that
            sensitivity_list = wait_statement.group("sensitivity_list")
            sensitivity_list_signals = []
            if sensitivity_list is not None:
                sensitivity_list_signals = [signal.strip() for signal in sensitivity_list.split(",")]
                new_sensitivity_list = f"{', '.join(sensitivity_list_signals)}, vunit_error"
                modified_wait_statement += f" on {new_sensitivity_list}"

            # Add log_active to an existing condition clause (until ...) or create one if not present
            original_wait_statement = wait_statement.group(0)[wait_statement.start("wait") - wait_statement.start() :]
            log_message = f'decorate("while waiting on ""{original_wait_statement}""")'
            # The location preprocessor will not detect that the code in the message is quoted and it will modify
            # any function it targets. is_active_msg is such a function but by appending a non-printable character
            # to that function name we avoid this problem without altering the logged message
            log_message = log_message.replace("is_active_msg", 'is_active_msg" & NUL & "')
            condition = wait_statement.group("condition")
            if condition is None:
                # If there was a sensitivity list the VHDL event attribute of those signals must be in the
                # condition or the wait statement will remain blocked on those VHDL events (log_active always
                # returns false).
                new_condition = " or ".join([f"{signal}'event" for signal in sensitivity_list_signals])
                new_condition = new_condition + " or " if new_condition else new_condition
                new_condition += f"log_active(vunit_error, {log_message})"
            elif "vunit_error" in condition:
                continue  # Don't touch a wait statement already triggering on vunit_error
            else:
                # The condition_operator function turns the original condition to a boolean that can be ORed
                # with the boolean log_active function. Using the condition operator (??) doesn't work since it can't
                # be applied to a condition that was already a boolean
                new_condition = f"condition_operator({condition}) or log_active(vunit_error, {log_message})"

            modified_wait_statement += f" until {new_condition}"

            # The time clause (for ...) is not modified
            timeout = wait_statement.group("timeout")
            if timeout is not None:
                modified_wait_statement += f" for {timeout}"

            modified_wait_statement += ";"

            # Replace original wait statement
            code = code[: wait_statement.start("wait")] + modified_wait_statement + code[wait_statement.end() :]

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
                r"(?<=preprocess_this :)(?P<prefix>\s)(?P<wait>wait)(\s+on\s+(?P<sensitivity_list>.*?))?(\s+until\s+(?P<condition>.*?))?(\s+for\s+(?P<timeout>.*?))?;",
                re.MULTILINE | re.DOTALL | re.IGNORECASE,
            )

    vu.add_preprocessor(RestrictedWaitStatementPreprocessor(order=99))
else:  # For blog
    # start_snippet add_preprocessor
    vu = VUnit.from_argv()
    vu.enable_location_preprocessing()  # order = 100 if no other value is provided
    vu.add_preprocessor(WaitStatementPreprocessor(order=99))
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

    for snippet in [
        "core_dump",
    ]:
        highlight_code(
            root / "incrementer.vhd",
            root / ".." / ".." / "img" / "vunit_events" / f"{snippet}.html",
            snippet,
        )


def post_run(log_registry):
    def _post_run(results):
        log_registry.generate_logs()

    return _post_run


extract_snippets()

tb_event = lib.test_bench("tb_event")

for test_runner_variant, dut_checker_variant, inject_dut_bug, core_dump_on_vunit_error in [
    (1, 1, False, False),
    (2, 2, False, False),
    (2, 2, True, False),
    (2, 3, True, False),
    (2, 4, True, False),
    (2, 5, True, False),
    (2, 6, True, False),
    (3, 7, False, False),
    (4, 7, False, False),
    (4, 7, False, True),
]:
    if (test_runner_variant, dut_checker_variant, inject_dut_bug, core_dump_on_vunit_error) == (2, 2, False, False):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "is_active_msg.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug, core_dump_on_vunit_error) == (2, 2, True, False):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "timeout_due_to_bug.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug, core_dump_on_vunit_error) == (2, 3, True, False):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_after_log_active.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug, core_dump_on_vunit_error) == (2, 4, True, False):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_with_dut_checker_logger.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug, core_dump_on_vunit_error) == (2, 5, True, False):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_with_custom_message.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug, core_dump_on_vunit_error) == (2, 6, True, False):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_with_decorated_message.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug, core_dump_on_vunit_error) == (3, 7, False, False):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_for_check_latency.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug, core_dump_on_vunit_error) == (4, 7, False, False):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_for_check_latency_with_vunit_error.html"
    elif (test_runner_variant, dut_checker_variant, inject_dut_bug, core_dump_on_vunit_error) == (4, 7, False, True):
        html_path = root / ".." / ".." / "img" / "vunit_events" / "log_with_core_dump.html"
    else:
        html_path = None

    tb_event.add_config(
        f"{test_runner_variant}+{dut_checker_variant}{'+bug' if inject_dut_bug else ''}{'+core_dump' if core_dump_on_vunit_error else ''}",
        generics=dict(
            test_runner_variant=test_runner_variant,
            dut_checker_variant=dut_checker_variant,
            inject_dut_bug=inject_dut_bug,
            core_dump_on_vunit_error=core_dump_on_vunit_error,
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
