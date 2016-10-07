# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the test runner
"""


from __future__ import print_function

import unittest
from os.path import join, dirname

from vunit.test_runner import TestRunner, create_output_path
from vunit.test_report import TestReport
from vunit.test_list import TestList
from vunit.ostools import renew_path
from vunit.test.mock_2or3 import mock


class TestTestRunner(unittest.TestCase):
    """
    Test the test runner
    """

    def setUp(self):
        self._tests = []
        self.output_path = join(dirname(__file__), "test_runner_out")
        renew_path(self.output_path)
        self.report = TestReport()
        self.runner = TestRunner(self.report, self.output_path)

    def test_runs_testcases_in_order(self):
        test_case1 = self.create_test("test1", True)
        test_case2 = self.create_test("test2", False)
        test_list = TestList()
        test_list.add_test(test_case1)
        test_list.add_test(test_case2)
        self.runner.run(test_list)
        test_case1.run.assert_called_once_with(create_output_path(self.output_path, "test1"))
        test_case2.run.assert_called_once_with(create_output_path(self.output_path, "test2"))
        self.assertEqual(self._tests, ["test1", "test2"])
        self.assertTrue(self.report.result_of("test1").passed)
        self.assertTrue(self.report.result_of("test2").failed)

    def test_handles_python_exeception(self):
        test_case = self.create_test("test", True)
        test_list = TestList()
        test_list.add_test(test_case)
        test_case.run.side_effect = KeyError
        self.runner.run(test_list)
        self.assertTrue(self.report.result_of("test").failed)

    def test_collects_output(self):
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
        self.runner.run(test_list)
        self.assertTrue(self.report.result_of("test").passed)
        self.assertEqual(self.report.result_of("test").output, output)

    def create_test(self, name, passed):
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
            self._tests.append(name)
            return passed

        test_case.run.side_effect = run_side_effect
        return test_case


class TestCaseMockSpec(object):  # pylint: disable=no-init
    """
    A test case mock specification class
    """
    name = None
    run = None
