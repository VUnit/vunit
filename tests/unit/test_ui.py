# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
#
# pylint: disable=too-many-public-methods, too-many-lines

"""
Acceptance test of the VUnit public interface class
"""

import unittest
from string import Template
from pathlib import Path
from os import chdir, getcwd
from os.path import relpath
import json
import re
from re import MULTILINE
from shutil import rmtree
from unittest import mock
from tests.common import set_env, with_tempdir, create_vhdl_test_bench_file
from vunit.ui import VUnit
from vunit.source_file import VHDL_EXTENSIONS, VERILOG_EXTENSIONS
from vunit.ostools import renew_path
from vunit.builtins import add_verilog_include_dir
from vunit.sim_if import SimulatorInterface
from vunit.vhdl_standard import VHDL
from vunit.ui.preprocessor import Preprocessor


class TestUi(unittest.TestCase):
    """
    Testing the VUnit public interface class
    """

    def setUp(self):
        self.tmp_path = str(Path(__file__).parent / "test_ui_tmp")
        renew_path(self.tmp_path)
        self.cwd = getcwd()
        chdir(self.tmp_path)

        self._output_path = str(Path(self.tmp_path) / "output")
        self._preprocessed_path = str(Path(self._output_path) / "preprocessed")

    def tearDown(self):
        chdir(self.cwd)
        if Path(self.tmp_path).exists():
            rmtree(self.tmp_path)

    def test_global_custom_preprocessors_should_be_applied_in_the_order_they_are_added(
        self,
    ):
        ui = self._create_ui()
        ui.add_library("lib")
        ui.add_preprocessor(VUnitfier())
        ui.add_preprocessor(ParentalControl())

        file_name = self.create_entity_file()
        ui.add_source_files(file_name, "lib")

        pp_source = Template(
            """
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
"""
        )
        fname = Path(file_name).name
        with (Path(self._preprocessed_path) / "lib" / fname).open() as fread:
            self.assertEqual(
                fread.read(),
                pp_source.substitute(entity="ent0", file=fname),
            )

    def test_global_check_and_location_preprocessors_should_be_applied_after_global_custom_preprocessors(
        self,
    ):
        ui = self._create_ui()
        ui.add_library("lib")
        ui.enable_location_preprocessing()
        ui.enable_check_preprocessing()
        ui.add_preprocessor(TestPreprocessor())

        entity_file = Path(self.create_entity_file())
        ui.add_source_files(str(entity_file), "lib")

        pp_source = Template(
            """\
-- check_relation(a = b, line_num => 1, file_name => "$file", \
context_msg => "Expected a = b. Left is " & to_string(a) & ". Right is " & to_string(b) & ".");

library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World", line_num => 11, file_name => "$file");
    check_relation(1 /= 2, line_num => 12, file_name => "$file", \
context_msg => "Expected 1 /= 2. Left is " & to_string(1) & ". Right is " & to_string(2) & ".");
    report "Here I am!";
end architecture;
"""
        )
        with (Path(self._preprocessed_path) / "lib" / entity_file.name).open() as fread:
            self.assertEqual(
                fread.read(),
                pp_source.substitute(entity="ent0", file=entity_file.name),
            )

    def test_locally_specified_preprocessors_should_be_used_instead_of_any_globally_defined_preprocessors(
        self,
    ):
        ui = self._create_ui()
        ui.add_library("lib")
        ui.enable_location_preprocessing()
        ui.enable_check_preprocessing()
        ui.add_preprocessor(TestPreprocessor())

        file_name1 = self.create_entity_file(1)
        file_name2 = self.create_entity_file(2)

        ui.add_source_files(file_name1, "lib", [])
        ui.add_source_files(file_name2, "lib", [VUnitfier()])

        pp_source = Template(
            """
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
"""
        )
        self.assertFalse((Path(self._preprocessed_path) / "lib" / Path(file_name1).name).exists())
        with (Path(self._preprocessed_path) / "lib" / Path(file_name2).name).open() as fread:
            expectd = pp_source.substitute(
                entity="ent2",
                report='log("Here I am!"); -- VUnitfier preprocessor: Report turned off, keeping original code.',
            )
            self.assertEqual(fread.read(), expectd)

    def test_that_application_order_of_preprocessors_can_be_controlled(self):
        ui = self._create_ui()
        ui.add_library("lib")
        ui.add_preprocessor(TestPreprocessor2(order=1))
        ui.enable_location_preprocessing(order=-1)
        ui.enable_check_preprocessing(order=-2)
        ui.add_preprocessor(TestPreprocessor())

        entity_file = Path(self.create_entity_file())
        ui.add_source_files(str(entity_file), "lib")

        pp_source = Template(
            """\
-- TestPreprocessor2
-- check_relation(a = b);

library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World", line_num => 10, file_name => "$file");
    check_relation(1 /= 2, context_msg => "Expected 1 /= 2. Left is \
" & to_string(1) & ". Right is " & to_string(2) & ".", line_num => 11, file_name => "$file");
    report "Here I am!";
end architecture;
"""
        )
        with (Path(self._preprocessed_path) / "lib" / entity_file.name).open() as fread:
            self.assertEqual(
                fread.read(),
                pp_source.substitute(entity="ent0", file=entity_file.name),
            )

    @mock.patch("vunit.ui.LOGGER.error", autospec=True)
    def test_recovers_from_preprocessing_error(self, logger):
        ui = self._create_ui()
        ui.add_library("lib")
        ui.enable_location_preprocessing()
        ui.enable_check_preprocessing()

        source_with_error = Template(
            """
library vunit_lib;
context vunit_lib.vunit_context;

entity $entity is
end entity;

architecture arch of $entity is
begin
    log("Hello World";
    check_relation(1 /= 2);
    report "Here I am!";
end architecture;
"""
        )
        file_name = Path(self.tmp_path) / "ent1.vhd"
        contents = source_with_error.substitute(entity="ent1")
        self.create_file(str(file_name), contents)

        ui.add_source_file(file_name, "lib")
        logger.assert_called_once_with("Failed to preprocess %s", str(Path(file_name).resolve()))
        self.assertFalse((Path(self._preprocessed_path) / "lib" / file_name.name).exists())

    def test_supported_source_file_suffixes(self):
        """Test adding a supported filetype, of any case, is accepted."""
        ui = self._create_ui()
        ui.add_library("lib")
        accepted_extensions = VHDL_EXTENSIONS + VERILOG_EXTENSIONS
        allowable_extensions = list(accepted_extensions)
        allowable_extensions.extend([ext.upper() for ext in accepted_extensions])
        allowable_extensions.append(
            VHDL_EXTENSIONS[0][0] + VHDL_EXTENSIONS[0][1].upper() + VHDL_EXTENSIONS[0][2:]
        )  # mixed case
        for idx, ext in enumerate(allowable_extensions):
            file_name = self.create_entity_file(idx, ext)
            ui.add_source_files(file_name, "lib")

    def test_unsupported_source_file_suffixes(self):
        """Test adding an unsupported filetype is rejected"""
        ui = self._create_ui()
        ui.add_library("lib")
        unsupported_name = "unsupported.docx"
        self.create_file(unsupported_name)
        self.assertRaises(RuntimeError, ui.add_source_files, unsupported_name, "lib")

    def test_exception_on_adding_zero_files(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        dname = Path(__file__).parent
        self.assertRaisesRegex(
            ValueError,
            "Pattern.*missing1.vhd.*",
            lib.add_source_files,
            str(dname / "missing1.vhd"),
        )
        self.assertRaisesRegex(
            ValueError,
            "File.*missing2.vhd.*",
            lib.add_source_file,
            str(dname / "missing2.vhd"),
        )

    def test_no_exception_on_adding_zero_files_when_allowed(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        lib.add_source_files(str(Path(__file__).parent / "missing.vhd"), allow_empty=True)

    def test_get_test_benchs_and_test(self):
        self.create_file(
            "tb_ent.vhd",
            """
entity tb_ent is
  generic (runner_cfg : string);
end entity;

architecture a of tb_ent is
begin
  main : process
  begin
    if run("test1") then
    elsif run("test2") then
    end if;
  end process;
end architecture;
        """,
        )

        self.create_file(
            "tb_ent2.vhd",
            """
entity tb_ent2 is
  generic (runner_cfg : string);
end entity;

architecture a of tb_ent2 is
begin
end architecture;
        """,
        )

        self.create_file(
            "tb_ent3.vhd",
            """
entity tb_ent3 is
  generic (runner_cfg : string);
end entity;

architecture a of tb_ent3 is
begin
end architecture;
        """,
        )

        ui = self._create_ui()
        lib1 = ui.add_library("lib1")
        lib2 = ui.add_library("lib2")
        lib1.add_source_file("tb_ent.vhd")
        lib1.add_source_file("tb_ent2.vhd")
        lib2.add_source_file("tb_ent3.vhd")
        self.assertEqual(lib1.test_bench("tb_ent").name, "tb_ent")
        self.assertEqual(lib1.test_bench("tb_ent2").name, "tb_ent2")
        self.assertEqual(lib1.test_bench("tb_ent").library.name, "lib1")

        self.assertEqual(
            [test_bench.name for test_bench in lib1.get_test_benches()],
            ["tb_ent", "tb_ent2"],
        )
        self.assertEqual([test_bench.name for test_bench in lib1.get_test_benches("*2")], ["tb_ent2"])

        libs = ui.get_libraries("lib*")
        self.assertEqual(
            [test_bench.name for test_bench in libs.get_test_benches()],
            ["tb_ent", "tb_ent2", "tb_ent3"],
        )
        self.assertEqual([test_bench.name for test_bench in libs.get_test_benches("*3")], ["tb_ent3"])

        self.assertEqual(lib1.test_bench("tb_ent").test("test1").name, "test1")
        self.assertEqual(lib1.test_bench("tb_ent").test("test2").name, "test2")

        self.assertEqual(
            [test.name for test in lib1.test_bench("tb_ent").get_tests()],
            ["test1", "test2"],
        )
        self.assertEqual([test.name for test in lib1.test_bench("tb_ent").get_tests("*1")], ["test1"])
        self.assertEqual([test.name for test in lib1.test_bench("tb_ent2").get_tests()], [])

    def test_get_test_bench_with_explicit_constant_runner_cfg(self):
        self.create_file(
            "tb_ent.vhd",
            """
entity tb_ent is
  generic (constant runner_cfg : in string);
end entity;

architecture a of tb_ent is
begin
  main : process
  begin
    if run("test1") then
    elsif run("test2") then
    end if;
  end process;
end architecture;
        """,
        )

        ui = self._create_ui()
        lib1 = ui.add_library("lib1")
        lib1.add_source_file("tb_ent.vhd")
        self.assertEqual(lib1.test_bench("tb_ent").name, "tb_ent")
        self.assertEqual(
            [test.name for test in lib1.test_bench("tb_ent").get_tests()],
            ["test1", "test2"],
        )

    def test_get_entities_case_insensitive(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        self.create_file(
            "tb_ent.vhd",
            """
entity tb_Ent is
  generic (runner_cfg : string);
end entity;
        """,
        )
        lib.add_source_file("tb_ent.vhd")
        self.assertEqual(lib.test_bench("tb_Ent").name, "tb_ent")
        self.assertEqual(lib.test_bench("TB_ENT").name, "tb_ent")
        self.assertEqual(lib.test_bench("tb_ent").name, "tb_ent")

        self.assertEqual(lib.entity("tb_Ent").name, "tb_ent")
        self.assertEqual(lib.entity("TB_ENT").name, "tb_ent")
        self.assertEqual(lib.entity("tb_ent").name, "tb_ent")

    def test_add_source_files(self):
        files = ["file1.vhd", "file2.vhd", "file3.vhd", "foo_file.vhd"]

        for file_name in files:
            self.create_file(file_name)

        ui = self._create_ui()
        lib = ui.add_library("lib")
        lib.add_source_files("file*.vhd")
        lib.add_source_files("foo_file.vhd")
        for file_name in files:
            assert lib.get_source_file(file_name).name.endswith(file_name)

        ui = self._create_ui()
        lib = ui.add_library("lib")
        lib.add_source_files(["file*.vhd", "foo_file.vhd"])
        for file_name in files:
            lib.get_source_file(file_name).name.endswith(file_name)

        ui = self._create_ui()
        lib = ui.add_library("lib")
        lib.add_source_files(("file*.vhd", "foo_file.vhd"))
        for file_name in files:
            lib.get_source_file(file_name).name.endswith(file_name)

        ui = self._create_ui()
        lib = ui.add_library("lib")
        lib.add_source_files(iter(["file*.vhd", "foo_file.vhd"]))
        for file_name in files:
            lib.get_source_file(file_name).name.endswith(file_name)

    def test_add_source_files_from_csv(self):
        csv = """
        lib,  tb_example.vhdl
        lib1 , tb_example1.vhd
        lib2, tb_example2.vhd
        lib3,"tb,ex3.vhd"
        """

        libraries = ["lib", "lib1", "lib2", "lib3"]
        files = ["tb_example.vhdl", "tb_example1.vhd", "tb_example2.vhd", "tb,ex3.vhd"]

        self.create_csv_file("test_csv.csv", csv)
        for file_name in files:
            self.create_file(file_name)

        ui = self._create_ui()
        ui.add_source_files_from_csv("test_csv.csv")

        for index, library_name in enumerate(libraries):
            file_name = files[index]
            file_name_from_ui = ui.get_source_file(file_name, library_name)
            self.assertIsNotNone(file_name_from_ui)

    def test_add_source_files_from_csv_return(self):
        csv = """
        lib, tb_example.vhd
        lib, tb_example1.vhd
        lib, tb_example2.vhd
        """

        list_of_files = ["tb_example.vhd", "tb_example1.vhd", "tb_example2.vhd"]

        for index, file_ in enumerate(list_of_files):
            self.create_file(file_, str(index))

        self.create_csv_file("test_returns.csv", csv)
        ui = self._create_ui()

        source_files = ui.add_source_files_from_csv("test_returns.csv")
        self.assertEqual([source_file.name for source_file in source_files], list_of_files)

    def test_add_source_files_errors(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        self.create_file("file.vhd")
        self.assertRaisesRegex(
            ValueError,
            r"missing\.vhd",
            lib.add_source_files,
            ["missing.vhd", "file.vhd"],
        )
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
        self.assertEqual(len(ui.get_libraries("lib*").get_source_files(file_name)), 2)
        self.assertEqual(len(ui.get_libraries("lib2").get_source_files(file_name)), 1)

        ui.get_source_file(file_name, library_name="lib1")
        ui.get_source_file(file_name, library_name="lib2")
        lib1.get_source_file(file_name)
        lib2.get_source_file(file_name)

    def test_get_libraries(self):
        ui = self._create_ui()

        libs = ui.get_libraries()
        self.assertEqual(len(libs), 1)
        self.assertEqual(libs[0].name, "vunit_lib")

        ui.add_library("lib1")
        ui.add_library("lib2")

        self.assertEqual(len(ui.get_libraries()), 3)
        self.assertEqual(len(ui.get_libraries("lib*")), 2)
        libs = ui.get_libraries("lib1")
        self.assertEqual(len(libs), 1)
        self.assertEqual(libs[0].name, "lib1")
        libs = ui.get_libraries("*2")
        self.assertEqual(len(libs), 1)
        self.assertEqual(libs[0].name, "lib2")

    def test_get_libraries_errors(self):
        ui = self._create_ui()
        ui.add_library("lib1")
        ui.add_library("lib2")
        non_existant_name = "non_existant"

        self.assertRaisesRegex(
            ValueError,
            f".*{non_existant_name}.*allow_empty.*",
            ui.get_libraries,
            non_existant_name,
        )

        self.assertEqual(len(ui.get_libraries(non_existant_name, allow_empty=True)), 0)

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
        compile_order = ui.get_compile_order([lib1.get_source_file(file_name)])
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
        self.assertEqual(
            set(text.splitlines()),
            set(
                """\
lib2, ent0.vhd
lib1, ent0.vhd
Listed 2 files""".splitlines()
            ),
        )

    @with_tempdir
    def test_filtering_tests(self, tempdir):
        def setup(ui):
            "Setup the project"
            lib = ui.add_library("lib")
            file_name = str(Path(tempdir) / "tb_filter.vhd")
            create_vhdl_test_bench_file(
                "tb_filter",
                file_name,
                tests=["Test 1", "Test 2", "Test 3", "Test 4"],
                test_attributes={
                    "Test 1": [".attr0"],
                    "Test 2": [".attr0", ".attr1"],
                    "Test 3": [".attr1"],
                    "Test 4": [],
                },
            )
            lib.add_source_file(file_name)
            lib.test_bench("tb_filter").test("Test 4").set_attribute(".attr2", None)

        def check_stdout(ui, expected):
            "Check that stdout matches expected"
            with mock.patch("sys.stdout", autospec=True) as stdout:
                self._run_main(ui)
            text = "".join([call[1][0] for call in stdout.write.mock_calls])
            # @TODO not always in the same order in Python3 due to dependency graph
            print(text)
            self.assertEqual(set(text.splitlines()), set(expected.splitlines()))

        ui = self._create_ui("--list", "*Test 1")
        setup(ui)
        check_stdout(ui, "lib.tb_filter.Test 1\nListed 1 tests")

        ui = self._create_ui("--list", "*Test*")
        setup(ui)
        check_stdout(
            ui,
            "lib.tb_filter.Test 1\n"
            "lib.tb_filter.Test 2\n"
            "lib.tb_filter.Test 3\n"
            "lib.tb_filter.Test 4\n"
            "Listed 4 tests",
        )

        ui = self._create_ui("--list", "*2*")
        setup(ui)
        check_stdout(ui, "lib.tb_filter.Test 2\n" "Listed 1 tests")

        ui = self._create_ui("--list", "--with-attribute=.attr0")
        setup(ui)
        check_stdout(ui, "lib.tb_filter.Test 1\n" "lib.tb_filter.Test 2\n" "Listed 2 tests")

        ui = self._create_ui("--list", "--with-attribute=.attr2")
        setup(ui)
        check_stdout(ui, "lib.tb_filter.Test 4\n" "Listed 1 tests")

        ui = self._create_ui("--list", "--with-attributes", ".attr0", "--with-attributes", ".attr1")
        setup(ui)
        check_stdout(ui, "lib.tb_filter.Test 2\n" "Listed 1 tests")

        ui = self._create_ui("--list", "--without-attributes", ".attr0")
        setup(ui)
        check_stdout(ui, "lib.tb_filter.Test 3\n" "lib.tb_filter.Test 4\n" "Listed 2 tests")

        ui = self._create_ui("--list", "--without-attributes", ".attr0", "--without-attributes", ".attr1")
        setup(ui)
        check_stdout(ui, "lib.tb_filter.Test 4\n" "Listed 1 tests")

        ui = self._create_ui("--list", "--with-attributes", ".attr0", "--without-attributes", ".attr1")
        setup(ui)
        check_stdout(ui, "lib.tb_filter.Test 1\n" "Listed 1 tests")

    @with_tempdir
    def test_export_json(self, tempdir):
        tdir = Path(tempdir)
        json_file = str(tdir / "export.json")

        ui = self._create_ui("--export-json", json_file)
        lib1 = ui.add_library("lib1")
        lib2 = ui.add_library("lib2")

        file_name1 = str(tdir / "tb_foo.vhd")
        create_vhdl_test_bench_file("tb_foo", file_name1)
        lib1.add_source_file(file_name1)

        file_name2 = str(tdir / "tb_bar.vhd")
        create_vhdl_test_bench_file(
            "tb_bar",
            file_name2,
            tests=["Test one", "Test two"],
            test_attributes={"Test one": [".attr0"]},
        )
        lib2.add_source_file(file_name2)
        lib2.test_bench("tb_bar").set_attribute(".attr1", "bar")

        self._run_main(ui)

        with Path(json_file).open("r") as fptr:
            data = json.load(fptr)

        # Check known keys
        self.assertEqual(set(data.keys()), set(["export_format_version", "files", "tests"]))

        # Check that export format is semantic version with integer values
        self.assertEqual(set(data["export_format_version"].keys()), set(("major", "minor", "patch")))
        assert all(isinstance(value, int) for value in data["export_format_version"].values())

        # Check the contents of the files section
        self.assertEqual(
            set((item["library_name"], item["file_name"]) for item in data["files"]),
            set(
                [
                    ("lib1", str(Path(file_name1).resolve())),
                    ("lib2", str(Path(file_name2).resolve())),
                ]
            ),
        )

        # Check the contents of the tests section
        self.assertEqual(
            {item["name"]: (item["location"], item["attributes"]) for item in data["tests"]},
            {
                "lib1.tb_foo.all": (
                    {"file_name": file_name1, "offset": 180, "length": 18},
                    {},
                ),
                "lib2.tb_bar.Test one": (
                    {"file_name": file_name2, "offset": 235, "length": 8},
                    {".attr0": None, ".attr1": "bar"},
                ),
                "lib2.tb_bar.Test two": (
                    {"file_name": file_name2, "offset": 283, "length": 8},
                    {".attr1": "bar"},
                ),
            },
        )

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

        self.assertRaisesRegex(
            ValueError,
            ".*%s.*allow_empty.*" % non_existant_name,
            ui.get_source_files,
            non_existant_name,
        )
        self.assertEqual(len(ui.get_source_files(non_existant_name, allow_empty=True)), 0)

        self.assertRaisesRegex(
            ValueError,
            ".*named.*%s.*multiple.*library_name.*" % file_name,
            ui.get_source_file,
            file_name,
        )

        self.assertRaisesRegex(
            ValueError,
            ".*Found no file named.*%s'" % non_existant_name,
            ui.get_source_file,
            non_existant_name,
        )

        self.assertRaisesRegex(
            ValueError,
            ".*Found no file named.*%s.* in library 'lib1'" % non_existant_name,
            ui.get_source_file,
            non_existant_name,
            "lib1",
        )

    def test_add_single_file_manual_dependencies(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        file_name1 = self.create_entity_file(1)
        file_name2 = self.create_entity_file(2)
        file1 = lib.add_source_file(file_name1)
        file2 = lib.add_source_file(file_name2)
        self.assertEqual(names(ui.get_compile_order([file1])), names([file1]))
        self.assertEqual(names(ui.get_compile_order([file2])), names([file2]))
        file1.add_dependency_on(file2)
        self.assertEqual(names(ui.get_compile_order([file1])), names([file2, file1]))
        self.assertEqual(names(ui.get_compile_order([file2])), names([file2]))

    def test_add_multiple_file_manual_dependencies(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        self.create_file("foo1.vhd")
        self.create_file("foo2.vhd")
        self.create_file("foo3.vhd")
        self.create_file("bar.vhd")
        foo_files = lib.add_source_files("foo*.vhd")
        bar_file = lib.add_source_file("bar.vhd")

        self.assertEqual(names(ui.get_compile_order([bar_file])), names([bar_file]))
        bar_file.add_dependency_on(foo_files)
        self.assertEqual(
            sorted(names(ui.get_compile_order([bar_file]))),
            sorted(names(foo_files + [bar_file])),
        )
        self.assertEqual(ui.get_compile_order([bar_file])[-1].name, bar_file.name)

    def test_add_fileset_manual_dependencies(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        self.create_file("foo1.vhd")
        self.create_file("foo2.vhd")
        self.create_file("foo3.vhd")
        self.create_file("bar.vhd")
        foo_files = lib.add_source_files("foo*.vhd")
        bar_file = lib.add_source_file("bar.vhd")

        for foo_file in foo_files:
            self.assertEqual(names(ui.get_compile_order([foo_file])), names([foo_file]))

        foo_files.add_dependency_on(bar_file)

        for foo_file in foo_files:
            self.assertEqual(names(ui.get_compile_order([foo_file])), names([bar_file, foo_file]))

    def _create_ui_with_mocked_project_add_source_file(self):
        """
        Helper method to create an VUnit object with a mocked project
        to test that the Project.add_source_files method gets the correct arguments
        """
        ui = self._create_ui()
        fun = mock.Mock()
        retval = mock.Mock()
        retval.design_units = []
        fun.return_value = retval
        ui._project.add_source_file = fun
        return ui, fun

    def test_add_source_files_has_include_dirs(self):
        file_name = "verilog.v"
        include_dirs = ["include_dir"]
        all_include_dirs = add_verilog_include_dir(include_dirs)
        self.create_file(file_name)

        def check(action):
            """
            Helper to check that project method was called
            """
            ui, add_source_file = self._create_ui_with_mocked_project_add_source_file()
            lib = ui.add_library("lib")
            action(ui, lib)
            add_source_file.assert_called_once_with(
                str(Path("verilog.v").resolve()),
                "lib",
                file_type="verilog",
                include_dirs=all_include_dirs,
                defines=None,
                vhdl_standard=VHDL.STD_2008,
                no_parse=False,
            )

        check(lambda ui, _: ui.add_source_files(file_name, "lib", include_dirs=include_dirs))
        check(lambda ui, _: ui.add_source_file(file_name, "lib", include_dirs=include_dirs))
        check(lambda _, lib: lib.add_source_files(file_name, include_dirs=include_dirs))
        check(lambda _, lib: lib.add_source_file(file_name, include_dirs=include_dirs))

    def test_add_source_files_has_defines(self):
        file_name = "verilog.v"
        self.create_file(file_name)
        all_include_dirs = add_verilog_include_dir([])
        defines = {"foo": "bar"}

        def check(action):
            """
            Helper to check that project method was called
            """
            ui, add_source_file = self._create_ui_with_mocked_project_add_source_file()
            lib = ui.add_library("lib")
            action(ui, lib)
            add_source_file.assert_called_once_with(
                str(Path("verilog.v").resolve()),
                "lib",
                file_type="verilog",
                include_dirs=all_include_dirs,
                defines=defines,
                vhdl_standard=VHDL.STD_2008,
                no_parse=False,
            )

        check(lambda ui, _: ui.add_source_files(file_name, "lib", defines=defines))
        check(lambda ui, _: ui.add_source_file(file_name, "lib", defines=defines))
        check(lambda _, lib: lib.add_source_files(file_name, defines=defines))
        check(lambda _, lib: lib.add_source_file(file_name, defines=defines))

    def test_add_source_files_has_no_parse(self):
        file_name = "verilog.v"
        self.create_file(file_name)
        all_include_dirs = add_verilog_include_dir([])

        for no_parse in (True, False):
            for method in range(4):
                (
                    ui,
                    add_source_file,
                ) = self._create_ui_with_mocked_project_add_source_file()
                lib = ui.add_library("lib")

                if method == 0:
                    ui.add_source_files(file_name, "lib", no_parse=no_parse)
                elif method == 1:
                    ui.add_source_file(file_name, "lib", no_parse=no_parse)
                elif method == 2:
                    lib.add_source_files(file_name, no_parse=no_parse)
                elif method == 3:
                    lib.add_source_file(file_name, no_parse=no_parse)

                    add_source_file.assert_called_once_with(
                        str(Path("verilog.v").resolve()),
                        "lib",
                        file_type="verilog",
                        include_dirs=all_include_dirs,
                        defines=None,
                        vhdl_standard=VHDL.STD_2008,
                        no_parse=no_parse,
                    )

    def test_compile_options(self):
        file_name = "foo.vhd"
        self.create_file(file_name)
        ui = self._create_ui()
        lib = ui.add_library("lib")
        source_file = lib.add_source_file(file_name)

        # Use methods on all types of interface objects
        for obj in [source_file, ui, lib, lib.get_source_files(file_name), ui.get_libraries("lib")]:
            obj.set_compile_option("ghdl.a_flags", [])
            self.assertEqual(source_file.get_compile_option("ghdl.a_flags"), [])

            obj.add_compile_option("ghdl.a_flags", ["1"])
            self.assertEqual(source_file.get_compile_option("ghdl.a_flags"), ["1"])

            obj.add_compile_option("ghdl.a_flags", ["2"])
            self.assertEqual(source_file.get_compile_option("ghdl.a_flags"), ["1", "2"])

            obj.set_compile_option("ghdl.a_flags", ["3"])
            self.assertEqual(source_file.get_compile_option("ghdl.a_flags"), ["3"])

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

        for method in range(4):
            with set_env(VUNIT_VHDL_STANDARD="93"):
                ui = self._create_ui()

            if method == 0:
                lib = ui.add_library("lib", vhdl_standard="2002")
                source_file = lib.add_source_file(file_name)
            elif method == 1:
                lib = ui.add_library("lib", vhdl_standard="2002")
                source_file = ui.add_source_file(file_name, "lib")
            elif method == 2:
                lib = ui.add_library("lib", vhdl_standard="2002")
                source_file = lib.add_source_files(file_name)[0]
            elif method == 3:
                lib = ui.add_library("lib", vhdl_standard="2002")
                source_file = ui.add_source_files(file_name, "lib")[0]

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

    @mock.patch("vunit.test.bench_list.LOGGER", autospec=True)
    def test_warning_on_no_tests(self, logger):
        ui = self._create_ui("--compile")
        self._run_main(ui)
        self.assertEqual(logger.warning.mock_calls, [])
        logger.reset_mock()

        ui = self._create_ui("--list")
        self._run_main(ui)
        self.assertEqual(len(logger.warning.mock_calls), 1)
        self.assertTrue("Found no test benches" in str(logger.warning.mock_calls))
        logger.reset_mock()

        ui = self._create_ui()
        self._run_main(ui)
        self.assertEqual(len(logger.warning.mock_calls), 1)
        self.assertTrue("Found no test benches" in str(logger.warning.mock_calls))
        logger.reset_mock()

    def test_post_run(self):
        post_run = mock.Mock()

        ui = self._create_ui()
        self._run_main(ui, post_run=post_run)
        self.assertTrue(post_run.called)

        for no_run_arg in ["--compile", "--files", "--list"]:
            post_run.reset_mock()
            ui = self._create_ui(no_run_arg)
            self._run_main(ui, post_run=post_run)
            self.assertFalse(post_run.called)

    def test_error_on_adding_duplicate_library(self):
        ui = self._create_ui()
        ui.add_library("lib")
        self.assertRaises(ValueError, ui.add_library, "lib")

    def test_allow_adding_duplicate_library(self):
        ui = self._create_ui()

        file_name = "file.vhd"
        self.create_file(file_name)

        file_name2 = "file2.vhd"
        self.create_file(file_name2)

        lib1 = ui.add_library("lib")
        source_file1 = lib1.add_source_file(file_name)
        self.assertEqual(
            [source_file.name for source_file in lib1.get_source_files()],
            [source_file1.name],
        )

        lib2 = ui.add_library("lib", allow_duplicate=True)
        for lib in [lib1, lib2]:
            self.assertEqual(
                [source_file.name for source_file in lib.get_source_files()],
                [source_file1.name],
            )

        source_file2 = lib2.add_source_file(file_name2)
        for lib in [lib1, lib2]:
            self.assertEqual(
                {source_file.name for source_file in lib.get_source_files()},
                {source_file1.name, source_file2.name},
            )

    def test_scan_tests_from_other_file(self):
        for tb_type in ["vhdl", "verilog"]:
            for tests_type in ["vhdl", "verilog"]:
                ui = self._create_ui()
                lib = ui.add_library("lib")

                if tb_type == "vhdl":
                    tb_file_name = "tb_top.vhd"
                    self.create_file(
                        tb_file_name,
                        """
entity tb_top is
  generic (runner_cfg : string);
end entity;

architecture a of tb_top is
begin
end architecture;
                    """,
                    )
                else:
                    tb_file_name = "tb_top.sv"
                    self.create_file(
                        tb_file_name,
                        """
module tb_top
  parameter string runner_cfg = "";
  tests #(.nested_runner_cfg(runner_cfg)) tests_inst();
endmodule;
                    """,
                    )

                if tests_type == "vhdl":
                    tests_file_name = "tests.vhd"
                    self.create_file(
                        tests_file_name,
                        """
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
                    """,
                    )
                else:
                    tests_file_name = "tests.sv"
                    self.create_file(
                        tests_file_name,
                        """
`include "vunit_defines.svh"
module tests;
   `NESTED_TEST_SUITE begin
      `TEST_CASE("test1") begin
      end
      `TEST_CASE("test2") begin
      end
   end;
endmodule
                    """,
                    )

                lib.add_source_file(tb_file_name)
                lib.add_source_file(tests_file_name)

                # tb_top is a single test case in itself
                self.assertEqual(ui.library("lib").test_bench("tb_top").get_tests(), [])

                if tb_type == "vhdl":
                    test_bench = lib.entity("tb_top")
                else:
                    test_bench = lib.module("tb_top")
                test_bench.scan_tests_from_file(tests_file_name)

                self.assertEqual(
                    [test.name for test in ui.library("lib").test_bench("tb_top").get_tests()],
                    ["test1", "test2"],
                )

    def test_scan_tests_from_other_file_missing(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        tb_file_name = "tb_top.sv"
        self.create_file(
            tb_file_name,
            """
`include "vunit_defines.svh"
module tb_top;
   `TEST_SUITE begin
      `TEST_CASE("test1") begin
      end
   end;
endmodule
        """,
        )
        lib.add_source_file(tb_file_name)
        self.assertRaises(ValueError, lib.test_bench("tb_top").scan_tests_from_file, "missing.sv")

    def test_can_list_tests_without_simulator(self):
        with set_env():
            ui = self._create_ui_real_sim("--list")
            self._run_main(ui, 0)

    def test_can_list_files_without_simulator(self):
        with set_env():
            ui = self._create_ui_real_sim("--files")
            self._run_main(ui, 0)

    @mock.patch("vunit.ui.LOGGER", autospec=True)
    def test_compile_without_simulator_fails(self, logger):
        with set_env():
            ui = self._create_ui_real_sim("--compile")
            self._run_main(ui, 1)
            self.assertEqual(len(logger.error.mock_calls), 1)
            self.assertTrue("No available simulator detected" in str(logger.error.mock_calls))

    @mock.patch("vunit.ui.LOGGER", autospec=True)
    def test_simulate_without_simulator_fails(self, logger):
        with set_env():
            ui = self._create_ui_real_sim()
            self._run_main(ui, 1)
            self.assertEqual(len(logger.error.mock_calls), 1)
            self.assertTrue("No available simulator detected" in str(logger.error.mock_calls))

    def test_set_sim_option_before_adding_file(self):
        """
        From GitHub issue #250
        """
        ui = self._create_ui()
        lib = ui.add_library("lib")
        libs = ui.get_libraries("lib")
        for method in (lib.set_sim_option, ui.set_sim_option, libs.set_sim_option):
            method("disable_ieee_warnings", True, allow_empty=True)
            self.assertRaises(ValueError, method, "disable_ieee_warnings", True)

        for method in (
            lib.set_compile_option,
            lib.add_compile_option,
            libs.set_compile_option,
            libs.add_compile_option,
            ui.set_compile_option,
            ui.add_compile_option,
        ):
            method("ghdl.elab_flags", [], allow_empty=True)
            self.assertRaises(ValueError, method, "ghdl.elab_flags", [])

    def test_get_testbench_files(self):
        ui = self._create_ui()
        lib = ui.add_library("lib")
        file_name = self.create_entity_file()
        lib.add_source_file(file_name)
        self.create_file(
            "tb_ent.vhd",
            """
entity tb_ent is
  generic (runner_cfg : string);
end entity;

architecture a of tb_ent is
begin
  main : process
  begin
    if run("test1") then
    elsif run("test2") then
    end if;
  end process;
end architecture;
        """,
        )

        self.create_file(
            "tb_ent2.vhd",
            """
entity tb_ent2 is
  generic (runner_cfg : string);
end entity;

architecture a of tb_ent2 is
begin
end architecture;
        """,
        )
        lib.add_source_file("tb_ent.vhd")
        lib.add_source_file("tb_ent2.vhd")
        simulator_if = ui._create_simulator_if()  # pylint: disable=protected-access
        target_files = ui._get_testbench_files(simulator_if)  # pylint: disable=protected-access
        expected = [
            lib.get_source_file(fname)._source_file  # pylint: disable=protected-access
            for fname in ["tb_ent2.vhd", "tb_ent.vhd"]
        ]
        self.assertEqual(
            sorted(target_files, key=lambda x: x.name),
            sorted(expected, key=lambda x: x.name),
        )

    @with_tempdir
    def test_update_test_pattern(self, tempdir):
        relative_tempdir = Path(relpath(str(tempdir.resolve()), str(Path().cwd())))

        def setup(ui):
            "Setup the project"
            ui.add_vhdl_builtins()
            lib1 = ui.add_library("lib1")
            lib2 = ui.add_library("lib2")

            rtl = []
            for i in range(4):
                vhdl_source = f"""\
entity rtl{i} is
end entity;

architecture a of rtl{i} is
begin
end architecture;
"""
                file_name = str(Path(tempdir) / f"rtl{i}.vhd")
                self.create_file(file_name, vhdl_source)
                rtl.append(lib1.add_source_file(file_name))

            verilog_source = """\
module rtl4;
endmodule
"""
            file_name = str(Path(tempdir) / f"rtl4.v")
            self.create_file(file_name, verilog_source)
            rtl.append(lib2.add_source_file(file_name))

            tb = []
            for i in range(2):
                file_name = str(Path(tempdir) / f"tb{i}.vhd")
                create_vhdl_test_bench_file(
                    f"tb{i}",
                    file_name,
                    tests=["Test 1"] if i == 0 else [],
                )
                if i == 0:
                    tb.append(lib1.add_source_file(file_name))
                else:
                    tb.append(lib2.add_source_file(file_name))

            rtl[1].add_dependency_on(rtl[0])
            rtl[2].add_dependency_on(rtl[0])
            rtl[2].add_dependency_on(rtl[4])
            tb[0].add_dependency_on(rtl[1])
            tb[1].add_dependency_on(rtl[2])

            return rtl, tb

        def check_stdout(ui, expected):
            "Check that stdout matches expected"
            with mock.patch("sys.stdout", autospec=True) as stdout:
                self._run_main(ui)
            text = "".join([call[1][0] for call in stdout.write.mock_calls])
            # @TODO not always in the same order in Python3 due to dependency graph
            print(text)
            self.assertEqual(set(text.splitlines()), set(expected.splitlines()))

        def restore_test_pattern():
            ui.update_test_pattern()

        ui = self._create_ui("--list")
        rtl, tb = setup(ui)
        ui.update_test_pattern()
        check_stdout(ui, "lib1.tb0.Test 1\nlib2.tb1.all\nListed 2 tests")

        restore_test_pattern()
        ui.update_test_pattern(["*"])
        check_stdout(ui, "lib1.tb0.Test 1\nlib2.tb1.all\nListed 2 tests")

        restore_test_pattern()
        ui.update_test_pattern(exclude_dependent_on=["*"])
        check_stdout(ui, "Listed 0 tests")

        restore_test_pattern()
        ui.update_test_pattern(["*"], ["*"])
        check_stdout(ui, "Listed 0 tests")

        restore_test_pattern()
        ui.update_test_pattern([rtl[0]._source_file.name])
        check_stdout(ui, "lib1.tb0.Test 1\nlib2.tb1.all\nListed 2 tests")

        restore_test_pattern()
        ui.update_test_pattern([rtl[1]._source_file.name])
        check_stdout(ui, "lib1.tb0.Test 1\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern([Path(rtl[2]._source_file.name)])
        check_stdout(ui, "lib2.tb1.all\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern([rtl[3]._source_file.name])
        check_stdout(ui, "Listed 0 tests")

        restore_test_pattern()
        ui.update_test_pattern([Path(rtl[4]._source_file.name)])
        check_stdout(ui, "lib2.tb1.all\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern([tb[0]._source_file.name])
        check_stdout(ui, "lib1.tb0.Test 1\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern([tb[1]._source_file.name])
        check_stdout(ui, "lib2.tb1.all\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern([tb[1]._source_file.name, rtl[1]._source_file.name])
        check_stdout(ui, "lib1.tb0.Test 1\nlib2.tb1.all\nListed 2 tests")

        restore_test_pattern()
        ui.update_test_pattern([tb[1]._source_file.name, "Missing file"])
        check_stdout(ui, "lib2.tb1.all\nListed 1 tests")

        restore_test_pattern()
        a_dir = Path(tempdir) / "a_dir"
        a_dir.mkdir()
        ui.update_test_pattern([tb[1]._source_file.name, a_dir])
        check_stdout(ui, "lib2.tb1.all\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern([relative_tempdir / "rtl1*"])
        check_stdout(ui, "lib1.tb0.Test 1\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern(["./*rtl1*"])
        check_stdout(ui, "lib1.tb0.Test 1\nListed 1 tests")

        # Create a path that starts with ..
        path = Path(rtl[0]._source_file.name).resolve()
        path_relative_drive = path.relative_to(path.anchor)
        relative_path_to_drive = Path("../" * len(Path(".").resolve().parents))
        test_path = relative_path_to_drive / path_relative_drive
        ui.update_test_pattern([test_path])
        check_stdout(ui, "lib1.tb0.Test 1\nlib2.tb1.all\nListed 2 tests")

        restore_test_pattern()
        ui.update_test_pattern([tempdir / "rtl?.vhd"])
        check_stdout(ui, "lib1.tb0.Test 1\nlib2.tb1.all\nListed 2 tests")

        restore_test_pattern()
        ui.update_test_pattern([rtl[0]._source_file.name], [rtl[1]._source_file.name])
        check_stdout(ui, "lib2.tb1.all\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern([rtl[0]._source_file.name], [rtl[3]._source_file.name])
        check_stdout(ui, "lib1.tb0.Test 1\nlib2.tb1.all\nListed 2 tests")

        restore_test_pattern()
        ui.update_test_pattern([rtl[0]._source_file.name], [rtl[3]._source_file.name, rtl[4]._source_file.name])
        check_stdout(ui, "lib1.tb0.Test 1\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern(exclude_dependent_on=[rtl[4]._source_file.name])
        check_stdout(ui, "lib1.tb0.Test 1\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern(["*.v"])
        check_stdout(ui, "lib2.tb1.all\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern(exclude_dependent_on=["*.v"])
        check_stdout(ui, "lib1.tb0.Test 1\nListed 1 tests")

        restore_test_pattern()
        ui.update_test_pattern(["*.v"], ["*.v"])
        check_stdout(ui, "Listed 0 tests")

        restore_test_pattern()
        ui.update_test_pattern(set([rtl[0]._source_file.name]), set([rtl[3]._source_file.name]))
        check_stdout(ui, "lib1.tb0.Test 1\nlib2.tb1.all\nListed 2 tests")

        ui = self._create_ui("--list", "*tb0*")
        rtl, tb = setup(ui)
        ui.update_test_pattern([tb[1]._source_file.name])
        check_stdout(ui, "lib1.tb0.Test 1\nlib2.tb1.all\nListed 2 tests")

    def test_get_simulator_name(self):
        ui = self._create_ui()
        self.assertEqual(ui.get_simulator_name(), "mock")

    def _create_ui(self, *args):
        """Create an instance of the VUnit public interface class"""
        with mock.patch(
            "vunit.sim_if.factory.SIMULATOR_FACTORY.select_simulator",
            new=lambda: MockSimulator,
        ):
            return self._create_ui_real_sim(*args)

    def _create_ui_real_sim(self, *args):
        """Create an instance of the VUnit public interface class"""
        return VUnit.from_argv(
            argv=["--output-path=%s" % self._output_path, "--clean"] + list(args),
        )

    def _run_main(self, ui, code=0, post_run=None):
        """
        Run ui.main and expect exit code
        """
        try:
            ui.main(post_run=post_run)
        except SystemExit as exc:
            self.assertEqual(exc.code, code)

    def create_entity_file(self, idx=0, file_suffix=".vhd"):
        """
        Create and a temporary file containing the same source code
        but with different entity names depending on the index
        """
        source = Template(
            """
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
"""
        )

        entity_name = "ent%i" % idx
        file_name = entity_name + file_suffix
        self.create_file(file_name, source.substitute(entity=entity_name))
        return file_name

    @staticmethod
    def create_file(file_name, contents=""):
        """
        Creata file in the temporary path with given contents
        """
        if not isinstance(file_name, Path):
            file_name = Path(file_name)
        with file_name.open("w") as fptr:
            fptr.write(contents)

    @staticmethod
    def create_csv_file(file_name, contents=""):
        """
        Create a temporary csv description file with given contents
        """
        if not isinstance(file_name, Path):
            file_name = Path(file_name)
        with file_name.open("w") as fprt:
            fprt.write(contents)


class TestPreprocessor(object):
    """
    A preprocessor that adds a check_relation call before the orginal code
    """

    def __init__(self):
        pass

    @staticmethod
    def run(code, file_name):  # pylint: disable=unused-argument
        return "-- check_relation(a = b);\n" + code


class TestPreprocessor2(Preprocessor):
    """
    A preprocessor that adds a comment before the orginal code
    """

    def __init__(self, order):
        super().__init__(order)

    @staticmethod
    def run(code, file_name):  # pylint: disable=unused-argument
        return "-- TestPreprocessor2\n" + code


class VUnitfier(object):
    """
    A preprocessor that replaces report statments with log calls
    """

    def __init__(self):
        self._report_pattern = re.compile(r'^(?P<indent>\s*)report\s*(?P<note>"[^"]*")\s*;', MULTILINE)

    def run(self, code, file_name):  # pylint: disable=unused-argument
        return self._report_pattern.sub(
            r"\g<indent>log(\g<note>); -- VUnitfier preprocessor: Report turned off, keeping original code.",
            code,
        )


class ParentalControl(object):
    """
    A preprocessor that replaces f..k with [BEEP]
    """

    def __init__(self):
        self._fword_pattern = re.compile(r"f..k")

    def run(self, code, file_name):  # pylint: disable=unused-argument
        return self._fword_pattern.sub(r"[BEEP]", code)


class MockSimulator(SimulatorInterface):
    """
    Mock of a SimulatorInterface
    """

    name = "mock"

    @staticmethod
    def from_args(output_path, *args, **kwargs):  # pylint: disable=unused-argument
        return MockSimulator(output_path="", gui=False)

    package_users_depend_on_bodies = False

    @staticmethod
    def compile_source_file_command(source_file):  # pylint: disable=unused-argument
        return True

    @staticmethod
    def simulate(output_path, test_suite_name, config, elaborate_only):  # pylint: disable=unused-argument
        return True


def names(lst):
    """
    Return a list of the .name attribute of the objects in the list
    """
    return [obj.name for obj in lst]
