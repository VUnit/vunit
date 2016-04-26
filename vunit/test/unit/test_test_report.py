# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the test report functionality
"""

from unittest import TestCase
from xml.etree import ElementTree
from os.path import join, dirname
import os
from vunit.test_report import TestReport, PASSED, SKIPPED, FAILED


class TestTestReport(TestCase):
    """
    Test the TestReport class
    """

    def setUp(self):
        self.printer = StubPrinter()

        self.output_file_contents = 'Output file contents\n<xml>&13!--"<\\xml>'
        self.output_file_name = join(dirname(__file__), "test_report_output.txt")
        with open(self.output_file_name, "w") as fwrite:
            fwrite.write(self.output_file_contents)

    def report_to_str(self, report):
        """
        Helper function to create a string with color tags of the report
        """

        self.printer.reset()
        report.print_str()
        return self.printer.report_str

    def test_report_with_all_passed_tests(self):
        report = self._report_with_all_passed_tests()
        report.set_real_total_time(1.0)
        self.assertEqual(self.report_to_str(report), """\
==== Summary ========================
{gi}pass{x} passed_test0 (1.0 seconds)
{gi}pass{x} passed_test1 (2.0 seconds)
=====================================
{gi}pass{x} 2 of 2
=====================================
Total time was 3.0 seconds
Elapsed time was 1.0 seconds
=====================================
{gi}All passed!{x}
""")
        self.assertTrue(report.all_ok())
        self.assertTrue(report.result_of("passed_test0").passed)
        self.assertTrue(report.result_of("passed_test1").passed)
        self.assertRaises(KeyError,
                          report.result_of, "invalid_test")

    def test_report_with_missing_tests(self):
        report = self._report_with_missing_tests()
        report.set_real_total_time(1.0)
        self.assertEqual(self.report_to_str(report), """\
==== Summary ========================
{gi}pass{x} passed_test0 (1.0 seconds)
{gi}pass{x} passed_test1 (2.0 seconds)
=====================================
{gi}pass{x} 2 of 2
=====================================
Total time was 3.0 seconds
Elapsed time was 1.0 seconds
=====================================
{gi}All passed!{x}
{rgi}WARNING: Test execution aborted after running 2 out of 3 tests{x}
""")
        self.assertTrue(report.all_ok())
        self.assertTrue(report.result_of("passed_test0").passed)
        self.assertTrue(report.result_of("passed_test1").passed)
        self.assertRaises(KeyError,
                          report.result_of, "invalid_test")

    def test_report_with_failed_tests(self):
        report = self._report_with_some_failed_tests()
        report.set_real_total_time(12.0)
        self.assertEqual(self.report_to_str(report), """\
==== Summary ========================
{gi}pass{x} passed_test  (2.0 seconds)
{ri}fail{x} failed_test0 (11.1 seconds)
{ri}fail{x} failed_test1 (3.0 seconds)
=====================================
{gi}pass{x} 1 of 3
{ri}fail{x} 2 of 3
=====================================
Total time was 16.1 seconds
Elapsed time was 12.0 seconds
=====================================
{ri}Some failed!{x}
""")
        self.assertFalse(report.all_ok())
        self.assertTrue(report.result_of("passed_test").passed)
        self.assertTrue(report.result_of("failed_test0").failed)
        self.assertTrue(report.result_of("failed_test1").failed)

    def test_report_with_skipped_tests(self):
        report = self._report_with_some_skipped_tests()
        report.set_real_total_time(3.0)
        self.assertEqual(self.report_to_str(report), """\
==== Summary ========================
{gi}pass{x} passed_test  (1.0 seconds)
{rgi}skip{x} skipped_test (0.0 seconds)
{ri}fail{x} failed_test  (3.0 seconds)
=====================================
{gi}pass{x} 1 of 3
{rgi}skip{x} 1 of 3
{ri}fail{x} 1 of 3
=====================================
Total time was 4.0 seconds
Elapsed time was 3.0 seconds
=====================================
{ri}Some failed!{x}
""")
        self.assertFalse(report.all_ok())
        self.assertTrue(report.result_of("passed_test").passed)
        self.assertTrue(report.result_of("skipped_test").skipped)
        self.assertTrue(report.result_of("failed_test").failed)

    def test_report_with_no_tests(self):
        report = self._new_report()
        self.assertEqual(self.report_to_str(report), """\
{rgi}No tests were run!{x}
""")
        self.assertTrue(report.all_ok())

    def assert_has_test(self, root, name, time, status, output=None):  # pylint: disable=too-many-arguments
        """
        Assert that junit report xml tree contains a test
        """
        output = self.output_file_contents if output is None else output
        for test in root.findall("testcase"):
            if test.attrib["name"] == name:
                self.assertEqual(test.attrib["time"], time)
                if status == "passed":
                    self.assertEqual(len(test.findall("*")), 1)
                    self.assertEqual(len(test.findall("system-out")), 1)
                elif status == "skipped":
                    self.assertEqual(len(test.findall("*")), 2)
                    self.assertEqual(len(test.findall("skipped")), 1)
                    self.assertEqual(len(test.findall("system-out")), 1)
                elif status == "failed":
                    self.assertEqual(len(test.findall("*")), 2)
                    self.assertEqual(len(test.findall("failure")), 1)
                    self.assertEqual(len(test.findall("system-out")), 1)
                else:
                    assert False

                self.assertEqual(test.find("system-out").text, output)
                break
        else:
            assert False

    def test_junit_report_with_all_passed_tests(self):
        report = self._report_with_all_passed_tests()
        root = ElementTree.fromstring(report.to_junit_xml_str())
        self.assertEqual(root.tag, "testsuite")
        self.assertEqual(len(root.findall("*")), 2)
        self.assert_has_test(root, "passed_test0", time="1.0", status="passed")
        self.assert_has_test(root, "passed_test1", time="2.0", status="passed")

    def test_junit_report_with__with_missing_output_file(self):
        report = self._report_with_all_passed_tests()
        os.remove(self.output_file_name)
        fail_output = "Failed to read output file: %s" % self.output_file_name
        root = ElementTree.fromstring(report.to_junit_xml_str())
        self.assertEqual(root.tag, "testsuite")
        self.assertEqual(len(root.findall("*")), 2)
        self.assert_has_test(root, "passed_test0", time="1.0", status="passed",
                             output=fail_output)
        self.assert_has_test(root, "passed_test1", time="2.0", status="passed",
                             output=fail_output)

    def test_junit_report_with_some_failed_tests(self):
        report = self._report_with_some_failed_tests()
        root = ElementTree.fromstring(report.to_junit_xml_str())
        self.assertEqual(root.tag, "testsuite")
        self.assertEqual(len(root.findall("*")), 3)
        self.assert_has_test(root, "failed_test0", time="11.1", status="failed")
        self.assert_has_test(root, "passed_test", time="2.0", status="passed")
        self.assert_has_test(root, "failed_test1", time="3.0", status="failed")

    def test_junit_report_with_some_skipped_tests(self):
        report = self._report_with_some_skipped_tests()
        root = ElementTree.fromstring(report.to_junit_xml_str())
        self.assertEqual(root.tag, "testsuite")
        self.assertEqual(len(root.findall("*")), 3)
        self.assert_has_test(root, "skipped_test", time="0.0", status="skipped")
        self.assert_has_test(root, "passed_test", time="1.0", status="passed")
        self.assert_has_test(root, "failed_test", time="3.0", status="failed")

    def test_junit_report_with_testcase_classname(self):
        report = self._new_report()
        report.add_result("test", PASSED, time=1.0,
                          output_file_name=self.output_file_name)
        report.add_result("lib.entity", PASSED, time=1.0,
                          output_file_name=self.output_file_name)
        report.add_result("lib.entity.test", PASSED, time=1.0,
                          output_file_name=self.output_file_name)
        report.add_result("lib.entity.config.test", PASSED, time=1.0,
                          output_file_name=self.output_file_name)
        root = ElementTree.fromstring(report.to_junit_xml_str())
        names = set((elem.attrib.get("classname", None), elem.attrib.get("name", None))
                    for elem in root.findall("testcase"))
        self.assertEqual(names, set([(None, "test"),
                                     ("lib", "entity"),
                                     ("lib.entity", "test"),
                                     ("lib.entity.config", "test")]))

    def _report_with_all_passed_tests(self):
        " @returns A report with all passed tests "
        report = self._new_report()
        report.add_result("passed_test0", PASSED, time=1.0,
                          output_file_name=self.output_file_name)
        report.add_result("passed_test1", PASSED, time=2.0,
                          output_file_name=self.output_file_name)
        report.set_expected_num_tests(2)
        return report

    def _report_with_missing_tests(self):
        " @returns A report with all passed tests "
        report = self._new_report()
        report.add_result("passed_test0", PASSED, time=1.0,
                          output_file_name=self.output_file_name)
        report.add_result("passed_test1", PASSED, time=2.0,
                          output_file_name=self.output_file_name)
        report.set_expected_num_tests(3)
        return report

    def _report_with_some_failed_tests(self):
        " @returns A report with some failed tests "
        report = self._new_report()
        report.add_result("failed_test0", FAILED, time=11.12,
                          output_file_name=self.output_file_name)
        report.add_result("passed_test", PASSED, time=2.0,
                          output_file_name=self.output_file_name)
        report.add_result("failed_test1", FAILED, time=3.0,
                          output_file_name=self.output_file_name)
        report.set_expected_num_tests(3)
        return report

    def _report_with_some_skipped_tests(self):
        " @returns A report with some skipped tests "
        report = self._new_report()
        report.add_result("passed_test", PASSED, time=1.0,
                          output_file_name=self.output_file_name)
        report.add_result("skipped_test", SKIPPED, time=0.0,
                          output_file_name=self.output_file_name)
        report.add_result("failed_test", FAILED, time=3.0,
                          output_file_name=self.output_file_name)
        report.set_expected_num_tests(3)
        return report

    def _new_report(self):
        return TestReport(self.printer)


class StubPrinter(object):
    """
    A stub of a ColorPrinter
    """
    def __init__(self):
        self.report_str = ""

    def reset(self):
        self.report_str = ""

    def write(self, text, fg=None, bg=None):
        """
        ColorPrinter write stub
        """
        if fg is not None or bg is not None:
            self.report_str += "{"

        if fg is not None:
            self.report_str += fg

        if bg is not None:
            self.report_str += bg.upper()

        if fg is not None or bg is not None:
            self.report_str += "}"

        self.report_str += text

        if fg is not None or bg is not None:
            self.report_str += "{x}"
