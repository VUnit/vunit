# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-public-methods, too-many-lines

"""
Tests the test test_bench module
"""


import unittest
from pathlib import Path
from unittest import mock
from tests.common import with_tempdir, get_vhdl_test_bench
from vunit.test.bench import (
    TestBench,
    _remove_verilog_comments,
    _find_tests,
    _get_line_offsets,
    _lookup_lineno,
    _find_attributes,
    _find_tests_and_attributes,
    Test,
    FileLocation,
    Attribute,
    LegacyAttribute,
)
from vunit.configuration import AttributeException
from vunit.ostools import write_file


class TestTestBench(unittest.TestCase):
    """
    Tests the test bench
    """

    @with_tempdir
    def test_that_single_vhdl_test_is_created(self, tempdir):
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"))
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.all"])

    @staticmethod
    @with_tempdir
    def test_no_architecture_at_creation(tempdir):
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"), no_arch=True)
        TestBench(design_unit)

    @with_tempdir
    def test_no_architecture_gives_runtime_error(self, tempdir):
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"), no_arch=True)
        test_bench = TestBench(design_unit)
        try:
            self.create_tests(test_bench)
        except RuntimeError as exc:
            self.assertEqual(str(exc), "Test bench 'tb_entity' has no architecture.")
        else:
            assert False, "RuntimeError not raised"

    @with_tempdir
    def test_that_single_verilog_test_is_created(self, tempdir):
        design_unit = Module("tb_module", file_name=str(Path(tempdir) / "file.v"))
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_module.all"])

    @with_tempdir
    def test_create_default_test(self, tempdir):
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.all"])

    @with_tempdir
    def test_multiple_architectures_are_not_allowed_for_test_bench(self, tempdir):
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        design_unit.add_architecture("arch2", file_name=str(Path(tempdir) / "arch2.vhd"))
        try:
            TestBench(design_unit)
        except RuntimeError as exc:
            self.assertEqual(
                str(exc),
                "Test bench not allowed to have multiple architectures. "
                "Entity tb_entity has arch:file.vhd, arch2:arch2.vhd",
            )
        else:
            assert False, "RuntimeError not raised"

    @with_tempdir
    def test_creates_tests_vhdl(self, tempdir):
        design_unit = Entity(
            "tb_entity",
            file_name=str(Path(tempdir) / "file.vhd"),
            contents="""\
if run("Test 1")
--if run("Test 2")
if run("Test 3")
if run("Test 4")
if run("Test 5") or run("Test 6")
if run  ("Test 7")
if run( "Test 8"  )
if ((run("Test 9")))
if my_protected_variable.run("Test 10")
""",
        )
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(
            tests,
            [
                "lib.tb_entity.Test 1",
                "lib.tb_entity.Test 3",
                "lib.tb_entity.Test 4",
                "lib.tb_entity.Test 5",
                "lib.tb_entity.Test 6",
                "lib.tb_entity.Test 7",
                "lib.tb_entity.Test 8",
                "lib.tb_entity.Test 9",
            ],
        )

    @with_tempdir
    def test_creates_tests_verilog(self, tempdir):
        design_unit = Module(
            "tb_module",
            file_name=str(Path(tempdir) / "file.v"),
            contents="""\
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
""",
        )
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(
            tests,
            [
                "lib.tb_module.Test 1",
                "lib.tb_module.Test 2",
                "lib.tb_module.Test 3",
                "lib.tb_module.Test 7",
                "lib.tb_module.Test 8",
            ],
        )

    @with_tempdir
    def test_keyerror_on_non_existent_test(self, tempdir):
        design_unit = Entity(
            "tb_entity",
            file_name=str(Path(tempdir) / "file.vhd"),
            contents='if run("Test")',
        )
        design_unit.generic_names = ["runner_cfg", "name"]
        test_bench = TestBench(design_unit)
        self.assertRaises(KeyError, test_bench.get_test_case, "Non existent test")

    @with_tempdir
    def test_creates_tests_when_adding_architecture_late(self, tempdir):
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"), no_arch=True)
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)

        design_unit.add_architecture(
            "arch",
            file_name=str(Path(tempdir) / "file.vhd"),
            contents="""\
if run("Test_1")
--if run("Test_2")
if run("Test_3")
""",
        )
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.Test_1", "lib.tb_entity.Test_3"])

    @with_tempdir
    def test_scan_tests_from_file(self, tempdir):
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)

        file_name = str(Path(tempdir) / "file.vhd")
        write_file(
            file_name,
            """\
if run("Test_1")
if run("Test_2")
""",
        )
        test_bench.scan_tests_from_file(file_name)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.Test_1", "lib.tb_entity.Test_2"])

    def _test_scan_tests_from_file_location(self, tempdir, code):
        fstr = str(Path(tempdir) / "file.vhd")

        design_unit = Entity("tb_entity", file_name=fstr)
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)

        write_file(fstr, code)
        test_bench.scan_tests_from_file(fstr)
        tests = self.create_tests(test_bench)
        test_info = tests[0].test_information
        location = test_info["lib.tb_entity.Test_1"].location
        assert location.offset == code.find("Test_1")
        assert location.length == len("Test_1")

    @with_tempdir
    def test_scan_tests_from_file_location_unix(self, tempdir):
        self._test_scan_tests_from_file_location(tempdir, 'foo \n bar \n if run("Test_1")')

    @with_tempdir
    def test_scan_tests_from_file_location_dos(self, tempdir):
        self._test_scan_tests_from_file_location(tempdir, 'foo \r\n bar \r\n if run("Test_1")')

    @with_tempdir
    def test_scan_tests_from_missing_file(self, tempdir):
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)

        try:
            test_bench.scan_tests_from_file("missing.vhd")
        except ValueError as exc:
            self.assertEqual(str(exc), "File 'missing.vhd' does not exist")
        else:
            assert False, "ValueError not raised"

    @with_tempdir
    def test_does_not_add_all_suffix_with_named_configurations(self, tempdir):
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)

        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.all"])

        test_bench.add_config(name="config", generics=dict())
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.config"])

    @with_tempdir
    def test_that_run_in_same_simulation_attribute_works(self, tempdir):
        design_unit = Entity(
            "tb_entity",
            file_name=str(Path(tempdir) / "file.vhd"),
            contents="""\
-- vunit: run_all_in_same_sim
if run("Test_1")
if run("Test_2")
--if run("Test_3")
""",
        )
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)
        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, [("lib.tb_entity", ("lib.tb_entity.Test_1", "lib.tb_entity.Test_2"))])

    @with_tempdir
    def test_that_run_in_same_simulation_attribute_from_python_works(self, tempdir):
        for value in [None, True]:
            design_unit = Entity(
                "tb_entity",
                file_name=str(Path(tempdir) / "file.vhd"),
                contents="""\
if run("Test_1")
if run("Test_2")
--if run("Test_3")
""",
            )
            design_unit.generic_names = ["runner_cfg"]
            test_bench = TestBench(design_unit)
            test_bench.set_attribute("run_all_in_same_sim", value)
            tests = self.create_tests(test_bench)
            self.assert_has_tests(tests, [("lib.tb_entity", ("lib.tb_entity.Test_1", "lib.tb_entity.Test_2"))])

    @with_tempdir
    def test_add_config(self, tempdir):
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"))
        design_unit.generic_names = ["runner_cfg", "value", "global_value"]
        test_bench = TestBench(design_unit)

        test_bench.set_generic("global_value", "global value")

        test_bench.add_config(name="value=1", generics=dict(value=1, global_value="local value"))
        test_bench.add_config(
            name="value=2", generics=dict(value=2), attributes={".foo": "bar"}, vhdl_configuration_name="cfg"
        )

        self.assertRaises(
            AttributeException,
            test_bench.add_config,
            name="c3",
            attributes={"foo", "bar"},
        )

        tests = self.create_tests(test_bench)
        self.assert_has_tests(tests, ["lib.tb_entity.value=1", "lib.tb_entity.value=2"])

        self.assertEqual(
            get_config_of(tests, "lib.tb_entity.value=1").generics,
            {"value": 1, "global_value": "local value"},
        )
        self.assertEqual(get_config_of(tests, "lib.tb_entity.value=1").attributes, {})
        self.assertIsNone(get_config_of(tests, "lib.tb_entity.value=1").vhdl_configuration_name)
        self.assertEqual(
            get_config_of(tests, "lib.tb_entity.value=2").generics,
            {"value": 2, "global_value": "global value"},
        )
        self.assertEqual(get_config_of(tests, "lib.tb_entity.value=2").attributes, {".foo": "bar"})
        self.assertEqual(get_config_of(tests, "lib.tb_entity.value=2").vhdl_configuration_name, "cfg")

    @with_tempdir
    def test_test_case_add_config(self, tempdir):
        design_unit = Entity(
            "tb_entity",
            file_name=str(Path(tempdir) / "file.vhd"),
            contents="""
if run("test 1")
if run("test 2")
        """,
        )
        design_unit.generic_names = ["runner_cfg", "value", "global_value"]
        test_bench = TestBench(design_unit)
        test_bench.set_generic("global_value", "global value")
        test_bench.set_sim_option("disable_ieee_warnings", True)

        test_case = test_bench.get_test_case("test 2")
        test_case.add_config(name="c1", generics=dict(value=1, global_value="local value"))
        test_case.add_config(
            name="c2",
            generics=dict(value=2),
            sim_options=dict(disable_ieee_warnings=False),
            attributes={".foo": "bar"},
        )

        self.assertRaises(
            AttributeException,
            test_case.add_config,
            name="c3",
            attributes={"foo", "bar"},
        )

        tests = self.create_tests(test_bench)
        self.assert_has_tests(
            tests,
            [
                "lib.tb_entity.test 1",
                "lib.tb_entity.c1.test 2",
                "lib.tb_entity.c2.test 2",
            ],
        )

        config_test1 = get_config_of(tests, "lib.tb_entity.test 1")
        config_c1_test2 = get_config_of(tests, "lib.tb_entity.c1.test 2")
        config_c2_test2 = get_config_of(tests, "lib.tb_entity.c2.test 2")
        self.assertEqual(config_test1.generics, {"global_value": "global value"})
        self.assertEqual(config_c1_test2.attributes, {})
        self.assertEqual(config_c1_test2.generics, {"value": 1, "global_value": "local value"})
        self.assertEqual(config_c2_test2.attributes, {".foo": "bar"})
        self.assertEqual(config_c2_test2.generics, {"value": 2, "global_value": "global value"})

    @with_tempdir
    def test_runtime_error_on_configuration_of_individual_test_with_same_sim(self, tempdir):
        design_unit = Entity(
            "tb_entity",
            file_name=str(Path(tempdir) / "file.vhd"),
            contents="""\
-- vunit: run_all_in_same_sim
if run("Test 1")
if run("Test 2")
""",
        )
        design_unit.generic_names = ["runner_cfg", "name"]
        test_bench = TestBench(design_unit)
        test_case = test_bench.get_test_case("Test 1")
        self.assertRaises(RuntimeError, test_case.set_generic, "name", "value")
        self.assertRaises(RuntimeError, test_case.set_sim_option, "name", "value")
        self.assertRaises(RuntimeError, test_case.add_config, "name")

    @with_tempdir
    def test_run_all_in_same_sim_can_be_configured(self, tempdir):
        design_unit = Entity(
            "tb_entity",
            file_name=str(Path(tempdir) / "file.vhd"),
            contents="""\
-- vunit: run_all_in_same_sim
if run("Test 1")
if run("Test 2")
""",
        )
        design_unit.generic_names = ["runner_cfg", "name"]
        test_bench = TestBench(design_unit)
        test_bench.set_generic("name", "value")
        test_bench.add_config("cfg")
        tests = self.create_tests(test_bench)
        self.assert_has_tests(
            tests,
            [
                (
                    "lib.tb_entity.cfg",
                    ("lib.tb_entity.cfg.Test 1", "lib.tb_entity.cfg.Test 2"),
                )
            ],
        )
        self.assertEqual(get_config_of(tests, "lib.tb_entity.cfg").generics, {"name": "value"})

    @with_tempdir
    def test_global_user_attributes_not_supported_yet(self, tempdir):
        design_unit = Entity(
            "tb_entity",
            file_name=str(Path(tempdir) / "file.vhd"),
            contents="""\
-- vunit: .attr0
if run("Test 1")
if run("Test 2")
""",
        )
        design_unit.generic_names = ["runner_cfg"]

        try:
            TestBench(design_unit)
        except RuntimeError as exc:
            self.assertEqual(
                str(exc),
                "File global attributes are not yet supported: .attr0 in %s line 1" % str(Path(tempdir) / "file.vhd"),
            )
        else:
            assert False, "RuntimeError not raised"

    @with_tempdir
    def test_error_on_global_attributes_on_tests(self, tempdir):
        design_unit = Entity(
            "tb_entity",
            file_name=str(Path(tempdir) / "file.vhd"),
            contents="""\
if run("Test 1")
-- vunit: run_all_in_same_sim
if run("Test 2")
""",
        )
        design_unit.generic_names = ["runner_cfg"]

        try:
            TestBench(design_unit)
        except RuntimeError as exc:
            self.assertEqual(
                str(exc),
                "Attribute run_all_in_same_sim is global and cannot be associated with test Test 1: %s line 2"
                % str(Path(tempdir) / "file.vhd"),
            )
        else:
            assert False, "RuntimeError not raised"

    @with_tempdir
    def test_error_on_global_attributes_from_python_on_tests(self, tempdir):
        design_unit = Entity(
            "tb_entity",
            file_name=str(Path(tempdir) / "file.vhd"),
            contents="""\
if run("Test 1")
if run("Test 2")
""",
        )
        design_unit.generic_names = ["runner_cfg"]

        test_bench = TestBench(design_unit)
        test = test_bench.get_test_case("Test 1")
        self.assertRaises(AttributeException, test.set_attribute, "run_all_in_same_sim", True)    

    @with_tempdir
    def test_test_information(self, tempdir):
        file_name = str(Path(tempdir) / "file.vhd")

        for same_sim in [True, False]:
            contents = get_vhdl_test_bench("tb_entity", tests=["Test 1", "Test 2"], same_sim=same_sim)

            design_unit = Entity("tb_entity", file_name=file_name, contents=contents)
            design_unit.generic_names = ["runner_cfg", "name"]
            test_bench = TestBench(design_unit)
            test_suites = self.create_tests(test_bench)

            if same_sim:
                self.assertEqual(len(test_suites), 1)
            else:
                self.assertEqual(len(test_suites), 2)

            self.assertEqual(
                set(item for test_suite in test_suites for item in test_suite.test_information.items()),
                set(
                    [
                        (
                            "lib.tb_entity.Test 1",
                            Test("Test 1", _file_location(file_name, "Test 1")),
                        ),
                        (
                            "lib.tb_entity.Test 2",
                            Test("Test 2", _file_location(file_name, "Test 2")),
                        ),
                    ]
                ),
            )

    @with_tempdir
    def test_fail_on_unknown_sim_option(self, tempdir):
        design_unit = Entity("tb_entity", file_name=str(Path(tempdir) / "file.vhd"))
        design_unit.generic_names = ["runner_cfg"]
        test_bench = TestBench(design_unit)
        self.assertRaises(ValueError, test_bench.set_sim_option, "unknown", "value")

    def test_remove_verilog_comments(self):
        self.assertEqual(_remove_verilog_comments("a\n// foo \nb"), "a\n       \nb")
        self.assertEqual(_remove_verilog_comments("a\n/* foo\n \n */ \nb"), "a\n      \n \n    \nb")

    def test_get_line_offsets(self):
        self.assertEqual(_get_line_offsets(""), [])
        self.assertEqual(_get_line_offsets("1"), [0])
        self.assertEqual(_get_line_offsets("12\n3"), [0, 3])
        self.assertEqual(_get_line_offsets("12\n3\n"), [0, 3])
        self.assertEqual(_get_line_offsets("12\n3\n4"), [0, 3, 5])

    def test_lookup_lineno(self):
        offsets = _get_line_offsets("12\n3\n4")
        self.assertEqual(_lookup_lineno(0, offsets), 1)
        self.assertEqual(_lookup_lineno(1, offsets), 1)
        self.assertEqual(_lookup_lineno(2, offsets), 1)
        self.assertEqual(_lookup_lineno(3, offsets), 2)
        self.assertEqual(_lookup_lineno(4, offsets), 2)
        self.assertEqual(_lookup_lineno(5, offsets), 3)

    def test_find_explicit_tests_vhdl(self):
        test1, test2 = _find_tests(
            """\
        -- if run("No test")
        if run("Test 1")
        if run("Test 2")
        """,
            file_name="file_name.vhd",
        )

        self.assertEqual(test1.name, "Test 1")
        self.assertEqual(test1.location.file_name, "file_name.vhd")
        self.assertEqual(test1.location.lineno, 2)

        self.assertEqual(test2.name, "Test 2")
        self.assertEqual(test2.location.file_name, "file_name.vhd")
        self.assertEqual(test2.location.lineno, 3)

    def test_find_explicit_tests_verilog(self):
        test1, test2 = _find_tests(
            """\
        /* `TEST_CASE("No test")

        */
        // `TEST_CASE("No test")
        `TEST_CASE("Test 1")
        `TEST_CASE("Test 2")
        """,
            file_name="file_name.sv",
        )

        self.assertEqual(test1.name, "Test 1")
        self.assertEqual(test1.location.file_name, "file_name.sv")
        self.assertEqual(test1.location.lineno, 5)

        self.assertEqual(test2.name, "Test 2")
        self.assertEqual(test2.location.file_name, "file_name.sv")
        self.assertEqual(test2.location.lineno, 6)

    def test_find_implicit_test_vhdl(self):
        with mock.patch("vunit.test.bench.LOGGER") as logger:
            (test,) = _find_tests(
                """\

            test_runner_setup(
            """,
                file_name="file_name.vhd",
            )
            self.assertEqual(test.name, None)
            self.assertEqual(test.location.file_name, "file_name.vhd")
            self.assertEqual(test.location.lineno, 2)
            assert not logger.warning.called

        with mock.patch("vunit.test.bench.LOGGER") as logger:
            (test,) = _find_tests(
                """\

            test_runner_setup
            """,
                file_name="file_name.vhd",
            )
            self.assertEqual(test.name, None)
            self.assertEqual(test.location.file_name, "file_name.vhd")
            self.assertEqual(test.location.lineno, 1)
            assert logger.warning.called

        with mock.patch("vunit.test.bench.LOGGER") as logger:
            (test,) = _find_tests(
                """\

            """,
                file_name="file_name.vhd",
            )
            self.assertEqual(test.name, None)
            self.assertEqual(test.location.file_name, "file_name.vhd")
            self.assertEqual(test.location.lineno, 1)
            assert logger.warning.called

    def test_find_implicit_test_verilog(self):
        with mock.patch("vunit.test.bench.LOGGER") as logger:
            (test,) = _find_tests(
                """\

            `TEST_SUITE""",
                file_name="file_name.sv",
            )
            self.assertEqual(test.name, None)
            self.assertEqual(test.location.file_name, "file_name.sv")
            self.assertEqual(test.location.lineno, 2)
            assert not logger.warning.called

        with mock.patch("vunit.test.bench.LOGGER") as logger:
            (test,) = _find_tests(
                """\
            TEST_SUITE
            """,
                file_name="file_name.sv",
            )
            self.assertEqual(test.name, None)
            self.assertEqual(test.location.file_name, "file_name.sv")
            self.assertEqual(test.location.lineno, 1)
            assert logger.warning.called

        with mock.patch("vunit.test.bench.LOGGER") as logger:
            (test,) = _find_tests(
                """\
            """,
                file_name="file_name.sv",
            )
            self.assertEqual(test.name, None)
            self.assertEqual(test.location.file_name, "file_name.sv")
            self.assertEqual(test.location.lineno, 1)
            assert logger.warning.called

    @mock.patch("vunit.test.bench.LOGGER")
    def test_duplicate_tests_cause_error(self, mock_logger):
        file_name = "file.vhd"
        self.assertRaises(
            RuntimeError,
            _find_tests,
            """\
if run("Test_1")
--if run("Test_1")
if run("Test_3")
if run("Test_2")
if run("Test_3")
if run("Test_3")
if run("Test_2")
        """,
            file_name=file_name,
        )

        error_calls = mock_logger.error.call_args_list
        self.assertEqual(len(error_calls), 3)

        msg = error_calls[0][0][0] % error_calls[0][0][1:]
        self.assertEqual(
            msg,
            'Duplicate test "Test_3" in %s line 5 previously defined on line 3' % file_name,
        )

        msg = error_calls[1][0][0] % error_calls[1][0][1:]
        self.assertEqual(
            msg,
            'Duplicate test "Test_3" in %s line 6 previously defined on line 3' % file_name,
        )

        msg = error_calls[2][0][0] % error_calls[2][0][1:]
        self.assertEqual(
            msg,
            'Duplicate test "Test_2" in %s line 7 previously defined on line 4' % file_name,
        )

    def test_find_attributes(self):
        code = """
// vunit: run_all_in_same_sim
// vunit:fail_on_warning
        """

        attributes = _find_attributes(code, file_name="file.vhd")
        self.assertEqual(
            attributes,
            [
                Attribute(
                    "run_all_in_same_sim",
                    None,
                    _code_file_location(code, "run_all_in_same_sim", "file.vhd"),
                ),
                Attribute(
                    "fail_on_warning",
                    None,
                    _code_file_location(code, "fail_on_warning", "file.vhd"),
                ),
            ],
        )

    def test_find_user_attributes(self):
        code = """
// vunit: .foo
// vunit: .foo-bar
        """
        attributes = _find_attributes(code, file_name="file.vhd")

        self.assertEqual(
            attributes,
            [
                Attribute(".foo", None, _code_file_location(code, ".foo", "file.vhd")),
                Attribute(".foo-bar", None, _code_file_location(code, ".foo-bar", "file.vhd")),
            ],
        )

    def test_invalid_attributes(self):
        try:
            _find_attributes(
                """\


// vunit: invalid
            """,
                file_name="file.vhd",
            )
        except RuntimeError as exc:
            self.assertEqual(str(exc), "Invalid attribute 'invalid' in file.vhd line 3")
        else:
            assert False, "RuntimeError not raised"

    def test_find_legacy_pragma(self):
        code = """
// vunit_pragma run_all_in_same_sim
// vunit_pragma fail_on_warning
        """
        attributes = _find_attributes(code, file_name="file.vhd")

        self.assertEqual(
            attributes,
            [
                LegacyAttribute(
                    "run_all_in_same_sim",
                    None,
                    _code_file_location(code, "run_all_in_same_sim", "file.vhd"),
                ),
                LegacyAttribute(
                    "fail_on_warning",
                    None,
                    _code_file_location(code, "fail_on_warning", "file.vhd"),
                ),
            ],
        )

    def test_associate_tests_and_attributes(self):
        (test1, test2), attributes = _find_tests_and_attributes(
            """\
// vunit: .arg0
        if run("test1")
// vunit: .arg1
// vunit: .arg1b
        if run("test2") // vunit: .arg2
// vunit: .arg2b
        """,
            file_name="file.vhd",
        )

        self.assertEqual([attr.name for attr in attributes], [".arg0"])

        self.assertEqual(test1.name, "test1")
        self.assertEqual(test1.location.file_name, "file.vhd")
        self.assertEqual(test1.location.lineno, 2)
        self.assertEqual([attr.name for attr in test1.attributes], [".arg1", ".arg1b"])

        self.assertEqual(test2.name, "test2")
        self.assertEqual(test2.location.file_name, "file.vhd")
        self.assertEqual(test2.location.lineno, 5)
        self.assertEqual([attr.name for attr in test2.attributes], [".arg2", ".arg2b"])

    def test_duplicate_attributes_ok(self):
        (test1, test2), attributes = _find_tests_and_attributes(
            """\
// vunit: .arg0
        if run("test1")
// vunit: .arg0
        if run("test2")
// vunit: .arg0
        """,
            file_name="file.vhd",
        )

        self.assertEqual([attr.name for attr in attributes], [".arg0"])

        self.assertEqual(test1.name, "test1")
        self.assertEqual(test1.location.file_name, "file.vhd")
        self.assertEqual(test1.location.lineno, 2)
        self.assertEqual([attr.name for attr in test1.attributes], [".arg0"])

        self.assertEqual(test2.name, "test2")
        self.assertEqual(test2.location.file_name, "file.vhd")
        self.assertEqual(test2.location.lineno, 4)
        self.assertEqual([attr.name for attr in test2.attributes], [".arg0"])

    def test_duplicate_test_attributes_not_ok(self):
        try:
            _find_tests_and_attributes(
                """\
        if run("test1")
// vunit: .arg0
// vunit: .arg0
        """,
                file_name="file.vhd",
            )
        except RuntimeError as exc:
            self.assertEqual(
                str(exc),
                "Duplicate attribute .arg0 of test test1 in file.vhd line 3, previously defined on line 2",
            )
        else:
            assert False, "RuntimeError not raised"

    def test_duplicate_global_attributes_not_ok(self):
        try:
            _find_tests_and_attributes(
                """\
// vunit: .arg0
// vunit: .arg0
        if run("test1")
        """,
                file_name="file.vhd",
            )
        except RuntimeError as exc:
            self.assertEqual(
                str(exc),
                "Duplicate attribute .arg0 of file.vhd line 2, previously defined on line 1",
            )
        else:
            assert False, "RuntimeError not raised"

    def test_does_not_associate_tests_and_legacy_attributes(self):
        code = """\
        if run("test1")
// vunit_pragma run_all_in_same_sim
// vunit_pragma fail_on_warning
        """
        (test1,), attributes = _find_tests_and_attributes(code, file_name="file.vhd")

        self.assertEqual(
            attributes,
            [
                LegacyAttribute(
                    "run_all_in_same_sim",
                    None,
                    _code_file_location(code, "run_all_in_same_sim", "file.vhd"),
                ),
                LegacyAttribute(
                    "fail_on_warning",
                    None,
                    _code_file_location(code, "fail_on_warning", "file.vhd"),
                ),
            ],
        )

        self.assertEqual(test1.name, "test1")
        self.assertEqual(test1.location.file_name, "file.vhd")
        self.assertEqual(test1.location.lineno, 1)
        self.assertEqual(test1.attributes, [])

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
                self.assertEqual(test1.test_names, list(test_cases))
            else:
                self.assertEqual(test1.name, test2)
                self.assertEqual(test1.test_names, [test2])

    @staticmethod
    def create_tests(test_bench):
        """
        Helper method to reduce boiler plate
        """
        return test_bench.create_tests("simulator_if", seed="seed", elaborate_only=False)


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

    def __init__(self, name, file_name, contents=""):
        self.name = name
        self.library_name = "lib"
        self.is_entity = False
        self.is_module = True
        self.generic_names = []
        self.file_name = file_name
        self.original_file_name = file_name
        write_file(file_name, contents)


class Entity(object):  # pylint: disable=too-many-instance-attributes
    """
    Mock Entity
    """

    def __init__(self, name, file_name, contents="", no_arch=False):
        self.name = name
        self.library_name = "lib"
        self.is_entity = True
        self.is_module = False
        self.architecture_names = {}

        if not no_arch:
            self.architecture_names = {"arch": file_name}

        self.generic_names = []
        self.file_name = file_name
        self.original_file_name = file_name
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


def _code_file_location(code, string, file_name=None):
    """
    Create a FileLocation by finding the string within the code
    """
    offset = code.find(string)
    return FileLocation(
        file_name=file_name,
        offset=offset,
        length=len(string),
        lineno=1 + sum((1 for char in code[:offset] if char == "\n")),
    )


def _file_location(file_name, string):
    """
    Create a FileLocation by finding the string within file_name
    """

    with open(file_name, "r") as fptr:
        code = fptr.read()
        return _code_file_location(code, string, file_name)
