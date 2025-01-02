# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Functionality to handle lists of test suites and filtering of them
"""

from .report import PASSED, FAILED


class TestList(object):
    """
    A list of test suites
    """

    def __init__(self):
        self._test_suites = []

    def add_suite(self, test_suite):
        self._test_suites.append(test_suite)

    def add_test(self, test_case):
        """
        Add a single test that is automatically wrapped into a test suite
        """
        test_suite = TestSuiteWrapper(test_case)
        self._test_suites.append(test_suite)

    def keep_matches(self, test_filter):
        """
        Keep only testcases matching any pattern
        """
        self._test_suites = [test for test in self._test_suites if test.keep_matches(test_filter)]

    @property
    def num_tests(self):
        """
        Return the number of tests within
        """
        num_tests = 0
        for test_suite in self:
            num_tests += len(test_suite.test_names)
        return num_tests

    @property
    def test_names(self):
        """
        Return the names of all tests
        """
        names = []
        for test_suite in self:
            names += test_suite.test_names
        return names

    def __iter__(self):
        return iter(self._test_suites)

    def __len__(self):
        return len(self._test_suites)

    def __getitem__(self, idx):
        return self._test_suites[idx]


class TestSuiteWrapper(object):
    """
    Wrapper which creates a test suite from a single test case
    """

    def __init__(self, test_case):
        self._test_case = test_case

    @property
    def file_name(self):
        return self._test_case.file_name

    @property
    def test_names(self):
        return [self._test_case.name]

    @property
    def name(self):
        return self._test_case.name

    @property
    def test_configuration(self):
        return {self.name: self._test_case.test_configuration}

    @property
    def test_information(self):
        return {self.name: self._test_case.test_information}

    def keep_matches(self, test_filter):
        attributes = self._test_case.attribute_names.copy()
        attributes.update(set(self._test_case.test_configuration.attributes.keys()))
        return test_filter(name=self._test_case.name, attribute_names=attributes)

    def run(self, *args, **kwargs):
        """
        Run the test suite and return the test results for all test cases
        """
        test_ok = self._test_case.run(*args, **kwargs)
        return {self._test_case.name: PASSED if test_ok else FAILED}
