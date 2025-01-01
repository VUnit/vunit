# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Contains different kinds of test suites
"""

from pathlib import Path
from time import time
from hashlib import blake2b
from threading import get_ident
from .. import ostools
from .report import PASSED, SKIPPED, FAILED


class IndependentSimTestCase(object):
    """
    A test case to be run in an independent simulation
    """

    def __init__(self, test, config, simulator_if, seed, *, elaborate_only=False):
        self._name = f"{config.library_name!s}.{config.design_unit_name!s}"

        if not config.is_default:
            self._name += "." + config.name

        if test.is_explicit:
            self._name += "." + test.name
        elif config.is_default:
            # JUnit XML test reports wants three dotted name hierarchies
            self._name += ".all"

        self._configuration = config

        self._test = test

        self._run = TestRun(
            simulator_if=simulator_if,
            config=config,
            elaborate_only=elaborate_only,
            test_suite_name=self._name,
            test_cases=[test.name],
            seed=seed,
        )

    @property
    def file_name(self):
        return self._test.location.file_name

    @property
    def name(self):
        return self._name

    @property
    def attribute_names(self):
        return self._test.attribute_names

    @property
    def test_configuration(self):
        return self._configuration

    @property
    def test_information(self):
        """
        Returns the test information
        """
        return self._test

    def run(self, *args, **kwargs):
        """
        Run the test case using the output_path
        """
        results = self._run.run(*args, **kwargs)
        return results[self._test.name] == PASSED


class SameSimTestSuite(object):
    """
    A test suite where multiple test cases are run within the same simulation
    """

    def __init__(self, tests, config, simulator_if, seed, *, elaborate_only=False):
        self._name = f"{config.library_name!s}.{config.design_unit_name!s}"

        if not config.is_default:
            self._name += "." + config.name

        self._configuration = config

        self._tests = tests
        self._run = TestRun(
            simulator_if=simulator_if,
            config=config,
            elaborate_only=elaborate_only,
            test_suite_name=self._name,
            test_cases=[test.name for test in tests],
            seed=seed,
        )

    @property
    def file_name(self):
        return self._tests[0].location.file_name if self._tests else ""

    @property
    def test_names(self):
        return [_full_name(self._name, test.name) for test in self._tests]

    @property
    def test_information(self):
        """
        Returns a dictionary mapping full test name to test information object
        """
        return {_full_name(self._name, test.name): test for test in self._tests}

    @property
    def name(self):
        return self._name

    def keep_matches(self, test_filter):
        """
        Keep tests which pattern return False if no remaining tests
        """

        def _merge_attributes(attribute_names, attributes):
            merged_attributes = attribute_names.copy()
            merged_attributes.update(set(attributes.keys()))
            return merged_attributes

        self._tests = [
            test
            for test in self._tests
            if test_filter(
                name=_full_name(self.name, test.name),
                attribute_names=_merge_attributes(test.attribute_names, self._configuration.attributes),
            )
        ]
        self._run.set_test_cases([test.name for test in self._tests])
        return len(self._tests) > 0

    def run(self, *args, **kwargs):
        """
        Run the test suite using output_path
        """
        results = self._run.run(*args, **kwargs)
        results = {_full_name(self._name, test_name): result for test_name, result in results.items()}
        return results


class TestRun(object):
    """
    A single simulation run yielding the results for one or several test cases
    """

    def __init__(self, *, simulator_if, config, elaborate_only, test_suite_name, test_cases, seed):  # pylint: disable=too-many-arguments
        self._simulator_if = simulator_if
        self._config = config
        self._elaborate_only = elaborate_only
        self._test_suite_name = test_suite_name
        self._test_cases = test_cases
        self._args_seed = seed

    def set_test_cases(self, test_cases):
        self._test_cases = test_cases

    def run(self, output_path, read_output):
        """
        Run selected test cases within the test suite

        Returns a dictionary of test results
        """
        results = {}
        for name in self._test_cases:
            results[name] = FAILED

        if not self._config.call_pre_config(output_path, self._simulator_if.output_path):
            return results

        # Ensure result file exists
        ostools.write_file(get_result_file_name(output_path), "")

        sim_ok = self._simulate(output_path)

        if self._elaborate_only:
            status = PASSED if sim_ok else FAILED
            return dict((name, status) for name in self._test_cases)

        results = self._read_test_results(file_name=get_result_file_name(output_path))

        done, results = self._check_results(results, sim_ok)
        if done:
            return results

        if not self._config.call_post_check(output_path, read_output):
            for name in self._test_cases:
                results[name] = FAILED

        return results

    def _check_results(self, results, sim_ok):
        """
        Test the results and the exit code; return True the status of any test is not PASSED
        """
        # If any test failed, return results
        for status in results.values():
            if status == FAILED:
                return True, results

        # Force fail if all tests pass in the presence of non-zero exit code
        if self._simulator_if.has_valid_exit_code() and not sim_ok:
            return (
                True,
                dict((name, FAILED) if results[name] is PASSED else (name, results[name]) for name in results),
            )

        return False, results

    def _simulate(self, output_path):
        """
        Add runner_cfg generic values and run simulation
        """

        config = self._config.copy()

        if self._args_seed:
            seed = self._args_seed
        elif "seed" in config.sim_options:
            seed = config.sim_options["seed"]
        else:
            now_us = str(int(time() * 1e6)).encode()
            thread_id = get_ident().to_bytes(8, byteorder="little")
            seed = blake2b(now_us, digest_size=8, salt=thread_id).hexdigest()

        print(f"Seed for {self._test_suite_name}: {seed}")

        if "output_path" in config.generic_names and "output_path" not in config.generics:
            config.generics["output_path"] = str(output_path.replace("\\", "/")) + "/"

        runner_cfg = {
            "enabled_test_cases": ",".join(
                encode_test_case(test_case) for test_case in self._test_cases if test_case is not None
            ),
            "use_color": self._simulator_if.use_color,
            "output path": output_path.replace("\\", "/") + "/",
            "active python runner": True,
            "tb path": config.tb_path.replace("\\", "/") + "/",
            "seed": seed,
        }

        # @TODO Warn if runner cfg already set?
        config.generics["runner_cfg"] = encode_dict(runner_cfg)

        return self._simulator_if.simulate(
            output_path=output_path,
            test_suite_name=self._test_suite_name,
            config=config,
            elaborate_only=self._elaborate_only,
        )

    def _read_test_results(self, file_name):  # pylint: disable=too-many-branches
        """
        Read test results from vunit_results file
        """

        results = {}
        for name in self._test_cases:
            results[name] = FAILED

        if not ostools.file_exists(file_name):
            return results

        test_results = ostools.read_file(file_name)
        test_starts = []
        test_suite_done = False

        for line in test_results.splitlines():
            if line.startswith("test_start:"):
                test_name = line[len("test_start:") :]
                if test_name not in test_starts:
                    test_starts.append(test_name)

            elif line.startswith("test_suite_done"):
                test_suite_done = True

        for idx, test_name in enumerate(test_starts):
            last_start = idx == len(test_starts) - 1

            if test_suite_done or not last_start:
                results[test_name] = PASSED

        for test_name in self._test_cases:
            # Anonymous test case
            if test_name is None:
                results[test_name] = PASSED if test_suite_done else FAILED
                continue

            if test_name not in test_starts:
                results[test_name] = SKIPPED

        for test_name in results:
            if test_name not in self._test_cases:
                raise RuntimeError(f"Got unknown test case {test_name!s}")

        return results


def encode_test_case(test_case):
    """
    Encode test case name to escape commas. Avoids that test case names including commas
    are interpreted as several test cases in the comma separated list of enabled test cases
    included in the runner_cfg string.
    """
    if test_case is not None:
        return test_case.replace(",", ",,")

    return None


def encode_dict(dictionary):
    """
    Encode dictionary for custom VHDL dictionary parser
    """

    def escape(value):
        return value.replace(":", "::").replace(",", ",,")

    encoded = []
    for key in sorted(dictionary.keys()):
        value = dictionary[key]
        encoded.append(f"{escape(key)!s} : {escape(encode_dict_value(value))!s}")
    return ",".join(encoded)


def encode_dict_value(value):  # pylint: disable=missing-docstring
    if isinstance(value, bool):
        return str(value).lower()

    return str(value)


def _full_name(test_suite_name, test_case_name):
    return test_suite_name + "." + test_case_name


def get_result_file_name(output_path):
    return str(Path(output_path) / "vunit_results")
