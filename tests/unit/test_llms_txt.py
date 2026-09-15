# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the generation of llms.txt and llms-full.txt from the text build of the documentation
"""

import unittest
from pathlib import Path
from tests.common import with_tempdir
from tools.llms_txt import read_pages, render_llms_full_txt, render_llms_txt, section_of, write_llms_files

PAGES = {
    "index": """\
VUnit: a test framework for HDL
*******************************

[image: shieldPyPI][image]

VUnit is an open source
unit testing framework.

[image]
""",
    "installing": "Installing\n**********\n\nUse pip.\n",
    "run/user_guide": "Run Library User Guide\n**********************\n\nTest cases.\n",
    "data_types/queue": "*queue* package\n***************\n\n   package queue_pkg is\n",
    "blog/2023_03_31_vunit_events": "VUnit Events\n************\n\nNews.\n",
    "genindex": "Index\n*****\n",
    "new_topic/page": "New Topic\n*********\n\nNew.\n",
}


def create_text_build(output_path, pages=None):
    """
    Create a text build with the given pages under output_path
    """
    for docname, text in (PAGES if pages is None else pages).items():
        path = Path(output_path) / "_text" / f"{docname}.txt"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")


class TestLlmsTxt(unittest.TestCase):
    """
    Test the generation of llms.txt and llms-full.txt
    """

    def test_section_of(self):
        self.assertEqual(section_of("index"), "Getting started")
        self.assertEqual(section_of("run/user_guide"), "User guides")
        self.assertEqual(section_of("data_types/user_guide"), "User guides")
        self.assertEqual(section_of("data_types/queue"), "API reference")
        self.assertEqual(section_of("blog/2023_03_31_vunit_events"), "Optional")
        self.assertEqual(section_of("new_topic/page"), "Other")
        self.assertIsNone(section_of("genindex"))

    @with_tempdir
    def test_llms_txt(self, tempdir):
        create_text_build(tempdir)
        self.assertEqual(
            render_llms_txt(read_pages(Path(tempdir) / "_text")),
            """\
# VUnit

> VUnit is an open source unit testing framework.

## Getting started

- [VUnit: a test framework for HDL](https://vunit.github.io/_text/index.txt): https://vunit.github.io/index.html
- [Installing](https://vunit.github.io/_text/installing.txt): https://vunit.github.io/installing.html

## User guides

- [Run Library User Guide](https://vunit.github.io/_text/run/user_guide.txt): https://vunit.github.io/run/user_guide.html

## API reference

- [VHDL API (JSON)](https://vunit.github.io/api/vunit_lib.json)
- [Python API (JSON)](https://vunit.github.io/api/python.json)
- [*queue* package](https://vunit.github.io/_text/data_types/queue.txt): https://vunit.github.io/data_types/queue.html

## Other

- [New Topic](https://vunit.github.io/_text/new_topic/page.txt): https://vunit.github.io/new_topic/page.html

## Optional

- [VUnit Events](https://vunit.github.io/_text/blog/2023_03_31_vunit_events.txt): https://vunit.github.io/blog/2023_03_31_vunit_events.html
""",
        )

    @with_tempdir
    def test_llms_txt_without_api(self, tempdir):
        create_text_build(tempdir)
        llms_txt = render_llms_txt(read_pages(Path(tempdir) / "_text"), api=False)
        self.assertNotIn("api/", llms_txt)
        self.assertIn("## API reference\n\n- [*queue* package]", llms_txt)

    @with_tempdir
    def test_llms_full_txt(self, tempdir):
        create_text_build(tempdir)
        llms_full_txt = render_llms_full_txt(read_pages(Path(tempdir) / "_text"))
        self.assertIn(
            "# Installing\n\nSource: https://vunit.github.io/installing.html\n\nInstalling\n**********\n\nUse pip.\n",
            llms_full_txt,
        )
        self.assertIn("# New Topic\n", llms_full_txt)
        self.assertNotIn("VUnit Events", llms_full_txt)
        self.assertNotIn("Index", llms_full_txt)
        self.assertLess(llms_full_txt.index("# Installing"), llms_full_txt.index("# *queue* package"))

    @with_tempdir
    def test_write_llms_files(self, tempdir):
        create_text_build(tempdir)
        write_llms_files(tempdir)
        self.assertTrue((Path(tempdir) / "llms.txt").read_text(encoding="utf-8").startswith("# VUnit\n"))
        self.assertIn("# Installing", (Path(tempdir) / "llms-full.txt").read_text(encoding="utf-8"))

    @with_tempdir
    def test_missing_front_page_is_an_error(self, tempdir):
        create_text_build(tempdir, {"installing": PAGES["installing"]})
        with self.assertRaisesRegex(RuntimeError, "no front page"):
            render_llms_txt(read_pages(Path(tempdir) / "_text"))
