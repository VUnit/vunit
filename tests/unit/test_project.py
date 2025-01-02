# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-lines

"""
Test the project functionality
"""


import unittest
from pathlib import Path
import os
from shutil import rmtree
from time import sleep
import itertools
from unittest import mock
from vunit.exceptions import CompileError
from vunit.ostools import renew_path, write_file
from vunit.project import Project
from vunit.source_file import file_type_of


class TestProject(unittest.TestCase):  # pylint: disable=too-many-public-methods
    """
    Test the Project class
    """

    def setUp(self):
        self.output_path = str(Path(__file__).parent / "test_project_out")
        renew_path(self.output_path)
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if Path(self.output_path).exists():
            rmtree(self.output_path)

    def test_parses_entity_architecture(self):
        self.project.add_library("lib", "work_path")

        # Add architecture before entity to test that they are paired later
        self.add_source_file(
            "lib",
            "file2.vhd",
            """\
architecture arch3 of foo is
begin
end architecture;
""",
        )

        file1 = self.add_source_file(
            "lib",
            "file1.vhd",
            """\
entity foo is
end entity;

architecture arch of foo is
begin
end architecture;

architecture arch2 of foo is
begin
end architecture;
""",
        )

        self.assert_has_entity(file1, "foo", architecture_names=["arch", "arch2", "arch3"])
        self.add_source_file(
            "lib",
            "file3.vhd",
            """\
architecture arch4 of foo is
begin
end architecture;
""",
        )

        self.assert_has_entity(file1, "foo", architecture_names=["arch", "arch2", "arch3", "arch4"])
        self.assert_has_architecture("file1.vhd", "arch", "foo")
        self.assert_has_architecture("file1.vhd", "arch2", "foo")
        self.assert_has_architecture("file2.vhd", "arch3", "foo")
        self.assert_has_architecture("file3.vhd", "arch4", "foo")

    def test_parses_entity_architecture_with_generics(self):
        self.project.add_library("lib", "work_path")
        file1 = self.add_source_file(
            "lib",
            "file1.vhd",
            """\
entity foo is
  generic (
    testing_that_foo : boolean;
    testing_that_bar : boolean);
end entity;

architecture arch of foo is
begin
end architecture;
""",
        )

        self.assert_has_entity(
            file1,
            "foo",
            generic_names=["testing_that_bar", "testing_that_foo"],
            architecture_names=["arch"],
        )
        self.assert_has_architecture("file1.vhd", "arch", "foo")

    def test_parses_package(self):
        self.project.add_library("lib", "work_path")
        self.add_source_file(
            "lib",
            "file1.vhd",
            """\
package foo is
end package;

package body foo is
begin
end package body;
""",
        )
        self.assert_has_package("file1.vhd", "foo")
        self.assert_has_package_body("file1.vhd", "foo")

    @mock.patch("vunit.source_file.LOGGER")
    def test_recovers_from_parse_error(self, logger):
        self.project.add_library("lib", "work_path")
        source_file = self.add_source_file(
            "lib",
            "file.vhd",
            """\
entity foo is
 port (foo : in bit;
end entity;
""",
        )
        logger.error.assert_called_once_with("Failed to parse %s", "file.vhd")
        self.assertEqual(source_file.design_units, [])

    def test_finds_entity_instantiation_dependencies(self):
        file1, file2, file3 = self.create_dummy_three_file_project()

        self.assert_compiles(file1, before=file2)
        self.assert_compiles(file2, before=file3)

    def test_primary_with_same_name_in_multiple_libraries_secondary_dependency(self):
        self.project.add_library("lib1", "lib1_path")
        self.project.add_library("lib2", "lib2_path")

        foo_arch = self.add_source_file(
            "lib1",
            "foo_arch.vhd",
            """
architecture arch of foo is
begin
end architecture;
""",
        )

        foo1_ent = self.add_source_file(
            "lib1",
            "foo1_ent.vhd",
            """
entity foo is
port (signal bar : boolean);
end entity;
""",
        )

        self.add_source_file(
            "lib2",
            "foo2_ent.vhd",
            """
entity foo is
end entity;
""",
        )

        self.assert_compiles(foo1_ent, before=foo_arch)

    def test_multiple_identical_file_names_with_different_path_in_same_library(self):
        self.project.add_library("lib", "lib_path")
        a_foo = self.add_source_file(
            "lib",
            str(Path("a") / "foo.vhd"),
            """
entity a_foo is
end entity;
""",
        )

        b_foo = self.add_source_file(
            "lib",
            str(Path("b") / "foo.vhd"),
            """
entity b_foo is
end entity;
""",
        )
        self.assert_should_recompile([a_foo, b_foo])
        self.update(a_foo)
        self.assert_should_recompile([b_foo])
        self.update(b_foo)
        self.assert_should_recompile([])

    def test_finds_entity_architecture_dependencies(self):
        self.project.add_library("lib", "lib_path")
        entity = self.add_source_file(
            "lib",
            "entity.vhd",
            """
entity foo is
end entity;
""",
        )

        arch1 = self.add_source_file(
            "lib",
            "arch1.vhd",
            """
architecture arch1 of foo is
begin
end architecture;
""",
        )

        arch2 = self.add_source_file(
            "lib",
            "arch2.vhd",
            """
architecture arch2 of foo is
begin
end architecture;
""",
        )
        self.assert_compiles(entity, before=arch1)
        self.assert_compiles(entity, before=arch2)

    def test_finds_package_dependencies(self):
        self.project.add_library("lib", "lib_path")
        package = self.add_source_file(
            "lib",
            "package.vhd",
            """
package foo is
end package;
""",
        )

        body = self.add_source_file(
            "lib",
            "body.vhd",
            """
package body foo is
begin
end package body;
""",
        )

        self.assert_compiles(package, before=body)

    def create_module_package_and_body(self, add_body=True):
        """
        Help function to create a three file project
        with a package, a package body and a module using the package
        """
        self.project.add_library("lib", "lib_path")

        package = self.add_source_file(
            "lib",
            "package.vhd",
            """
package pkg is
end package;
""",
        )

        body = None
        if add_body:
            body = self.add_source_file(
                "lib",
                "body.vhd",
                """
package body pkg is
begin
end package body;
""",
            )

        self.project.add_library("lib2", "work_path")
        module = self.add_source_file(
            "lib2",
            "module.vhd",
            """
library lib;
use lib.pkg.all;

entity module is
end entity;

architecture arch of module is
begin
end architecture;
""",
        )
        return package, body, module

    def test_finds_use_package_dependencies_case_insensitive(self):
        for library_clause, use_clause in itertools.combinations(("lib", "Lib"), 2):
            self.project = Project()
            self.project.add_library("Lib", "lib_path")

            package = self.add_source_file(
                "Lib",
                "package.vhd",
                """
package pkg is
end package;

package body PKG is
begin
end package body;
""",
            )

            self.project.add_library("lib2", "lib2_path")
            module = self.add_source_file(
                "lib2",
                "module.vhd",
                """
library {library_clause};
use {use_clause}.PKG.all;
            """.format(
                    library_clause=library_clause, use_clause=use_clause
                ),
            )
            self.assert_compiles(package, before=module)

    def test_error_on_case_insensitive_library_name_conflict(self):
        self.project.add_library("Lib", "lib_path1")
        try:
            self.project.add_library("lib", "lib_path1")
        except RuntimeError as exception:
            self.assertEqual(
                str(exception),
                "Library name 'lib' not case-insensitive unique. " "Library name 'Lib' previously defined",
            )
        else:
            raise AssertionError("RuntimeError not raised")

    def test_finds_use_package_dependencies(self):
        package, body, module = self.create_module_package_and_body()
        self.assert_compiles(package, before=body)
        self.assert_compiles(package, before=module)
        self.assert_not_compiles(body, before=module)

    def test_finds_extra_package_body_dependencies(self):
        self.project = Project(depend_on_package_body=True)
        package, body, module = self.create_module_package_and_body()
        self.assert_compiles(package, before=body)
        self.assert_compiles(body, before=module)
        self.assert_compiles(package, before=module)

    def test_that_package_can_have_no_body(self):
        self.project = Project(depend_on_package_body=True)
        package, _, module = self.create_module_package_and_body(add_body=False)
        self.assert_compiles(package, before=module)

    def test_package_instantiation_dependencies_on_generic_package(self):
        self.project.add_library("pkg_lib", "pkg_lib_path")
        pkg = self.add_source_file(
            "pkg_lib",
            "pkg.vhd",
            """
package pkg is
end package;
        """,
        )

        self.project.add_library("lib", "lib_path")
        ent = self.add_source_file(
            "lib",
            "ent.vhd",
            """
library pkg_lib;

entity ent is
end entity;

architecture a of ent is
   package pkg_inst is new pkg_lib.pkg;
begin
end architecture;
""",
        )

        self.assert_compiles(pkg, before=ent)

    def test_package_instantiation_dependencies_on_instantiated_package(self):
        self.project.add_library("lib", "lib_path")
        generic_pkg = self.add_source_file(
            "lib",
            "generic_pkg.vhd",
            """
package generic_pkg is
  generic (foo : boolean);
end package;
""",
        )
        instance_pkg = self.add_source_file(
            "lib",
            "instance_pkg.vhd",
            """
package instance_pkg is new work.generic_pkg
  generic map (foo => false);
""",
        )
        user = self.add_source_file(
            "lib",
            "user.vhd",
            """
use work.instance_pkg;
""",
        )
        self.assert_compiles(generic_pkg, before=instance_pkg)
        self.assert_compiles(instance_pkg, before=user)

    def test_finds_context_dependencies(self):
        self.project.add_library("lib", "lib_path")
        context = self.add_source_file(
            "lib",
            "context.vhd",
            """
context foo is
end context;
""",
        )

        self.project.add_library("lib2", "work_path")
        module = self.add_source_file(
            "lib2",
            "module.vhd",
            """
library lib;
context lib.foo;

entity module is
end entity;

architecture arch of module is
begin
end architecture;
""",
        )

        self.assert_compiles(context, before=module)

    def test_finds_configuration_dependencies(self):
        self.project.add_library("lib", "lib_path")
        cfg = self.add_source_file(
            "lib",
            "cfg.vhd",
            """
configuration cfg of ent is
end configuration;
""",
        )

        ent = self.add_source_file(
            "lib",
            "ent.vhd",
            """
entity ent is
end entity;
""",
        )

        ent_a1 = self.add_source_file(
            "lib",
            "ent_a1.vhd",
            """
architecture a1 of ent is
begin
end architecture;
""",
        )

        ent_a2 = self.add_source_file(
            "lib",
            "ent_a2.vhd",
            """
architecture a2 of ent is
begin
end architecture;
""",
        )

        self.assert_compiles(ent, before=cfg)
        self.assert_compiles(ent_a1, before=cfg)
        self.assert_compiles(ent_a2, before=cfg)

    def test_finds_configuration_reference_dependencies(self):
        self.project.add_library("lib", "lib_path")
        cfg = self.add_source_file(
            "lib",
            "cfg.vhd",
            """
configuration cfg of ent is
end configuration;
""",
        )

        self.add_source_file(
            "lib",
            "ent.vhd",
            """
entity ent is
end entity;
""",
        )

        self.add_source_file(
            "lib",
            "ent_a.vhd",
            """
architecture a of ent is
begin
end architecture;
""",
        )

        top = self.add_source_file(
            "lib",
            "top.vhd",
            """
entity top is
end entity;

architecture a of top is
   for inst : comp use configuration work.cfg;
begin
   inst : comp;
end architecture;
""",
        )

        self.assert_compiles(cfg, before=top)

    def test_specific_architecture_reference_dependencies(self):
        """
        GHDL dependes also on architecture when specificially mentioned
        """
        self.project.add_library("lib", "lib_path")

        self.add_source_file(
            "lib",
            "ent.vhd",
            """
entity ent is
end entity;
""",
        )

        ent_a1 = self.add_source_file(
            "lib",
            "ent_a1.vhd",
            """
architecture a1 of ent is
begin
end architecture;
""",
        )

        ent_a2 = self.add_source_file(
            "lib",
            "ent_a2.vhd",
            """
architecture a2 of ent is
begin
end architecture;
""",
        )

        top1 = self.add_source_file(
            "lib",
            "top1.vhd",
            """
entity top1 is
end entity;

architecture a of top1 is
begin
  inst : entity work.ent(a1);
end architecture;
""",
        )

        top2 = self.add_source_file(
            "lib",
            "top2.vhd",
            """
entity top2 is
end entity;

architecture a of top2 is
  for inst : comp use entity work.ent(a2);
begin
  inst : comp;
end architecture;
""",
        )

        self.assert_compiles(ent_a1, before=top1)
        self.assert_compiles(ent_a2, before=top2)

    def test_error_on_ambiguous_architecture(self):
        self.project.add_library("lib", "lib_path")

        self.add_source_file(
            "lib",
            "ent.vhd",
            """
entity ent is
end entity;
""",
        )

        self.add_source_file(
            "lib",
            "ent_a1.vhd",
            """
architecture a1 of ent is
begin
end architecture;
""",
        )

        self.add_source_file(
            "lib",
            "ent_a2.vhd",
            """
architecture a2 of ent is
begin
end architecture;
""",
        )

        self.add_source_file(
            "lib",
            "top.vhd",
            """
entity top is
end entity;

architecture a of top is
begin
  inst : entity work.ent;
end architecture;
""",
        )
        self.assertRaises(
            RuntimeError,
            self.project.create_dependency_graph,
        )

    def test_work_library_reference_non_lower_case(self):
        """
        Bug discovered in #556
        """
        self.project.add_library("UPPER", "lib_path")

        self.add_source_file(
            "UPPER",
            "ent.vhd",
            """
entity ent is
end entity;
""",
        )

        ent_a1 = self.add_source_file(
            "UPPER",
            "ent_a1.vhd",
            """
architecture a1 of ent is
begin
end architecture;
""",
        )

        top1 = self.add_source_file(
            "UPPER",
            "top1.vhd",
            """
entity top1 is
end entity;

architecture a of top1 is
begin
  inst : entity work.ent(a1);
end architecture;
""",
        )

        self.assert_compiles(ent_a1, before=top1)

    @mock.patch("vunit.project.LOGGER")
    def test_warning_on_missing_specific_architecture_reference(self, mock_logger):
        self.project.add_library("lib", "lib_path")

        self.add_source_file(
            "lib",
            "ent.vhd",
            """
entity ent is
end entity;
""",
        )

        self.add_source_file(
            "lib",
            "arch.vhd",
            """
architecture a1 of ent is
begin
end architecture;
""",
        )

        self.add_source_file(
            "lib",
            "top.vhd",
            """
entity top1 is
end entity;

architecture a of top1 is
begin
  inst1 : entity work.ent(a1);
  inst2 : entity work.ent(a2); # Missing
end architecture;
""",
        )

        self.project.get_files_in_compile_order()
        warning_calls = mock_logger.warning.call_args_list
        log_msg = warning_calls[0][0][0] % warning_calls[0][0][1:]
        self.assertEqual(len(warning_calls), 1)
        self.assertIn("top.vhd", log_msg)
        self.assertIn("a2", log_msg)
        self.assertIn("lib.ent", log_msg)

    @mock.patch("vunit.project.LOGGER")
    def test_error_on_duplicate_file(self, logger):
        self.project.add_library("lib", "lib_path")
        file1 = self.add_source_file("lib", "file.vhd", "entity foo is end entity;")
        self.assertRaises(
            RuntimeError,
            self.add_source_file,
            "lib",
            "file.vhd",
            "entity foo is end entity foo;",
        )

        # No extra design unit of file added
        lib = self.project.get_library("lib")
        self.assertEqual([ent.name for ent in lib.get_entities()], ["foo"])
        self.assertEqual(lib.get_source_file("file.vhd"), file1)
        self.assertEqual(self.project.get_source_files_in_order(), [file1])
        self.assertFalse(logger.warning.called)

    @mock.patch("vunit.library.LOGGER")
    def test_no_error_on_duplicate_identical_file(self, logger):
        self.project.add_library("lib", "lib_path")
        file1 = self.add_source_file("lib", "file.vhd", "entity foo is end entity;")
        file2 = self.add_source_file("lib", "file.vhd", "entity foo is end entity;")
        self.assertEqual(id(file1), id(file2))

        # No extra design unit of file added
        lib = self.project.get_library("lib")
        self.assertEqual([ent.name for ent in lib.get_entities()], ["foo"])
        self.assertEqual(lib.get_source_file("file.vhd"), file1)
        self.assertEqual(self.project.get_source_files_in_order(), [file1])
        self.assertTrue(logger.info.called)

    def _test_warning_on_duplicate(self, code, message, verilog=False):
        """
        Utility function to test adding the same duplicate code under
        file.vhd and file_copy.vhd where the duplication should cause a warning message.
        """
        suffix = "v" if verilog else "vhd"

        self.add_source_file("lib", "file." + suffix, code)

        with mock.patch("vunit.library.LOGGER") as mock_logger:
            self.add_source_file("lib", "file_copy." + suffix, code)
            warning_calls = mock_logger.warning.call_args_list
            log_msg = warning_calls[0][0][0] % warning_calls[0][0][1:]
            self.assertEqual(len(warning_calls), 1)
            self.assertEqual(log_msg, message)

    def test_warning_on_duplicate_entity(self):
        self.project.add_library("lib", "lib_path")
        self._test_warning_on_duplicate(
            """
entity ent is
end entity;
""",
            "file_copy.vhd: entity 'ent' previously defined in file.vhd",
        )

    def test_warning_on_duplicate_package(self):
        self.project.add_library("lib", "lib_path")
        self._test_warning_on_duplicate(
            """
package pkg is
end package;
""",
            "file_copy.vhd: package 'pkg' previously defined in file.vhd",
        )

    def test_warning_on_duplicate_configuration(self):
        self.project.add_library("lib", "lib_path")
        self._test_warning_on_duplicate(
            """
configuration cfg of ent is
end configuration;
""",
            "file_copy.vhd: configuration 'cfg' previously defined in file.vhd",
        )

    def test_warning_on_duplicate_package_body(self):
        self.project.add_library("lib", "lib_path")
        self.add_source_file(
            "lib",
            "pkg.vhd",
            """
package pkg is
end package;
""",
        )

        self._test_warning_on_duplicate(
            """
package body pkg is
end package bodY;
""",
            "file_copy.vhd: package body 'pkg' previously defined in file.vhd",
        )

    def test_warning_on_duplicate_architecture(self):
        self.project.add_library("lib", "lib_path")
        self.add_source_file(
            "lib",
            "ent.vhd",
            """
entity ent is
end entity;
""",
        )

        self.add_source_file(
            "lib",
            "arch.vhd",
            """
architecture a_no_duplicate of ent is
begin
end architecture;
""",
        )

        self._test_warning_on_duplicate(
            """
architecture a of ent is
begin
end architecture;
""",
            "file_copy.vhd: architecture 'a' previously defined in file.vhd",
        )

    def test_warning_on_duplicate_context(self):
        self.project.add_library("lib", "lib_path")
        self._test_warning_on_duplicate(
            """
context ctx is
end context;
""",
            "file_copy.vhd: context 'ctx' previously defined in file.vhd",
        )

    def test_error_on_adding_duplicate_library(self):
        self.project.add_library(logical_name="lib", directory="dir")
        self.assertRaises(ValueError, self.project.add_library, logical_name="lib", directory="dir")

    def test_warning_on_duplicate_verilog_module(self):
        self.project.add_library("lib", "lib_path")
        self._test_warning_on_duplicate(
            """
module foo;
endmodule
""",
            "file_copy.v: module 'foo' previously defined in file.v",
            verilog=True,
        )

    def test_warning_on_duplicate_verilog_package(self):
        self.project.add_library("lib", "lib_path")
        self._test_warning_on_duplicate(
            """
package pkg;
endpackage
""",
            "file_copy.v: package 'pkg' previously defined in file.v",
            verilog=True,
        )

    def test_should_recompile_all_files_initially(self):
        file1, file2, file3 = self.create_dummy_three_file_project()
        self.assert_should_recompile([file1, file2, file3])
        self.assert_should_recompile([file1, file2, file3])

    def test_updating_creates_hash_files(self):
        files = self.create_dummy_three_file_project()

        for source_file in files:
            self.update(source_file)
            self.assertTrue(Path(self.hash_file_name_of(source_file)).exists())

    def test_should_not_recompile_updated_files(self):
        file1, file2, file3 = self.create_dummy_three_file_project()

        self.update(file1)
        self.assert_should_recompile([file2, file3])

        self.update(file2)
        self.assert_should_recompile([file3])

        self.update(file3)
        self.assert_should_recompile([])

    def test_should_recompile_files_affected_by_change(self):
        file1, file2, file3 = self.create_dummy_three_file_project()

        self.update(file1)
        self.update(file2)
        self.update(file3)
        self.assert_should_recompile([])

        file1, file2, file3 = self.create_dummy_three_file_project()
        self.assert_should_recompile([])

        file1, file2, file3 = self.create_dummy_three_file_project(update_file1=True)
        self.assert_should_recompile([file1, file2, file3])

    def test_should_recompile_files_after_changing_compile_options(self):
        file1, file2, file3 = self.create_dummy_three_file_project()

        self.update(file1)
        self.update(file2)
        self.update(file3)
        self.assert_should_recompile([])

        file2.set_compile_option("ghdl.a_flags", ["--no-vital-checks"])
        self.assert_should_recompile([file2, file3])

    def test_should_recompile_files_after_changing_vhdl_standard(self):
        write_file("file_name.vhd", "")

        self.project = Project()
        self.project.add_library("lib", "lib_path")
        source_file = self.project.add_source_file("file_name.vhd", library_name="lib", vhdl_standard="2008")
        self.assert_should_recompile([source_file])
        self.update(source_file)
        self.assert_should_recompile([])

        self.project = Project()
        self.project.add_library("lib", "lib_path")
        source_file = self.project.add_source_file("file_name.vhd", library_name="lib", vhdl_standard="2002")
        self.assert_should_recompile([source_file])

    def test_add_compile_option(self):
        self.project.add_library("lib", "lib_path")
        file1 = self.add_source_file("lib", "file.vhd", "")
        file1.add_compile_option("ghdl.a_flags", ["--foo"])
        self.assertEqual(file1.get_compile_option("ghdl.a_flags"), ["--foo"])
        file1.add_compile_option("ghdl.a_flags", ["--bar"])
        self.assertEqual(file1.get_compile_option("ghdl.a_flags"), ["--foo", "--bar"])
        file1.set_compile_option("ghdl.a_flags", ["--xyz"])
        self.assertEqual(file1.get_compile_option("ghdl.a_flags"), ["--xyz"])

    def test_add_compile_option_does_not_mutate_argument(self):
        self.project.add_library("lib", "lib_path")
        file1 = self.add_source_file("lib", "file.vhd", "")
        options = ["--foo"]
        file1.add_compile_option("ghdl.a_flags", options)
        options[0] = "--xyz"
        self.assertEqual(file1.get_compile_option("ghdl.a_flags"), ["--foo"])
        file1.add_compile_option("ghdl.a_flags", ["--bar"])
        self.assertEqual(options, ["--xyz"])

    def test_set_compile_option_does_not_mutate_argument(self):
        self.project.add_library("lib", "lib_path")
        file1 = self.add_source_file("lib", "file.vhd", "")
        options = ["--foo"]
        file1.set_compile_option("ghdl.a_flags", options)
        options[0] = "--xyz"
        self.assertEqual(file1.get_compile_option("ghdl.a_flags"), ["--foo"])

    def test_compile_option_validation(self):
        self.project.add_library("lib", "lib_path")
        source_file = self.add_source_file("lib", "file.vhd", "")
        self.assertRaises(ValueError, source_file.set_compile_option, "foo", None)
        self.assertRaises(ValueError, source_file.set_compile_option, "ghdl.a_flags", None)
        self.assertRaises(ValueError, source_file.add_compile_option, "ghdl.a_flags", None)
        self.assertRaises(ValueError, source_file.get_compile_option, "foo")

    def test_should_recompile_files_affected_by_change_with_later_timestamp(self):
        file1, file2, file3 = self.create_dummy_three_file_project()

        self.update(file1)
        self.update(file2)
        self.update(file3)
        self.assert_should_recompile([])

        file1, file2, file3 = self.create_dummy_three_file_project()
        self.assert_should_recompile([])

        file1, file2, file3 = self.create_dummy_three_file_project(update_file1=True)
        self.assert_should_recompile([file1, file2, file3])

        tick()
        self.update(file1)
        self.assert_should_recompile([file2, file3])

    def test_should_recompile_files_missing_hash(self):
        file1, file2, file3 = self.create_dummy_three_file_project()

        self.update(file1)
        self.update(file2)
        self.update(file3)
        self.assert_should_recompile([])

        os.remove(self.hash_file_name_of(file2))
        self.assert_should_recompile([file2, file3])

    def test_finds_component_instantiation_dependencies(self):
        self.project.add_library("toplib", "work_path")
        top = self.add_source_file(
            "toplib",
            "top.vhd",
            """\
entity top is
end entity;

architecture arch of top is
begin
    labelFoo : component foo
    generic map(WIDTH => 16)
    port map(clk => '1',
             rst => '0',
             in_vec => record_reg.input_signal,
             output => some_signal(UPPER_CONSTANT-1 downto LOWER_CONSTANT+1));

    label2Foo : foo2
    port map(clk => '1',
             rst => '0',
             output => "00");
end architecture;
""",
        )

        comp1 = self.add_source_file(
            "toplib",
            "comp1.vhd",
            """\
entity foo is
end entity;
""",
        )

        comp2 = self.add_source_file(
            "toplib",
            "comp2.vhd",
            """\
entity foo2 is
end entity;

architecture arch of foo2 is
begin
end architecture;
""",
        )
        comp1_arch = self.add_source_file(
            "toplib",
            "comp1_arch.vhd",
            """\
architecture arch of foo is
begin
end architecture;
""",
        )

        self.assert_has_component_instantiation("top.vhd", "foo")
        self.assert_has_component_instantiation("top.vhd", "foo2")
        dependencies = self.project.get_dependencies_in_compile_order([top], implementation_dependencies=True)
        self.assertIn(comp1, dependencies)
        self.assertIn(comp1_arch, dependencies)
        self.assertIn(comp2, dependencies)

    def test_get_minimal_file_set_in_compile_order_without_target(self):
        self.create_dummy_three_file_project()
        deps = self.project.get_minimal_file_set_in_compile_order()
        self.assertEqual(len(deps), 3)
        self.assertTrue(deps[0] == self.project.get_source_files_in_order()[0])
        self.assertTrue(deps[1] == self.project.get_source_files_in_order()[1])
        self.assertTrue(deps[2] == self.project.get_source_files_in_order()[2])

    def test_get_minimal_file_set_in_compile_order_with_target(self):
        self.create_dummy_three_file_project()
        deps = self.project.get_minimal_file_set_in_compile_order(
            target_files=[self.project.get_source_files_in_order()[1]]
        )
        self.assertEqual(len(deps), 2)
        self.assertTrue(deps[0] == self.project.get_source_files_in_order()[0])
        self.assertTrue(deps[1] == self.project.get_source_files_in_order()[1])

        # To test that indirect dependencies are included
        deps = self.project.get_dependencies_in_compile_order(
            target_files=[self.project.get_source_files_in_order()[2]]
        )
        self.assertEqual(len(deps), 3)
        self.assertTrue(deps[0] == self.project.get_source_files_in_order()[0])
        self.assertTrue(deps[1] == self.project.get_source_files_in_order()[1])
        self.assertTrue(deps[2] == self.project.get_source_files_in_order()[2])

    def test_get_dependencies_in_compile_order_without_target(self):
        self.create_dummy_three_file_project()
        deps = self.project.get_dependencies_in_compile_order()
        self.assertEqual(len(deps), 3)
        self.assertTrue(deps[0] == self.project.get_source_files_in_order()[0])
        self.assertTrue(deps[1] == self.project.get_source_files_in_order()[1])
        self.assertTrue(deps[2] == self.project.get_source_files_in_order()[2])

    def test_get_dependencies_in_compile_order_with_target(self):
        self.create_dummy_three_file_project()
        deps = self.project.get_dependencies_in_compile_order(
            target_files=[self.project.get_source_files_in_order()[1]]
        )
        self.assertEqual(len(deps), 2)
        self.assertTrue(deps[0] == self.project.get_source_files_in_order()[0])
        self.assertTrue(deps[1] == self.project.get_source_files_in_order()[1])

        # To test that indirect dependencies are included
        deps = self.project.get_dependencies_in_compile_order(
            target_files=[self.project.get_source_files_in_order()[2]]
        )
        self.assertEqual(len(deps), 3)
        self.assertTrue(deps[0] == self.project.get_source_files_in_order()[0])
        self.assertTrue(deps[1] == self.project.get_source_files_in_order()[1])
        self.assertTrue(deps[2] == self.project.get_source_files_in_order()[2])

    def test_compiles_same_file_into_different_libraries(self):
        pkgs = []
        second_pkgs = []
        self.project.add_library("lib", "lib_path")

        other_pkg = self.add_source_file(
            "lib",
            "other_pkg.vhd",
            """
package other_pkg is
end package other_pkg;
""",
        )

        for lib in ["lib1", "lib2"]:
            self.project.add_library(lib, lib + "_path")
            pkgs.append(
                self.add_source_file(
                    lib,
                    "pkg.vhd",
                    """
library lib;
use lib.other_pkg.all;

package pkg is
end package pkg;
""",
                )
            )

            second_pkgs.append(
                self.add_source_file(
                    lib,
                    lib + "_pkg.vhd",
                    """
use work.pkg.all;

package second_pkg is
end package second_pkg;
""",
                )
            )

        self.assertNotEqual(self.hash_file_name_of(pkgs[0]), self.hash_file_name_of(pkgs[1]))
        self.assertEqual(len(self.project.get_files_in_compile_order()), 5)
        self.assert_compiles(other_pkg, before=pkgs[0])
        self.assert_compiles(other_pkg, before=pkgs[1])
        self.assert_compiles(pkgs[0], before=second_pkgs[0])
        self.assert_compiles(pkgs[1], before=second_pkgs[1])

    def test_has_verilog_module(self):
        self.project.add_library("lib", "lib_path")
        self.add_source_file(
            "lib",
            "module.v",
            """\
module name;
endmodule
""",
        )
        library = self.project.get_library("lib")
        modules = library.get_modules()
        self.assertEqual(len(modules), 1)

    def test_finds_verilog_package_import_dependencies(self):
        self.project.add_library("lib", "lib_path")
        pkg = self.add_source_file(
            "lib",
            "pkg.sv",
            """\
package pkg;
endpackage
""",
        )
        module = self.add_source_file(
            "lib",
            "module.sv",
            """\
module name;
  import pkg::*;
endmodule
""",
        )
        self.assert_compiles(pkg, before=module)

    def test_finds_verilog_package_reference_dependencies(self):
        self.project.add_library("lib", "lib_path")
        pkg = self.add_source_file(
            "lib",
            "pkg.sv",
            """\
package pkg;
endpackage
""",
        )
        module = self.add_source_file(
            "lib",
            "module.sv",
            """\
module name;
  pkg::func();
endmodule
""",
        )
        self.assert_compiles(pkg, before=module)

    def test_verilog_package_reference_is_case_sensitive(self):
        self.project = Project()
        self.project.add_library("lib", "lib_path")
        pkg = self.add_source_file(
            "lib",
            "pkg.sv",
            """\
package Pkg;
endpackage
""",
        )
        module = self.add_source_file(
            "lib",
            "module.sv",
            """\
module name;
  pkg::func();
endmodule
""",
        )
        self.assert_not_compiles(pkg, before=module)

        self.project = Project()
        self.project.add_library("lib", "lib_path")
        pkg = self.add_source_file(
            "lib",
            "pkg.sv",
            """\
package pkg;
endpackage
""",
        )
        module = self.add_source_file(
            "lib",
            "module.sv",
            """\
module name;
  Pkg::func();
endmodule
""",
        )
        self.assert_not_compiles(pkg, before=module)

    def test_finds_verilog_module_instantiation_dependencies(self):
        self.project.add_library("lib", "lib_path")
        module1 = self.add_source_file(
            "lib",
            "module1.sv",
            """\
module module1;
endmodule
""",
        )
        module2 = self.add_source_file(
            "lib",
            "module2.sv",
            """\
module module2;
  module1 inst();
endmodule
""",
        )
        self.assert_compiles(module1, before=module2)

    def test_verilog_module_instantiation_is_case_sensitive(self):
        self.project = Project()
        self.project.add_library("lib", "lib_path")
        module1 = self.add_source_file(
            "lib",
            "module1.sv",
            """\
module Module1;
endmodule
""",
        )
        module2 = self.add_source_file(
            "lib",
            "module2.sv",
            """\
module module2;
  module1 inst();
endmodule
""",
        )
        self.assert_not_compiles(module1, before=module2)

        self.project = Project()
        self.project.add_library("lib", "lib_path")
        module1 = self.add_source_file(
            "lib",
            "module1.sv",
            """\
module module1;
endmodule
""",
        )
        module2 = self.add_source_file(
            "lib",
            "module2.sv",
            """\
module module2;
  Module1 inst();
endmodule
""",
        )
        self.assert_not_compiles(module1, before=module2)

    def test_finds_verilog_module_instantiation_dependencies_in_vhdl(self):
        self.project.add_library("lib1", "lib_path")
        self.project.add_library("lib2", "lib_path")
        module1 = self.add_source_file(
            "lib1",
            "module1.sv",
            """\
module module1;
endmodule
""",
        )
        module2 = self.add_source_file(
            "lib2",
            "module2.vhd",
            """\
library lib1;

entity ent is
end entity;

architecture a of ent is
begin
  inst : entity lib1.module1;
end architecture;
""",
        )
        self.assert_compiles(module1, before=module2)

    def test_finds_verilog_include_dependencies(self):
        def create_project():
            """
            Create the test project
            """
            self.project = Project()
            self.project.add_library("lib", "lib_path")
            return self.add_source_file(
                "lib",
                "module.sv",
                """\
`include "include.svh"
""",
            )

        write_file(
            "include.svh",
            """\
module name;
endmodule
""",
        )
        module = create_project()
        self.assert_should_recompile([module])

        for src_file in self.project.get_files_in_compile_order():
            self.update(src_file)
        create_project()
        self.assert_should_recompile([])

        write_file(
            "include.svh",
            """\
module other_name;
endmodule
""",
        )
        module = create_project()
        self.assert_should_recompile([module])

    def test_verilog_defines_affects_dependency_scanning(self):
        self.project.add_library("lib", "lib_path")
        self.add_source_file(
            "lib",
            "module.v",
            """\
`ifdef foo
module mod;
endmodule
`endif
""",
        )
        library = self.project.get_library("lib")
        modules = library.get_modules()
        self.assertEqual(len(modules), 0)

        self.project = Project()
        self.project.add_library("lib", "lib_path")
        self.add_source_file(
            "lib",
            "module.v",
            """\
`ifdef foo
module mod;
endmodule
`endif
""",
            defines={"foo": ""},
        )
        library = self.project.get_library("lib")
        modules = library.get_modules()
        self.assertEqual(len(modules), 1)

    def test_recompile_when_updating_defines(self):
        contents1 = """
module mod1;
endmodule
"""
        contents2 = """
module mod2;
endmodule
"""
        self.project = Project()
        self.project.add_library("lib", "lib_path")
        mod1 = self.add_source_file("lib", "module1.v", contents1)
        mod2 = self.add_source_file("lib", "module2.v", contents2)
        self.assert_should_recompile([mod1, mod2])
        self.update(mod1)
        self.update(mod2)
        self.assert_should_recompile([])

        self.project = Project()
        self.project.add_library("lib", "lib_path")
        mod1 = self.add_source_file("lib", "module1.v", contents1, defines={"foo": "bar"})
        mod2 = self.add_source_file("lib", "module2.v", contents2)
        self.assert_should_recompile([mod1])
        self.update(mod1)
        self.update(mod2)
        self.assert_should_recompile([])

        self.project = Project()
        self.project.add_library("lib", "lib_path")
        mod1 = self.add_source_file("lib", "module1.v", contents1, defines={"foo": "other_bar"})
        mod2 = self.add_source_file("lib", "module2.v", contents2)
        self.assert_should_recompile([mod1])
        self.update(mod1)
        self.update(mod2)
        self.assert_should_recompile([])

    def test_manual_dependencies(self):
        self.project.add_library("lib", "lib_path")
        ent1 = self.add_source_file(
            "lib",
            "ent1.vhd",
            """\
entity ent1 is
end ent1;

architecture arch of ent1 is
begin
end architecture;
""",
        )

        ent2 = self.add_source_file(
            "lib",
            "ent2.vhd",
            """\
entity ent2 is
end ent2;

architecture arch of ent2 is
begin
end architecture;
""",
        )

        self.project.add_manual_dependency(ent2, depends_on=ent1)
        self.assert_compiles(ent1, before=ent2)

    @mock.patch("vunit.project.LOGGER", autospec=True)
    def test_circular_dependencies_causes_error(self, logger):
        self.project.add_library("lib", "lib_path")
        self.add_source_file(
            "lib",
            "ent1.vhd",
            """\
entity ent1 is
end ent1;

architecture arch of ent1 is
begin
   ent2_inst : entity work.ent2;
end architecture;
""",
        )

        self.add_source_file(
            "lib",
            "ent2.vhd",
            """\
entity ent2 is
end ent2;

architecture arch of ent2 is
begin
   ent1_inst : entity work.ent1;
end architecture;
""",
        )

        self.assertRaises(CompileError, self.project.get_files_in_compile_order)
        logger.error.assert_called_once_with(
            "Found circular dependency:\n%s", "ent1.vhd ->\n" "ent2.vhd ->\n" "ent1.vhd"
        )

    def test_order_of_adding_libraries_is_kept(self):
        for order in itertools.combinations(range(4), 4):
            project = Project()
            for idx in order:
                project.add_library("lib%i" % idx, "lib%i_path" % idx)

            library_names = [lib.name for lib in project.get_libraries()]
            self.assertEqual(library_names, ["lib%i" % idx for idx in order])

    def test_file_type_of(self):
        self.assertEqual(file_type_of("file.vhd"), "vhdl")
        self.assertEqual(file_type_of("file.vhdl"), "vhdl")
        self.assertEqual(file_type_of("file.sv"), "systemverilog")
        self.assertEqual(file_type_of("file.v"), "verilog")
        self.assertEqual(file_type_of("file.vams"), "verilog")
        self.assertRaises(RuntimeError, file_type_of, "file.foo")

    def test_circular_dependencies_through_libraries(self):
        """
        Create a projected containing two identical files in two separated
        library and instantiate an entity from the first library.
        """
        self.project = Project()
        self.project.add_library("lib_1", "work_path")
        self.project.add_library("lib_2", "work_path")
        self.project.add_library("lib", "work_path")
        text_file_1_2 = """\
        library ieee;
        use ieee.std_logic_1164.all;

        entity buffer1 is
          port (Q : out std_logic);
        end entity;

        architecture arch of buffer1 is begin
          Q <= '1';
        end architecture;

        library ieee;
        use ieee.std_logic_1164.all;

        entity buffer2 is
          port (Q : out std_logic);
        end entity;

        architecture arch of buffer2 is
          component buffer1
            port (Q : out std_logic);
          end component buffer1;

        begin
          my_buffer_i : buffer1
            port map (Q => Q);
        end architecture;
        """
        self.add_source_file("lib_1", "file1.vhd", text_file_1_2)
        self.add_source_file("lib_2", "file2.vhd", text_file_1_2)
        file3 = self.add_source_file(
            "lib",
            "file3.vhd",
            """\
        library lib_1;

        entity your_buffer is
        end entity;

        architecture arch of your_buffer is
        begin
          my_buffer_i : entity lib_1.buffer1;
        end architecture;
        """,
        )
        self.project.get_dependencies_in_compile_order([file3], implementation_dependencies=True)

    def test_dependencies_on_multiple_libraries(self):
        """
        Create a projected containing two identical files in two separated
        library and instantiate an entity from the first library.
        """
        self.project = Project()
        self.project.add_library("lib_1", "work_path")
        self.project.add_library("lib_2", "work_path")
        self.project.add_library("lib", "work_path")
        text_file_1_2 = """\
library ieee;use ieee.std_logic_1164.all;
entity buffer1 is  port (D : in std_logic;Q : out std_logic);end entity;
architecture arch of buffer1 is begin Q <= D; end architecture;
library ieee;use ieee.std_logic_1164.all;
entity buffer2 is port (D : in std_logic; Q : out std_logic);end entity;
architecture arch of buffer2 is
component buffer1 port (D : in  std_logic;Q : out std_logic);end component buffer1;
begin my_buffer_i : buffer1 port map (D => D,Q => Q);end architecture;
        """
        self.add_source_file("lib_1", "file1.vhd", text_file_1_2)
        lib2_file1_vhd = self.add_source_file("lib_2", "file1.vhd", text_file_1_2)
        file3 = self.add_source_file(
            "lib",
            "file3.vhd",
            """\
library ieee;use ieee.std_logic_1164.all;
library lib_1;entity your_buffer is port (D : in std_logic; Q : out std_logic);end entity;
architecture arch of your_buffer is
component buffer1 port (D : in  std_logic;Q : out std_logic);end component buffer1;
begin  my_buffer_i : buffer1 port map (D => D,Q => Q);end architecture;
        """,
        )
        dep_files = self.project.get_dependencies_in_compile_order([file3], implementation_dependencies=True)
        self.assertNotIn(lib2_file1_vhd, dep_files)

    def test_dependencies_on_separated_architecture(self):
        """
        Create a projected containing an entity file separated from architecture file.
        Dependency should involve also architecture.
        """
        self.project = Project()
        self.project.add_library("lib", "work_path")
        self.add_source_file(
            "lib",
            "file1.vhd",
            """\
library ieee;
use ieee.std_logic_1164.all;

entity buffer1 is
  port (D : in std_logic;
        Q : out std_logic);
end entity;
        """,
        )

        file1_arch_vhd = self.add_source_file(
            "lib",
            "file1_arch.vhd",
            """\
library ieee;
use ieee.std_logic_1164.all;

architecture arch of buffer1 is
begin
  Q <= D;
end architecture;
        """,
        )

        file3 = self.add_source_file(
            "lib",
            "file3.vhd",
            """\
library ieee;
use ieee.std_logic_1164.all;

entity your_buffer is
port (D : in std_logic; Q : out std_logic);
end entity;

architecture arch of your_buffer is
begin
my_buffer_i : entity work.buffer1
  port map (D => D,Q => Q);
end architecture;
        """,
        )
        dep_files = self.project.get_dependencies_in_compile_order([file3], implementation_dependencies=True)
        self.assertIn(file1_arch_vhd, dep_files)

    def test_dependencies_on_verilog_component(self):
        """
        Create a projected containing an verilog file separated.
        Dependency should involve it.
        """
        self.project = Project()
        self.project.add_library("lib", "work_path")
        file1_v = self.add_source_file(
            "lib",
            "file1.v",
            """\
module buffer1 (input   D,output   Q);
assign Q = D;
endmodule
        """,
        )
        file3 = self.add_source_file(
            "lib",
            "file3.vhd",
            """\
library ieee;use ieee.std_logic_1164.all;
entity your_buffer is port (D : in std_logic;Q : out std_logic);end entity;
architecture arch of your_buffer is
component buffer1 port (D : in  std_logic;Q : out std_logic);end component buffer1;
begin my_buffer_i : buffer1 port map (D => D,Q => Q);end architecture;
        """,
        )
        dep_files = self.project.get_dependencies_in_compile_order([file3], implementation_dependencies=True)
        self.assertIn(file1_v, dep_files)

    def create_dummy_three_file_project(self, update_file1=False):
        """
        Create a projected containing three dummy files
        optionally only updating file1
        """
        self.project = Project()
        self.project.add_library("lib", "work_path")

        if update_file1:
            file1 = self.add_source_file(
                "lib",
                "file1.vhd",
                """\
entity module1 is
end entity;

architecture arch of module1 is
begin
end architecture;
""",
            )
        else:
            file1 = self.add_source_file(
                "lib",
                "file1.vhd",
                """\
entity module1 is
end entity;

architecture arch of module1 is
begin
  report "Updated";
end architecture;
""",
            )
        file2 = self.add_source_file(
            "lib",
            "file2.vhd",
            """\
entity module2 is
end entity;

architecture arch of module2 is
begin
  module1_inst : entity lib.module1;
end architecture;
""",
        )

        file3 = self.add_source_file(
            "lib",
            "file3.vhd",
            """\
entity module3 is
end entity;

architecture arch of module3 is
begin
  module1_inst : entity work.module2;
end architecture;
""",
        )
        return file1, file2, file3

    def test_add_source_file_has_vhdl_standard(self):
        write_file("file.vhd", "")

        for std in ("93", "2002", "2008", "2019"):
            project = Project()
            project.add_library("lib", "lib_path")
            source_file = project.add_source_file("file.vhd", library_name="lib", file_type="vhdl", vhdl_standard=std)
            self.assertEqual(source_file.get_vhdl_standard(), std)

    def test_add_source_file_has_no_parse_vhdl(self):
        for no_parse in (True, False):
            project = Project()
            file_name = "file.vhd"
            write_file(
                file_name,
                """
    entity ent is
    end entity;
                       """,
            )
            project.add_library("lib", "work_path")
            source_file = project.add_source_file(
                file_name, "lib", file_type=file_type_of(file_name), no_parse=no_parse
            )
            self.assertEqual(len(source_file.design_units), int(not no_parse))

    def test_add_source_file_has_no_parse_verilog(self):
        for no_parse in (True, False):
            project = Project()
            file_name = "file.v"
            write_file(
                file_name,
                """
    module mod;
    endmodule
                       """,
            )
            project.add_library("lib", "work_path")
            source_file = project.add_source_file(
                file_name, "lib", file_type=file_type_of(file_name), no_parse=no_parse
            )
            self.assertEqual(len(source_file.design_units), int(not no_parse))

    @mock.patch("vunit.project.LOGGER")
    def test_no_warning_builtin_library_reference(self, mock_logger):
        self.project.add_library("lib", "lib_path")

        self.add_source_file(
            "lib",
            "ent.vhd",
            """
use std.foo.all;
use ieee.bar.all;
use builtin_lib.all;
""",
        )

        self.project.add_builtin_library("builtin_lib")
        self.project.get_files_in_compile_order()
        warning_calls = mock_logger.warning.call_args_list
        self.assertEqual(len(warning_calls), 0)

    def test_add_external_library(self):
        os.makedirs("lib_path")
        self.project.add_library("lib", "lib_path", is_external=True)

    def test_add_external_library_must_exist(self):
        try:
            self.project.add_library("lib2", "lib_path2", is_external=True)
        except ValueError as err:
            self.assertEqual(str(err), "External library 'lib_path2' does not exist")
        else:
            assert False, "ValueError not raised"

    def test_add_external_library_must_be_a_directory(self):
        write_file("lib_path3", "")
        try:
            self.project.add_library("lib3", "lib_path3", is_external=True)
        except ValueError as err:
            self.assertEqual(str(err), "External library must be a directory. Got 'lib_path3'")
        else:
            assert False, "ValueError not raised"

    def add_source_file(self, library_name, file_name, contents, defines=None):
        """
        Convenient wrapper arround project.add_source_file
        """
        write_file(file_name, contents)
        source_file = self.project.add_source_file(
            file_name, library_name, file_type=file_type_of(file_name), defines=defines
        )
        return source_file

    def hash_file_name_of(self, source_file):
        """
        Get the hash file name of a source_file
        """
        return self.project._hash_file_name_of(source_file)  # pylint: disable=protected-access

    def update(self, source_file):
        """
        Wrapper arround project.update
        """
        self.project.update(source_file)

    def assert_should_recompile(self, source_files):
        self.assertCountEqual(source_files, self.project.get_files_in_compile_order())

    def assert_compiles(self, source_file, before):
        """
        Assert that the compile order of source_file is before the file named 'before'.
        """
        for src_file in self.project.get_files_in_compile_order():
            self.update(src_file)
        self.assert_should_recompile([])
        tick()
        self.update(source_file)
        self.assertIn(before, self.project.get_files_in_compile_order())

    def assert_not_compiles(self, source_file, before):
        """
        Assert that the compile order of source_file is not before the file named 'before'.
        """
        for src_file in self.project.get_files_in_compile_order():
            self.update(src_file)
        self.assert_should_recompile([])
        tick()
        self.update(source_file)
        self.assertNotIn(before, self.project.get_files_in_compile_order())

    def assert_has_package_body(self, source_file_name, package_name):
        """
        Assert that there is a package body with package_name withing source_file_name
        """
        unit = self._find_design_unit(source_file_name, "package body", package_name, False, package_name)
        self.assertIsNotNone(unit)

    def assert_has_package(self, source_file_name, name):
        """
        Assert that there is a package with name withing source_file_name
        """
        unit = self._find_design_unit(source_file_name, "package", name)
        self.assertIsNotNone(unit)

    def assert_has_entity(self, source_file, name, generic_names=None, architecture_names=None):
        """
        Assert that there is an entity with name withing source_file
        that has architectures with architecture_names.
        """
        generic_names = [] if generic_names is None else generic_names
        architecture_names = [] if architecture_names is None else architecture_names

        for entity in source_file.library.get_entities():
            if entity.name == name:
                self.assertCountEqual(entity.generic_names, generic_names)
                self.assertCountEqual(entity.architecture_names, architecture_names)
                return

        self.assertFalse("Did not find entity " + name + "in " + source_file.name)

    def assert_has_architecture(self, source_file_name, name, entity_name):
        """
        Assert that there is an architecture with name of entity_name within source_file_name
        """
        unit = self._find_design_unit(source_file_name, "architecture", name, False, entity_name)
        self.assertIsNotNone(unit)

    def assert_has_component_instantiation(self, source_file_name, component_name):
        """
        Assert that there is a component instantion with component with source_file_name
        """
        found_comp = False
        for source_file in self.project.get_source_files_in_order():
            for component in source_file.depending_components:
                if component == component_name:
                    found_comp = True

        self.assertTrue(
            found_comp,
            "Did not find component " + component_name + " in " + source_file_name,
        )

    def _find_design_unit(  # pylint: disable=too-many-arguments
        self,
        source_file_name,
        design_unit_type,
        design_unit_name,
        is_primary=True,
        primary_design_unit_name=None,
    ):
        """
        Utility fnction to find and return a design unit
        """

        for source_file in self.project.get_source_files_in_order():
            for design_unit in source_file.design_units:
                if design_unit.unit_type != design_unit_type:
                    continue
                if design_unit.name != design_unit_name:
                    continue

                self.assertEqual(design_unit.is_primary, is_primary)
                self.assertEqual(source_file.name, source_file_name)
                if not is_primary:
                    self.assertEqual(design_unit.primary_design_unit, primary_design_unit_name)
                return design_unit

        return None


def tick():
    sleep(0.01)
