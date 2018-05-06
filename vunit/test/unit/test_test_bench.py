# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-public-methods

"""
Tests the test test_bench module
"""


import unittest
from os.path import join

from vunit.test_bench import TestBench
from vunit.ostools import write_file
from vunit.test.mock_2or3 import mock
from vunit.test.common import with_tempdir


class TestTestBench(unittest.TestCase):
    """
    Tests the test bench
    """

    @with_tempdir
    def test_that_single_vhdl_test_is_created(self, tempdir):
        design_unit = Entity('tb_entity', file_name=join(tempdir, "file.vhd"))
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.all"])

    @staticmethod
    @with_tempdir
    def test_no_architecture_at_creation(tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"),
                             no_arch=True)
        TestBench(design_unit)

    @with_tempdir
    def test_no_architecture_gives_runtime_error(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"),
                             no_arch=True)
        test_bench = TestBench(design_unit)
        try:
            self.create_tests(test_bench)
        except RuntimeError as exc:
            self.assertEqual(str(exc),
                             "Test bench 'tb_entity' has no architecture.")
        else:
            assert False, "RuntimeError not raised"

    @with_tempdir
    def test_that_single_verilog_test_is_created(self, tempdir):
        design_unit = Module('tb_module', file_name=join(tempdir, "file.v"))
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_module.all"])

    @with_tempdir
    def test_create_default_test(self, tempdir):
        design_unit = Entity('tb_entity', file_name=join(tempdir, "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.all"])

    @with_tempdir
    def test_multiple_architectures_are_not_allowed_for_test_bench(self, tempdir):
        design_unit = Entity('tb_entity', file_name=join(tempdir, "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        design_unit.add_architecture('arch2', file_name=join(tempdir, "arch2.vhd"))
        try:
            TestBench(design_unit)
        except RuntimeError as exc:
            self.assertEqual(str(exc),
                             "Test bench not allowed to have multiple architectures. "
                             "Entity tb_entity has arch:file.vhd, arch2:arch2.vhd")
        else:
            assert False, "RuntimeError not raised"

    @with_tempdir
    def test_creates_tests_vhdl(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"),
                             contents='''\
if run("Test 1")
--if run("Test 2")
if run("Test 3")
if run("Test 4")
if run("Test 5") or run("Test 6")
if run  ("Test 7")
if run( "Test 8"  )
if ((run("Test 9")))
if my_protected_variable.run("Test 10")
''')
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests,
                              ["lib.tb_entity.Test 1",
                               "lib.tb_entity.Test 3",
                               "lib.tb_entity.Test 4",
                               "lib.tb_entity.Test 5",
                               "lib.tb_entity.Test 6",
                               "lib.tb_entity.Test 7",
                               "lib.tb_entity.Test 8",
                               "lib.tb_entity.Test 9"])

    @with_tempdir
    def test_creates_tests_verilog(self, tempdir):
        design_unit = Module('tb_module',
                             file_name=join(tempdir, "file.v"),
                             contents='''\
`TEST_CASE("Test 1")
`TEST_CASE  ("Test 2")
`TEST_CASE( "Test 3"  )
// `TEST_CASE("Test 4")
/*
 `TEST_CASE("Test 5")
*/
/* `TEST_CASE("Test 6") */
`TEST_CASE("Test 7")
/* comment */
`TEST_CASE("Test 8")
/* comment */
''')
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests,
                              ["lib.tb_module.Test 1",
                               "lib.tb_module.Test 2",
                               "lib.tb_module.Test 3",
                               "lib.tb_module.Test 7",
                               "lib.tb_module.Test 8"])

    @with_tempdir
    @mock.patch("vunit.test_bench.LOGGER")
    def test_duplicate_tests_cause_error(self, mock_logger, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"),
                             contents='''\
if run("Test_1")
--if run("Test_1")
if run("Test_3")
if run("Test_2")
if run("Test_3")
if run("Test_3")
if run("Test_2")
''')
        design_unit.generic_names = ["runner_cfg"]
        self.assertRaises(RuntimeError, TestBench, design_unit)

        error_calls = mock_logger.error.call_args_list
        self.assertEqual(len(error_calls), 2)
        call0_args = error_calls[0][0]
        self.assertIn("Test_3", call0_args)
        self.assertIn(design_unit.file_name, call0_args)

        call1_args = error_calls[1][0]
        self.assertIn("Test_2", call1_args)
        self.assertIn(design_unit.file_name, call1_args)

    @with_tempdir
    def test_keyerror_on_non_existent_test(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"),
                             contents='if run("Test")')
        design_unit.generic_names = ["runner_cfg", "name"]
        test_bench = TestBench(design_unit)
        self.assertRaises(KeyError, test_bench.get_test_case, "Non existent test")

    @with_tempdir
    def test_creates_tests_when_adding_architecture_late(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"),
                             no_arch=True)
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)

        design_unit.add_architecture("arch",
                                     file_name=join(tempdir, "arch.vhd"),
                                     contents='''\
if run("Test_1")
--if run("Test_2")
if run("Test_3")
''')
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests,
                              ["lib.tb_entity.Test_1",
                               "lib.tb_entity.Test_3"])

    @with_tempdir
    def test_scan_tests_from_file(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)

        file_name = join(tempdir, "file.vhd")
        write_file(file_name, '''\
if run("Test_1")
if run("Test_2")
''')
        test_bench.scan_tests_from_file(file_name)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests,
                              ["lib.tb_entity.Test_1",
                               "lib.tb_entity.Test_2"])

    @with_tempdir
    def test_scan_tests_from_missing_file(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)

        try:
            test_bench.scan_tests_from_file("missing.vhd")
        except ValueError as exc:
            self.assertEqual(str(exc),
                             "File 'missing.vhd' does not exist")
        else:
            assert False, "ValueError not raised"

    @with_tempdir
    def test_does_not_add_all_suffix_with_named_configurations(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)

        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.all"])

        test_bench.add_config(name="config", generics=dict())
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.config"])

    @with_tempdir
    def test_that_pragma_run_in_same_simulation_works(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"),
                             contents='''\
-- vunit_pragma run_all_in_same_sim
if run("Test_1")
if run("Test_2")
--if run("Test_3")
''')
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests,
                              [("lib.tb_entity", ("lib.tb_entity.Test_1", "lib.tb_entity.Test_2"))])

    @with_tempdir
    def test_add_config(self, tempdir):
        design_unit = Entity('tb_entity', file_name=join(tempdir, "file.vhd"))
        design_unit.generic_names = ["runner_cfg", "value", "global_value"]
        test_bench = TestBench(design_unit)

        test_bench.set_generic("global_value", "global value")

        test_bench.add_config(name="value=1",
                              generics=dict(value=1,
                                            global_value="local value"))
        test_bench.add_config(name="value=2",
                              generics=dict(value=2))

        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.value=1",
                                      "lib.tb_entity.value=2"])

        self.assertEqual(get_config_of(tests, "lib.tb_entity.value=1").generics,
                         {"value": 1, "global_value": "local value"})
        self.assertEqual(get_config_of(tests, "lib.tb_entity.value=2").generics,
                         {"value": 2, "global_value": "global value"})

    @with_tempdir
    def test_test_case_add_config(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"),
                             contents='''
if run("test 1")
if run("test 2")
        ''')
        design_unit.generic_names = ["runner_cfg", "value", "global_value"]
        test_bench = TestBench(design_unit)
        test_bench.set_generic("global_value", "global value")
        test_bench.set_sim_option("disable_ieee_warnings", True)

        test_case = test_bench.get_test_case('test 2')
        test_case.add_config(name="c1",
                             generics=dict(value=1,
                                           global_value="local value"))
        test_case.add_config(name="c2",
                             generics=dict(value=2),
                             sim_options=dict(disable_ieee_warnings=False))

        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.test 1",
                                      "lib.tb_entity.c1.test 2",
                                      "lib.tb_entity.c2.test 2"])

        config_test1 = get_config_of(tests, "lib.tb_entity.test 1")
        config_c1_test2 = get_config_of(tests, "lib.tb_entity.c1.test 2")
        config_c2_test2 = get_config_of(tests, "lib.tb_entity.c2.test 2")
        self.assertEqual(config_test1.generics,
                         {"global_value": "global value"})
        self.assertEqual(config_c1_test2.generics,
                         {"value": 1, "global_value": "local value"})
        self.assertEqual(config_c2_test2.generics,
                         {"value": 2, "global_value": "global value"})

    @with_tempdir
    def test_runtime_error_on_configuration_of_individual_test_with_same_sim(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"),
                             contents='''\
if run("Test 1")
if run("Test 2")
-- vunit_pragma run_all_in_same_sim
''')
        design_unit.generic_names = ["runner_cfg", "name"]
        test_bench = TestBench(design_unit)
        test_case = test_bench.get_test_case("Test 1")
        self.assertRaises(RuntimeError, test_case.set_generic, "name", "value")
        self.assertRaises(RuntimeError, test_case.set_sim_option, "name", "value")
        self.assertRaises(RuntimeError, test_case.add_config, "name")

    @with_tempdir
    def test_run_all_in_same_sim_can_be_configured(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"),
                             contents='''\
if run("Test 1")
if run("Test 2")
-- vunit_pragma run_all_in_same_sim
''')
        design_unit.generic_names = ["runner_cfg", "name"]
        test_bench = TestBench(design_unit)
        test_bench.set_generic("name", "value")
        test_bench.add_config("cfg")
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests,
                              [("lib.tb_entity.cfg",
                                ("lib.tb_entity.cfg.Test 1", "lib.tb_entity.cfg.Test 2"))])
        self.assertEqual(get_config_of(tests, "lib.tb_entity.cfg").generics,
                         {"name": "value"})

    @with_tempdir
    def test_fail_on_unknown_sim_option(self, tempdir):
        design_unit = Entity('tb_entity',
                             file_name=join(tempdir, "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)
        self.assertRaises(ValueError, test_bench.set_sim_option, "unknown", "value")

    def assert_has_tests(self, test_list, tests):
        """
        Asser that the test_list contains tests.
        A test can be either a string to represent a single test or a
        tuple to represent multiple tests within a test suite.
        """
        self.assertEqual(len(test_list), len(tests))
        for test1, test2 in zip(test_list, tests):
            if isinstance(test2, tuple):
                name, test_cases = test2
                self.assertEqual(test1.name, name)
                self.assertEqual(test1.test_cases, list(test_cases))
            else:
                self.assertEqual(test1.name, test2)

    @staticmethod
    def create_tests(test_bench):
        """
        Helper method to reduce boiler plate
        """
        return test_bench.create_tests("simulator_if", elaborate_only=False)


def get_config_of(tests, test_name):
    """
    Find generic values of test
    """
    for test in tests:
        if test.name == test_name:
            try:
                return test._test_case._run._config  # pylint: disable=protected-access
            except AttributeError:
                return test._run._config  # pylint: disable=protected-access
    raise KeyError(test_name)


class Module(object):
    """
    Mock Module
    """
    def __init__(self, name, file_name, contents=''):
        self.name = name
        self.library_name = "lib"
        self.is_entity = False
        self.is_module = True
        self.generic_names = []
        self.file_name = file_name
        write_file(file_name, contents)


class Entity(object):  # pylint: disable=too-many-instance-attributes
    """
    Mock Entity
    """
    def __init__(self, name, file_name, contents='', no_arch=False):
        self.name = name
        self.library_name = "lib"
        self.is_entity = True
        self.is_module = False
        self.architecture_names = {}

        if not no_arch:
            self.architecture_names = {"arch": file_name}

        self.generic_names = []
        self.file_name = file_name
        write_file(file_name, contents)
        self._add_architecture_callback = None

    def set_add_architecture_callback(self, callback):
        """
        Set callback to be called when an architecture is added
        """
        assert self._add_architecture_callback is None
        self._add_architecture_callback = callback

    def add_architecture(self, name, file_name, contents=""):
        """
        Add architecture to this entity
        """
        self.architecture_names[name] = file_name
        write_file(file_name, contents)

        if self._add_architecture_callback is not None:
            self._add_architecture_callback()
