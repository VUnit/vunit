# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""Tests for release note generation."""

import importlib.util
import unittest
from pathlib import Path

from tests.common import with_tempdir

_MODULE_PATH = Path(__file__).parents[2] / "docs" / "create_release_notes.py"
_SPEC = importlib.util.spec_from_file_location("create_release_notes", _MODULE_PATH)
_CREATE_RELEASE_NOTES = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_CREATE_RELEASE_NOTES)


class TestReleaseNoteFiles(unittest.TestCase):
    """Test release note file ordering."""

    @with_tempdir
    def test_orders_files_by_descending_semantic_version(self, tempdir):
        release_notes = Path(tempdir) / "release_notes"
        release_notes.mkdir()
        for version in (
            "4.9.0",
            "4.10.0",
            "4.10.1",
            "5.0.0.dev4",
            "5.0.0.dev15",
            "5.0.0",
        ):
            (release_notes / f"{version}.rst").touch()

        files = _CREATE_RELEASE_NOTES._release_note_files(Path(tempdir))

        self.assertEqual(
            [file.stem for file in files],
            ["5.0.0", "5.0.0.dev15", "5.0.0.dev4", "4.10.1", "4.10.0", "4.9.0"],
        )
