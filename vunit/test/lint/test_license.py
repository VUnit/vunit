# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
License header sanity check
"""
from __future__ import print_function

import unittest
from os.path import join, splitext, abspath, commonprefix
from os import walk
import re
from datetime import datetime
from subprocess import Popen, PIPE, STDOUT
from vunit import ROOT
from vunit.builtins import VHDL_PATH
import vunit.ostools as ostools


class TestLicense(unittest.TestCase):
    """
    Test that each file in the repository contains a valid license
    header with a correct year range.
    The correct year range is computed based on the commit history.
    """

    def test_that_a_valid_license_exists_in_source_files_and_that_global_licensing_information_is_correct(self):
        licensed_files = []
        for root, _, files in walk(ROOT):
            for file_name in files:
                if 'preprocessed' in root:
                    continue
                if 'codecs' in root:
                    continue
                if root == join(ROOT, "docs"):
                    continue
                if join(ROOT, ".tox") in root:
                    continue
                osvvm_directory = abspath(join(VHDL_PATH, 'osvvm'))
                if is_prefix_of(osvvm_directory, abspath(join(root, file_name))):
                    continue
                osvvm_integration_example_directory = abspath(
                    join(ROOT, 'examples', 'vhdl', 'osvvm_integration', 'src'))
                if is_prefix_of(osvvm_integration_example_directory, abspath(join(root, file_name))):
                    continue
                if splitext(file_name)[1] in ('.vhd', '.vhdl', '.py', '.v', '.sv'):
                    licensed_files.append(join(root, file_name))

        for file_name in licensed_files:
            code = ostools.read_file(file_name)

            self._check_license(code, file_name)

            if splitext(file_name)[1] in ('.vhd', '.vhdl', '.v', '.sv'):
                self._check_no_trailing_whitespace(code, file_name)

    _re_license_notice = re.compile(
        r"(?P<comment_start>#|--|//) This Source Code Form is subject to the terms of the Mozilla Public" + "\n"
        r"(?P=comment_start) License, v\. 2\.0\. If a copy of the MPL was not distributed with this file," + "\n"
        r"(?P=comment_start) You can obtain one at http://mozilla\.org/MPL/2\.0/\." + "\n"
        r"(?P=comment_start)" + "\n"
        r"(?P=comment_start) Copyright \(c\) (?P<first_year>20\d\d)(-(?P<last_year>20\d\d))?, " +
        r"Lars Asplund lars\.anders\.asplund@gmail\.com")
    _re_log_date = re.compile(r'Date:\s*(?P<year>20\d\d)-\d\d-\d\d')

    def _check_license(self, code, file_name):
        """
        Check that the license header of file_name is valid
        """
        proc = Popen(['git', 'log', '--follow', '--date=short', file_name],
                     bufsize=0, stdout=PIPE, stdin=PIPE, stderr=STDOUT, universal_newlines=True)
        out, _ = proc.communicate()
        first_year = None
        last_year = None
        for date in self._re_log_date.finditer(out):
            first_year = int(date.group('year')) if first_year is None else min(int(date.group('year')), first_year)
            last_year = int(date.group('year')) if last_year is None else max(int(date.group('year')), last_year)

        if first_year is None and last_year is None:
            # File not in log yet, set to current year
            first_year = datetime.now().year
            last_year = first_year

        match = self._re_license_notice.search(code)
        self.assertIsNotNone(match, "Failed to find license notice in %s" % file_name)
        if first_year == last_year:
            self.assertEqual(int(match.group('first_year')), first_year,
                             'Expected copyright year to be %d in %s' % (first_year, file_name))
            self.assertIsNone(match.group('last_year'), 'Expected no copyright years range in %s' % file_name)
        else:
            self.assertIsNotNone(match.group('last_year'),
                                 'Expected copyright year range %d-%d in %s' % (first_year, last_year, file_name))
            self.assertEqual(int(match.group('first_year')), first_year,
                             'Expected copyright year range to start with %d in %s' % (first_year, file_name))
            self.assertEqual(int(match.group('last_year')), last_year,
                             'Expected copyright year range to end with %d in %s' % (last_year, file_name))

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
            raise AssertionError("Line %i of %s contains trailing whitespace", idx + 1, file_name)


def is_prefix_of(prefix, of_path):
    """
    Return True if 'prefix' is a prefix of 'of_path'
    """
    return commonprefix([prefix, of_path]) == prefix
