# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Provide test reporting functionality
"""


from xml.etree import ElementTree
import os
import socket
import re
from pathlib import Path
from vunit.color_printer import COLOR_PRINTER
from vunit.ostools import read_file


def get_parsed_time(time_in, max_time=0):
    """
    Return string representation of input value
    in hours, minutes and seconds.
    Inputs:
      time_in  : Time to convert to string
      max_time : Longest test time among tests. Optional parameter
    """
    time_str = ""

    (minutes, seconds) = divmod(time_in, 60)
    (hours, minutes) = divmod(minutes, 60)

    if max(time_in, max_time) >= 3600:
        # If the longest test took 10 hours or more, pad the string to take this
        # into account.
        padding = len(f"{int(max_time // 3600)} h ")
        if hours > 0:
            time_str += f"{int(hours)} h ".rjust(padding)
        else:
            time_str += " " * padding
    if max(time_in, max_time) >= 60:
        # If the longest test took an hour (or more), or the longest test took
        # 10 minutes or more, pad the string to take this into account.
        padding = 7 if (max_time / 60 >= 10) else 6
        if minutes > 0:
            time_str += f"{int(minutes)} min ".rjust(padding)
        else:
            time_str += " " * padding

    # If the longest test took a minute (or more), or the longest test
    # took 10 seconds or more, pad the string to take this into account.
    padding = 6 if (max_time >= 10) else 5
    time_str += f"{seconds:2.1f} s".rjust(padding)

    return time_str


class TestReport(object):
    """
    Collect reports from running testcases
    """

    def __init__(self, printer=COLOR_PRINTER):
        self._test_results = {}
        self._test_names_in_order = []
        self._printer = printer
        self._real_total_time = 0.0
        self._expected_num_tests = 0

    def set_real_total_time(self, real_total_time):
        """
        Set the real total execution time
        """
        self._real_total_time = real_total_time

    def set_expected_num_tests(self, expected_num_tests):
        """
        Set the number of tests that we expect to run
        """
        self._expected_num_tests = expected_num_tests

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
        passed, failed, skipped = self._split()
        if result.passed:
            self._printer.write("pass", fg="gi")
        elif result.failed:
            self._printer.write("fail", fg="ri")
        elif result.skipped:
            self._printer.write("skip", fg="rgi")
        else:
            assert False

        args = []
        args.append(f"P={len(passed):d}")
        args.append(f"S={len(skipped):d}")
        args.append(f"F={len(failed):d}")
        args.append(f"T={total_tests:d}")

        self._printer.write(f" ({' '.join(args)!s}) {result.name!s} ({get_parsed_time(result.time)})\n")

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
        all_tests = passed + skipped + failures

        if not all_tests:
            self._printer.write("No tests were run!", fg="rgi")
            self._printer.write("\n")
            return

        prefix = "==== Summary "
        max_len = max(len(test.name) for test in all_tests)
        max_time = max(test.time for test in all_tests)
        self._printer.write(f"{prefix!s}{'=' * (max(max_len - len(prefix) + 25, 0))}\n")
        for test_result in all_tests:
            test_result.print_status(self._printer, padding=max_len, max_time=max_time)

        self._printer.write(("=" * (max(max_len + 25, 0))) + "\n")
        n_failed = len(failures)
        n_skipped = len(skipped)
        n_passed = len(passed)
        total = len(all_tests)

        self._printer.write("pass", fg="gi")
        self._printer.write(f" {n_passed:d} of {total:d}\n")

        if n_skipped > 0:
            self._printer.write("skip", fg="rgi")
            self._printer.write(f" {n_skipped:d} of {total:d}\n")

        if n_failed > 0:
            self._printer.write("fail", fg="ri")
            self._printer.write(f" {n_failed:d} of {total:d}\n")
        self._printer.write(("=" * (max(max_len + 25, 0))) + "\n")

        total_time = sum((result.time for result in self._test_results.values()))
        self._printer.write(f"Total time was {get_parsed_time(total_time)}\n")
        self._printer.write(f"Elapsed time was {get_parsed_time(self._real_total_time)}\n")

        self._printer.write(("=" * (max(max_len + 25, 0))) + "\n")

        if n_failed > 0:
            self._printer.write("Some failed!", fg="ri")
        elif n_skipped > 0:
            self._printer.write("Some skipped!", fg="rgxi")
        else:
            self._printer.write("All passed!", fg="gi")
        self._printer.write("\n")

        assert len(all_tests) <= self._expected_num_tests
        if len(all_tests) < self._expected_num_tests:
            self._printer.write(
                f"WARNING: Test execution aborted after running "
                f"{len(all_tests):d} out of {self._expected_num_tests:d} tests",
                fg="rgi",
            )
            self._printer.write("\n")

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

    def to_junit_xml_str(self, xunit_xml_format="jenkins"):
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
        root.attrib["hostname"] = socket.gethostname()

        for result in self._test_results_in_order():
            root.append(result.to_xml(xunit_xml_format))

        xml = ElementTree.tostring(root, encoding="unicode")
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
        return f"TestStatus({self._name!r})"


PASSED = TestStatus("passed")
SKIPPED = TestStatus("skipped")
FAILED = TestStatus("failed")


class TestResult(object):
    """
    Represents the result of a single test case
    """

    def __init__(self, name, status, time, output_file_name):
        assert status in (PASSED, FAILED, SKIPPED)
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
            return read_file(self._output_file_name)

        return f"Failed to read output file: {self._output_file_name!s}"

    @property
    def passed(self):
        return self._status == PASSED

    @property
    def skipped(self):
        return self._status == SKIPPED

    @property
    def failed(self):
        return self._status == FAILED

    def print_status(self, printer, padding=0, max_time=0):
        """
        Print the status and runtime of this test result
        """
        if self.passed:
            printer.write("pass", fg="gi")
            printer.write(" ")
        elif self.failed:
            printer.write("fail", fg="ri")
            printer.write(" ")
        elif self.skipped:
            printer.write("skip", fg="rgi")
            printer.write(" ")

        my_padding = max(padding - len(self.name), 0)

        printer.write(f"{self.name + (' ' * my_padding)} ({get_parsed_time(self.time, max_time)})\n")

    def to_xml(self, xunit_xml_format):
        """
        Convert the test result to ElementTree XML object
        """
        test = ElementTree.Element("testcase")
        match = re.search(r"(.+)\.([^.]+)$", self.name)
        if match:
            test.attrib["classname"] = match.group(1)
            test.attrib["name"] = match.group(2)
        else:
            test.attrib["name"] = self.name
        test.attrib["time"] = f"{self.time:.1f}"

        # By default the output is stored in system-out
        system_out = ElementTree.SubElement(test, "system-out")
        system_out.text = self.output

        if self.failed:
            failure = ElementTree.SubElement(test, "failure")
            failure.attrib["message"] = "Failed"

            # Store output under <failure> if the 'bamboo' format is specified
            if xunit_xml_format == "bamboo":
                failure.text = system_out.text
                system_out.text = ""

        elif self.skipped:
            skipped = ElementTree.SubElement(test, "skipped")
            skipped.attrib["message"] = "Skipped"
        return test

    def to_dict(self):
        """
        Convert a subset of the test result to a dictionary
        """
        return {
            "status": self._status.name,
            "time": self.time,
            "path": str(Path(self._output_file_name).parent),
        }
