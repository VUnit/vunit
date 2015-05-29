# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Functionality to automatically create test suites from a project
"""


import logging
LOGGER = logging.getLogger(__name__)

from os.path import basename, dirname, splitext
import re

from vunit.test_list import TestList
from vunit.test_bench import TestBench
import vunit.ostools as ostools
from vunit.vhdl_parser import remove_comments
from vunit.test_suites import IndependentSimTestCase, SameSimTestSuite
from vunit.test_configuration import create_scope


class TestScanner(object):
    """
    Scans a project for test benches
    """

    def __init__(self, simulator_if, configuration, elaborate_only=False):
        self._simulator_if = simulator_if
        self._cfg = configuration
        self._elaborate_only = elaborate_only

    def from_project(self, project, entity_filter=None):
        """
        Return a TestList with all test found within the project
        entity_filter -- An optional filter function of entity objects
        """
        test_list = TestList()
        for library in project.get_libraries():
            for entity in library.get_entities():
                if entity_filter is None or entity_filter(entity):
                    self._create_tests_from_entity(test_list, entity)
        return test_list

    def _create_tests_from_entity(self, test_list, entity):
        """
        Derive test cases from an entity if there is one generic called
        runner_cfg
        """
        for architecture_name in sorted(entity.architecture_names):
            self._create_tests_from_architecture(test_list, entity, architecture_name)

    def _create_test_bench(self, entity, architecture_name, config, fail_on_warning):
        """
        Helper function to create a test bench given a config
        """
        def add_tb_path_generic(generics):
            """
            Add tb_path generic pointing to directory name of test bench
            """
            name = "tb_path"
            file_name = entity.architecture_names[architecture_name]
            new_value = '%s/' % dirname(file_name).replace("\\", "/")
            if name in generics and name in entity.generic_names:
                LOGGER.warning(("The '%s' generic from a configuration of %s of was overwritten, "
                                "old value was '%s', new value is '%s'"),
                               name,
                               create_test_name(entity, architecture_name, config.name),
                               generics["tb_path"],
                               new_value)

            generics["tb_path"] = new_value

        generics = config.generics.copy()
        add_tb_path_generic(generics)
        generics = prune_generics(generics, entity.generic_names)

        return TestBench(simulator_if=self._simulator_if,
                         library_name=entity.library_name,
                         architecture_name=architecture_name,
                         entity_name=entity.name,
                         fail_on_warning=fail_on_warning,
                         has_output_path="output_path" in entity.generic_names,
                         generics=generics,
                         pli=config.pli,
                         elaborate_only=self._elaborate_only)

    def _parse(self, entity, architecture_name):
        """
        Parse file for run strings and pragmas
        """
        file_name = entity.architecture_names[architecture_name]
        code = ostools.read_file(file_name)
        pragmas = self.find_pragmas(code, file_name)

        # @TODO use presence of runner_cfg as tb_filter instead of tb_*
        has_runner_cfg = "runner_cfg" in entity.generic_names

        if has_runner_cfg:
            run_strings = self.find_run_strings(code, file_name)
        else:
            run_strings = []

        return pragmas, run_strings

    def _create_tests_from_architecture(self, test_list, entity, architecture_name):
        """
        Derive test cases from an architecture if there is one generic called
        runner_cfg
        """
        has_runner_cfg = "runner_cfg" in entity.generic_names
        pragmas, run_strings = self._parse(entity, architecture_name)
        should_run_in_same_sim = "run_all_in_same_sim" in pragmas

        def create_test_bench(config):
            """
            Helper function to create a test bench
            """
            fail_on_warning = "fail_on_warning" in pragmas
            return self._create_test_bench(entity, architecture_name, config, fail_on_warning)

        def create_post_check(config):
            """
            Helper function to create a post_check unless elaborate only
            """
            if self._elaborate_only:
                return None
            return config.post_check

        def create_name(config, run_string=None):
            """
            Helper function to create a test name
            """
            return create_test_name(entity, architecture_name, config.name, run_string)

        self._warn_on_individual_configuration(create_scope(entity.library_name, entity.name),
                                               run_strings,
                                               should_run_in_same_sim)

        if len(run_strings) == 0 or not has_runner_cfg:
            scope = create_scope(entity.library_name, entity.name)
            configurations = self._cfg.get_configurations(scope)
            for config in configurations:
                test_list.add_test(
                    IndependentSimTestCase(
                        name=create_name(config),
                        test_case=None,
                        test_bench=create_test_bench(config),
                        has_runner_cfg=has_runner_cfg,
                        post_check_function=create_post_check(config)))
        elif should_run_in_same_sim:
            scope = create_scope(entity.library_name, entity.name)
            configurations = self._cfg.get_configurations(scope)
            for config in configurations:
                test_list.add_suite(
                    SameSimTestSuite(name=create_name(config),
                                     test_cases=run_strings,
                                     test_bench=create_test_bench(config),
                                     post_check_function=create_post_check(config)))
        else:
            for run_string in run_strings:
                scope = create_scope(entity.library_name, entity.name, run_string)
                configurations = self._cfg.get_configurations(scope)
                for config in configurations:
                    test_list.add_test(
                        IndependentSimTestCase(
                            name=create_name(config, run_string),
                            test_case=run_string,
                            test_bench=create_test_bench(config),
                            has_runner_cfg=has_runner_cfg,
                            post_check_function=create_post_check(config)))

    def _warn_on_individual_configuration(self, scope, run_strings, should_run_in_same_sim):
        """
        Warn on individual test configurations
        """
        more_specific = self._cfg.more_specific_configurations(scope)
        self._warn_on_non_existent(more_specific, run_strings)
        if should_run_in_same_sim and len(more_specific) != 0:
            LOGGER.warning("Found %i individual test configurations within \"%s\""
                           " which is not possible with run_all_in_same_sim",
                           len(more_specific),
                           dotjoin(*scope))

    @staticmethod
    def _warn_on_non_existent(more_specific, run_strings):
        """
        Warn on configuration of non existent test
        @TODO since we cannot raise KeyError on .test() in ui
        """
        for specific_scope in sorted(more_specific):
            if not specific_scope[-1] in run_strings:
                LOGGER.warning("Found configuration of non-existent test \"%s\"",
                               dotjoin(*specific_scope))

    _valid_run_string_fmt = r'[A-Za-z0-9_\-\. ]+'
    _re_valid_run_string = re.compile(_valid_run_string_fmt + "$")
    _re_run_string = re.compile(r'\s+run\("(.*?)"\)', re.IGNORECASE)

    def find_run_strings(self, code, file_name):
        """
        Finds all if run("something") strings in file
        """
        code = remove_comments(code)

        run_strings = [match.group(1)
                       for match in self._re_run_string.finditer(code)]

        unique = set()
        not_unique = set()
        for run_string in run_strings:
            if run_string in unique and run_string not in not_unique:
                # @TODO line number information could be useful
                LOGGER.error('Duplicate test case "%s" in %s',
                             run_string, file_name)
                not_unique.add(run_string)
            unique.add(run_string)

        if len(not_unique) > 0:
            raise TestScannerError

        for run_string in run_strings:
            if self._re_valid_run_string.match(run_string) is None:
                LOGGER.warning('Test name "%s" does not match %s in %s',
                               run_string, self._valid_run_string_fmt, file_name)

        return run_strings

    _re_pragma = re.compile(r'vunit_pragma\s+([a-zA-Z0-9_]+)', re.IGNORECASE)
    _valid_pragmas = ["run_all_in_same_sim", "fail_on_warning"]

    def find_pragmas(self, code, file_name):
        """
        Return a list of all vunit pragmas parsed from the code
        """
        pragmas = []
        for match in self._re_pragma.finditer(code):
            pragma = match.group(1)
            if pragma not in self._valid_pragmas:
                LOGGER.warning("Invalid pragma '%s' in %s",
                               pragma,
                               file_name)
            pragmas.append(pragma)
        return pragmas


def tb_filter(entity):
    """ Filter entities with file name tb_* and entity_name tb_* """
    file_ok = basename(entity.file_name).startswith("tb_") or splitext(basename(entity.file_name))[0].endswith("_tb")
    entity_ok = entity.name.startswith("tb_") or entity.name.endswith("_tb")

    if file_ok and entity_ok:
        return True
    return False


class TestScannerError(Exception):
    pass


def dotjoin(*args):
    """ string arguments joined by '.' unless empty string or None"""
    return ".".join(arg for arg in args if arg not in ("", None))


def prune_generics(generics, generic_names):
    """
    Keep only generics with name in generic_names
    """
    generics = generics.copy()
    for gname in list(generics.keys()):
        if gname not in generic_names:
            del generics[gname]
    return generics


def create_test_name(entity, architecture_name, config_name, test_name=None):
    if len(entity.architecture_names) > 1:
        return dotjoin(entity.library_name, entity.name, architecture_name, config_name, test_name)
    else:
        return dotjoin(entity.library_name, entity.name, config_name, test_name)
