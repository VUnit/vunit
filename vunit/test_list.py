# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

from vunit.test_report import (PASSED, FAILED)

class TestList:
    def __init__(self):
        self._test_suites = []

    def add_suite(self, test_suite):
        self._test_suites.append(test_suite)

    def add_test(self, test_case):
        test_suite = TestSuiteWrapper(test_case)
        self._test_suites.append(test_suite)

    def keep_matches(self, test_filter):
        """
        Keep only testcases matching any pattern
        """
        self._test_suites = [test for test in self._test_suites
                             if test.keep_matches(test_filter)]

    def __iter__(self):
        return iter(self._test_suites)

    def __len__(self):
        return len(self._test_suites)

class TestSuiteWrapper:
    def __init__(self, test_case):
        self._test_case = test_case

    @property
    def test_cases(self):
        return [self._test_case.name]

    @property
    def name(self):
        return self._test_case.name

    def keep_matches(self, test_filter):
        return test_filter(self._test_case.name)

    def run(self, output_path):
        test_ok = self._test_case.run(output_path)
        return {self._test_case.name : PASSED if test_ok else FAILED}
