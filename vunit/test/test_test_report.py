# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from unittest import TestCase
from vunit.test_report import TestReport, PASSED, SKIPPED, FAILED
from xml.etree import ElementTree
from os.path import join, dirname


class TestTestReport(TestCase):
    """
    Collect reports from running testcases
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
        self.assertEqual(self.report_to_str(report), """\
{gi}pass{x} passed_test0 after 1.0 seconds
{gi}pass{x} passed_test1 after 2.0 seconds

Total time 3.0 seconds
2 of 2 passed
{gi}All passed!
{x}""")
        self.assertTrue(report.all_ok())
        self.assertTrue(report.result_of("passed_test0").passed)
        self.assertTrue(report.result_of("passed_test1").passed)
        self.assertRaises(KeyError,
                          report.result_of, "invalid_test")

    def test_report_with_failed_tests(self):
        report = self._report_with_some_failed_tests()
        self.assertEqual(self.report_to_str(report), """\
{gi}pass{x} passed_test after 2.0 seconds
{ri}fail{x} failed_test0 after 11.1 seconds
{ri}fail{x} failed_test1 after 3.0 seconds

Total time 16.1 seconds
1 of 3 passed
2 of 3 failed
{ri}Some failed!
{x}""")
        self.assertFalse(report.all_ok())
        self.assertTrue(report.result_of("passed_test").passed)
        self.assertTrue(report.result_of("failed_test0").failed)
        self.assertTrue(report.result_of("failed_test1").failed)

    def test_report_with_skipped_tests(self):
        report = self._report_with_some_skipped_tests()
        self.assertEqual(self.report_to_str(report), """\
{gi}pass{x} passed_test after 1.0 seconds
{rgi}skip{x} skipped_test after 0.0 seconds
{ri}fail{x} failed_test after 3.0 seconds

Total time 4.0 seconds
1 of 3 passed
1 of 3 skipped
1 of 3 failed
{ri}Some failed!
{x}""")
        self.assertFalse(report.all_ok())
        self.assertTrue(report.result_of("passed_test").passed)
        self.assertTrue(report.result_of("skipped_test").skipped)
        self.assertTrue(report.result_of("failed_test").failed)

    def assert_has_test(self, root, name, time, status):
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

                self.assertEqual(test.find("system-out").text,
                                 self.output_file_contents)
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

    def _report_with_all_passed_tests(self):
        " @returns A report with all passed tests "
        report = self._new_report()
        report.add_result("passed_test0", PASSED, time=1.0,
                          output_file_name=self.output_file_name)
        report.add_result("passed_test1", PASSED, time=2.0,
                          output_file_name=self.output_file_name)
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
        return report

    def _new_report(self):
        return TestReport(self.printer)


class StubPrinter:
    def __init__(self):
        self.report_str = ""

    def reset(self):
        self.report_str = ""

    def write(self, text, fg=None, bg=None):
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
