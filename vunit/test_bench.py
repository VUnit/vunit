# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2017, Lars Asplund lars.anders.asplund@gmail.com

"""
Contains classes to represent a test bench and test cases
"""

import logging
from os.path import basename
import re
from collections import OrderedDict
from vunit.ostools import file_exists
from vunit.cached import cached
from vunit.test_list import TestList
from vunit.vhdl_parser import remove_comments
from vunit.test_suites import IndependentSimTestCase, SameSimTestSuite
from vunit.parsing.encodings import HDL_FILE_ENCODING
from vunit.project import file_type_of
from vunit.configuration import Configuration, ConfigurationVisitor, DEFAULT_NAME


LOGGER = logging.getLogger(__name__)


class TestBench(ConfigurationVisitor):
    """
    A VUnit test bench top level
    """

    def __init__(self, design_unit, database=None):
        ConfigurationVisitor.__init__(self)
        self.design_unit = design_unit
        self._database = database

        self._individual_tests = False
        self._configs = {}
        self.test_cases = []

        if design_unit.is_entity:
            design_unit.set_add_architecture_callback(self._add_architecture_callback)
            if design_unit.architecture_names:
                self._add_architecture_callback()
        else:
            self.scan_tests_from_file(design_unit.file_name)

    def _add_architecture_callback(self):
        """
        Called when architectures have been added
        """
        self._check_architectures(self.design_unit)
        file_name = list(self.design_unit.architecture_names.values())[0]
        self.scan_tests_from_file(file_name)

    @property
    def name(self):
        return self.design_unit.name

    @property
    def library_name(self):
        return self.design_unit.library_name

    def get_default_config(self):
        """
        Get the default configuration of this test bench
        """
        if self._individual_tests:
            raise RuntimeError("Test bench %s.%s has individually configured tests"
                               % (self.library_name, self.name))
        return self._configs[DEFAULT_NAME]

    @staticmethod
    def _check_architectures(design_unit):
        """
        Check that an entity which has been classified as a VUnit test bench
        has exactly one architecture. Raise RuntimeError otherwise.
        """
        if design_unit.is_entity:
            if not design_unit.architecture_names:
                raise RuntimeError("Test bench '%s' has no architecture."
                                   % design_unit.name)

            elif len(design_unit.architecture_names) > 1:
                raise RuntimeError("Test bench not allowed to have multiple architectures. "
                                   "Entity %s has %s"
                                   % (design_unit.name,
                                      ", ".join("%s:%s" % (name, basename(fname))
                                                for name, fname in sorted(design_unit.architecture_names.items()))))

    def create_tests(self, simulator_if, elaborate_only, test_list=None):
        """
        Create all test cases from this test bench
        """

        self._check_architectures(self.design_unit)

        if test_list is None:
            test_list = TestList()

        if self._individual_tests:
            for test_case in self.test_cases:
                test_case.create_tests(simulator_if, elaborate_only, test_list)
        elif not self.test_cases:
            for config in self._get_configurations_to_run():
                test_list.add_test(
                    IndependentSimTestCase(
                        test_case=None,
                        config=config,
                        simulator_if=simulator_if,
                        elaborate_only=elaborate_only))
        else:
            for config in self._get_configurations_to_run():
                test_list.add_suite(
                    SameSimTestSuite(
                        test_cases=self.test_case_names,
                        config=config,
                        simulator_if=simulator_if,
                        elaborate_only=elaborate_only))
        return test_list

    @property
    def test_case_names(self):
        return [test.name for test in self.test_cases]

    def get_test_case(self, name):
        """
        Return the test case with name or raise KeyError
        """
        for test_case in self.test_cases:
            if test_case.name == name:
                return test_case
        raise KeyError(name)

    def get_configuration_dicts(self):
        """
        Get all configurations within the test bench

        If running all tests in the same simulation there are no individual test configurations
        """
        if self._individual_tests:
            configs = []
            for test_case in self.test_cases:
                configs += test_case.get_configuration_dicts()
            return configs

        return [self._configs]

    def _get_configurations_to_run(self):
        """
        Get all simulation runs for this test bench
        """
        configs = self._configs.copy()
        if len(configs) > 1:
            # Remove default configurations when there are more than one
            del configs[DEFAULT_NAME]
        return configs.values()

    def scan_tests_from_file(self, file_name):
        """
        Scan file for test cases and pragmas
        """
        if not file_exists(file_name):
            raise ValueError("File %r does not exist" % file_name)

        def parse(content):
            """
            Parse pragmas and test case names
            """
            pragmas = _find_pragmas(content, file_name)
            test_case_names = _find_test_cases(content, file_name)
            return pragmas, test_case_names

        pragmas, test_case_names = cached("test_bench.parse",
                                          parse,
                                          file_name,
                                          encoding=HDL_FILE_ENCODING,
                                          database=self._database)

        default_config = Configuration(DEFAULT_NAME, self.design_unit)

        if "fail_on_warning" in pragmas:
            default_config.set_sim_option("vhdl_assert_stop_level", "warning")

        self._configs = OrderedDict({default_config.name: default_config})

        self._individual_tests = "run_all_in_same_sim" not in pragmas and len(test_case_names) > 0
        self.test_cases = [TestCase(name,
                                    self.design_unit,
                                    self._individual_tests,
                                    default_config.copy())
                           for name in test_case_names]


class TestCase(ConfigurationVisitor):
    """
    A test case within a test bench
    """
    def __init__(self, name, design_unit, enable_configuration, default_config):
        ConfigurationVisitor.__init__(self)
        self.name = name
        self.design_unit = design_unit
        self._enable_configuration = enable_configuration
        self._configs = OrderedDict({default_config.name: default_config})

    def get_default_config(self):
        """
        Get the default configuration of this test case
        """
        self._check_enabled()
        return self._configs[DEFAULT_NAME]

    def _check_enabled(self):
        if not self._enable_configuration:
            raise RuntimeError("Individual test configuration is not possible with run_all_in_same_sim")

    def get_configuration_dicts(self):
        """
        Get all configurations of this test
        """
        return [self._configs]

    def _get_configurations_to_run(self):
        """
        Get all simulation runs for this test bench
        """
        configs = self._configs.copy()
        if len(configs) > 1:
            # Remove default configurations when there are more than one
            del configs[DEFAULT_NAME]
        return configs.values()

    def create_tests(self, simulator_if, elaborate_only, test_list=None):
        """
        Create all tests from this test case which may be several depending on the number of configurations
        """
        for config in self._get_configurations_to_run():
            test_list.add_test(
                IndependentSimTestCase(
                    test_case=self.name,
                    config=config,
                    simulator_if=simulator_if,
                    elaborate_only=elaborate_only))


_RE_VHDL_TEST_CASE = re.compile(r'(\s|\()+run\s*\(\s*"(?P<name>.*?)"\s*\)', re.IGNORECASE)
_RE_VERILOG_TEST_CASE = re.compile(r'`TEST_CASE\("(?P<name>.*?)"\)')


def _find_test_cases(code, file_name):
    """
    Finds all if run("something") strings in file
    """
    is_verilog = file_type_of(file_name) == 'verilog'
    if is_verilog:
        regexp = _RE_VERILOG_TEST_CASE
    else:
        code = remove_comments(code)
        regexp = _RE_VHDL_TEST_CASE

    test_cases = [match.group("name")
                  for match in regexp.finditer(code)]

    unique = set()
    not_unique = set()
    for test_case in test_cases:
        if test_case in unique and test_case not in not_unique:
            # @TODO line number information could be useful
            LOGGER.error('Duplicate test case "%s" in %s',
                         test_case, file_name)
            not_unique.add(test_case)
        unique.add(test_case)

    if not_unique:
        raise RuntimeError('Duplicate test cases')

    return test_cases


_RE_PRAGMA = re.compile(r'vunit_pragma\s+([a-zA-Z0-9_]+)', re.IGNORECASE)
_VALID_PRAGMAS = ["run_all_in_same_sim", "fail_on_warning"]


def _find_pragmas(code, file_name):
    """
    Return a list of all vunit pragmas parsed from the code

    @TODO only look inside comments
    """
    pragmas = []
    for match in _RE_PRAGMA.finditer(code):
        pragma = match.group(1)
        if pragma not in _VALID_PRAGMAS:
            LOGGER.warning("Invalid pragma '%s' in %s",
                           pragma,
                           file_name)
        pragmas.append(pragma)
    return pragmas
