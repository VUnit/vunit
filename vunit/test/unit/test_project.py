# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

import unittest
from os.path import join
from stub_ostools import OstoolsStub
import vunit.project
from vunit.project import Project


class TestProject(unittest.TestCase):
    def setUp(self):
        self.stub = OstoolsStub()
        vunit.project.ostools = self.stub
        self.project = Project()

    def tearDown(self):
        vunit.project.ostools = vunit.ostools

    def test_parses_entity_architecture(self):
        self.project.add_library("lib", "work_path")
        self.add_source_file("lib", "file1.vhd", """\
entity foo is
end entity;

architecture arch of foo is
begin
end architecture;

architecture arch2 of foo is
begin
end architecture;
""")

        self.add_source_file("lib", "file2.vhd", """\
architecture arch3 of foo is
begin
end architecture;
""")

        self.assert_has_entity("file1.vhd", "foo",
                               architecture_names=["arch", "arch2", "arch3"])
        self.assert_has_architecture("file1.vhd", "arch", "foo")
        self.assert_has_architecture("file1.vhd", "arch2", "foo")
        self.assert_has_architecture("file2.vhd", "arch3", "foo")

    def test_parses_entity_architecture_with_generics(self):
        self.project.add_library("lib", "work_path")
        self.add_source_file("lib", "file1.vhd", """\
entity foo is
  generic (
    testing_that_foo : boolean;
    testing_that_bar : boolean);
end entity;

architecture arch of foo is
begin
end architecture;
""")

        self.assert_has_entity("file1.vhd", "foo",
                               generic_names=["testing_that_bar", "testing_that_foo"],
                               architecture_names=["arch"])
        self.assert_has_architecture("file1.vhd", "arch", "foo")

    def test_parses_package(self):
        self.project.add_library("lib", "work_path")
        self.add_source_file("lib", "file1.vhd", """\
package foo is
end package;

package body foo is
begin
end package body;
""")
        self.assert_has_package("file1.vhd", "foo")
        self.assert_has_package_body("file1.vhd", "foo")

    def test_finds_entity_instantiation_dependencies(self):
        self.create_dummy_three_file_project()

        self.assert_compiles_before("file1.vhd", before="file2.vhd")
        self.assert_compiles_before("file2.vhd", before="file3.vhd")

    def test_primary_with_same_name_in_multiple_libraries_secondary_dependency(self):
        self.project.add_library("lib1", "lib1_path")
        self.project.add_library("lib2", "lib2_path")

        self.add_source_file("lib1", "foo_arch.vhd", """
architecture arch of foo is
begin
end architecture;
""")

        self.add_source_file("lib1", "foo1_ent.vhd", """
entity foo is
port (signal bar : boolean);
end entity;
""")

        self.add_source_file("lib2", "foo2_ent.vhd", """
entity foo is
end entity;
""")

        self.update("foo_arch.vhd")
        self.update("foo1_ent.vhd")
        self.update("foo2_ent.vhd")
        self.assert_should_recompile([])

        self.stub.tick()
        self.update("foo1_ent.vhd")
        self.assert_should_recompile(["foo_arch.vhd"])

    def test_multiple_identical_file_names_with_different_path_in_same_library(self):
        self.project.add_library("lib", "lib_path")
        self.add_source_file("lib", join("a", "foo.vhd"), """
entity a_foo is
end entity;
""")

        self.add_source_file("lib", join("b", "foo.vhd"), """
entity b_foo is
end entity;
""")
        self.assert_should_recompile([join("a", "foo.vhd"), join("b", "foo.vhd")])
        self.update(join("a", "foo.vhd"))
        self.update(join("b", "foo.vhd"))
        self.assert_should_recompile([])

    def test_finds_entity_architecture_dependencies(self):
        self.project.add_library("lib", "lib_path")
        self.add_source_file("lib", "entity.vhd", """
entity foo is
end entity;
""")

        self.add_source_file("lib", "arch1.vhd", """
architecture arch1 of foo is
begin
end architecture;
""")

        self.add_source_file("lib", "arch2.vhd", """
architecture arch2 of foo is
begin
end architecture;
""")
        self.assert_compiles_before("entity.vhd", before="arch1.vhd")
        self.assert_compiles_before("entity.vhd", before="arch2.vhd")

    def test_finds_package_dependencies(self):
        self.project.add_library("lib", "lib_path")
        self.add_source_file("lib", "package.vhd", """
package foo is
end package;
""")

        self.add_source_file("lib", "body.vhd", """
package body foo is
begin
end package body;
""")

        self.assert_compiles_before("package.vhd", before="body.vhd")

    def test_finds_use_package_dependencies(self):
        self.project.add_library("lib", "lib_path")
        self.add_source_file("lib", "package.vhd", """
package foo_pkg is
end package;
""")

        self.add_source_file("lib", "body.vhd", """
package body foo_pkg is
begin
end package body;
""")

        self.project.add_library("lib2", "work_path")
        self.add_source_file("lib2", "module.vhd", """
library lib;
use lib.foo_pkg.all;

entity module is
end entity;

architecture arch of module is
begin
end architecture;
""")

        self.assert_compiles_before("package.vhd", before="body.vhd")
        self.assert_compiles_before("package.vhd", before="module.vhd")

    def test_finds_context_dependencies(self):
        self.project.add_library("lib", "lib_path")
        self.add_source_file("lib", "context.vhd", """
context foo is
end context;
""")

        self.project.add_library("lib2", "work_path")
        self.add_source_file("lib2", "module.vhd", """
library lib;
context lib.foo;

entity module is
end entity;

architecture arch of module is
begin
end architecture;
""")

        self.assert_compiles_before("context.vhd", before="module.vhd")

    def test_should_recompile_all_files_initially(self):
        self.create_dummy_three_file_project()
        self.assert_should_recompile(["file1.vhd", "file2.vhd", "file3.vhd"])
        self.assert_should_recompile(["file1.vhd", "file2.vhd", "file3.vhd"])

    def test_updating_creates_hash_files(self):
        self.create_dummy_three_file_project()

        for file_name in ["file1.vhd", "file2.vhd", "file3.vhd"]:
            self.update(file_name)
            self.assertIn(self.project._hash_file_name_of(self.get_source_file(file_name)), self.stub._files.keys())

    def test_should_not_recompile_updated_files(self):
        self.create_dummy_three_file_project()

        self.update("file1.vhd")
        self.assert_should_recompile(["file2.vhd", "file3.vhd"])

        self.update("file2.vhd")
        self.assert_should_recompile(["file3.vhd"])

        self.update("file3.vhd")
        self.assert_should_recompile([])

    def test_should_recompile_files_affected_by_change(self):
        self.create_dummy_three_file_project()

        self.update("file1.vhd")
        self.update("file2.vhd")
        self.update("file3.vhd")
        self.assert_should_recompile([])

        self.create_dummy_three_file_project()
        self.assert_should_recompile([])

        self.create_dummy_three_file_project(update_file1=True)
        self.assert_should_recompile(["file1.vhd", "file2.vhd", "file3.vhd"])

    def test_should_recompile_files_affected_by_change_with_later_timestamp(self):
        self.create_dummy_three_file_project()

        self.update("file1.vhd")
        self.update("file2.vhd")
        self.update("file3.vhd")
        self.assert_should_recompile([])

        self.create_dummy_three_file_project()
        self.assert_should_recompile([])

        self.create_dummy_three_file_project(update_file1=True)
        self.assert_should_recompile(["file1.vhd", "file2.vhd", "file3.vhd"])

        self.stub.tick()
        self.update("file1.vhd")
        self.assert_should_recompile(["file2.vhd", "file3.vhd"])

    def test_should_recompile_files_missing_hash(self):
        self.create_dummy_three_file_project()

        self.update("file1.vhd")
        self.update("file2.vhd")
        self.update("file3.vhd")
        self.assert_should_recompile([])

        self.stub.remove_file(self.project._hash_file_name_of(self.get_source_file("file2.vhd")))
        self.assert_should_recompile(["file2.vhd", "file3.vhd"])

    def test_finds_component_instantiation_dependencies(self):
        self.project = Project(depend_on_components=True)
        self.project.add_library("toplib", "work_path")
        self.add_source_file("toplib", "top.vhd", """\
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
""")

        self.project.add_library("libcomp1", "work_path")
        self.add_source_file("libcomp1", "comp1.vhd", """\
entity foo is
end entity;

architecture arch of foo is
begin
end architecture;
""")

        self.project.add_library("libcomp2", "work_path")
        self.add_source_file("libcomp2", "comp2.vhd", """\
entity foo2 is
end entity;

architecture arch of foo2 is
begin
end architecture;
""")

        self.assert_has_component("top.vhd", "foo")
        self.assert_has_component("top.vhd", "foo2")

        self.assert_compiles_before("comp1.vhd", before="top.vhd")
        self.assert_compiles_before("comp2.vhd", before="top.vhd")

    def create_dummy_three_file_project(self, update_file1=False):
        self.project = Project()
        self.project.add_library("lib", "work_path")

        if update_file1:
            self.add_source_file("lib", "file1.vhd", """\
entity module1 is
end entity;

architecture arch of module1 is
begin
end architecture;
""")
        else:
            self.add_source_file("lib", "file1.vhd", """\
entity module1 is
end entity;

architecture arch of module1 is
begin
  report "Updated";
end architecture;
""")
        self.add_source_file("lib", "file2.vhd", """\
entity module2 is
end entity;

architecture arch of module2 is
begin
  module1_inst : entity lib.module1;
end architecture;
""")

        self.add_source_file("lib", "file3.vhd", """\
entity module3 is
end entity;

architecture arch of module3 is
begin
  module1_inst : entity work.module2;
end architecture;
""")

    def add_source_file(self, library_name, file_name, contents):
        self.stub.write_file(file_name, contents)
        self.project.add_source_file(file_name, library_name)

    def get_source_file(self, file_name):
        return self.project._source_files[file_name]

    def update(self, file_name):
        self.project.update(self.project._source_files[file_name])

    def assert_should_recompile(self, file_names):
        self.assert_count_equal(file_names, [dep.name for dep in self.project.get_files_in_compile_order()])

    def assert_compiles_before(self, file_name, before):
        for src_file in self.project.get_files_in_compile_order():
            self.update(src_file.name)
        self.assert_should_recompile([])
        self.stub.tick()
        self.update(file_name)
        self.assertIn(before, [dep.name for dep in self.project.get_files_in_compile_order()])

    def assert_has_package_body(self, source_file_name, package_name):
        unit = self._find_design_unit(source_file_name,
                                      "package body",
                                      "package body for " + package_name,
                                      False, package_name)
        self.assertIsNotNone(unit)

    def assert_has_package(self, source_file_name, name):
        unit = self._find_design_unit(source_file_name,
                                      "package",
                                      name)
        self.assertIsNotNone(unit)

    def assert_has_entity(self, source_file_name, name,
                          generic_names=None,
                          architecture_names=None):
        source_file = self.project._source_files[source_file_name]
        generic_names = [] if generic_names is None else generic_names
        architecture_names = [] if architecture_names is None else architecture_names

        for entity in source_file.library.get_entities():
            if entity.name == name:
                self.assert_count_equal(entity.generic_names, generic_names)
                self.assert_count_equal(entity.architecture_names, architecture_names)
                return

        self.assertFalse("Did not find entity " + name + "in " + source_file_name)

    def assert_has_architecture(self, source_file_name, name, entity_name):
        unit = self._find_design_unit(source_file_name,
                                      "architecture",
                                      name, False, entity_name)
        self.assertIsNotNone(unit)

    def assert_has_component(self, source_file_name, component_name):
        found_comp = False
        for source_file in self.project._source_files.values():
            for component in source_file.depending_components:
                if component == component_name:
                    found_comp = True

        self.assertTrue(found_comp, "Did not find component " + component_name + " in " + source_file_name)

    def _find_design_unit(self,
                          source_file_name,
                          design_unit_type,
                          design_unit_name,
                          is_primary=True,
                          primary_design_unit_name=None):

        for source_file in self.project._source_files.values():
            for design_unit in source_file.design_units:
                if design_unit.name != design_unit_name:
                    continue

                self.assertEqual(design_unit.is_primary, is_primary)
                self.assertEqual(design_unit.unit_type, design_unit_type)
                self.assertEqual(source_file.name, source_file_name)
                if not is_primary:
                    self.assertEqual(design_unit.primary_design_unit, primary_design_unit_name)
                return design_unit

        return None

    def assert_count_equal(self, values1, values2):
        # Python 2.7 compatability
        self.assertEqual(sorted(values1), sorted(values2))
