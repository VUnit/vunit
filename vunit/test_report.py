# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Provide test reporting functionality
"""


from vunit.color_printer import COLOR_PRINTER
from xml.etree import ElementTree
from sys import version_info
import os


class TestReport(object):
    """
    Collect reports from running testcases
    """
    def __init__(self, printer=COLOR_PRINTER):
        self._test_results = {}
        self._test_names_in_order = []
        self._printer = printer

    def num_tests(self):
        """
        Return the number of tests in the report
        """
        return len(self._test_results)

    def add_result(self, *args, **kwargs):
        """
        Add a a test result
        """
        result = TestResult(*args, **kwargs)
        self._test_results[result.name] = result
        self._test_names_in_order.append(result.name)

    def _last_test_result(self):
        """
        Return the latest test result or fail
        """
        return self._test_results[self._test_names_in_order[-1]]

    def _test_results_in_order(self):
        """
        Return the test results in the order they were added
        """
        for name in self._test_names_in_order:
            yield self.result_of(name)

    def print_latest_status(self, total_tests):
        """
        Print the latest status including the last test run and the
        total number of passed, failed and skipped tests
        """
        result = self._last_test_result()
        passed, failed, _ = self._split()
        if result.passed:
            self._printer.write("pass", fg='gi')
        elif result.failed:
            self._printer.write("fail", fg='ri')
        elif result.skipped:
            self._printer.write("skip", fg='rgi')
        else:
            assert False
        self._printer.write(" (P=%i F=%i T=%i) %s\n" %
                            (len(passed),
                             len(failed),
                             total_tests,
                             result.name))

    def all_ok(self):
        """
        Return true if all test passed
        """
        return all(test_result.passed for test_result in self._test_results.values())

    def has_test(self, test_name):
        return test_name in self._test_results

    def result_of(self, test_name):
        return self._test_results[test_name]

    def print_str(self):
        """
        Print the report as a colored string
        """

        passed, failures, skipped = self._split()

        for test_result in passed + skipped + failures:
            test_result.print_status(self._printer)

        self._printer.write("\n")
        n_failed = len(failures)
        n_skipped = len(skipped)
        n_passed = len(passed)
        total = n_failed + n_passed + n_skipped
        total_time = sum((result.time for result in self._test_results.values()))

        self._printer.write("Total time %.1f seconds\n" % total_time)
        self._printer.write("%i of %i passed\n" % (n_passed, total))

        if n_skipped > 0:
            self._printer.write("%i of %i skipped\n" % (n_skipped, total))

        if n_failed > 0:
            self._printer.write("%i of %i failed\n" % (n_failed, total))
            self._printer.write("Some failed!\n", fg='ri')
        else:
            self._printer.write("All passed!\n", fg='gi')

    def _split(self):
        """
        Split the test cases into passed and failures
        """
        failures = []
        passed = []
        skipped = []
        for result in self._test_results_in_order():
            if result.passed:
                passed.append(result)
            elif result.failed:
                failures.append(result)
            elif result.skipped:
                skipped.append(result)

        return passed, failures, skipped

    def to_junit_xml_str(self):
        """
        Convert test report to a junit xml string
        """
        _, failures, skipped = self._split()

        root = ElementTree.Element("testsuite")
        root.attrib["name"] = "testsuite"
        root.attrib["errors"] = "0"
        root.attrib["failures"] = str(len(failures))
        root.attrib["skipped"] = str(len(skipped))
        root.attrib["tests"] = str(len(self._test_results))

        for result in self._test_results_in_order():
            root.append(result.to_xml())

        if version_info >= (3, 0):
            # Python 3.x
            xml = ElementTree.tostring(root, encoding="unicode")
        else:
            # Python 2.x
            xml = ElementTree.tostring(root, encoding="utf-8")
        return xml


class TestStatus(object):
    """
    The status of a test
    """
    def __init__(self, name):
        self._name = name

    @property
    def name(self):
        return self._name

    def __eq__(self, other):
        return isinstance(other, type(self)) and self.name == other.name

    def __repr__(self):
        return "TestStatus(%r)" % self._name


PASSED = TestStatus("passed")
SKIPPED = TestStatus("skipped")
FAILED = TestStatus("failed")


class TestResult(object):
    """
    Represents the result of a single test case
    """

    def __init__(self, name, status, time, output_file_name):
        assert status in (PASSED,
                          FAILED,
                          SKIPPED)
        self.name = name
        self._status = status
        self.time = time
        self._output_file_name = output_file_name

    @property
    def output(self):
        """
        Return test output
        """
        file_exists = os.path.isfile(self._output_file_name)
        is_readable = os.access(self._output_file_name, os.R_OK)
        if file_exists and is_readable:
            with open(self._output_file_name, "r") as fread:
                return fread.read()
        else:
            return "Failed to read output file: %s" % self._output_file_name

    @property
    def passed(self):
        return self._status == PASSED

    @property
    def skipped(self):
        return self._status == SKIPPED

    @property
    def failed(self):
        return self._status == FAILED

    def print_status(self, printer):
        """
        Print the status and runtime of this test result
        """
        if self.passed:
            printer.write("pass", fg='gi')
            printer.write(" ")
        elif self.failed:
            printer.write("fail", fg='ri')
            printer.write(" ")
        elif self.skipped:
            printer.write("skip", fg='rgi')
            printer.write(" ")

        printer.write("%s after %.1f seconds\n" % (self.name, self.time))

    def to_xml(self):
        """
        Convert the test result to ElementTree XML object
        """
        test = ElementTree.Element("testcase")
        test.attrib["name"] = self.name
        test.attrib["time"] = "%.1f" % self.time
        if self.failed:
            failure = ElementTree.SubElement(test, "failure")
            failure.attrib["message"] = "Failed"
        elif self.skipped:
            skipped = ElementTree.SubElement(test, "skipped")
            skipped.attrib["message"] = "Skipped"
        system_out = ElementTree.SubElement(test, "system-out")
        system_out.text = self.output
        return test
