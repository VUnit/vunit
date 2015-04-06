# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from unittest import TestCase
from vunit.vhdl_parser import (VHDLDesignFile,
                               VHDLInterfaceElement,
                               VHDLEntity,
                               VHDLSubtypeIndication)


class TestVHDLParser(TestCase):

    def test_parsing_empty(self):
        design_file = VHDLDesignFile.parse("")
        self.assertEqual(design_file.entities, [])
        self.assertEqual(design_file.packages, [])
        self.assertEqual(design_file.architectures, [])

    def test_parsing_simple_entity(self):
        entity = self.parse_single_entity("""\
entity simple is
end entity;
""")
        self.assertEqual(entity.identifier, "simple")
        self.assertEqual(entity.ports, [])
        self.assertEqual(entity.generics, [])

    def test_getting_entities_from_design_file(self):
        design_file = VHDLDesignFile.parse("""
entity entity1 is
end entity;

package package1 is
end package;

entity entity2 is
end entity;
""")
        entities = design_file.entities
        self.assertEqual(len(entities), 2)
        self.assertEqual(entities[0].identifier, "entity1")
        self.assertEqual(entities[1].identifier, "entity2")

    def test_getting_architectures_from_design_file(self):
        design_file = VHDLDesignFile.parse("""
entity foo is
end entity;

architecture rtl of foo is
begin
end architecture;
""")
        self.assertEqual(len(design_file.entities), 1)
        self.assertEqual(len(design_file.architectures), 1)
        arch = design_file.architectures
        self.assertEqual(len(arch), 1)
        self.assertEqual(arch[0].entity, "foo")
        self.assertEqual(arch[0].identifier, "rtl")

    def test_parsing_libraries(self):
        design_file = VHDLDesignFile.parse("""
library name1;
 use name1.foo.all;

library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use name1.bla.all;

library lib1,lib2, lib3;
use lib1.foo, lib2.bar,lib3.xyz;

context name1.is_identifier;
""")
        self.assertEqual(len(design_file.libraries), 5)
        self.assertEqual(len(design_file.contexts), 0)
        self.assertEqual(design_file.libraries,
                         {"ieee": set([("numeric_std", "all"), ("std_logic_1164", "all")]),
                          "name1": set([("foo", "all"), ("bla", "all"), ("is_identifier",)]),
                          "lib1": set([("foo",)]),
                          "lib2": set([("bar",)]),
                          "lib3": set([("xyz",)])})

    def test_parsing_entity_with_generics(self):
        entity = self.parse_single_entity("""\
entity name is
   generic (max_value : integer range 2-2 to 2**10 := (2-19)*4;
            enable_foo : boolean
   );
end entity;
""")
        self.assertEqual(entity.identifier, "name")
        self.assertNotEqual(entity.generics, [])
        self.assertEqual(entity.ports, [])
        generics = entity.generics
        self.assertEqual(len(generics), 2)

        self.assertEqual(generics[0].identifier, "max_value")
        self.assertEqual(generics[0].init_value, "(2-19)*4")
        self.assertEqual(generics[0].mode, None)
        self.assertEqual(generics[0].subtype_indication.code, "integer range 2-2 to 2**10")
        self.assertEqual(generics[0].subtype_indication.type_mark, "integer")
        # @TODO does not work
#        self.assertEqual(generics[0].subtypeIndication.constraint, "range 2-2 to 2**10")
        self.assertEqual(generics[1].identifier, "enable_foo")
        self.assertEqual(generics[1].init_value, None)
        self.assertEqual(generics[1].mode, None)
        self.assertEqual(generics[1].subtype_indication.code, "boolean")
        self.assertEqual(generics[1].subtype_indication.type_mark, "boolean")

    def test_parsing_entity_with_ports(self):
        entity = self.parse_single_entity("""\
entity name is
   port (clk : in std_logic;
         data : out std_logic_vector(11-1 downto 0));
end entity;
""")

        self.assertEqual(entity.identifier, "name")
        self.assertEqual(entity.generics, [])
        self.assertNotEqual(entity.ports, [])

        ports = entity.ports
        self.assertEqual(len(ports), 2)

        self.assertEqual(ports[0].identifier, "clk")
        self.assertEqual(ports[0].init_value, None)
        self.assertEqual(ports[0].mode, "in")
        self.assertEqual(ports[0].subtype_indication.code, "std_logic")
        self.assertEqual(ports[0].subtype_indication.type_mark, "std_logic")

        self.assertEqual(ports[1].identifier, "data")
        self.assertEqual(ports[1].init_value, None)
        self.assertEqual(ports[1].mode, "out")
        self.assertEqual(ports[1].subtype_indication.code, "std_logic_vector(11-1 downto 0)")
        self.assertEqual(ports[1].subtype_indication.type_mark, "std_logic_vector")
        self.assertEqual(ports[1].subtype_indication.constraint, "(11-1 downto 0)")

    def test_parsing_simple_package_body(self):
        package_body = self.parse_single_package_body("""\
package body simple is
begin
end package body;
""")
        self.assertEqual(package_body.identifier, "simple")

    def test_parsing_simple_package(self):
        package = self.parse_single_package("""\
package simple is
end package;
""")
        self.assertEqual(package.identifier, "simple")

    def test_parsing_package_with_constants(self):
        package = self.parse_single_package("""\
package name is
  constant foo : integer := 15 - 1 * 2;
  constant bar : boolean := false or true;
end package;
""")
        self.assertEqual(package.identifier, "name")
        constants = package.constant_declarations
        self.assertEqual(len(constants), 2)
        self.assertEqual(constants[0].identifier, "foo")
        self.assertEqual(constants[0].expression, "15 - 1 * 2")
        self.assertEqual(constants[0].subtype_indication.type_mark, "integer")
        self.assertEqual(constants[1].identifier, "bar")
        self.assertEqual(constants[1].expression, "false or true")
        self.assertEqual(constants[1].subtype_indication.type_mark, "boolean")

    def test_parsing_context(self):
        context = self.parse_single_context("""\
context foo is
  library bar;
  use bar.bar_pkg.all;
end context;
""")
        self.assertEqual(context.identifier, "foo")

        context = self.parse_single_context("""\
context identifier is
  library bar;
  use bar.bar_pkg.all;
end context identifier;
""")
        self.assertEqual(context.identifier, "identifier")

    def test_converting_interface_element_to_string(self):
        iface_element = VHDLInterfaceElement("identifier",
                                             VHDLSubtypeIndication.parse("integer"),
                                             "in",
                                             "0")
        self.assertEqual(str(iface_element),
                         "identifier : in integer := 0")

        iface_element = VHDLInterfaceElement("identifier",
                                             VHDLSubtypeIndication.parse("integer"),
                                             "in")
        self.assertEqual(str(iface_element),
                         "identifier : in integer")

        iface_element = VHDLInterfaceElement("identifier",
                                             VHDLSubtypeIndication.parse("integer"))
        self.assertEqual(str(iface_element),
                         "identifier : integer")

    def test_converting_entity_to_string(self):
        entity = self._create_entity()
        self.assertEqual(entity.to_str(sindent="xx ", indent="  "), """\
xx entity name is
xx   generic (
xx     data_width : natural := 16);
xx   port (
xx     clk : in std_logic;
xx     data : out std_logic_vector(data_width-1 downto 0));
xx end entity;
""")

        entity = self._create_entity()
        entity.ports = []
        self.assertEqual(entity.to_str(sindent="xx ", indent="  "), """\
xx entity name is
xx   generic (
xx     data_width : natural := 16);
xx end entity;
""")

        entity = self._create_entity()
        entity.generics = []
        self.assertEqual(entity.to_str(sindent="xx ", indent="  ", as_component=True), """\
xx component name is
xx   port (
xx     clk : in std_logic;
xx     data : out std_logic_vector(data_width-1 downto 0));
xx end component;
""")

        entity = self._create_entity()
        entity.generics = []
        entity.ports = []
        self.assertEqual(entity.to_str(sindent="xx ", indent="  "), """\
xx entity name is
xx end entity;
""")

    def test_converting_entity_to_instantiation_string(self):
        entity = self._create_entity()
        self.assertEqual(entity.to_instantiation_str(name="name_inst",
                                                     sindent="xx ",
                                                     indent="  "), """\
xx name_inst : name
xx   generic map (
xx     data_width => data_width)
xx   port map (
xx     clk => clk,
xx     data => data);
""")

        entity = self._create_entity()
        entity.generics = []
        self.assertEqual(entity.to_instantiation_str(name="name_inst"), """\
  name_inst : name
    port map (
      clk => clk,
      data => data);
""")

        entity = self._create_entity()
        entity.ports = []
        self.assertEqual(entity.to_instantiation_str(name="name_inst"), """\
  name_inst : name
    generic map (
      data_width => data_width);
""")

        entity = self._create_entity()
        entity.ports = []
        entity.generics = []
        self.assertEqual(entity.to_instantiation_str(name="name_inst"), """\
  name_inst : name;
""")

    def test_converting_entity_to_instantiation_string_with_mapping(self):
        entity = self._create_entity()
        self.assertEqual(entity.to_instantiation_str(name="name_inst",
                                                     mapping={"clk": "'1'",
                                                              "data_width": "foo = bar"}), """\
  name_inst : name
    generic map (
      data_width => foo = bar)
    port map (
      clk => '1',
      data => data);
""")

    def test_converting_entity_to_signal_declaration_string(self):
        entity = self._create_entity()
        self.assertEqual(entity.to_signal_declaration_str(sindent="xx "), """\
xx signal clk : std_logic;
xx signal data : std_logic_vector(data_width-1 downto 0);
""")

    def test_getting_component_instantiations_from_design_file(self):
        design_file = VHDLDesignFile.parse("""
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

    label3Foo : foo3 port map (clk, rst, X"A");

end architecture;

""")
        component_instantiations = design_file.component_instantiations
        self.assertEqual(len(component_instantiations), 3)
        self.assertEqual(component_instantiations[0], "foo")
        self.assertEqual(component_instantiations[1], "foo2")
        self.assertEqual(component_instantiations[2], "foo3")

    def test_adding_generics_to_entity(self):
        entity = VHDLEntity("name")
        entity.add_generic("max_value", "boolean", "20")
        self.assertEqual(len(entity.generics), 1)
        self.assertEqual(entity.generics[0].identifier, "max_value")
        self.assertEqual(entity.generics[0].subtype_indication.type_mark, "boolean")
        self.assertEqual(entity.generics[0].init_value, "20")

    def test_adding_ports_to_entity(self):
        entity = VHDLEntity("name")
        entity.add_port("foo", "inout", "foo_t")
        self.assertEqual(len(entity.ports), 1)
        self.assertEqual(entity.ports[0].identifier, "foo")
        self.assertEqual(entity.ports[0].mode, "inout")
        self.assertEqual(entity.ports[0].subtype_indication.type_mark, "foo_t")

    def parse_single_entity(self, code):
        """
        Helper function to parse a single entity
        """
        design_file = VHDLDesignFile.parse(code)
        self.assertEqual(len(design_file.entities), 1)
        return design_file.entities[0]

    def parse_single_package(self, code):
        """
        Helper function to parse a single package
        """
        design_file = VHDLDesignFile.parse(code)
        self.assertEqual(len(design_file.packages), 1)
        return design_file.packages[0]

    def parse_single_context(self, code):
        """
        Helper function to parse a single context
        """
        design_file = VHDLDesignFile.parse(code)
        self.assertEqual(len(design_file.contexts), 1)
        return design_file.contexts[0]

    def parse_single_package_body(self, code):
        """
        Helper function to parse a single package body
        """
        design_file = VHDLDesignFile.parse(code)
        self.assertEqual(len(design_file.package_bodies), 1)
        return design_file.package_bodies[0]

    def _create_entity(self):
        """
        Helper function to create a VHDLEntity
        """
        data_width = VHDLInterfaceElement("data_width",
                                          VHDLSubtypeIndication.parse("natural := 16"))

        clk = VHDLInterfaceElement("clk",
                                   VHDLSubtypeIndication.parse("std_logic"),
                                   "in")
        data = VHDLInterfaceElement("data",
                                    VHDLSubtypeIndication.parse("std_logic_vector(data_width-1 downto 0)"),
                                    "out")

        entity = VHDLEntity(identifier="name",
                            generics=[data_width],
                            ports=[clk, data])
        return entity
