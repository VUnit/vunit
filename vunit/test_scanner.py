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
from vunit.test_configuration import dotjoin


class TestScanner:
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

    def _create_tests_from_architecture(self, test_list, entity, architecture_name):
        """
        Derive test cases from an architecture if there is one generic called
        runner_cfg
        """
        file_name = entity.architecture_names[architecture_name]
        code = ostools.read_file(file_name)
        pragmas = self.find_pragmas(code, file_name)
        should_run_in_same_sim = "run_all_in_same_sim" in pragmas
        configurations = self._cfg.get_configurations(entity, architecture_name)

        def create_test_bench(config):
            """
            Helper function to create a test bench given a config
            """
            generics = config.generics.copy()

            if "tb_path" in entity.generic_names:
                new_value = '%s/' % dirname(file_name).replace("\\", "/")
                if "tb_path" in generics:
                    LOGGER.warning(("The 'tb_path' generic from a configuration of %s of was overwritten, " %
                                    dotjoin(entity.library_name, entity.name, config.name)) +
                                   ("old value was '%s', new value is '%s'" %
                                    (generics["tb_path"], new_value)))

                generics["tb_path"] = new_value

            return TestBench(simulator_if=self._simulator_if,
                             library_name=entity.library_name,
                             architecture_name=architecture_name,
                             entity_name=entity.name,
                             fail_on_warning="fail_on_warning" in pragmas,
                             has_output_path="output_path" in entity.generic_names,
                             generics=generics,
                             pli=config.pli,
                             elaborate_only=self._elaborate_only)

        if "runner_cfg" in entity.generic_names:
            run_strings = self.find_run_strings(code, file_name)
            if len(run_strings) == 0:
                run_strings = [""]

            if should_run_in_same_sim:
                for config in configurations:
                    test_bench = create_test_bench(config)
                    post_check = None if self._elaborate_only else config.post_check
                    test_list.add_suite(
                        SameSimTestSuite(name=config.name,
                                         test_cases=run_strings,
                                         test_bench=test_bench,
                                         post_check_function=post_check))
            else:
                for run_string in run_strings:
                    for config in configurations:
                        test_bench = create_test_bench(config)
                        post_check = None if self._elaborate_only else config.post_check
                        test_list.add_test(
                            IndependentSimTestCase(
                                name=dotjoin(config.name, run_string),
                                test_case=run_string,
                                test_bench=test_bench,
                                has_runner_cfg=True,
                                post_check_function=post_check))

        else:
            for config in configurations:
                test_bench = create_test_bench(config)
                post_check = None if self._elaborate_only else config.post_check
                test_list.add_test(
                    IndependentSimTestCase(
                        name=config.name,
                        test_case=None,
                        test_bench=test_bench,
                        has_runner_cfg=False,
                        post_check_function=post_check))

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
