# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Tests the test scanner
"""


import unittest
from os.path import join, dirname, exists
from shutil import rmtree
from os import makedirs

from vunit.test_scanner import TestScanner, TestScannerError, tb_filter
from vunit.test_configuration import TestConfiguration

from vunit.test.mock_2or3 import mock


class TestTestScanner(unittest.TestCase):
    """
    Tests the test scanner
    """

    def setUp(self):
        self.simulator_if = 'simulator_if'
        self.test_scanner = TestScanner(self.simulator_if, TestConfiguration())

        self.output_path = join(dirname(__file__), "test_scanner_out")

        if exists(self.output_path):
            rmtree(self.output_path, ignore_errors=True)
        makedirs(self.output_path)

    def tearDown(self):
        if exists(self.output_path):
            rmtree(self.output_path)

    @staticmethod
    def write_file(name, contents):
        with open(name, "w") as fwrite:
            fwrite.write(contents)

    def test_that_no_tests_are_created(self):
        project = ProjectStub()
        tests = self.test_scanner.from_project(project)
        self.assertEqual(len(tests), 0)

    def test_that_single_test_is_created(self):
        project = ProjectStub()
        work = project.add_library("work")
        work.add_entity("tb_entity", out("tb_entity.vhd"),
                        {"arch": out("arch.vhd")})
        self.write_file(out("arch.vhd"), "")
        tests = self.test_scanner.from_project(project)
        self.assert_has_tests(tests,
                              ["work.tb_entity"])

    def test_that_tests_are_filtered(self):
        project = ProjectStub()
        work = project.add_library("work")

        work.add_entity("tb_entity", out("tb_entity.vhd"),
                        {"arch": out("arch1.vhd")})
        self.write_file(out("arch1.vhd"), "")

        work.add_entity("tb_entity2", out("path", "tb_entity2.vhd"),
                        {"arch": out("arch2.vhd")})
        self.write_file(out("arch2.vhd"), "")

        work.add_entity("entity2", out("entity2.vhd"),
                        {"arch": ""})

        work.add_entity("entity_tb", out("entity_tb.vhd"),
                        {"arch": out("entity_tb.vhd")})
        self.write_file(out("entity_tb.vhd"), "")

        tests = self.test_scanner.from_project(project, entity_filter=tb_filter)
        self.assert_has_tests(tests,
                              ["work.tb_entity",
                               "work.tb_entity2",
                               "work.entity_tb"])

    def test_that_two_tests_are_created(self):
        project = ProjectStub()
        work = project.add_library("work")
        work.add_entity("tb_entity", out("tb_entity.vhd"),
                        {"arch1": out("arch1.vhd"),
                         "arch2": out("arch2.vhd")})
        self.write_file(out("arch1.vhd"), "")
        self.write_file(out("arch2.vhd"), "")

        tests = self.test_scanner.from_project(project)
        self.assert_has_tests(tests,
                              ["work.tb_entity.arch1",
                               "work.tb_entity.arch2"])

    def test_create_tests_with_runner_cfg_generic(self):
        project = ProjectStub()
        work = project.add_library("work")
        work.add_entity("tb_entity", out("tb_entity.vhd"),
                        {"arch": out("entity_arch.vhd")},
                        ["runner_cfg"])

        self.write_file(out("entity_arch.vhd"), '''\
if run("Test_1")
--if run("Test_2")
if run("Test_3")
''')

        tests = self.test_scanner.from_project(project)
        self.assert_has_tests(tests,
                              ["work.tb_entity.Test_1",
                               "work.tb_entity.Test_3"])

    @mock.patch("vunit.test_scanner.LOGGER")
    def test_duplicate_tests_cause_error(self, mock_logger):
        project = ProjectStub()
        work = project.add_library("work")
        work.add_entity("tb_entity", out("tb_entity.vhd"),
                        {"arch": out("entity_arch.vhd")},
                        ["runner_cfg"])

        self.write_file(out("entity_arch.vhd"), '''\
if run("Test_1")
--if run("Test_1")
if run("Test_3")
if run("Test_2")
if run("Test_3")
if run("Test_3")
if run("Test_2")
''')

        self.assertRaises(TestScannerError, self.test_scanner.from_project, project)

        error_calls = mock_logger.error.call_args_list
        self.assertEqual(len(error_calls), 2)
        self.assertTrue("Test_3" in error_calls[0][0][1])
        self.assertTrue(out("entity_arch.vhd") in error_calls[0][0][2])

        self.assertTrue("Test_2" in str(error_calls[1][0][1]))
        self.assertTrue(out("entity_arch.vhd") in error_calls[1][0][2])

    def test_create_default_test_with_runner_cfg_generic(self):
        project = ProjectStub()
        work = project.add_library("work")
        work.add_entity("tb_entity", out("tb_entity.vhd"),
                        {"arch": out("entity_arch.vhd")},
                        ["runner_cfg"])

        self.write_file(out("entity_arch.vhd"), '')

        tests = self.test_scanner.from_project(project)
        self.assert_has_tests(tests,
                              ["work.tb_entity"])

    def test_that_pragma_run_in_same_simulation_works(self):
        project = ProjectStub()
        work = project.add_library("work")
        work.add_entity("tb_entity", out("tb_entity.vhd"),
                        {"arch": out("entity_arch.vhd")},
                        ["runner_cfg"])

        self.write_file(out("entity_arch.vhd"), '''\
-- vunit_pragma run_all_in_same_sim
if run("Test_1")
if run("Test_2")
--if run("Test_3")
''')

        tests = self.test_scanner.from_project(project)
        self.assert_has_tests(tests,
                              [("work.tb_entity", ("work.tb_entity.Test_1", "work.tb_entity.Test_2"))])

    def assert_has_tests(self, test_list, tests):
        self.assertEqual(len(test_list), len(tests))
        for test1, test2 in zip(test_list, tests):
            if isinstance(test2, tuple):
                name, test_cases = test2
                self.assertEqual(test1.name, name)
                self.assertEqual(test1.test_cases, list(test_cases))
            else:
                self.assertEqual(test1.name, test2)


class ProjectStub:
    """
    A stub of the Project class
    """
    def __init__(self):
        self._libraries = []

    def add_library(self, library_name):
        """
        Add a library stub with library_name to the stubbed project
        """
        library = LibraryStub(library_name)
        self._libraries.append(library)
        return library

    def get_libraries(self):
        return self._libraries


class LibraryStub:
    """
    A stub of the Library class
    """
    def __init__(self, name):
        self.name = name
        self._entities = []

    def get_entities(self):
        return self._entities

    def add_entity(self,
                   name,
                   file_name,
                   architecture_names,
                   generic_names=None):
        generic_names = generic_names if generic_names is not None else []
        self._entities.append(
            EntityStub(name,
                       self.name,
                       file_name,
                       architecture_names,
                       generic_names))


class EntityStub:
    """
    A stub of the Entity class
    """
    def __init__(self, name, library_name, file_name,
                 architecture_names, generic_names):
        self.name = name
        self.library_name = library_name
        self.file_name = file_name
        self.architecture_names = architecture_names
        self.generic_names = generic_names


def out(*args):
    return join(dirname(__file__), "test_scanner_out", *args)
