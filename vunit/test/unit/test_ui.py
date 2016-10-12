# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com
# pylint: disable=too-many-public-methods

"""
Acceptance test of the VUnit public interface class
"""

from __future__ import print_function
import unittest
from string import Template
import os
from os.path import join, dirname, basename, exists, abspath
import re
from re import MULTILINE
from shutil import rmtree
from vunit.ui import VUnit
from vunit.project import VHDL_EXTENSIONS, VERILOG_EXTENSIONS
from vunit.test.mock_2or3 import mock
from vunit.test.common import set_env
from vunit.ostools import renew_path
from vunit.builtins import add_verilog_include_dir
from vunit.simulator_interface import SimulatorInterface


class TestUi(unittest.TestCase):
    """
    Testing the VUnit public interface class
    """
    def setUp(self):
        self.tmp_path = join(dirname(__file__), "test_ui_tmp")
        renew_path(self.tmp_path)
        self.cwd = os.getcwd()
        os.chdir(self.tmp_path)

        self._output_path = join(self.tmp_path, 'output')
        self._preprocessed_path = join(self._output_path, "preprocessed")
        self.mocksim = None

    def tearDown(self):
        os.chdir(self.cwd)
        if exists(self.tmp_path):
            rmtree(self.tmp_path)

    def test_global_custom_preprocessors_should_be_applied_in_the_order_they_are_added(self):
        ui = self._create_ui()
        ui.add_library('lib')
        ui.add_preprocessor(VUnitfier())
        ui.add_preprocessor(ParentalControl())

        file_name = self.create_entity_file()
        ui.add_source_files(file_name, 'lib')

        pp_source = Template("""
library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World");
    check_relation(1 /= 2);
    log("Here I am!"); -- VUnitfier preprocessor: Report turned of[BEEP]eeping original code.
end architecture;
""")
        with open(join(self._preprocessed_path, 'lib', basename(file_name))) as fread:
            self.assertEqual(fread.read(), pp_source.substitute(entity='ent0', file=basename(file_name)))

    def test_global_check_and_location_preprocessors_should_be_applied_after_global_custom_preprocessors(self):
        ui = self._create_ui()
        ui.add_library('lib')
        ui.enable_location_preprocessing()
        ui.enable_check_preprocessing()
        ui.add_preprocessor(TestPreprocessor())

        file_name = self.create_entity_file()
        ui.add_source_files(file_name, 'lib')

        pp_source = Template("""\
-- check_relation(a = b, line_num => 1, file_name => "$file", \
auto_msg => "Relation a = b failed! Left is " & to_string(a) & ". Right is " & to_string(b) & ".");

library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World", line_num => 11, file_name => "$file");
    check_relation(1 /= 2, line_num => 12, file_name => "$file", \
auto_msg => "Relation 1 /= 2 failed! Left is " & to_string(1) & ". Right is " & to_string(2) & ".");
    report "Here I am!";
end architecture;
""")
        with open(join(self._preprocessed_path, 'lib', basename(file_name))) as fread:
            self.assertEqual(fread.read(), pp_source.substitute(entity='ent0', file=basename(file_name)))

    def test_locally_specified_preprocessors_should_be_used_instead_of_any_globally_defined_preprocessors(self):
        ui = self._create_ui()
        ui.add_library('lib')
        ui.enable_location_preprocessing()
        ui.enable_check_preprocessing()
        ui.add_preprocessor(TestPreprocessor())

        file_name1 = self.create_entity_file(1)
        file_name2 = self.create_entity_file(2)

        ui.add_source_files(file_name1, 'lib', [])
        ui.add_source_files(file_name2, 'lib', [VUnitfier()])

        pp_source = Template("""
library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World");
    check_relation(1 /= 2);
    $report
end architecture;
""")
        self.assertFalse(exists(join(self._preprocessed_path, 'lib', basename(file_name1))))
        with open(join(self._preprocessed_path, 'lib', basename(file_name2))) as fread:
            expectd = pp_source.substitute(
                entity='ent2',
                report='log("Here I am!"); -- VUnitfier preprocessor: Report turned off, keeping original code.')
            self.assertEqual(fread.read(), expectd)

    def test_supported_source_file_suffixes(self):
        """Test adding a supported filetype, of any case, is accepted."""
        ui = self._create_ui()
        ui.add_library('lib')
        accepted_extensions = VHDL_EXTENSIONS + VERILOG_EXTENSIONS
        allowable_extensions = [ext for ext in accepted_extensions]
        allowable_extensions.extend([ext.upper() for ext in accepted_extensions])
        allowable_extensions.append(VHDL_EXTENSIONS[0][0] + VHDL_EXTENSIONS[0][1].upper() +
                                    VHDL_EXTENSIONS[0][2:])  # mixed case
        for idx, ext in enumerate(allowable_extensions):
            file_name = self.create_entity_file(idx, ext)
            ui.add_source_files(file_name, 'lib')

    def test_unsupported_source_file_suffixes(self):
        """Test adding an unsupported filetype is rejected"""
        ui = self._create_ui()
        ui.add_library('lib')
        unsupported_name = "unsupported.docx"
        self.create_file(unsupported_name)
        self.assertRaises(RuntimeError, ui.add_source_files, unsupported_name, 'lib')

    def test_can_add_non_ascii_encoded_files(self):
        ui = self._create_ui()
        lib = ui.add_library('lib')
        lib.add_source_files(join(dirname(__file__), 'test_ui_encoding.vhd'))
        lib.entity("encoding")  # Fill raise exception of not found

    def test_exception_on_adding_zero_files(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        self.assertRaisesRegex(ValueError, "Pattern.*missing1.vhd.*",
                               lib.add_source_files, join(dirname(__file__), 'missing1.vhd'))
        self.assertRaisesRegex(ValueError, "File.*missing2.vhd.*",
                               lib.add_source_file, join(dirname(__file__), 'missing2.vhd'))

    def test_no_exception_on_adding_zero_files_when_allowed(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        lib.add_source_files(join(dirname(__file__), 'missing.vhd'), allow_empty=True)

    def test_add_source_files(self):
        files = ["file1.vhd",
                 "file2.vhd",
                 "file3.vhd",
                 "file_foo.vhd"]

        for file_name in files:
            self.create_file(file_name)

        ui = self._create_ui()
        lib = ui.add_library("lib")
        lib.add_source_files("file*.vhd")
        lib.add_source_files("file_foo.vhd")
        for file_name in files:
            lib.get_source_file(file_name)

        ui = self._create_ui()
        lib = ui.add_library("lib")
        lib.add_source_files(["file*.vhd", "file_foo.vhd"])
        for file_name in files:
            lib.get_source_file(file_name)

        ui = self._create_ui()
        lib = ui.add_library("lib")
        lib.add_source_files(("file*.vhd", "file_foo.vhd"))
        for file_name in files:
            lib.get_source_file(file_name)

        ui = self._create_ui()
        lib = ui.add_library("lib")
        lib.add_source_files(iter(["file*.vhd", "file_foo.vhd"]))
        for file_name in files:
            lib.get_source_file(file_name)

    def test_add_source_files_errors(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        self.create_file("file.vhd")
        self.assertRaisesRegex(ValueError, r"missing\.vhd", lib.add_source_files, ["missing.vhd", "file.vhd"])
        self.assertRaisesRegex(ValueError, r"missing\.vhd", lib.add_source_files, "missing.vhd")

    def test_get_source_files(self):
        ui = self._create_ui()
        lib1 = ui.add_library("lib1")
        lib2 = ui.add_library("lib2")
        file_name = self.create_entity_file()
        lib1.add_source_file(file_name)
        lib2.add_source_file(file_name)

        self.assertEqual(len(ui.get_source_files(file_name)), 2)
        self.assertEqual(len(lib1.get_source_files(file_name)), 1)
        self.assertEqual(len(lib2.get_source_files(file_name)), 1)

        ui.get_source_file(file_name, library_name="lib1")
        ui.get_source_file(file_name, library_name="lib2")
        lib1.get_source_file(file_name)
        lib2.get_source_file(file_name)

    def test_get_compile_order_smoke_test(self):
        ui = self._create_ui()
        lib1 = ui.add_library("lib1")
        lib2 = ui.add_library("lib2")
        file_name = self.create_entity_file()
        lib1.add_source_file(file_name)
        lib2.add_source_file(file_name)

        # Without argument
        compile_order = ui.get_compile_order()
        self.assertEqual(len(compile_order), 2)
        self.assertEqual(compile_order[0].name, file_name)
        self.assertEqual(compile_order[1].name, file_name)

        # With argument
        compile_order = ui.get_compile_order(lib1.get_source_file(file_name))
        self.assertEqual(len(compile_order), 1)
        self.assertEqual(compile_order[0].name, file_name)

    def test_list_files_flag(self):
        ui = self._create_ui("--files")
        lib1 = ui.add_library("lib1")
        lib2 = ui.add_library("lib2")
        file_name = self.create_entity_file()
        lib1.add_source_file(file_name)
        lib2.add_source_file(file_name)

        with mock.patch("sys.stdout", autospec=True) as stdout:
            self._run_main(ui)
        text = "".join([call[1][0] for call in stdout.write.mock_calls])
        # @TODO not always in the same order in Python3 due to dependency graph
        self.assertEqual(set(text.splitlines()),
                         set("""\
lib2, ent0.vhd
lib1, ent0.vhd
Listed 2 files""".splitlines()))

    def test_library_attributes(self):
        ui = self._create_ui()
        lib1 = ui.add_library("lib1")
        self.assertEqual(lib1.name, "lib1")

    def test_source_file_attributes(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        self.create_file("file_name.vhd")
        source_file = lib.add_source_file("file_name.vhd")
        self.assertEqual(source_file.name, "file_name.vhd")
        self.assertEqual(source_file.library.name, "lib")

    def test_get_source_files_errors(self):
        ui = self._create_ui()
        lib1 = ui.add_library("lib1")
        lib2 = ui.add_library("lib2")
        file_name = self.create_entity_file()
        lib1.add_source_file(file_name)
        lib2.add_source_file(file_name)
        non_existant_name = "non_existant"

        self.assertRaisesRegex(ValueError, ".*%s.*allow_empty.*" % non_existant_name,
                               ui.get_source_files, non_existant_name)
        self.assertEqual(len(ui.get_source_files(non_existant_name, allow_empty=True)), 0)

        self.assertRaisesRegex(ValueError, ".*named.*%s.*multiple.*library_name.*" % file_name,
                               ui.get_source_file, file_name)

        self.assertRaisesRegex(ValueError, ".*Found no file named.*%s'" % non_existant_name,
                               ui.get_source_file, non_existant_name)

        self.assertRaisesRegex(ValueError, ".*Found no file named.*%s.* in library 'lib1'" % non_existant_name,
                               ui.get_source_file, non_existant_name, "lib1")

    @mock.patch("vunit.project.Project.add_manual_dependency", autospec=True)
    def test_add_single_file_manual_dependencies(self, add_manual_dependency):
        # pylint: disable=protected-access
        ui = self._create_ui()
        lib = ui.add_library("lib")
        file_name1 = self.create_entity_file(1)
        file_name2 = self.create_entity_file(2)
        file1 = lib.add_source_file(file_name1)
        file2 = lib.add_source_file(file_name2)

        add_manual_dependency.assert_has_calls([])
        file1.depends_on(file2)
        add_manual_dependency.assert_has_calls([
            mock.call(ui._project,
                      file1._source_file,
                      depends_on=file2._source_file)])

    @mock.patch("vunit.project.Project.add_manual_dependency", autospec=True)
    def test_add_multiple_file_manual_dependencies(self, add_manual_dependency):
        # pylint: disable=protected-access
        ui = self._create_ui()
        lib = ui.add_library("lib")
        self.create_file("foo1.vhd")
        self.create_file("foo2.vhd")
        self.create_file("foo3.vhd")
        self.create_file("bar.vhd")
        foo_files = lib.add_source_files("foo*.vhd")
        bar_file = lib.add_source_file("bar.vhd")

        add_manual_dependency.assert_has_calls([])
        bar_file.depends_on(foo_files)
        add_manual_dependency.assert_has_calls([
            mock.call(ui._project,
                      bar_file._source_file,
                      depends_on=foo_file._source_file)
            for foo_file in foo_files])

    @mock.patch("vunit.project.Project.add_manual_dependency", autospec=True)
    def test_add_fileset_manual_dependencies(self, add_manual_dependency):
        # pylint: disable=protected-access
        ui = self._create_ui()
        lib = ui.add_library("lib")
        self.create_file("foo1.vhd")
        self.create_file("foo2.vhd")
        self.create_file("foo3.vhd")
        self.create_file("bar.vhd")
        foo_files = lib.add_source_files("foo*.vhd")
        bar_file = lib.add_source_file("bar.vhd")

        add_manual_dependency.assert_has_calls([])
        foo_files.depends_on(bar_file)
        add_manual_dependency.assert_has_calls([
            mock.call(ui._project,
                      foo_file._source_file,
                      depends_on=bar_file._source_file)
            for foo_file in foo_files])

    def test_add_source_files_has_include_dirs(self):
        file_name = "verilog.v"
        include_dirs = ["include_dir"]
        all_include_dirs = add_verilog_include_dir(include_dirs)
        self.create_file(file_name)

        def check(action):
            """
            Helper to check that project method was called
            """
            with mock.patch.object(ui, "_project", autospec=True) as project:
                action()
                project.add_source_file.assert_called_once_with(abspath("verilog.v"),
                                                                "lib",
                                                                file_type="verilog",
                                                                include_dirs=all_include_dirs,
                                                                defines=None,
                                                                vhdl_standard='2008')
        ui = self._create_ui()
        ui.add_library("lib")
        check(lambda: ui.add_source_files(file_name, "lib", include_dirs=include_dirs))

        ui = self._create_ui()
        ui.add_library("lib")
        check(lambda: ui.add_source_file(file_name, "lib", include_dirs=include_dirs))

        ui = self._create_ui()
        lib = ui.add_library("lib")
        check(lambda: lib.add_source_files(file_name, include_dirs=include_dirs))

        ui = self._create_ui()
        lib = ui.add_library("lib")
        check(lambda: lib.add_source_file(file_name, include_dirs=include_dirs))

    def test_add_source_files_has_defines(self):
        file_name = "verilog.v"
        self.create_file(file_name)
        all_include_dirs = add_verilog_include_dir([])
        defines = {"foo": "bar"}

        def check(action):
            """
            Helper to check that project method was called
            """
            with mock.patch.object(ui, "_project", autospec=True) as project:
                action()
                project.add_source_file.assert_called_once_with(abspath("verilog.v"),
                                                                "lib",
                                                                file_type="verilog",
                                                                include_dirs=all_include_dirs,
                                                                defines=defines,
                                                                vhdl_standard='2008')
        ui = self._create_ui()
        ui.add_library("lib")
        check(lambda: ui.add_source_files(file_name, "lib", defines=defines))

        ui = self._create_ui()
        ui.add_library("lib")
        check(lambda: ui.add_source_file(file_name, "lib", defines=defines))

        ui = self._create_ui()
        lib = ui.add_library("lib")
        check(lambda: lib.add_source_files(file_name, defines=defines))

        ui = self._create_ui()
        lib = ui.add_library("lib")
        check(lambda: lib.add_source_file(file_name, defines=defines))

    def test_compile_options(self):
        file_name = "foo.vhd"
        self.create_file(file_name)
        ui = self._create_ui()
        lib = ui.add_library("lib")
        source_file = lib.add_source_file(file_name)

        # Use methods on all types of interface objects
        for obj in [source_file, ui, lib, lib.get_source_files(file_name)]:
            obj.set_compile_option("ghdl.flags", [])
            self.assertEqual(source_file.get_compile_option("ghdl.flags"), [])

            obj.add_compile_option("ghdl.flags", ["1"])
            self.assertEqual(source_file.get_compile_option("ghdl.flags"), ["1"])

            obj.add_compile_option("ghdl.flags", ["2"])
            self.assertEqual(source_file.get_compile_option("ghdl.flags"), ["1", "2"])

            obj.set_compile_option("ghdl.flags", ["3"])
            self.assertEqual(source_file.get_compile_option("ghdl.flags"), ["3"])

    def test_default_vhdl_standard_is_used(self):
        file_name = "foo.vhd"
        self.create_file(file_name)
        with set_env(VUNIT_VHDL_STANDARD="93"):
            ui = self._create_ui()
        lib = ui.add_library("lib")
        source_file = lib.add_source_file(file_name)
        self.assertEqual(source_file.vhdl_standard, "93")

    def test_library_default_vhdl_standard_is_used(self):
        file_name = "foo.vhd"
        self.create_file(file_name)
        with set_env(VUNIT_VHDL_STANDARD="93"):
            ui = self._create_ui()
        lib = ui.add_library("lib", vhdl_standard="2002")
        source_file = lib.add_source_file(file_name)
        self.assertEqual(source_file.vhdl_standard, "2002")

    def test_add_source_file_vhdl_standard_is_used(self):
        file_name = "foo.vhd"
        self.create_file(file_name)

        for method in range(4):
            with set_env(VUNIT_VHDL_STANDARD="93"):
                ui = self._create_ui()
            lib = ui.add_library("lib", vhdl_standard="2002")

            if method == 0:
                source_file = lib.add_source_file(file_name, vhdl_standard="2008")
            elif method == 1:
                source_file = lib.add_source_files(file_name, vhdl_standard="2008")[0]
            elif method == 2:
                source_file = ui.add_source_file(file_name, "lib", vhdl_standard="2008")
            elif method == 3:
                source_file = ui.add_source_files(file_name, "lib", vhdl_standard="2008")[0]

            self.assertEqual(source_file.vhdl_standard, "2008")

    def test_verilog_file_has_vhdl_standard_none(self):
        file_name = "foo.v"
        self.create_file(file_name)
        ui = self._create_ui()
        lib = ui.add_library("lib")
        source_file = lib.add_source_file(file_name)
        self.assertEqual(source_file.vhdl_standard, None)

    def test_entity_has_pre_config(self):
        # pylint: disable=protected-access
        def pre_config():
            return False
        ui = self._create_ui("lib.test_ui_tb.test_one")
        ui._configuration.add_config = mock.create_autospec(ui._configuration.add_config)
        lib = ui.add_library("lib")
        lib.add_source_files(join(dirname(__file__), 'test_ui_tb.vhd'))
        ent = lib.entity("test_ui_tb")
        ent.add_config(name="cfg", pre_config=pre_config)
        ui._configuration.add_config.assert_called_once_with(
            name="cfg",
            scope=('lib', 'test_ui_tb'),
            post_check=None,
            pre_config=pre_config,
            generics={})

    def test_test_has_pre_config(self):
        # pylint: disable=protected-access
        def pre_config():
            return False
        ui = self._create_ui("lib.test_ui_tb.test_one")
        ui._configuration.add_config = mock.create_autospec(ui._configuration.add_config)
        lib = ui.add_library("lib")
        lib.add_source_files(join(dirname(__file__), 'test_ui_tb.vhd'))
        test = lib.entity("test_ui_tb").test("test_one")
        test.add_config(name="cfg", pre_config=pre_config)
        ui._configuration.add_config.assert_called_once_with(
            name="cfg",
            scope=('lib', 'test_ui_tb', 'test_one'),
            post_check=None,
            pre_config=pre_config,
            generics={})

    @mock.patch("vunit.ui.LOGGER", autospec=True)
    def test_warning_on_no_tests(self, logger):
        ui = self._create_ui("--compile")
        self._run_main(ui)
        self.assertEqual(logger.warning.mock_calls, [])
        logger.reset_mock()

        ui = self._create_ui("--list")
        self._run_main(ui)
        self.assertEqual(len(logger.warning.mock_calls), 1)
        self.assertTrue("found no test benches" in str(logger.warning.mock_calls))
        logger.reset_mock()

        ui = self._create_ui()
        self._run_main(ui)
        self.assertEqual(len(logger.warning.mock_calls), 1)
        self.assertTrue("found no test benches" in str(logger.warning.mock_calls))
        logger.reset_mock()

    def test_scan_tests_from_other_file(self):
        for tb_type in ["vhdl", "verilog"]:
            for tests_type in ["vhdl", "verilog"]:
                ui = self._create_ui()
                lib = ui.add_library("lib")

                print(tb_type, tests_type)
                if tb_type == "vhdl":
                    tb_file_name = "tb_top.vhd"
                    self.create_file(tb_file_name, """
entity tb_top is
  generic (runner_cfg : string);
end entity;

architecture a of tb_top is
begin
end architecture;
                    """)
                else:
                    tb_file_name = "tb_top.sv"
                    self.create_file(tb_file_name, """
module tb_top
  parameter string runner_cfg = "";
  tests #(.nested_runner_cfg(runner_cfg)) tests_inst();
endmodule;
                    """)

                if tests_type == "vhdl":
                    tests_file_name = "tests.vhd"
                    self.create_file(tests_file_name, """
entity tests is
  generic (nested_runner_cfg : string);
end entity;

architecture a of tests is
begin
  main : process
    if run("test1") then
    elsif run("test2")
    end if;
  end process;
end architecture;
                    """)
                else:
                    tests_file_name = "tests.sv"
                    self.create_file(tests_file_name, """
`include "vunit_defines.svh"
module tests;
   `NESTED_TEST_SUITE begin
      `TEST_CASE("test1") begin
      end
      `TEST_CASE("test2") begin
      end
   end;
endmodule
                    """)

                lib.add_source_file(tb_file_name)
                lib.add_source_file(tests_file_name)

                tests = ui._create_tests(None)  # pylint: disable=protected-access
                # tb_top is a single test case in itself
                self.assertEqual(tests.test_names(), ["lib.tb_top.all"])

                if tb_type == "vhdl":
                    test_bench = lib.entity("tb_top")
                else:
                    test_bench = lib.module("tb_top")
                test_bench.scan_tests_from_file(tests_file_name)

                tests = ui._create_tests(None)  # pylint: disable=protected-access
                # tb_top is a single test case in itself
                self.assertEqual(tests.test_names(), ["lib.tb_top.test1",
                                                      "lib.tb_top.test2"])

    def test_scan_tests_from_other_file_missing(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        tb_file_name = "tb_top.sv"
        self.create_file(tb_file_name, """
module tb_top
endmodule;
        """)
        lib.add_source_file(tb_file_name)
        self.assertRaises(ValueError, lib.module("tb_top").scan_tests_from_file, "missing.sv")

    def test_can_list_tests_without_simulator(self):
        with set_env(PATH=""):
            ui = self._create_ui("--list")
            self._run_main(ui, 0)

    def _create_ui(self, *args):
        """ Create an instance of the VUnit public interface class """
        ui = VUnit.from_argv(argv=["--output-path=%s" % self._output_path,
                                   "--clean"] + list(args),
                             compile_builtins=False)

        factory = MockSimulatorFactory(self._output_path)
        self.mocksim = factory.mocksim
        ui._simulator_factory = factory  # pylint: disable=protected-access
        return ui

    def _run_main(self, ui, code=0):
        """
        Run ui.main and expect exit code
        """
        try:
            ui.main()
        except SystemExit as exc:
            self.assertEqual(exc.code, code)

    def create_entity_file(self, idx=0, file_suffix='.vhd'):
        """
        Create and a temporary file containing the same source code
        but with different entity names depending on the index
        """
        source = Template("""
library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World");
    check_relation(1 /= 2);
    report "Here I am!";
end architecture;
""")

        entity_name = "ent%i" % idx
        file_name = entity_name + file_suffix
        self.create_file(file_name,
                         source.substitute(entity=entity_name))
        return file_name

    @staticmethod
    def create_file(file_name, contents=""):
        """
        Creata file in the temporary path with given contents
        """
        with open(file_name, "w") as fptr:
            fptr.write(contents)

    def assertRaisesRegex(self, *args, **kwargs):  # pylint: disable=invalid-name
        """
        Python 2/3 compatability
        """
        if hasattr(unittest.TestCase, "assertRaisesRegex"):
            unittest.TestCase.assertRaisesRegex(self, *args, **kwargs)  # pylint: disable=no-member
        else:
            unittest.TestCase.assertRaisesRegexp(self, *args, **kwargs)  # pylint: disable=deprecated-method


class TestPreprocessor(object):
    """
    A preprocessor that appends a check_relation call before the orginal code
    """
    def __init__(self):
        pass

    @staticmethod
    def run(code, file_name):  # pylint: disable=unused-argument
        return '-- check_relation(a = b);\n' + code


class VUnitfier(object):
    """
    A preprocessor that replaces report statments with log calls
    """
    def __init__(self):
        self._report_pattern = re.compile(r'^(?P<indent>\s*)report\s*(?P<note>"[^"]*")\s*;', MULTILINE)

    def run(self, code, file_name):   # pylint: disable=unused-argument
        return self._report_pattern.sub(
            r'\g<indent>log(\g<note>); -- VUnitfier preprocessor: Report turned off, keeping original code.', code)


class ParentalControl(object):
    """
    A preprocessor that replaces f..k with [BEEP]
    """
    def __init__(self):
        self._fword_pattern = re.compile(r'f..k')

    def run(self, code, file_name):   # pylint: disable=unused-argument
        return self._fword_pattern.sub(r'[BEEP]', code)


class MockSimulatorFactory(object):
    """
    Mock a simulator factory
    """
    simulator_name = "mocksim"

    def __init__(self, output_path):
        self._output_path = output_path
        self.mocksim = mock.Mock(spec=SimulatorInterface)

        def compile_side_effect(*args, **kwargs):
            return True

        def simulate_side_effect(*args, **kwargs):
            return True

        self.mocksim.compile_project.side_effect = compile_side_effect
        self.mocksim.simulate.side_effect = simulate_side_effect

    @property
    def simulator_output_path(self):
        return join(self._output_path, self.simulator_name)

    def create(self):
        return self.mocksim
