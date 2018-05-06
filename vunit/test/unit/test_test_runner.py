# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the test runner
"""


from __future__ import print_function

import unittest
from os.path import join, abspath

from vunit.hashing import hash_string
from vunit.test_runner import TestRunner, create_output_path
from vunit.test_report import TestReport
from vunit.test_list import TestList
from vunit.test.mock_2or3 import mock
from vunit.test.common import with_tempdir


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
        test_case1.run.assert_called_once_with(create_output_path(tempdir, "test1"))
        test_case2.run.assert_called_once_with(create_output_path(tempdir, "test2"))
        test_case3.run.assert_called_once_with(create_output_path(tempdir, "test3"))
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
        test_case1.run.assert_called_once_with(create_output_path(tempdir, "test1"))
        test_case2.run.assert_called_once_with(create_output_path(tempdir, "test2"))
        self.assertFalse(test_case3.run.called)
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

        def side_effect(*args, **kwargs):
            raise KeyError

        test_case.run.side_effect = side_effect
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

        test_case.run.side_effect = side_effect
        runner.run(test_list)
        self.assertTrue(report.result_of("test").passed)
        self.assertEqual(report.result_of("test").output, output)

    def test_create_output_path_on_linux(self):
        with mock.patch("sys.platform", new="linux"):
            with mock.patch("os.environ", new={}):
                output_path = "output_path"
                test_name = "_" * 400
                test_output = create_output_path(output_path, test_name)
                self.assertEqual(test_output, join(abspath(output_path), test_name + "_" + hash_string(test_name)))

                output_path = "output_path"
                test_name = "123._-+"
                test_output = create_output_path(output_path, test_name)
                self.assertEqual(test_output, join(abspath(output_path), test_name + "_" + hash_string(test_name)))

                output_path = "output_path"
                test_name = "#<>:"
                safe_name = "____"
                test_output = create_output_path(output_path, test_name)
                self.assertEqual(test_output, join(abspath(output_path), safe_name + "_" + hash_string(test_name)))

    def test_create_output_path_on_windows(self):
        with mock.patch("sys.platform", new="win32"):
            with mock.patch("os.environ", new={}):
                output_path = "output_path"
                test_name = "_" * 400
                test_output = create_output_path(output_path, test_name)
                self.assertEqual(len(test_output), 260 - 100 + 1)

            with mock.patch("os.environ", new={"VUNIT_TEST_OUTPUT_PATH_MARGIN": "-1000"}):
                output_path = "output_path"
                test_name = "_" * 400
                test_output = create_output_path(output_path, test_name)
                self.assertEqual(test_output, join(abspath(output_path), test_name + "_" + hash_string(test_name)))

            with mock.patch("os.environ", new={"VUNIT_SHORT_TEST_OUTPUT_PATHS": ""}):
                output_path = "output_path"
                test_name = "_" * 400
                test_output = create_output_path(output_path, test_name)
                self.assertEqual(test_output, join(abspath(output_path), hash_string(test_name)))

    @staticmethod
    def create_test(name, passed, order=None):
        """
        Utility function to create a mocked test with name
        that is either passed or failed
        """
        test_case = mock.Mock(spec_set=TestCaseMockSpec)
        test_case.configure_mock(name=name)

        def run_side_effect(*args, **kwargs):  # pylint: disable=unused-argument
            """
            Side effect that registers that is has been run
            """
            if order is not None:
                order.append(name)
            return passed

        test_case.run.side_effect = run_side_effect
        return test_case


class TestCaseMockSpec(object):  # pylint: disable=no-init
    """
    A test case mock specification class
    """
    name = None
    run = None
