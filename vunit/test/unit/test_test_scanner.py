# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-public-methods

"""
Tests the test scanner
"""


import unittest
from os.path import join, dirname, exists
from shutil import rmtree

from vunit.test_scanner import TestScanner, TestScannerError, tb_filter, dotjoin
from vunit.test_configuration import TestConfiguration, create_scope
from vunit.ostools import renew_path
from vunit.test.mock_2or3 import mock


class TestTestScanner(unittest.TestCase):
    """
    Tests the test scanner
    """

    def setUp(self):
        self.simulator_if = 'simulator_if'
        self.configuration = TestConfiguration()
        self.test_scanner = TestScanner(self.simulator_if, self.configuration)
        self.output_path = join(dirname(__file__), "test_scanner_out")
        renew_path(self.output_path)

    def tearDown(self):
        if exists(self.output_path):
            rmtree(self.output_path)

    def test_that_no_tests_are_created(self):
        project = ProjectStub()
        tests = self.test_scanner.from_project(project)
        self.assertEqual(len(tests), 0)

    def test_that_single_vhdl_test_is_created(self):
        project = ProjectStub()
        lib = project.add_library("lib")
        lib.add_entity("tb_entity")
        tests = self.test_scanner.from_project(project)
        self.assert_has_tests(tests, ["lib.tb_entity.all"])

    def test_that_single_verilog_test_is_created(self):
        project = ProjectStub()
        lib = project.add_library("lib")
        lib.add_module("tb_module")
        tests = self.test_scanner.from_project(project)
        self.assert_has_tests(tests, ["lib.tb_module.all"])

    def test_runner_cfg_creates_tests_from_entity(self):
        project = ProjectStub()
        lib = project.add_library("lib")

        lib.add_entity("entity_ok", generic_names=["runner_cfg"])
        lib.add_entity("entity_not_ok")

        tests = self.test_scanner.from_project(project, entity_filter=tb_filter)
        self.assert_has_tests(tests,
                              ["lib.entity_ok.all"])

    def test_runner_cfg_creates_tests_from_module(self):
        project = ProjectStub()
        lib = project.add_library("lib")

        lib.add_module("module_ok", generic_names=["runner_cfg"])
        lib.add_module("module_not_ok")

        tests = self.test_scanner.from_project(project, entity_filter=tb_filter)
        self.assert_has_tests(tests,
                              ["lib.module_ok.all"])

    def test_warning_on_missing_runner_cfg_when_matching_tb_pattern(self):
        project = ProjectStub()
        lib = project.add_library("lib")
        module = lib.add_module("tb_module_not_ok")

        with mock.patch("vunit.test_scanner.LOGGER", autospec=True) as logger:
            tests = self.test_scanner.from_project(project, entity_filter=tb_filter)
            logger.warning.assert_has_calls([
                mock.call('%s %s matches testbench name regex %s '
                          'but has no %s runner_cfg and will therefore not be run.\n'
                          'in file %s',
                          'Module',
                          'tb_module_not_ok',
                          '(tb_.*)|(.*_tb)',
                          'parameter',
                          module.file_name)])
        self.assert_has_tests(tests, [])

    def test_warning_on_runner_cfg_but_not_matching_tb_pattern(self):
        project = ProjectStub()
        lib = project.add_library("lib")
        entity = lib.add_entity("entity_ok_but_warning", generic_names=["runner_cfg"])

        with mock.patch("vunit.test_scanner.LOGGER", autospec=True) as logger:
            tests = self.test_scanner.from_project(project, entity_filter=tb_filter)
            logger.warning.assert_has_calls([
                mock.call('%s %s has runner_cfg %s but the file name and the %s name does not match regex %s\n'
                          'in file %s',
                          'Entity',
                          'entity_ok_but_warning',
                          'generic',
                          'entity',
                          '(tb_.*)|(.*_tb)',
                          entity.file_name)])
        self.assert_has_tests(tests, ["lib.entity_ok_but_warning.all"])

    def test_that_two_tests_are_created_from_two_architectures(self):
        project = ProjectStub()
        lib = project.add_library("lib")
        ent = lib.add_entity("tb_entity")
        ent.add_architecture("arch2")

        tests = self.test_scanner.from_project(project)
        self.assert_has_tests(tests,
                              ["lib.tb_entity.arch.all",
                               "lib.tb_entity.arch2.all"])

    def test_create_tests_with_runner_cfg_generic(self):
        project = ProjectStub()
        lib = project.add_library("lib")
        lib.add_entity("tb_entity",
                       generic_names=["runner_cfg"],
                       contents='''\
if run("Test_1")
--if run("Test_2")
if run("Test_3")
''')

        tests = self.test_scanner.from_project(project)
        self.assert_has_tests(tests,
                              ["lib.tb_entity.Test_1",
                               "lib.tb_entity.Test_3"])

    @mock.patch("vunit.test_scanner.LOGGER")
    def test_duplicate_tests_cause_error(self, mock_logger):
        project = ProjectStub()
        lib = project.add_library("lib")
        ent = lib.add_entity("tb_entity",
                             generic_names=["runner_cfg"],
                             contents='''\
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
        call0_args = error_calls[0][0]
        self.assertIn("Test_3", call0_args)
        self.assertIn(ent.file_name, call0_args)

        call1_args = error_calls[1][0]
        self.assertIn("Test_2", call1_args)
        self.assertIn(ent.file_name, call1_args)

    @mock.patch("vunit.test_scanner.LOGGER")
    def test_warning_on_configuration_of_non_existent_test(self, mock_logger):
        project = ProjectStub()
        lib = project.add_library("lib")
        lib.add_entity("tb_entity",
                       generic_names=["runner_cfg", "name"],
                       contents='if run("Test")')

        test_scope = create_scope("lib", "tb_entity", "Test")
        self.configuration.set_generic("name", "value",
                                       scope=test_scope)

        test_1_scope = create_scope("lib", "tb_entity", "No test 1")
        self.configuration.add_config(scope=test_1_scope,
                                      name="",
                                      generics=dict())

        test_2_scope = create_scope("lib", "tb_entity", "No test 2")
        self.configuration.set_generic("name", "value",
                                       scope=test_2_scope)

        tests = self.test_scanner.from_project(project)

        warning_calls = mock_logger.warning.call_args_list
        self.assertEqual(len(warning_calls), 2)
        call_args0 = warning_calls[0][0]
        call_args1 = warning_calls[1][0]
        self.assertIn(dotjoin(*test_1_scope), call_args0)
        self.assertIn(dotjoin(*test_2_scope), call_args1)
        self.assert_has_tests(tests,
                              ["lib.tb_entity.Test"])

    @mock.patch("vunit.test_scanner.LOGGER")
    def test_warning_on_configuration_of_individual_test_with_same_sim(self, mock_logger):
        project = ProjectStub()
        lib = project.add_library("lib")
        lib.add_entity("tb_entity",
                       generic_names=["runner_cfg"],
                       contents='''\
if run("Test 1")
if run("Test 2")
-- vunit_pragma run_all_in_same_sim
''')

        test_scope = create_scope("lib", "tb_entity", "Test 1")
        self.configuration.set_generic("name", "value", scope=test_scope)
        tests = self.test_scanner.from_project(project)

        warning_calls = mock_logger.warning.call_args_list
        self.assertEqual(len(warning_calls), 1)
        call_args = warning_calls[0][0]
        self.assertIn(1, call_args)
        self.assertIn("lib.tb_entity", call_args)
        self.assert_has_tests(tests,
                              [("lib.tb_entity", ("lib.tb_entity.Test 1", "lib.tb_entity.Test 2"))])

    def test_create_default_test_with_runner_cfg_generic(self):
        project = ProjectStub()
        lib = project.add_library("lib")
        lib.add_entity("tb_entity",
                       generic_names=["runner_cfg"])

        tests = self.test_scanner.from_project(project)
        self.assert_has_tests(tests,
                              ["lib.tb_entity.all"])

    def test_does_not_add_all_suffix_with_named_configurations(self):

        def helper(config_name, suffix):
            """
            Add config with name and check that the test has the given suffix
            """
            project = ProjectStub()
            lib = project.add_library("lib")
            lib.add_entity("tb_entity",
                           generic_names=["runner_cfg"])
            self.configuration = TestConfiguration()
            self.test_scanner = TestScanner(self.simulator_if, self.configuration)
            self.configuration.add_config(scope=create_scope("lib", "tb_entity"),
                                          name=config_name,
                                          generics=dict())
            tests = self.test_scanner.from_project(project)
            self.assert_has_tests(tests,
                                  ["lib.tb_entity" + suffix])
        helper("config", ".config")
        helper("", ".all")
        helper(None, ".all")

    def test_that_pragma_run_in_same_simulation_works(self):
        project = ProjectStub()
        lib = project.add_library("lib")
        lib.add_entity("tb_entity",
                       generic_names=["runner_cfg"],
                       contents='''\
-- vunit_pragma run_all_in_same_sim
if run("Test_1")
if run("Test_2")
--if run("Test_3")
''')

        tests = self.test_scanner.from_project(project)
        self.assert_has_tests(tests,
                              [("lib.tb_entity", ("lib.tb_entity.Test_1", "lib.tb_entity.Test_2"))])

    def test_adds_tb_path_generic(self):
        project = ProjectStub()
        lib = project.add_library("lib")
        lib.add_entity("tb_entity_with_tb_path",
                       generic_names=["tb_path"])

        lib.add_entity("tb_entity_without_tb_path")

        tests = self.test_scanner.from_project(project)

        with_path_generics = find_generics(tests, "lib.tb_entity_with_tb_path.all")
        without_path_generics = find_generics(tests, "lib.tb_entity_without_tb_path.all")
        self.assertEqual(with_path_generics["tb_path"], (out() + "/").replace("\\", "/"))
        self.assertNotIn("tb_path", without_path_generics)

    @mock.patch("vunit.test_scanner.LOGGER")
    def test_warning_on_non_overrriden_tb_path(self, mock_logger):
        project = ProjectStub()
        lib = project.add_library("lib")

        lib.add_entity("tb_entity",
                       generic_names=["tb_path"])

        tb_path_non_overriden_value = "foo"
        self.configuration.set_generic("tb_path", tb_path_non_overriden_value)
        tests = self.test_scanner.from_project(project)

        warning_calls = mock_logger.warning.call_args_list
        tb_path_value = (out() + "/").replace("\\", "/")
        self.assertEqual(len(warning_calls), 1)
        call_args = warning_calls[0][0]
        self.assertIn("lib.tb_entity", call_args)
        self.assertIn(tb_path_non_overriden_value, call_args)
        self.assertIn(tb_path_value, call_args)
        generics = find_generics(tests, "lib.tb_entity.all")
        self.assertEqual(generics["tb_path"], tb_path_value)

    @mock.patch("vunit.test_scanner.LOGGER")
    def test_warning_on_setting_missing_generic(self, mock_logger):
        project = ProjectStub()
        lib = project.add_library("lib")

        lib.add_entity("tb_entity",
                       generic_names=[""])
        self.configuration.set_generic("name123", "value123")
        self.test_scanner.from_project(project)
        warning_calls = mock_logger.warning.call_args_list
        self.assertEqual(len(warning_calls), 1)
        call_args = warning_calls[0][0]
        self.assertIn("lib", call_args)
        self.assertIn("tb_entity", call_args)
        self.assertIn("name123", call_args)
        self.assertIn("value123", call_args)

    def assert_has_tests(self, test_list, tests):
        """
        Asser that the test_list contains tests.
        A test can be either a string to represent a single test or a
        tuple to represent multiple tests within a test suite.
        """
        self.assertEqual(len(test_list), len(tests))
        for test1, test2 in zip(test_list, sorted(tests)):
            if isinstance(test2, tuple):
                name, test_cases = test2
                self.assertEqual(test1.name, name)
                self.assertEqual(test1.test_cases, list(test_cases))
            else:
                self.assertEqual(test1.name, test2)


class ProjectStub(object):
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


class LibraryStub(object):
    """
    A stub of the Library class
    """
    def __init__(self, name):
        self.name = name
        self._entities = []
        self._modules = []

    def get_entities(self):
        return self._entities

    def get_modules(self):
        return self._modules

    def add_entity(self,
                   name,
                   file_name=None,
                   architecture_names=None,
                   generic_names=None,
                   contents=""):
        """
        Add a stubbed entity
        """
        if file_name is None:
            file_name = out(name + ".vhd")

        if architecture_names is None:
            architecture_names = {"arch": file_name}

        if generic_names is None:
            generic_names = []

        entity = EntityStub(name,
                            self.name,
                            file_name,
                            architecture_names,
                            generic_names)
        entity.set_contents(contents)
        self._entities.append(entity)
        return entity

    def add_module(self,
                   name,
                   file_name=None,
                   generic_names=None,
                   contents=""):
        """
        Add a stubbed entity
        """
        if file_name is None:
            file_name = out(name + ".sv")

        module = ModuleStub(name,
                            self.name,
                            file_name,
                            generic_names if generic_names is not None else [])
        self._modules.append(module)
        module.set_contents(contents)
        return module


class ModuleStub(object):
    """
    A stub of a Module
    """
    def __init__(self, name, library_name, file_name, generic_names):
        self.name = name
        self.library_name = library_name
        self.file_name = file_name
        self.generic_names = generic_names

    def set_contents(self, contents):
        """
        Set contents of module file
        """
        with open(self.file_name, "w") as fwrite:
            fwrite.write(contents)

    @property
    def is_entity(self):
        return False


class EntityStub(object):
    """
    A stub of the Entity class
    """
    def __init__(self,  # pylint: disable=too-many-arguments
                 name, library_name, file_name,
                 architecture_names, generic_names):
        self.name = name
        self.library_name = library_name
        self.file_name = file_name
        self.architecture_names = architecture_names
        self.generic_names = generic_names

    @property
    def is_entity(self):
        return True

    def set_contents(self, contents, architecture_name=None):
        """
        Set contents of architecture file
        """
        if architecture_name is None:
            assert len(self.architecture_names) == 1
            architecture_name = list(self.architecture_names.keys())[0]

        file_name = self.architecture_names[architecture_name]

        with open(file_name, "w") as fwrite:
            fwrite.write(contents)

    def add_architecture(self, name, file_name=None, contents=""):
        """
        Add architecture
        """
        if file_name is None:
            file_name = out(name + "_arch.vhd")
        self.architecture_names[name] = file_name
        arch = ArchitectureStub(self, name)
        arch.set_contents(contents)


class ArchitectureStub(object):
    """
    Stub of architecture
    """
    def __init__(self, entity, name):
        self._entity = entity
        self._name = name

    def set_contents(self, contents):
        self._entity.set_contents(contents, self._name)


def out(*args):
    return join(dirname(__file__), "test_scanner_out", *args)


def find_generics(tests, name):
    """
    Find generic values of test
    """
    for test in tests:
        if test.name == name:
            return test._test_case._test_bench._sim_config.generics  # pylint: disable=protected-access
    raise KeyError(name)
