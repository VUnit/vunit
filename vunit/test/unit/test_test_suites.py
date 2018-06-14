# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the test suites
"""

from os.path import join
from unittest import TestCase
from vunit.test_suites import (TestRun)
from vunit.test_report import (PASSED, SKIPPED, FAILED)
from vunit.test.common import create_tempdir


class TestTestSuites(TestCase):
    """
    Test the test suites
    """

    def test_missing_results_fails_all(self):
        self.assertEqual(
            self._read_test_results(contents=None,
                                    expected_test_cases=["test1", "test2"]),
            {"test1": FAILED, "test2": FAILED})

    def test_read_results_all_passed(self):
        self.assertEqual(
            self._read_test_results(contents="""\
test_start:test1
test_start:test2
test_suite_done
""",
                                    expected_test_cases=["test1", "test2"]),
            {"test1": PASSED, "test2": PASSED})

    def test_read_results_suite_not_done(self):
        self.assertEqual(
            self._read_test_results(contents="""\
test_start:test1
test_start:test2
""",
                                    expected_test_cases=["test1", "test2"]),
            {"test1": PASSED, "test2": FAILED})

        self.assertEqual(
            self._read_test_results(contents="""\
test_start:test2
test_start:test1
""",
                                    expected_test_cases=["test1", "test2"]),
            {"test1": FAILED, "test2": PASSED})

    def test_read_results_skipped_test(self):
        self.assertEqual(
            self._read_test_results(contents="""\
test_start:test1
test_suite_done
""",
                                    expected_test_cases=["test1", "test2", "test3"]),
            {"test1": PASSED, "test2": SKIPPED, "test3": SKIPPED})

    def test_read_results_anonynmous_test_pass(self):
        self.assertEqual(
            self._read_test_results(contents="""\
test_suite_done
""",
                                    expected_test_cases=[None]),
            {None: PASSED})

    def test_read_results_anonynmous_test_fail(self):
        self.assertEqual(
            self._read_test_results(contents="""\
""",
                                    expected_test_cases=[None]),
            {None: FAILED})

    def test_read_results_unknown_test(self):
        try:
            self._read_test_results(
                contents="""\
test_start:test1
test_start:test3
test_suite_done""",
                expected_test_cases=["test1"])
        except RuntimeError as exc:
            self.assertIn("unknown test case test3", str(exc))
        else:
            assert False, "RuntimeError not raised"

    @staticmethod
    def _read_test_results(contents, expected_test_cases):
        """
        Helper method to test the read_test_results function
        """
        with create_tempdir() as path:
            file_name = join(path, "vunit_results")
            if contents is not None:
                with open(file_name, "w") as fptr:
                    fptr.write(contents)

            run = TestRun(simulator_if=None,
                          config=None,
                          elaborate_only=False,
                          test_suite_name=None,
                          test_cases=expected_test_cases)
            return run._read_test_results(file_name=file_name)  # pylint: disable=protected-access
