# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2017, Lars Asplund lars.anders.asplund@gmail.com

"""
Contains different kinds of test suites
"""


from os.path import join
import inspect
import vunit.ostools as ostools
from vunit.test_report import (PASSED, SKIPPED, FAILED)


class IndependentSimTestCase(object):
    """
    A test case to be run in an independent simulation
    """
    def __init__(self, test_case, config, simulator_if, elaborate_only=False):
        self._name = "%s.%s" % (config.library_name, config.design_unit_name)

        if not config.is_default:
            self._name += "." + config.name

        if test_case is not None:
            self._name += "." + test_case
        elif config.is_default:
            # JUnit XML test reports wants three dotted name hiearchies
            self._name += ".all"

        self._test_case = test_case
        self._config = config
        self._simulator_if = simulator_if
        self._elaborate_only = elaborate_only

    @property
    def name(self):
        return self._name

    def run(self, output_path):
        """
        Run the test case using the output_path
        """
        if not call_pre_config(self._config.pre_config, output_path,
                               self._simulator_if.get_output_path()):
            return False

        enabled_test_cases = [self._test_case]
        config = _add_runner_cfg(self._config, output_path, enabled_test_cases)
        sim_ok = self._simulator_if.simulate(join(output_path, self._simulator_if.name),
                                             self._name,
                                             config,
                                             elaborate_only=self._elaborate_only)

        if self._elaborate_only:
            return sim_ok

        vunit_results_file = join(output_path, "vunit_results")
        if not ostools.file_exists(vunit_results_file):
            return False
        test_results = ostools.read_file(vunit_results_file)

        expected_results = ""
        if self._test_case is not None:
            expected_results += "test_start:%s\n" % self._test_case
        expected_results += "test_suite_done\n"

        if not test_results == expected_results:
            return False

        if self._config.post_check is None:
            return True

        return self._config.post_check(output_path)


class SameSimTestSuite(object):
    """
    A test suite where multiple test cases are run within the same simulation
    """

    def __init__(self, test_cases, config, simulator_if, elaborate_only=False):
        self._name = "%s.%s" % (config.library_name, config.design_unit_name)

        if not config.is_default:
            self._name += "." + config.name

        self._test_cases = test_cases
        self._config = config
        self._simulator_if = simulator_if
        self._elaborate_only = elaborate_only

    @property
    def test_cases(self):
        return [self._full_name(name) for name in self._test_cases]

    @property
    def name(self):
        return self._name

    def _full_name(self, name):  # pylint: disable=missing-docstring
        if name == "":
            return self._name

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
        if not call_pre_config(self._config.pre_config, output_path,
                               self._simulator_if.get_output_path()):
            return False

        enabled_test_cases = [encode_test_case(test_case) for test_case in self._test_cases]
        config = _add_runner_cfg(self._config, output_path, enabled_test_cases)
        sim_ok = self._simulator_if.simulate(join(output_path, self._simulator_if.name),
                                             self._name,
                                             config,
                                             elaborate_only=self._elaborate_only)

        if self._elaborate_only:
            retval = {}
            for name in self.test_cases:
                retval[name] = PASSED if sim_ok else FAILED
            return retval

        retval = self._read_test_results(output_path)

        if self._config.post_check is None:
            return retval

        # Do not run post check unless all passed
        for status in retval.values():
            if status != PASSED:
                return retval

        if not self._config.post_check(output_path):
            for name in self.test_cases:
                retval[name] = FAILED

        return retval

    def _read_test_results(self, output_path):
        """
        Read test results from vunit_results file
        """
        vunit_results_file = join(output_path, "vunit_results")

        retval = {}
        for name in self.test_cases:
            retval[name] = FAILED

        if not ostools.file_exists(vunit_results_file):
            return retval

        test_results = ostools.read_file(vunit_results_file)
        test_starts = []
        test_suite_done = False

        for line in test_results.splitlines():

            if line.startswith("test_start:"):
                test_name = line[len("test_start:"):]
                test_starts.append(self._full_name(test_name))

            elif line.startswith("test_suite_done"):
                test_suite_done = True

        for idx, test_name in enumerate(test_starts):
            last_start = idx == len(test_starts) - 1

            if test_suite_done or not last_start:
                retval[test_name] = PASSED

        for test_name in self.test_cases:
            if test_name not in test_starts:
                retval[test_name] = SKIPPED

        return retval


def _add_runner_cfg(config, output_path, enabled_test_cases):
    """
    Return a new Configuration object with runner_cfg, output path and tb path information set
    """
    config = config.copy()

    if "output_path" in config.generic_names and "output_path" not in config.generics:
        config.generics["output_path"] = '%s/' % output_path.replace("\\", "/")

    runner_cfg = {
        "enabled_test_cases": ",".join(encode_test_case(test_case)
                                       for test_case in enabled_test_cases
                                       if test_case is not None),
        "output path": output_path.replace("\\", "/") + "/",
        "active python runner": True,
        "tb path": config.tb_path.replace("\\", "/") + "/",
    }

    # @TODO Warn if runner cfg already set?
    config.generics["runner_cfg"] = encode_dict(runner_cfg)
    return config


def encode_test_case(test_case):
    """
    Encode test case name to escape commas. Avoids that test case names including commas
    are interpreted as several test cases in the comma separated list of enabled test cases
    included in the runner_cfg string.
    """
    if test_case is not None:
        return test_case.replace(',', ',,')

    return None


def encode_dict(dictionary):
    """
    Encode dictionary for custom VHDL dictionary parser
    """
    def escape(value):
        return value.replace(':', '::').replace(',', ',,')

    encoded = []
    for key in sorted(dictionary.keys()):
        value = dictionary[key]
        encoded.append("%s : %s" % (escape(key),
                                    escape(encode_dict_value(value))))
    return ",".join(encoded)


def encode_dict_value(value):  # pylint: disable=missing-docstring
    if isinstance(value, bool):
        return str(value).lower()

    return str(value)


def call_pre_config(pre_config, output_path, simulator_output_path):
    """
    Call pre_config if available. Setting optional output_path
    """
    if pre_config is not None:
        args = inspect.getargspec(pre_config).args  # pylint: disable=deprecated-method
        if args == ["output_path", "simulator_output_path"]:
            if not pre_config(output_path, simulator_output_path):
                return False
        elif "output_path" in args:
            if not pre_config(output_path):
                return False
        else:
            if not pre_config():
                return False
    return True
