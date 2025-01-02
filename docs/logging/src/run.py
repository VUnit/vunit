# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
"""
WARNING:

This script and the VHDL code it simulates are developed to
generate HTML code snippets and log transcripts for the user
documentation. By generating documentation from source we
make sure that what is documented is syntactically and semantically
correct. While the resulting HTML is for educational
purposes, the source used to generate it is NOT. It contains
a lot of special construct related to the HTML generation and doesn't
represent real-world use of the documented features.
"""
print(__doc__)

from pathlib import Path
from shutil import copy
from vunit import VUnit
from tools.doc_support import highlight_code, highlight_log

root = Path(__file__).parent


def extract_snippets():
    for snippet in [
        "log_call",
        "log_call_with_logger",
        "logger_declaration",
        "logger_from_id",
        "standard_log_levels",
        "conditional_log",
        "custom_log_level",
        "log_call_with_custom_level",
        "set_format",
        "stopping_simulation",
        "print",
        "print_to_open_file",
        "log_visibility",
        "mocking",
        "mock_queue_length",
        "disabled_log",
        "convenience_procedure",
        "another_convenience_procedure",
    ]:
        highlight_code(
            root / "tb_logging.vhd",
            root / ".." / f"{snippet}.html",
            snippet,
        )

    for snippet in ["set_debug_option", "location_preprocessing", "additional_subprograms", "use_external_log"]:
        highlight_code(root / "run.py", root / ".." / f"{snippet}.html", snippet, language="python")


extract_snippets()


class LogRegistry:
    def __init__(self):
        self._paths = dict()

    def register(self, log_path, html_path):
        self._paths[log_path] = html_path

    def generate_logs(self):
        for log_path, html_path in self._paths.items():
            print(f"Generating {html_path} from {log_path}")
            highlight_log(Path(log_path), Path(html_path))


log_registry = LogRegistry()


def make_post_check(html_path, log_registry, log_name):
    def post_check(output_path):
        log_registry.register(Path(output_path) / log_name, html_path)

        return True

    return post_check


vu = VUnit.from_argv()
vu.add_vhdl_builtins()
lib = vu.add_library("lib")
lib.add_source_files(root / "tb_logging.vhd")

tb = lib.test_bench("tb_logging")

test = tb.test("Document set_format")
test.set_post_check(make_post_check(root / ".." / "set_format_log.html", log_registry, "level_log.txt"))

test = tb.test("Document verbose format")
test.set_post_check(make_post_check(root / ".." / "verbose_format_log.html", log_registry, "verbose_log.txt"))

test = tb.test("Document log_time_unit")
test.set_post_check(make_post_check(root / ".." / "log_time_unit_log.html", log_registry, "verbose_log.txt"))

test = tb.test("Document full_time_resolution")
test.set_post_check(make_post_check(root / ".." / "full_time_resolution_log.html", log_registry, "verbose_log.txt"))

test = tb.test("Document fix decimals")
test.set_post_check(make_post_check(root / ".." / "fix_decimals_log.html", log_registry, "verbose_log.txt"))

test = tb.test("Document log location")
test.set_post_check(make_post_check(root / ".." / "log_location_log.html", log_registry, "verbose_log.txt"))


def post_run(log_registry):
    def _post_run(results):
        log_registry.generate_logs()

    return _post_run


# This is just used for documentation

# start_snippet location_preprocessing
ui = VUnit.from_argv()
ui.add_vhdl_builtins()
ui.enable_location_preprocessing()
# end_snippet location_preprocessing

# start_snippet additional_subprograms
ui = VUnit.from_argv()
ui.add_vhdl_builtins()
ui.enable_location_preprocessing(additional_subprograms=["my_convenience_procedure"])
# end_snippet additional_subprograms

# start_snippet use_external_log
ui.add_vhdl_builtins(use_external_log="path/to/other/common_log_pkg/body")
# end_snippet use_external_log

# start_snippet set_debug_option
testbenches = lib.get_source_files("*tb*")
testbenches.set_compile_option("rivierapro.vcom_flags", ["-dbg"])
# end_snippet set_debug_option


vu.main(post_run(log_registry))
