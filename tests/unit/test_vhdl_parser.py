# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test of the VHDL parser
"""

from unittest import TestCase
from vunit.vhdl_parser import (
    VHDLDesignFile,
    VHDLInterfaceElement,
    VHDLEntity,
    VHDLSubtypeIndication,
    VHDLEnumerationType,
    VHDLArrayType,
    VHDLReference,
    VHDLRecordType,
    remove_comments,
)


class TestVHDLParser(TestCase):  # pylint: disable=too-many-public-methods
    """
    Test of the VHDL parser
    """

    def test_parsing_empty(self):
        design_file = VHDLDesignFile.parse("")
        self.assertEqual(design_file.entities, [])
        self.assertEqual(design_file.packages, [])
        self.assertEqual(design_file.architectures, [])

    def test_parsing_simple_entity(self):
        entity = self.parse_single_entity(
            """\
entity simple is
end entity;
"""
        )
        self.assertEqual(entity.identifier, "simple")
        self.assertEqual(entity.ports, [])
        self.assertEqual(entity.generics, [])

    def test_parsing_entity_with_package_generic(self):
        entity = self.parse_single_entity(
            """\
entity ent is
  generic (
    package p is new work.pkg generic map (c => 1, b => 2);
    package_g : integer
    );
end entity;
"""
        )
        self.assertEqual(entity.identifier, "ent")
        self.assertEqual(entity.ports, [])
        self.assertEqual(len(entity.generics), 1)
        self.assertEqual(entity.generics[0].identifier, "package_g")
        self.assertEqual(entity.generics[0].subtype_indication.type_mark, "integer")

    def test_parsing_entity_with_type_generic(self):
        entity = self.parse_single_entity(
            """\
entity ent is
  generic (
    type t;
    type_g : integer
    );
end entity;
"""
        )
        self.assertEqual(entity.identifier, "ent")
        self.assertEqual(entity.ports, [])
        self.assertEqual(len(entity.generics), 1)
        self.assertEqual(entity.generics[0].identifier, "type_g")
        self.assertEqual(entity.generics[0].subtype_indication.type_mark, "integer")

    def test_parsing_entity_with_string_semicolon_colon(self):
        entity = self.parse_single_entity(
            """\
entity ent is
  generic (
        const : string := "a;a";
        const2 : string := ";a""a;a";
        const3 : string := ": a b c :"
    );
end entity;
"""
        )
        self.assertEqual(entity.identifier, "ent")
        self.assertEqual(entity.ports, [])
        self.assertEqual(len(entity.generics), 3)
        self.assertEqual(entity.generics[0].identifier, "const")
        self.assertEqual(entity.generics[0].subtype_indication.type_mark, "string")
        self.assertEqual(entity.generics[0].init_value, '"a;a"')
        self.assertEqual(entity.generics[1].identifier, "const2")
        self.assertEqual(entity.generics[1].subtype_indication.type_mark, "string")
        self.assertEqual(entity.generics[1].init_value, '";a""a;a"')
        self.assertEqual(entity.generics[2].identifier, "const3")
        self.assertEqual(entity.generics[2].subtype_indication.type_mark, "string")
        self.assertEqual(entity.generics[2].init_value, '": a b c :"')

    def test_parsing_entity_with_function_generic(self):
        entity = self.parse_single_entity(
            """\
entity ent is
  generic (
    function f(a : integer; b : integer) return integer;
    function_g : boolean;
    impure function if(a : integer; b : integer) return integer;
    procedure_g : boolean;
    procedure p(a : integer; b : integer)
    );
end entity;
"""
        )
        self.assertEqual(entity.identifier, "ent")
        self.assertEqual(entity.ports, [])
        self.assertEqual(len(entity.generics), 2)
        self.assertEqual(entity.generics[0].identifier, "function_g")
        self.assertEqual(entity.generics[0].subtype_indication.type_mark, "boolean")
        self.assertEqual(entity.generics[1].identifier, "procedure_g")
        self.assertEqual(entity.generics[1].subtype_indication.type_mark, "boolean")

    def test_getting_entities_from_design_file(self):
        design_file = VHDLDesignFile.parse(
            """
entity entity1 is
end entity;

package package1 is
end package;

entity entity2 is
end entity;
"""
        )
        entities = design_file.entities
        self.assertEqual(len(entities), 2)
        self.assertEqual(entities[0].identifier, "entity1")
        self.assertEqual(entities[1].identifier, "entity2")

    def test_getting_architectures_from_design_file(self):
        design_file = VHDLDesignFile.parse(
            """
entity foo is
end entity;

architecture rtl of foo is
begin
end architecture;
"""
        )
        self.assertEqual(len(design_file.entities), 1)
        self.assertEqual(len(design_file.architectures), 1)
        arch = design_file.architectures
        self.assertEqual(len(arch), 1)
        self.assertEqual(arch[0].entity, "foo")
        self.assertEqual(arch[0].identifier, "rtl")

    def test_parsing_references(self):
        design_file = VHDLDesignFile.parse(
            """
library name1;
 use name1.foo.all;

library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use name1.bla.all;

library lib1,lib2, lib3;
use lib1.foo, lib2.bar,lib3.xyz;

context name1.is_identifier;

entity work1.foo1
entity work1.foo1(a1)
for all : bar use entity work2.foo2
for all : bar use entity work2.foo2 (a2)
for foo : bar use configuration work.cfg

entity foo is -- False
configuration bar of ent -- False

package new_pkg is new lib.pkg;
"""
        )
        self.assertEqual(len(design_file.references), 14)
        self.assertEqual(
            sorted(design_file.references, key=repr),
            sorted(
                [
                    VHDLReference("configuration", "work", "cfg", None),
                    VHDLReference("context", "name1", "is_identifier", None),
                    VHDLReference("entity", "work1", "foo1", "a1"),
                    VHDLReference("entity", "work1", "foo1", None),
                    VHDLReference("entity", "work2", "foo2", "a2"),
                    VHDLReference("entity", "work2", "foo2", None),
                    VHDLReference("package", "ieee", "numeric_std", "all"),
                    VHDLReference("package", "ieee", "std_logic_1164", "all"),
                    VHDLReference("package", "lib1", "foo", None),
                    VHDLReference("package", "lib2", "bar", None),
                    VHDLReference("package", "lib3", "xyz", None),
                    VHDLReference("package", "name1", "bla", "all"),
                    VHDLReference("package", "name1", "foo", "all"),
                    VHDLReference("package", "lib", "pkg", None),
                ],
                key=repr,
            ),
        )

    def test_parsing_entity_with_generics(self):
        entity = self.parse_single_entity(
            """\
entity name is
   generic (max_value : integer range 2-2 to 2**10 := (2-19)*4;
            enable_foo : boolean
   );
end entity;
"""
        )
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

    def test_parsing_entity_with_generics_and_trailing_semicolon(self):
        entity = self.parse_single_entity(
            """\
entity name is
   generic (max_value : integer range 2-2 to 2**10 := (2-19)*4;
            enable_foo : boolean  ;
   );
end entity;
"""
        )
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

    def test_parsing_entity_with_generics_corner_cases(self):
        self.parse_single_entity(
            """\
entity name is end entity;
"""
        )

        entity = self.parse_single_entity(
            """\
entity name is generic(g : t); end entity;
"""
        )
        self.assertEqual(len(entity.generics), 1)
        self.assertEqual(entity.generics[0].identifier, "g")

        entity = self.parse_single_entity(
            """\
entity name is generic
(
g : t
);
end entity;
"""
        )
        self.assertEqual(len(entity.generics), 1)
        self.assertEqual(entity.generics[0].identifier, "g")

        entity = self.parse_single_entity(
            """\
end architecture; entity name is generic
(
g : t
);
end entity;
"""
        )
        self.assertEqual(len(entity.generics), 1)
        self.assertEqual(entity.generics[0].identifier, "g")

        entity = self.parse_single_entity(
            """\
entity name is foo_generic
(
g : t
);
end entity;
"""
        )
        self.assertEqual(len(entity.generics), 0)

    def _check_entity_with_ports(self, entity):
        self.assertEqual(entity.identifier, "name")
        self.assertEqual(entity.generics, [])
        self.assertNotEqual(entity.ports, [])

        ports = entity.ports
        self.assertEqual(len(ports), 12)

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

        self.assertEqual(ports[2].identifier, "signal_data2")
        self.assertEqual(ports[2].init_value, None)
        self.assertEqual(ports[2].mode, "in")
        self.assertEqual(ports[2].subtype_indication.code, "std_logic")
        self.assertEqual(ports[2].subtype_indication.type_mark, "std_logic")
        self.assertEqual(ports[2].subtype_indication.constraint, None)

        self.assertEqual(ports[3].identifier, "data3")
        self.assertEqual(ports[3].init_value, None)
        self.assertEqual(ports[3].mode, "in")
        self.assertEqual(ports[3].subtype_indication.code, "signal_type")
        self.assertEqual(ports[3].subtype_indication.type_mark, "signal_type")
        self.assertEqual(ports[3].subtype_indication.constraint, None)

        self.assertEqual(ports[4].identifier, "data4_signal")
        self.assertEqual(ports[4].init_value, None)
        self.assertEqual(ports[4].mode, "in")
        self.assertEqual(ports[4].subtype_indication.code, "std_logic")
        self.assertEqual(ports[4].subtype_indication.type_mark, "std_logic")
        self.assertEqual(ports[4].subtype_indication.constraint, None)

        self.assertEqual(ports[5].identifier, "data5")
        self.assertEqual(ports[5].init_value, None)
        self.assertEqual(ports[5].mode, "in")
        self.assertEqual(ports[5].subtype_indication.code, "type_signal")
        self.assertEqual(ports[5].subtype_indication.type_mark, "type_signal")
        self.assertEqual(ports[5].subtype_indication.constraint, None)

        self.assertEqual(ports[6].identifier, "clk2")
        self.assertEqual(ports[6].init_value, None)
        self.assertEqual(ports[6].mode, "in")
        self.assertEqual(ports[6].subtype_indication.code, "std_logic")
        self.assertEqual(ports[6].subtype_indication.type_mark, "std_logic")

        self.assertEqual(ports[7].identifier, "data7")
        self.assertEqual(ports[7].init_value, None)
        self.assertEqual(ports[7].mode, "out")
        self.assertEqual(ports[7].subtype_indication.code, "std_logic_vector(11-1 downto 0)")
        self.assertEqual(ports[7].subtype_indication.type_mark, "std_logic_vector")
        self.assertEqual(ports[7].subtype_indication.constraint, "(11-1 downto 0)")

        self.assertEqual(ports[8].identifier, "signal_data8")
        self.assertEqual(ports[8].init_value, None)
        self.assertEqual(ports[8].mode, "in")
        self.assertEqual(ports[8].subtype_indication.code, "std_logic")
        self.assertEqual(ports[8].subtype_indication.type_mark, "std_logic")
        self.assertEqual(ports[8].subtype_indication.constraint, None)

        self.assertEqual(ports[9].identifier, "data9")
        self.assertEqual(ports[9].init_value, None)
        self.assertEqual(ports[9].mode, "in")
        self.assertEqual(ports[9].subtype_indication.code, "signal_type")
        self.assertEqual(ports[9].subtype_indication.type_mark, "signal_type")
        self.assertEqual(ports[9].subtype_indication.constraint, None)

        self.assertEqual(ports[10].identifier, "data10_signal")
        self.assertEqual(ports[10].init_value, None)
        self.assertEqual(ports[10].mode, "in")
        self.assertEqual(ports[10].subtype_indication.code, "std_logic")
        self.assertEqual(ports[10].subtype_indication.type_mark, "std_logic")
        self.assertEqual(ports[10].subtype_indication.constraint, None)

        self.assertEqual(ports[11].identifier, "data11")
        self.assertEqual(ports[11].init_value, None)
        self.assertEqual(ports[11].mode, "in")
        self.assertEqual(ports[11].subtype_indication.code, "type_signal")
        self.assertEqual(ports[11].subtype_indication.type_mark, "type_signal")
        self.assertEqual(ports[11].subtype_indication.constraint, None)

    def test_parsing_entity_with_ports(self):
        entity = self.parse_single_entity(
            """\
entity name is
port (
    clk : in std_logic;
 \t data : out std_logic_vector(11-1 downto 0);
    signal_data2 : in std_logic;
\t  data3 :\tin signal_type;
    data4_signal : in\tstd_logic;
    data5\t: in type_signal;
\t\tsignal clk2 : in std_logic;
    signal\tdata7 : out std_logic_vector(11-1 downto 0);
    signal signal_data8 : in std_logic;
    signal\t data9 : in signal_type;
    signal data10_signal :\tin std_logic;\t
    signal \t data11 : in type_signal
);
end entity;
"""
        )
        self._check_entity_with_ports(entity)

    def test_parsing_entity_with_ports_and_trailing_semicolon(self):
        entity = self.parse_single_entity(
            """\
entity name is
port (
    clk : in std_logic;
 \t data : out std_logic_vector(11-1 downto 0);
    signal_data2 : in std_logic;
\t  data3 :\tin signal_type;
    data4_signal : in\tstd_logic;
    data5\t: in type_signal;
\t\tsignal clk2 : in std_logic;
    signal\tdata7 : out std_logic_vector(11-1 downto 0);
    signal signal_data8 : in std_logic;
    signal\t data9 : in signal_type;
    signal data10_signal :\tin std_logic;\t
    signal \t data11 : in type_signal
;);
end entity;
"""
        )
        self._check_entity_with_ports(entity)

    def test_parsing_simple_package_body(self):
        package_body = self.parse_single_package_body(
            """\
package body simple is
begin
end package body;
"""
        )
        self.assertEqual(package_body.identifier, "simple")

    def test_parsing_simple_package(self):
        package = self.parse_single_package(
            """\
package simple is
end package;
"""
        )
        self.assertEqual(package.identifier, "simple")

    def test_parsing_generic_package(self):
        package = self.parse_single_package(
            """\
package pkg is
  generic (c : integer;
           b : bit_vector(4-1 downto 0));
end package;
"""
        )
        self.assertEqual(package.identifier, "pkg")

    def test_parsing_generic_package_instance(self):
        package = self.parse_single_package(
            """\
package instance_pkg is new work.generic_pkg;
"""
        )
        self.assertEqual(package.identifier, "instance_pkg")

        package = self.parse_single_package(
            """\


package instance_pkg is
new work.generic_pkg;
"""
        )
        self.assertEqual(package.identifier, "instance_pkg")

        package = self.parse_single_package(
            """\
package instance_pkg is new work.generic_pkg
        generic map (foo : boolean);
"""
        )
        self.assertEqual(package.identifier, "instance_pkg")

        # Skip nested packages using the heuristic that the package is
        # indented from the first column.
        design_file = VHDLDesignFile.parse(
            """\
 package instance_pkg is new work.generic_pkg
"""
        )
        self.assertEqual(len(design_file.packages), 0)

    def test_parsing_context(self):
        context = self.parse_single_context(
            """\
context foo is
  library bar;
  use bar.bar_pkg.all;
end context;

context name1.is_identifier; -- Should be ignored
"""
        )
        self.assertEqual(context.identifier, "foo")

        context = self.parse_single_context(
            """\
context identifier is
  library bar;
  use bar.bar_pkg.all;
end context identifier;
"""
        )
        self.assertEqual(context.identifier, "identifier")

    def test_getting_component_instantiations_from_design_file(self):
        design_file = VHDLDesignFile.parse(
            """
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

"""
        )
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

    def test_that_enumeration_type_declarations_are_found(self):
        code = """\
type incomplete_type_declaration_t;
 type   color_t  is( blue ,red  , green ) ;  -- Color type
type animal_t is (cow);"""

        enums = {e.identifier: e.literals for e in VHDLEnumerationType.find(code)}
        expect = {"color_t": ["blue", "red", "green"], "animal_t": ["cow"]}
        self.assertEqual(enums, expect)

    def test_that_array_type_declarations_are_found(self):
        code = """\
type constrained_integer_array_t is array(3 downto 0) of integer;
type unconstrained_fish_array_t is array(integer range <>) of fish_t;
type constrained_badgers_array_t is array ( -1 downto 0 ) of badger_t;
type unconstrained_natural_array_t is array ( integer range <> ) of natural;
"""
        arrays = {e.identifier: e.subtype_indication.type_mark for e in VHDLArrayType.find(code)}
        expect = {
            "constrained_integer_array_t": "integer",
            "unconstrained_fish_array_t": "fish_t",
            "constrained_badgers_array_t": "badger_t",
            "unconstrained_natural_array_t": "natural",
        }
        self.assertEqual(arrays, expect)

    def test_that_record_type_declarations_are_found(self):
        code = """\
type space_time_t is record
  x, y, z : real;
  t : time;
end record space_time_t;

type complex_t is record
  im, re : real;
end record;

 type  foo  is
record
  bar:std_logic_vector(7 downto 0)  ;
 end  record  ;"""

        records = {e.identifier: e.elements for e in VHDLRecordType.find(code)}
        self.assertEqual(len(records), 3)

        self.assertIn("space_time_t", records)
        self.assertEqual(records["space_time_t"][0].identifier_list, ["x", "y", "z"])
        self.assertEqual(records["space_time_t"][0].subtype_indication.type_mark, "real")
        self.assertEqual(records["space_time_t"][1].identifier_list, ["t"])
        self.assertEqual(records["space_time_t"][1].subtype_indication.type_mark, "time")

        self.assertIn("complex_t", records)
        self.assertEqual(records["complex_t"][0].identifier_list, ["im", "re"])
        self.assertEqual(records["complex_t"][0].subtype_indication.type_mark, "real")

        self.assertIn("foo", records)
        self.assertEqual(records["foo"][0].identifier_list, ["bar"])
        self.assertEqual(records["foo"][0].subtype_indication.type_mark, "std_logic_vector")
        self.assertEqual(records["foo"][0].subtype_indication.constraint, "(7 downto 0)")
        self.assertTrue(records["foo"][0].subtype_indication.array_type)

    def test_remove_comments(self):
        self.assertEqual(remove_comments("a\n-- foo  \nb"), "a\n        \nb")

    def test_two_adjacent_hyphens_in_a_literal(self):
        stimulus = 'signal a : std_logic_vector(3 downto 0) := "----";'
        self.assertEqual(remove_comments(stimulus), stimulus)

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

    @staticmethod
    def _create_entity():
        """
        Helper function to create a VHDLEntity
        """
        data_width = VHDLInterfaceElement("data_width", VHDLSubtypeIndication.parse("natural := 16"))

        clk = VHDLInterfaceElement("clk", VHDLSubtypeIndication.parse("std_logic"), "in")
        data = VHDLInterfaceElement(
            "data",
            VHDLSubtypeIndication.parse("std_logic_vector(data_width-1 downto 0)"),
            "out",
        )

        entity = VHDLEntity(identifier="name", generics=[data_width], ports=[clk, data])
        return entity
