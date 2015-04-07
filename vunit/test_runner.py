# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from __future__ import print_function

from os.path import join, dirname, exists
from os import makedirs
from shutil import rmtree

import traceback
import vunit.ostools as ostools
from vunit.test_report import PASSED, FAILED

import sys


class TestRunner:
    def __init__(self, report, output_path, verbose=False):
        self._report = report
        self._output_path = output_path
        self._verbose = verbose

    def _run_test_suite(self, test_suite, num_tests):
        start = ostools.get_time()

        for test_name in test_suite.test_cases:
            self._print_test_case_banner(test_name)

        output_path = self._output_path_of(test_suite)
        output_file_name = join(output_path, "output.txt")
        output_file = self._create_output_file(output_file_name)
        if output_file is None:
            results = self._fail_suite(test_suite)
            self._add_results(results, output_file_name, num_tests)
            return

        old_stdout = sys.stdout
        old_stderr = sys.stderr
        try:
            if self._verbose:
                sys.stdout = TeeToFile([old_stderr, output_file])
                sys.stderr = TeeToFile([old_stdout, output_file])
            else:
                sys.stdout = TeeToFile([output_file])
                sys.stderr = TeeToFile([output_file])

            results = test_suite.run(self._output_path_of(test_suite))
        except:  # pylint: disable=bare-except
            traceback.print_exc()
            results = self._fail_suite(test_suite)
        finally:
            sys.stdout = old_stdout
            sys.stderr = old_stderr
            output_file.close()

        self._maybe_print_output_if_not_verbose(results, output_file_name)
        self._add_results(results, output_file_name, num_tests,
                          runtime=ostools.get_time() - start)

    @staticmethod
    def _create_output_file(output_file_name):
        """
        Remove parent folder of output file if it exists and re-create it
        """
        output_path = dirname(output_file_name)
        try:
            # If we could not clean output path, fail all tests
            if exists(output_path):
                rmtree(output_path)
            makedirs(output_path)
            return open(output_file_name, "w")
        except:  # pylint: disable=bare-except
            traceback.print_exc()
        return None

    def _maybe_print_output_if_not_verbose(self, results, output_file_name):
        """
        Print output after failure when not in verbose mode
        """
        any_not_passed = any(value != PASSED for value in results.values())
        if (not self._verbose) and any_not_passed:
            with open(output_file_name, "r") as fread:
                for line in fread:
                    print(line, end="")

    def _add_results(self, results, output_file_name, num_tests, runtime=0.0):
        """
        Add results to test suite
        """
        time = runtime / len(results)
        for test_name in results:
            self._report.add_result(test_name,
                                    results[test_name],
                                    time,
                                    output_file_name)
            self._report.print_latest_status(total_tests=num_tests)
        print()

    def _output_path_of(self, test_suite):
        """
        Return output path of the test suite
        """
        return join(self._output_path, self._encode_path(test_suite.name))

    @staticmethod
    def _fail_suite(test_suite):
        """ Return failure for all tests in suite """
        results = {}
        for test_name in test_suite.test_cases:
            results[test_name] = FAILED
        return results

    @staticmethod
    def _print_test_case_banner(test_case_name):
        """ Print a banner before running each testcase """
        print("running %s" % test_case_name)

    @staticmethod
    def _encode_path(path):
        """ @TODO what if two tests named 'Test 1' and 'Test_1' ? """
        return path.replace(" ", "_")

    def run(self, test_suites):
        num_tests = 0
        for test_suite in test_suites:
            for test_name in test_suite.test_cases:
                num_tests += 1
                if self._verbose:
                    print("Running test: " + test_name)

        if self._verbose:
            print("Running %i tests" % num_tests)

        for test_suite in test_suites:
            self._run_test_suite(test_suite, num_tests)


class TeeToFile:
    def __init__(self, files):
        self._files = files

    def write(self, txt):
        for ofile in self._files:
            ofile.write(txt)

    def flush(self):
        for ofile in self._files:
            ofile.flush()
