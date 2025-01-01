# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the test suites
"""

from pathlib import Path
from unittest import TestCase
from tests.common import create_tempdir
from vunit.test.suites import TestRun
from vunit.test.report import PASSED, SKIPPED, FAILED
from vunit.sim_if import SimulatorInterface


class TestTestSuites(TestCase):
    """
    Test the test suites
    """

    def test_missing_results_fails_all(self):
        self._read_test_results({"test1": FAILED, "test2": FAILED}, None)

    def test_read_results_all_passed(self):
        self._read_test_results(
            {"test1": PASSED, "test2": PASSED},
            """\
test_start:test1
test_start:test2
test_suite_done
""",
        )

    def test_read_results_suite_not_done(self):
        self._read_test_results(
            {"test1": PASSED, "test2": FAILED},
            """\
test_start:test1
test_start:test2
""",
        )

        self._read_test_results(
            {"test1": FAILED, "test2": PASSED},
            """\
test_start:test2
test_start:test1
""",
        )

    def test_read_results_skipped_test(self):
        self._read_test_results(
            {"test1": PASSED, "test2": SKIPPED, "test3": SKIPPED},
            """\
test_start:test1
test_suite_done
""",
        )

    def test_read_results_anonynmous_test_pass(self):
        self._read_test_results(
            {None: PASSED},
            """\
test_suite_done
""",
        )

    def test_read_results_anonynmous_test_fail(self):
        self._read_test_results(
            {None: FAILED},
            """\
""",
        )

    def test_read_results_unknown_test(self):
        try:
            self._read_test_results(
                ["test1"],
                """\
test_start:test1
test_start:test3
test_suite_done""",
            )
        except RuntimeError as exc:
            self.assertIn("unknown test case test3", str(exc))
        else:
            assert False, "RuntimeError not raised"

    def _read_test_results(self, expected, contents):
        """
        Helper method to test the read_test_results function
        """
        with create_tempdir() as path:
            file_name = Path(path) / "vunit_results"
            if contents is not None:
                with file_name.open("w") as fptr:
                    fptr.write(contents)

            run = TestRun(
                simulator_if=None,
                config=None,
                elaborate_only=False,
                test_suite_name=None,
                test_cases=expected,
                seed="seed"
            )
            results = run._read_test_results(file_name=file_name)  # pylint: disable=protected-access
            self.assertEqual(results, expected)
            return results

    def test_exit_code(self):
        """
        Test that results are overwritten when none is FAILED but the exit code is nonzero
        """

        def test(contents, results, expected=None, werechecked=None):
            """
            Test the four combinations of 'sim_ok' and 'has_valid_exit_code'
            """
            if werechecked is None:
                werechecked = [True, True, True, True]
            self._test_exit_code(contents, results, True, False, werechecked[0])
            self._test_exit_code(contents, results, False, False, werechecked[1])
            self._test_exit_code(contents, results, True, True, werechecked[2])
            val = results
            if expected is not None:
                val = expected
            self._test_exit_code(contents, val, False, True, werechecked[3])

        test(
            """\ntest_start:test1\ntest_suite_done\n""",
            {"test1": PASSED},
            {"test1": FAILED},
            [False, False, False, True],
        )

        test(
            """\ntest_start:test1\ntest_suite_done\n""",
            {"test1": PASSED, "test2": SKIPPED},
            {"test1": FAILED, "test2": SKIPPED},
            [False, False, False, True],
        )

        test("""\ntest_start:test1\n""", {"test1": FAILED, "test2": SKIPPED})
        contents = """\ntest_start:test1\ntest_start:test2\n"""
        test(contents, {"test1": PASSED, "test2": FAILED})
        test(contents, {"test1": PASSED, "test2": FAILED, "test3": SKIPPED})

    def _test_exit_code(
        self,
        contents,
        expected,
        sim_ok=True,
        has_valid_exit_code=False,
        waschecked=False,
    ):
        """
        Helper method to test the check_results function
        """
        with create_tempdir() as path:
            file_name = Path(path) / "vunit_results"
            if contents is not None:
                with file_name.open("w") as fptr:
                    fptr.write(contents)

            sim_if = SimulatorInterface

            @staticmethod
            def func():
                return has_valid_exit_code

            sim_if.has_valid_exit_code = func

            run = TestRun(
                simulator_if=sim_if,
                config=None,
                elaborate_only=False,
                test_suite_name=None,
                test_cases=expected,
                seed="seed"
            )

            results = run._read_test_results(file_name=file_name)  # pylint: disable=protected-access
            self.assertEqual(
                run._check_results(results, sim_ok),  # pylint: disable=protected-access
                (waschecked, expected),
            )
