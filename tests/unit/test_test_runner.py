# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the test runner
"""

from pathlib import Path
import unittest
from unittest import mock
from tests.common import with_tempdir
from vunit.hashing import hash_string
from vunit.test.runner import TestRunner
from vunit.test.report import TestReport
from vunit.test.list import TestList


class TestTestRunner(unittest.TestCase):
    """
    Test the test runner
    """

    @with_tempdir
    def test_runs_testcases_in_order(self, tempdir):
        report = TestReport()
        runner = TestRunner(report, tempdir)

        order = []
        test_case1 = self.create_test("test1", True, order=order)
        test_case2 = self.create_test("test2", False, order=order)
        test_case3 = self.create_test("test3", True, order=order)
        test_list = TestList()
        test_list.add_test(test_case1)
        test_list.add_test(test_case2)
        test_list.add_test(test_case3)
        runner.run(test_list)
        self.assertEqual(test_case1.output_path, runner._get_output_path("test1"))
        self.assertEqual(test_case2.output_path, runner._get_output_path("test2"))
        self.assertEqual(test_case3.output_path, runner._get_output_path("test3"))
        self.assertEqual(order, ["test1", "test2", "test3"])
        self.assertTrue(report.result_of("test1").passed)
        self.assertTrue(report.result_of("test2").failed)
        self.assertTrue(report.result_of("test3").passed)

    @with_tempdir
    def test_fail_fast(self, tempdir):
        report = TestReport()
        runner = TestRunner(report, tempdir, fail_fast=True)

        order = []
        test_case1 = self.create_test("test1", True, order=order)
        test_case2 = self.create_test("test2", False, order=order)
        test_case3 = self.create_test("test3", True, order=order)
        test_list = TestList()
        test_list.add_test(test_case1)
        test_list.add_test(test_case2)
        test_list.add_test(test_case3)
        try:
            runner.run(test_list)
        except KeyboardInterrupt:
            pass
        self.assertEqual(test_case1.output_path, runner._get_output_path("test1"))
        self.assertEqual(test_case2.output_path, runner._get_output_path("test2"))
        self.assertEqual(test_case3.called, False)
        self.assertEqual(order, ["test1", "test2"])
        self.assertTrue(report.result_of("test1").passed)
        self.assertTrue(report.result_of("test2").failed)

    @with_tempdir
    def test_handles_python_exeception(self, tempdir):
        report = TestReport()
        runner = TestRunner(report, tempdir)

        test_case = self.create_test("test", True)
        test_list = TestList()
        test_list.add_test(test_case)

        def side_effect(*args, **kwargs):  # pylint: disable=unused-argument
            raise KeyError

        test_case.run_side_effect = side_effect
        runner.run(test_list)
        self.assertTrue(report.result_of("test").failed)

    @with_tempdir
    def test_collects_output(self, tempdir):
        report = TestReport()
        runner = TestRunner(report, tempdir)

        test_case = self.create_test("test", True)
        test_list = TestList()
        test_list.add_test(test_case)

        output = "Output string, <xml>, </xml>\n"

        def side_effect(*args, **kwargs):  # pylint: disable=unused-argument
            """
            Side effect that print output to stdout
            """
            print(output, end="")
            return True

        test_case.run_side_effect = side_effect
        runner.run(test_list)
        self.assertTrue(report.result_of("test").passed)
        self.assertEqual(report.result_of("test").output, output)

    @with_tempdir
    def test_can_read_output(self, tempdir):
        report = TestReport()
        runner = TestRunner(report, tempdir)

        test_case = self.create_test("test", True)
        test_list = TestList()
        test_list.add_test(test_case)

        def side_effect(read_output, **kwargs):  # pylint: disable=unused-argument
            """
            Side effect that print output to stdout
            """
            print("out1", end="")
            print("out2", end="")
            assert read_output() == "out1out2"
            print("out3", end="")
            print("out4", end="")
            assert read_output() == "out1out2out3out4"
            print("out5", end="")
            return True

        test_case.run_side_effect = side_effect
        runner.run(test_list)
        self.assertTrue(report.result_of("test").passed)
        self.assertEqual(report.result_of("test").output, "out1out2out3out4out5")

    def test_get_output_path_on_linux(self):
        output_path = "output_path"
        report = TestReport()
        runner = TestRunner(report, output_path)

        with mock.patch("sys.platform", new="linux"):
            with mock.patch("os.environ", new={}):
                test_name = "_" * 400
                test_output = runner._get_output_path(test_name)
                self.assertEqual(
                    test_output,
                    str(Path(output_path).resolve() / (test_name + "_" + hash_string(test_name))),
                )

                output_path = "output_path"
                test_name = "123._-+"
                test_output = runner._get_output_path(test_name)
                self.assertEqual(
                    test_output,
                    str(Path(output_path).resolve() / (test_name + "_" + hash_string(test_name))),
                )

                output_path = "output_path"
                test_name = "#<>:"
                safe_name = "____"
                test_output = runner._get_output_path(test_name)
                self.assertEqual(
                    test_output,
                    str(Path(output_path).resolve() / (safe_name + "_" + hash_string(test_name))),
                )

    def test_get_output_path_on_windows(self):
        output_path = "output_path"
        report = TestReport()
        runner = TestRunner(report, output_path)

        with mock.patch("sys.platform", new="win32"):
            with mock.patch("os.environ", new={}):
                test_name = "_" * 400
                test_output = runner._get_output_path(test_name)
                self.assertEqual(len(test_output), 260 - 100 + 1)

            with mock.patch("os.environ", new={"VUNIT_TEST_OUTPUT_PATH_MARGIN": "-1000"}):
                output_path = "output_path"
                test_name = "_" * 400
                test_output = runner._get_output_path(test_name)
                self.assertEqual(
                    test_output,
                    str(Path(output_path).resolve() / (test_name + "_" + hash_string(test_name))),
                )

            with mock.patch("os.environ", new={"VUNIT_SHORT_TEST_OUTPUT_PATHS": ""}):
                output_path = "output_path"
                test_name = "_" * 400
                test_output = runner._get_output_path(test_name)
                self.assertEqual(
                    test_output,
                    str(Path(output_path).resolve() / hash_string(test_name)),
                )

    @staticmethod
    def create_test(name, passed, order=None):
        """
        Utility function to create a mocked test with name
        that is either passed or failed
        """

        def run_side_effect(*args, **kwargs):  # pylint: disable=unused-argument
            """
            Side effect that registers that is has been run
            """
            if order is not None:
                order.append(name)
            return passed

        test_case = TestCaseMock(name=name, run_side_effect=run_side_effect)
        return test_case


class TestCaseMock(object):
    """
    A test case mock class
    """

    def __init__(self, name, run_side_effect):
        self.name = name
        self.output_path = None
        self.read_output = None
        self.called = False
        self.run_side_effect = run_side_effect

    def run(self, output_path, read_output):
        """
        Mock run method that just records the arguments
        """
        assert not self.called
        self.called = True
        self.output_path = output_path
        self.read_output = read_output
        return self.run_side_effect(output_path=output_path, read_output=read_output)
