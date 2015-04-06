# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from __future__ import print_function

from os.path import join, exists
from os import makedirs
from shutil import rmtree

import traceback
import vunit.ostools as ostools
from vunit.test_report import TestResult, PASSED, FAILED

import sys


class TestRunner:
    def __init__(self, report, output_path, verbose=False):
        self._report = report
        self._output_path = output_path
        self._verbose = verbose

    def _run_test_suite(self, test_suite, num_tests):

        def add_and_print_results(results, runtime):
            time = runtime / len(test_suite.test_cases)
            for test_name in test_suite.test_cases:
                self._report.add_result(test_name,
                                        results[test_name],
                                        time,
                                        output_file_name)
                self._report.print_latest_status(total_tests=num_tests)
            print()

        for test_name in test_suite.test_cases:
            self._print_test_case_banner(test_name)

        start = ostools.get_time()
        old_stdout = sys.stdout
        old_stderr = sys.stderr

        output_path = join(self._output_path, self._encode_path(test_suite.name))
        output_file_name = join(output_path, "output.txt")

        try:
            # If we could not clean output path, fail all tests
            if exists(output_path):
                rmtree(output_path)
            makedirs(output_path)
            output_file = open(output_file_name, "w")
        except:  # pylint: disable=bare-except
            traceback.print_exc()
            results = self._fail_suite(test_suite)
            add_and_print_results(results, 0.0)
            return

        try:
            if self._verbose:
                sys.stdout = TeeToFile([old_stderr, output_file])
                sys.stderr = TeeToFile([old_stdout, output_file])
            else:
                sys.stdout = TeeToFile([output_file])
                sys.stderr = TeeToFile([output_file])

            results = test_suite.run(output_path)
        except:  # pylint: disable=bare-except
            traceback.print_exc()
            results = self._fail_suite(test_suite)
        finally:
            sys.stdout = old_stdout
            sys.stderr = old_stderr
            output_file.close()

        any_not_passed = any(value != PASSED for value in results.values())
        if (not self._verbose) and any_not_passed:
            with open(output_file_name, "r") as fread:
                for line in fread:
                    print(line, end="")

        runtime = ostools.get_time() - start
        add_and_print_results(results, runtime)

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
