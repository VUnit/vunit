#!/usr/bin/env python3

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
        "tb_dut",
    ]:
        highlight_code(
            root / "tb_dut.vhd",
            root / ".." / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "local_declarations",
    ]:
        highlight_code(
            root / "tb_dut_local_declarations.vhd",
            root / ".." / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "id_from_attribute",
        "id_from_string",
        "id_from_string_wo_colon",
        "id_naming",
        "second_id_from_string",
        "id_from_parent",
        "get_tree",
    ]:
        highlight_code(
            root / "tb_id.vhd",
            root / ".." / f"{snippet}.html",
            snippet,
        )

    for snippet in [
        "null_id",
    ]:
        highlight_code(
            root / "verification_component_x_with_logger.vhd",
            root / ".." / f"{snippet}.html",
            snippet,
        )


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


def make_post_check(html_path, log_registry, log_no=None, log_name="raw_log.txt"):
    def post_check(output_path):
        if log_no:
            copy(str(root / f"log.txt"), str(root / f"log{log_no}.txt"))
            log_registry.register(root / f"log{log_no}.txt", html_path)
            (root / "log.txt").unlink()
        else:
            log_registry.register(Path(output_path) / log_name, html_path)

        return True

    return post_check


vu = VUnit.from_argv()
lib = vu.add_library("lib")
lib.add_source_files(root / "dut.vhd")
lib.add_source_files(root / "tb_dut.vhd")
lib.add_source_files(root / "tb_dut_local_declarations.vhd")
lib.add_source_files(root / "verification_component_x.vhd")
lib.add_source_files(root / "verification_component_y.vhd")

lib2 = vu.add_library("lib2")
lib2.add_source_files(root / "tb_id.vhd")
lib2.add_source_files(root / "verification_component_x_with_logger.vhd")

tb_dut = lib.test_bench("tb_dut")
tb_dut.set_post_check(make_post_check(root / ".." / "tb_dut_log.html", log_registry, 1))
tb_dut2 = lib.test_bench("tb_dut2")
tb_dut2.set_post_check(make_post_check(root / ".." / "tb_dut_local_declarations_log.html", log_registry, 2))

lib2_tb_dut = lib2.test_bench("tb_dut")
lib2_tb_dut.test("Document naming").set_post_check(make_post_check(root / ".." / "id_naming_log.html", log_registry))
lib2_tb_dut.test("Document get_tree").set_post_check(make_post_check(root / ".." / "get_tree_log.html", log_registry))
lib2_tb_dut.test("Document full tree").set_post_check(make_post_check(root / ".." / "full_tree_log.html", log_registry))
lib2_tb_dut.test("Document has_id").set_post_check(make_post_check(root / ".." / "has_id_log.html", log_registry))
lib2_tb_dut.test("Document traversing").set_post_check(
    make_post_check(root / ".." / "traversing_log.html", log_registry)
)
lib2_tb_dut.test("Document null IDs").set_post_check(
    make_post_check(root / ".." / "null_id_log.html", log_registry, log_name="verbose_log.txt")
)
lib2_tb_dut.test("Document null IDs").set_generic("use_null_id", True)


def post_run(log_registry):
    def _post_run(results):
        log_registry.generate_logs()

    return _post_run


vu.main(post_run(log_registry))
