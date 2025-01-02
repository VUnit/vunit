# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
License header sanity check
"""

import unittest
from warnings import simplefilter, catch_warnings
from pathlib import Path
from os.path import commonprefix
from os import walk
import re
from vunit import ROOT as RSTR
from vunit.builtins import VHDL_PATH
from vunit import ostools
from vunit.about import license_text

ROOT = Path(RSTR)

RE_LICENSE_NOTICE = re.compile(
    r"(?P<comment_start>#|--|//) This Source Code Form is subject to the terms of the Mozilla Public" + "\n"
    r"(?P=comment_start) License, v\. 2\.0\. If a copy of the MPL was not distributed with this file," + "\n"
    r"(?P=comment_start) You can obtain one at http://mozilla\.org/MPL/2\.0/\." + "\n"
    r"(?P=comment_start)" + "\n"
    r"(?P=comment_start) Copyright \(c\) (?P<first_year>20\d\d)(-(?P<last_year>20\d\d))?, "
    + r"Lars Asplund lars\.anders\.asplund@gmail\.com"
)

RE_LOG_DATE = re.compile(r"Date:\s*(?P<year>20\d\d)-\d\d-\d\d")

FIRST_YEAR = 2014
LAST_YEAR = 2025


class TestLicense(unittest.TestCase):
    """
    Test that each file in the repository contains a valid license
    header with a correct year range.
    The correct year range is computed based on the commit history.
    """

    def test_that_a_valid_license_exists_in_source_files_and_that_global_licensing_information_is_correct(
        self,
    ):
        for file_name in find_licensed_files():
            code = ostools.read_file(file_name)
            self._check_license(code, file_name)
            if Path(file_name).suffix in (".vhd", ".vhdl", ".v", ".sv"):
                self._check_no_trailing_whitespace(code, file_name)

    def test_that_license_file_matches_vunit_license_text(self):
        with catch_warnings():
            simplefilter("ignore", category=DeprecationWarning)
            with (ROOT / "LICENSE.rst").open("r") as lic:
                self.assertEqual(lic.read(), license_text())

    def _check_license(self, code, file_name):
        """
        Check that the license header of file_name is valid
        """

        match = RE_LICENSE_NOTICE.search(code)
        self.assertIsNotNone(match, "Failed to find license notice in %s" % file_name)
        self.assertEqual(
            int(match.group("first_year")),
            FIRST_YEAR,
            "Expected copyright year range to start with %d in %s" % (FIRST_YEAR, file_name),
        )
        self.assertEqual(
            int(match.group("last_year")),
            LAST_YEAR,
            "Expected copyright year range to end with %d in %s" % (LAST_YEAR, file_name),
        )

    @staticmethod
    def _check_no_trailing_whitespace(code, file_name):
        """
        Check that there is no trailing whitespace within the code
        """
        for idx, line in enumerate(code.splitlines()):
            sline = line.rstrip()
            if sline == line:
                continue
            line_prefix = "%i: " % (idx + 1)
            print("Trailing whitespace violation in %s" % file_name)
            print(line_prefix + line)
            for _ in range(len(line_prefix) + len(sline)):
                print(" ", end="")
            for _ in range(len(line) - len(sline)):
                print("~", end="")
            print()
            raise AssertionError("Line %i of %s contains trailing whitespace" % (idx + 1, file_name))


def fix_license(file_name):
    """
    Fix license notice in file
    """

    with open(file_name, "r") as fptr:
        text = fptr.read()

    replacement = "Copyright (c) %i-%i, Lars Asplund lars.anders.asplund@gmail.com" % (
        FIRST_YEAR,
        LAST_YEAR,
    )

    text = re.sub(
        r"Copyright \(c\) (?P<first_year>20\d\d)(-(?P<last_year>20\d\d))?, "
        r"Lars Asplund lars\.anders\.asplund@gmail\.com",
        replacement,
        text,
    )

    with open(file_name, "w") as fptr:
        fptr.write(text)


def find_licensed_files():
    """
    Return all licensed files
    """
    licensed_files = []
    for root, _, files in walk(RSTR):
        for file_name in files:
            if "preprocessed" in root:
                continue
            if "codecs" in root:
                continue
            if root == str(ROOT / "docs"):
                continue
            if str(ROOT / "venv") in root:
                continue
            if str(ROOT / ".tox") in root:
                continue
            if is_prefix_of(
                (VHDL_PATH / "osvvm").resolve(),
                (Path(root) / file_name).resolve(),
            ):
                continue
            if file_name == "AlertLogPkg.vhd":
                continue
            if is_prefix_of(
                (VHDL_PATH / "JSON-for-VHDL").resolve(),
                (Path(root) / file_name).resolve(),
            ):
                continue
            if Path(file_name).suffix in (".vhd", ".vhdl", ".py", ".v", ".sv"):
                licensed_files.append(str(Path(root) / file_name))
    return licensed_files


def is_prefix_of(prefix: Path, of_path: Path):
    """
    Return True if 'prefix' is a prefix of 'of_path'
    """
    return commonprefix([str(prefix), str(of_path)]) == str(prefix)


def main():
    """
    Fix license notice in all licensed files
    """
    for file_name in find_licensed_files():
        fix_license(file_name)


if __name__ == "__main__":
    main()
