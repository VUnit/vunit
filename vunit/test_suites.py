# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Contains different kinds of test suites
"""


from os.path import join

import vunit.ostools as ostools
from vunit.test_report import (PASSED, SKIPPED, FAILED)


class IndependentSimTestCase(object):
    """
    A test case to be run in an independent simulation
    """
    def __init__(self,  # pylint: disable=too-many-arguments
                 name, test_case, test_bench, has_runner_cfg=False,
                 pre_config=None, post_check=None):
        self._name = name
        self._test_case = test_case
        self._test_bench = test_bench
        self._has_runner_cfg = has_runner_cfg
        self._pre_config = pre_config
        self._post_check = post_check

    @property
    def name(self):
        return self._name

    def run(self, output_path):
        """
        Run the test case using the output_path
        """
        generics = {}

        if self._pre_config is not None:
            if not self._pre_config():
                return False

        if self._has_runner_cfg:
            runner_cfg = {
                "enabled_test_cases": self._test_case,
                "output path": output_path.replace("\\", "/") + "/",
                "active python runner": True,
            }

            generics["runner_cfg"] = encode_dict(runner_cfg)

        if not self._test_bench.run(output_path, generics):
            return False

        if self._post_check is None:
            return True
        else:
            return self._post_check(output_path)


class SameSimTestSuite(object):
    """
    A test suite where multiple test cases are run within the same simulation
    """

    def __init__(self,  # pylint: disable=too-many-arguments
                 name, test_cases, test_bench, pre_config=None, post_check=None):
        self._name = name
        self._test_cases = test_cases
        self._test_bench = test_bench
        self._pre_config = pre_config
        self._post_check = post_check

    @property
    def test_cases(self):
        return [self._full_name(name) for name in self._test_cases]

    @property
    def name(self):
        return self._name

    def _full_name(self, name):
        if name == "":
            return self._name
        else:
            return self._name + "." + name

    def keep_matches(self, test_filter):
        """
        Keep tests which pattern return False if no remaining tests
        """
        self._test_cases = [name for name in self._test_cases
                            if test_filter(self._full_name(name))]
        return len(self._test_cases) > 0

    def run(self, output_path):
        """
        Run the test suite using output_path
        """

        if self._pre_config is not None:
            if not self._pre_config():
                return False

        runner_cfg = {
            "enabled_test_cases": ",".join(self._test_cases),
            "output path": output_path.replace("\\", "/") + "/",
            "active python runner": True,
        }

        generics = {
            "runner_cfg": encode_dict(runner_cfg),
        }

        passed = self._test_bench.run(output_path, generics)

        if passed:
            retval = {}
            for name in self.test_cases:
                retval[name] = PASSED
        else:
            retval = self._determine_partial_pass(output_path)

        if self._post_check is None:
            return retval

        # Do not run post check unless all passed
        for status in retval.values():
            if status != PASSED:
                return retval

        if not self._post_check(output_path):
            for name in self.test_cases:
                retval[name] = FAILED

        return retval

    def _determine_partial_pass(self, output_path):
        """
        In case of simulation failure determine which of the individual test cases failed.
        This is done by reading the test_runner_trace.csv file and checking for test case entry points.
        """
        log_file = join(output_path, "test_runner_trace.csv")

        retval = {}
        for name in self.test_cases:
            retval[name] = FAILED

        if not ostools.file_exists(log_file):
            return retval

        test_log = ostools.read_file(log_file)
        test_starts = []
        for test_name in self._test_cases:
            if "Test Runner,Test case: " + test_name in test_log:
                test_starts.append(test_name)

        for test_name in test_starts[:-1]:
            retval[self._full_name(test_name)] = PASSED

        for test_name in self._test_cases:
            if test_name not in test_starts:
                retval[self._full_name(test_name)] = SKIPPED
        return retval


def encode_dict(dictionary):
    """
    Encode dictionary for custom VHDL dictionary parser
    """
    def escape(value):
        return value.replace(':', '::').replace(',', ',,')

    encoded = []
    for key, value in dictionary.items():
        encoded.append("%s : %s" % (escape(key),
                                    escape(encode_dict_value(value))))
    return ",".join(encoded)


def encode_dict_value(value):
    if isinstance(value, bool):
        return str(value).lower()
    else:
        return str(value)
