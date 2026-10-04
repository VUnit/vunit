# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the generation of llms-full.txt from the text build of the documentation
"""

import unittest
from pathlib import Path
from tests.common import with_tempdir
from tools.build_docs import write_llms_full_txt


class TestLlmsFullTxt(unittest.TestCase):
    """
    Test the generation of llms-full.txt
    """

    @with_tempdir
    def test_concatenates_documentation_pages_front_page_first(self, tempdir):
        text_path = Path(tempdir) / "text"
        pages = {
            "index": "VUnit\n*****\n\nIntro.\n",
            "cli": "Command Line Interface\n**********************\n\nOptions.\n",
            "data_types/queue": "*queue* package\n***************\n\n   package queue_pkg is\n",
            "blog/2023_03_31_vunit_events": "VUnit Events\n************\n",
            "genindex": "Index\n*****\n",
        }
        for docname, text in pages.items():
            path = text_path / f"{docname}.txt"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")

        write_llms_full_txt(text_path, Path(tempdir) / "llms-full.txt")

        self.assertEqual(
            (Path(tempdir) / "llms-full.txt").read_text(encoding="utf-8"),
            "# VUnit\n\nSource: https://vunit.github.io/index.html\n\nVUnit\n*****\n\nIntro.\n\n"
            "# Command Line Interface\n\nSource: https://vunit.github.io/cli.html\n\n"
            "Command Line Interface\n**********************\n\nOptions.\n\n"
            "# *queue* package\n\nSource: https://vunit.github.io/data_types/queue.html\n\n"
            "*queue* package\n***************\n\n   package queue_pkg is\n",
        )
