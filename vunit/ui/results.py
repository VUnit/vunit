# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

"""
UI class Results
"""

from os.path import join, basename, normpath
from .common import TEST_OUTPUT_PATH


class Results(object):
    """
    Gives access to results after running tests
    """

    def __init__(self, output_path, simulator_if, report):
        self._output_path = output_path
        self._simulator_if = simulator_if
        self._report = report

    def merge_coverage(self, file_name, args=None):
        """
        Create a merged coverage report from the individual coverage files

        :param file_name: The resulting coverage file name.
        :param args: The tool arguments for the merge command. Should be a list of strings.
        """
        self._simulator_if.merge_coverage(file_name=file_name, args=args)

    def get_report(self):
        """
        Get a report (dictionary) of tests: status, time and output path

        :returns: A :class:`Report` object
        """
        report = Report(self._output_path)
        for (
            test
        ) in self._report._test_results_in_order():  # pylint: disable=protected-access
            obj = test.to_dict()
            report.tests.update(
                {
                    test.name: TestResult(
                        join(self._output_path, TEST_OUTPUT_PATH),
                        obj["status"],
                        obj["time"],
                        obj["path"],
                    )
                }
            )
        return report


class Report(object):
    """
    Gives access to test results and paths after running tests

    :data output_path: Absolute path to the output path (see :ref:`cli`)
    :data tests: Dictionary of :class:`TestResult` objects
    """

    def __init__(self, output_path):
        self.output_path = output_path
        self.tests = {}


class TestResult(object):
    """
    Gives access to a subset of the results of a test

    :data status: Result status (passed, failed or skipped)
    :data time: Simulation time
    :data path: Absolute path of the test output

    :example:

    .. code-block:: python

       def post_func(results):
           report = results.get_report()
           print(report.output_path)
           for key, test in report.tests.items():
               print(key)
               print(test.status)
               print(test.time)
               print(test.path)
               print(test.relpath)

       vu.main(post_run=post_func)
    """

    def __init__(self, test_output_path, status, time, path):
        self._test_output_path = test_output_path
        self.status = status
        self.time = time
        self.path = path

    @property
    def relpath(self):
        """
        If the path is a subdir to the default TEST_OUTPUT_PATH, return the subdir only
        """
        base = basename(self.path)
        return (
            base
            if normpath(join(self._test_output_path, base)) == normpath(self.path)
            else self.path
        )
