# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""Terminal-facing functions for creating VHDL testbenches."""

from functools import partial

from .cli_helpers import _ask, _ask_path, _choose_action, _print_error, _print_preview, _print_result
from .generation import testbench as generator
from .generation.testbench import DEFAULT_TEST, validate_library, validate_source, validate_testbench, validate_tests


def _config(source_path, testbench_path, library, tests=None):
    config = {"source": source_path, "testbench": testbench_path, "library": library}
    if tests:
        config["tests"] = list(tests)
    return config


def preview(source_path, testbench_path, library="work", tests=None):
    """Render the configured testbench without writing it."""
    try:
        return generator.preview(_config(source_path, testbench_path, library, tests))["files"][0]["content"]
    except (OSError, ValueError, AttributeError, IndexError) as exc:
        print(f"Error creating testbench: {exc}")
        return None


def validate(source_path, testbench_path, library="work", tests=None):
    """Validate a complete testbench configuration before creation."""
    return preview(source_path, testbench_path, library, tests) is not None


def run(source_path, testbench_path, library="work", preview=None, tests=None):
    """Create a testbench and report the result to the terminal.

    With ``preview`` (a ``PreviewOptions``), display the generation plan instead of writing files.
    """
    config = _config(source_path, testbench_path, library, tests)
    try:
        result = generator.preview(config) if preview else generator.generate(config)
    except (OSError, ValueError, AttributeError, IndexError) as exc:
        _print_error("Error creating testbench", exc, preview)
        return 1
    _print_result(result, preview)
    return 0


def ask_tests():
    """Collect test names, ending on a blank answer.

    Answering the first prompt with the default ``first_test`` (for example by pressing Enter) returns no tests, so
    that the generator's default placeholder is used and nothing more is asked.
    """
    tests = []
    while True:
        prompt = "Add test name (blank to finish)" if tests else "Add test name"
        name = _ask(prompt, None if tests else DEFAULT_TEST)
        if not name or (not tests and name == DEFAULT_TEST):
            return tests
        try:
            validate_tests(tests + [name])
        except ValueError as exc:
            print(f"Error: {exc}")
            continue
        tests.append(name)


def _show_preview(config, tests):
    """Print the generated testbench unless the configuration is invalid."""
    generated = preview(config["source"], config["testbench"], config["library"], tests)
    if generated is not None:
        _print_preview(generated)


def _remove_test(tests):
    """Remove a test chosen by exact name or by its 1-based position in the list."""
    if not tests:
        print("There are no tests to remove.")
        return
    answer = _ask("Test to remove (name or number)")
    if answer in tests:
        tests.remove(answer)
    elif answer.isdigit() and 1 <= int(answer) <= len(tests):
        del tests[int(answer) - 1]
    else:
        print(f"Error: no such test: {answer}")


def _add_test(tests):
    """Add a test name, keeping the list valid."""
    candidate = _ask("Test name")
    try:
        validate_tests(tests + [candidate])
    except ValueError as exc:
        print(f"Error: {exc}")
        return
    tests.append(candidate)


def review(source, testbench, library, plan_options=None, tests=None):
    """Review and edit the configuration before creating the file, or before previewing it with ``plan_options``."""
    config = {"source": source, "library": library, "testbench": testbench}
    tests = list(tests or [])
    ask_path = partial(_ask_path, show_controls=True)
    editors = {
        "Edit source file": ("source", "DUT file", ask_path, validate_source),
        "Edit source library": ("library", "DUT library", _ask, validate_library),
        "Edit testbench path": ("testbench", "Testbench file", ask_path, validate_testbench),
    }
    while True:
        print(
            f"\nDUT file: {config['source']}\n"
            f"DUT library: {config['library']}\nTestbench file: {config['testbench']}\n"
            f"Tests: {', '.join(tests) if tests else DEFAULT_TEST + ' (default)'}"
        )
        action = _choose_action(
            list(editors)
            + ["Add test", "Remove test"]
            + (["Preview", "Cancel"] if plan_options else ["Preview", "Create", "Cancel"])
        )
        if action == "Cancel":
            print("Cancelled; no files written.")
            return 0
        if action == "Preview" and plan_options:
            if validate(config["source"], config["testbench"], config["library"], tests):
                return run(config["source"], config["testbench"], config["library"], plan_options, tests)
            continue
        if action == "Preview":
            _show_preview(config, tests)
            continue
        if action == "Create":
            if validate(config["source"], config["testbench"], config["library"], tests):
                return run(config["source"], config["testbench"], config["library"], tests=tests)
            continue
        if action == "Add test":
            _add_test(tests)
            continue
        if action == "Remove test":
            _remove_test(tests)
            continue
        field, prompt, ask, check = editors[action]
        candidate = ask(prompt, config[field])
        try:
            check(candidate)
        except (OSError, ValueError, AttributeError, IndexError) as exc:
            print(f"Error: {exc}")
            continue
        config[field] = candidate
