# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test of the machine-readable VHDL and Python API reference generator.

Uses small, inline GHDL XML documents together with matching VHDL source
text (no GHDL invoked) and a small Python module defined in this file (no
Sphinx build). Columns are computed from the same source-text literals with
str.index() rather than hand-counted, so a typo in the fixture cannot make
a test pass for the wrong reason.
"""

import sys
import unittest
from pathlib import Path
from xml.etree import ElementTree

from tools import build_api_reference as bar


def _col(line_text, needle):
    """1-based column of the first occurrence of needle in line_text."""
    return line_text.index(needle) + 1


class TestSourceTextSlicing(unittest.TestCase):
    """
    SourceText.slice_from: delimiters, bracket depth, string and character
    literals, and the "no closing delimiter" error.
    """

    def test_slices_up_to_semicolon(self):
        source = bar.SourceText("  integer;\n")
        self.assertEqual(source.slice_from(1, 3, "f.vhd", 1, allow_assign=True), "integer")

    def test_stops_at_assign_for_types(self):
        source = bar.SourceText("positive := 1;\n")
        self.assertEqual(source.slice_from(1, 1, "f.vhd", 1, allow_assign=True), "positive")

    def test_does_not_stop_at_assign_for_values(self):
        # A default value never itself contains ":=", but allow_assign=False
        # must not treat ":" specially either.
        source = bar.SourceText('a & ":" & b;\n')
        self.assertEqual(source.slice_from(1, 1, "f.vhd", 1, allow_assign=False), 'a & ":" & b')

    def test_balances_parentheses_before_stopping_at_semicolon(self):
        source = bar.SourceText("array (natural range <>) of rec_t;\n")
        self.assertEqual(
            source.slice_from(1, 1, "f.vhd", 1, allow_assign=True),
            "array (natural range <>) of rec_t",
        )

    def test_stray_close_paren_ends_a_parameter_slice(self):
        # As found inside "(name : positive := 1)" -- the type/default slice
        # for the last parameter in a list must stop at the enclosing ")".
        source = bar.SourceText("positive := 1)\n")
        self.assertEqual(source.slice_from(1, 1, "f.vhd", 1, allow_assign=False), "positive := 1")

    def test_collapses_whitespace_to_single_spaces(self):
        source = bar.SourceText("integer\n  range\n  0 to 15;\n")
        self.assertEqual(source.slice_from(1, 1, "f.vhd", 1, allow_assign=True), "integer range 0 to 15")

    def test_comments_neither_delimit_nor_belong_to_the_slice(self):
        source = bar.SourceText("natural -- width; (in bits)\n  range 0 to 8 := 8;\n")
        self.assertEqual(source.slice_from(1, 1, "f.vhd", 1, allow_assign=True), "natural range 0 to 8")
        # A trailing comment on the last parameter of a list, before the closing parenthesis
        source = bar.SourceText("8 -- default width )\n  );\n")
        self.assertEqual(source.slice_from(1, 1, "f.vhd", 1, allow_assign=False), "8")

    def test_string_literal_semicolon_is_not_a_delimiter(self):
        source = bar.SourceText('string := "a;b";\n')
        self.assertEqual(source.slice_from(1, 1, "f.vhd", 1, allow_assign=True), "string")
        # And the value itself, starting after ":=", keeps the semicolon.
        self.assertEqual(bar.SourceText('"a;b";\n').slice_from(1, 1, "f.vhd", 1, allow_assign=False), '"a;b"')

    def test_escaped_quote_inside_string_literal(self):
        source = bar.SourceText('"a""b";\n')
        self.assertEqual(source.slice_from(1, 1, "f.vhd", 1, allow_assign=False), '"a""b"')

    def test_character_literal_semicolon_is_not_a_delimiter(self):
        # A ';' character literal used as a default value: the semicolon
        # inside the literal must not end the slice.
        source = bar.SourceText("character := ';';\n")
        self.assertEqual(source.slice_from(1, 1, "f.vhd", 1, allow_assign=False), "character := ';'")

    def test_attribute_tick_is_not_mistaken_for_a_character_literal(self):
        source = bar.SourceText("integer range -1 to integer'high;\n")
        self.assertEqual(source.slice_from(1, 1, "f.vhd", 1, allow_assign=True), "integer range -1 to integer'high")

    def test_no_delimiter_raises(self):
        source = bar.SourceText("integer\n")
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            source.slice_from(1, 1, "f.vhd", 7, allow_assign=True)
        self.assertIn("f.vhd:7", str(ctx.exception))

    def test_tab_stop_column_mapping(self):
        # A real gotcha: GHDL reports columns with tab stops of 8, like a
        # terminal, not one column per character.
        source = bar.SourceText('\tname : string := "";\n')
        # Column 9 is where "name" starts after one leading tab; slicing
        # from there (stopping at ":=") proves the start position is right.
        self.assertEqual(source.slice_from(1, 9, "f.vhd", 1, allow_assign=True), "name : string")


class TestDocComments(unittest.TestCase):
    """
    The contiguous "--" comment block directly above a declaration, doc
    comment termination on a blank line, and the license-header exclusion
    for a package's own doc.
    """

    def test_extracts_comment_block_directly_above(self):
        text = "  -- Returns the length\n  -- of the queue\n  function length return natural;\n"
        source = bar.SourceText(text)
        self.assertEqual(bar.comment_block_above(source, 3), "Returns the length\nof the queue")

    def test_blank_line_ends_the_block(self):
        text = "  -- Unrelated comment\n\n  function length return natural;\n"
        source = bar.SourceText(text)
        self.assertIsNone(bar.comment_block_above(source, 3))

    def test_no_comment_above_gives_none(self):
        text = "  use work.foo_pkg.all;\n  function length return natural;\n"
        source = bar.SourceText(text)
        self.assertIsNone(bar.comment_block_above(source, 2))

    def test_license_header_excluded_from_package_doc(self):
        text = (
            "-- This Source Code Form is subject to the terms of the Mozilla Public\n"
            "-- License, v. 2.0.\n"
            "package my_pkg is\n"
        )
        source = bar.SourceText(text)
        self.assertIsNone(bar.package_doc(source, 3))

    def test_non_license_comment_kept_for_package_doc(self):
        text = "-- A package for testing\npackage my_pkg is\n"
        source = bar.SourceText(text)
        self.assertEqual(bar.package_doc(source, 2), "A package for testing")

    def test_impure_on_a_preceding_line_shifts_the_doc_anchor(self):
        text = "  -- Returns something\n  impure\n  function get return integer;\n"
        source = bar.SourceText(text)
        self.assertEqual(bar.comment_block_above(source, bar.subprogram_first_line(source, 3)), "Returns something")

    def test_impure_on_the_same_line_does_not_pull_in_the_comment_above(self):
        # Here the comment belongs to something else entirely -- decl_line
        # already holds "impure function", so the search starts one line
        # above *that*, which is blank.
        text = "  -- Unrelated\n\n  impure function get return integer;\n"
        source = bar.SourceText(text)
        self.assertIsNone(bar.comment_block_above(source, bar.subprogram_first_line(source, 3)))


class TestConvertSubprogram(unittest.TestCase):
    """
    procedure/function, pure/impure, operators, parameter classes/modes/
    defaults, constrained parameter types, return types.
    """

    def _parse(self, xml):
        return ElementTree.fromstring(xml)

    def test_procedure_has_no_pure_flag(self):
        line = "  procedure proc_set (target : in rec_t);"
        xml = f"""
        <el kind="procedure_declaration" identifier="proc_set" line="1"
            col="{_col(line, "proc_set")}" has_body="false">
          <interface_declaration_chain>
            <el kind="interface_constant_declaration" identifier="target" mode="in">
              <subtype_indication line="1" col="{_col(line, "rec_t")}" file="f.vhd"/>
            </el>
          </interface_declaration_chain>
        </el>
        """
        el = self._parse(xml)
        source = bar.SourceText(line + "\n")
        entry = bar.convert_subprogram(el, source, "f.vhd")
        self.assertEqual(entry["kind"], "procedure")
        self.assertIsNone(entry["pure"])
        self.assertFalse(entry["operator"])
        self.assertEqual(entry["parameters"][0]["type"], "rec_t")
        self.assertEqual(entry["parameters"][0]["class"], "constant")
        self.assertEqual(entry["parameters"][0]["mode"], "in")

    def test_function_pure_flag_and_return_type(self):
        for pure_flag, prefix in (("false", "impure "), ("true", "")):
            with self.subTest(pure_flag=pure_flag):
                line = f"  {prefix}function func_get (target : rec_t) return integer;"
                xml = f"""
                <el kind="function_declaration" identifier="func_get" line="1"
                    col="{_col(line, "func_get")}" pure_flag="{pure_flag}" has_body="false">
                  <interface_declaration_chain/>
                  <return_type_mark identifier="integer"/>
                </el>
                """
                entry = bar.convert_subprogram(self._parse(xml), bar.SourceText(line + "\n"), "f.vhd")
                self.assertEqual(entry["kind"], "function")
                self.assertEqual(entry["pure"], pure_flag == "true")
                self.assertEqual(entry["return_type"], "integer")

    def test_operator_identifier_is_flagged(self):
        line = '  function "+" (l, r : rec_t) return rec_t;'
        xml = f"""
        <el kind="function_declaration" identifier="+" line="1"
            col="{_col(line, chr(34) + "+" + chr(34))}" pure_flag="false" has_body="false">
          <interface_declaration_chain/>
          <return_type_mark identifier="rec_t"/>
        </el>
        """
        el = self._parse(xml)
        source = bar.SourceText(line + "\n")
        entry = bar.convert_subprogram(el, source, "f.vhd")
        self.assertTrue(entry["operator"])
        self.assertEqual(entry["name"], "+")

    def test_parameter_default_value(self):
        line = "    value : in integer := 0"
        xml = f"""
        <el kind="procedure_declaration" identifier="proc_set" line="1" col="1" has_body="false">
          <interface_declaration_chain>
            <el kind="interface_constant_declaration" identifier="value" mode="in">
              <subtype_indication line="1" col="{_col(line, "integer")}" file="f.vhd"/>
              <default_value line="1" col="{_col(line, "0")}" file="f.vhd"/>
            </el>
          </interface_declaration_chain>
        </el>
        """
        el = self._parse(xml)
        source = bar.SourceText(line + ";\n")
        entry = bar.convert_subprogram(el, source, "f.vhd")
        self.assertEqual(entry["parameters"][0]["default"], "0")

    def test_signal_and_variable_parameter_classes(self):
        line = "    signal net : inout t; variable pass : out boolean"
        xml = f"""
        <el kind="procedure_declaration" identifier="p" line="1" col="1" has_body="false">
          <interface_declaration_chain>
            <el kind="interface_signal_declaration" identifier="net" mode="inout">
              <subtype_indication line="1" col="{_col(line, "t;")}" file="f.vhd"/>
            </el>
            <el kind="interface_variable_declaration" identifier="pass" mode="out">
              <subtype_indication line="1" col="{_col(line, "boolean")}" file="f.vhd"/>
            </el>
          </interface_declaration_chain>
        </el>
        """
        el = self._parse(xml)
        source = bar.SourceText(line + ";\n")
        entry = bar.convert_subprogram(el, source, "f.vhd")
        self.assertEqual(entry["parameters"][0]["class"], "signal")
        self.assertEqual(entry["parameters"][0]["mode"], "inout")
        self.assertEqual(entry["parameters"][1]["class"], "variable")

    def test_constrained_parameter_type(self):
        line = "    data : std_logic_vector(7 downto 0)"
        xml = f"""
        <el kind="procedure_declaration" identifier="p" line="1" col="1" has_body="false">
          <interface_declaration_chain>
            <el kind="interface_constant_declaration" identifier="data" mode="in">
              <subtype_indication line="1" col="{_col(line, "std_logic_vector")}" file="f.vhd"/>
            </el>
          </interface_declaration_chain>
        </el>
        """
        el = self._parse(xml)
        source = bar.SourceText(line + ";\n")
        entry = bar.convert_subprogram(el, source, "f.vhd")
        self.assertEqual(entry["parameters"][0]["type"], "std_logic_vector(7 downto 0)")

    def test_implicit_operator_parameter_without_subtype_indication(self):
        # GHDL synthesizes "=" for every type; its parameters carry a type
        # reference but no textual subtype_indication (nothing was written).
        xml = """
        <el kind="function_declaration" identifier="=" line="1" col="1"
            pure_flag="false" has_body="false" implicit_definition="IIR_PREDEFINED_RECORD_EQUALITY">
          <interface_declaration_chain>
            <el kind="interface_constant_declaration" identifier="" mode="in">
              <type ref="1"/>
            </el>
          </interface_declaration_chain>
          <return_type ref="1"/>
        </el>
        """
        el = self._parse(xml)
        source = bar.SourceText("\n")
        entry = bar.convert_subprogram(el, source, "f.vhd")
        self.assertTrue(entry["operator"])
        self.assertIsNone(entry["parameters"][0]["type"])
        self.assertEqual(entry["parameters"][0]["name"], "")

    def test_unhandled_parameter_kind_raises(self):
        xml = """
        <el kind="procedure_declaration" identifier="p" line="1" col="1" has_body="false">
          <interface_declaration_chain>
            <el kind="interface_mystery_declaration" identifier="x" mode="in"/>
          </interface_declaration_chain>
        </el>
        """
        el = self._parse(xml)
        source = bar.SourceText("\n")
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            bar.convert_subprogram(el, source, "f.vhd")
        self.assertIn("interface_mystery_declaration", str(ctx.exception))


class TestConvertAlias(unittest.TestCase):
    """Aliases with signatures and return types, including object aliases."""

    def test_subprogram_alias_with_signature_and_return_type(self):
        xml = """
        <el kind="non_object_alias_declaration" identifier="alias_get" line="9">
          <name kind="simple_name" identifier="func_get"/>
          <alias_signature>
            <type_marks_list>
              <el identifier="rec_t"/>
            </type_marks_list>
            <return_type_mark identifier="integer"/>
          </alias_signature>
        </el>
        """
        el = ElementTree.fromstring(xml)
        entry = bar.convert_alias(el)
        self.assertEqual(entry["name"], "alias_get")
        self.assertEqual(entry["target"], "func_get")
        self.assertEqual(entry["signature"], ["rec_t"])
        self.assertEqual(entry["return_type"], "integer")
        self.assertNotIn("doc", entry)

    def test_procedure_alias_has_no_return_type(self):
        xml = """
        <el kind="non_object_alias_declaration" identifier="alias_set" line="9">
          <name kind="simple_name" identifier="proc_set"/>
          <alias_signature>
            <type_marks_list>
              <el identifier="rec_t"/>
              <el identifier="integer"/>
            </type_marks_list>
          </alias_signature>
        </el>
        """
        el = ElementTree.fromstring(xml)
        entry = bar.convert_alias(el)
        self.assertEqual(entry["signature"], ["rec_t", "integer"])
        self.assertIsNone(entry["return_type"])

    def test_object_alias_has_no_signature(self):
        # "alias null_byte_vector_ptr is null_string_ptr;" -- an
        # object_alias_declaration, aliasing a constant, not a subprogram.
        xml = """
        <el kind="object_alias_declaration" identifier="null_vec_ptr" line="21">
          <name kind="simple_name" identifier="null_ptr"/>
        </el>
        """
        el = ElementTree.fromstring(xml)
        entry = bar.convert_alias(el)
        self.assertEqual(entry["target"], "null_ptr")
        self.assertEqual(entry["signature"], [])
        self.assertIsNone(entry["return_type"])

    def test_dotted_selected_name_target(self):
        xml = """
        <el kind="non_object_alias_declaration" identifier="a" line="1">
          <name kind="selected_name" identifier="push">
            <prefix kind="simple_name" identifier="work"/>
          </name>
        </el>
        """
        el = ElementTree.fromstring(xml)
        entry = bar.convert_alias(el)
        self.assertEqual(entry["target"], "work.push")


class TestConvertType(unittest.TestCase):
    """Records, enumerations, protected types and their methods, other types."""

    def test_record_type(self):
        line = "    a : integer;"
        xml = f"""
        <el kind="type_declaration" identifier="rec_t" line="1">
          <type_definition kind="record_type_definition">
            <elements_declaration_list>
              <el identifier="a">
                <subtype_indication line="1" col="{_col(line, "integer")}" file="f.vhd"/>
              </el>
            </elements_declaration_list>
          </type_definition>
        </el>
        """
        el = ElementTree.fromstring(xml)
        source = bar.SourceText(line + "\n")
        entry = bar.convert_type(el, source, "f.vhd")
        self.assertEqual(entry["kind"], "record")
        self.assertEqual(entry["elements"], [{"name": "a", "type": "integer"}])

    def test_enumeration_type(self):
        xml = """
        <el kind="type_declaration" identifier="color_t" line="1">
          <type_definition kind="enumeration_type_definition">
            <enumeration_literal_list>
              <el identifier="red"/>
              <el identifier="green"/>
              <el identifier="blue"/>
            </enumeration_literal_list>
          </type_definition>
        </el>
        """
        el = ElementTree.fromstring(xml)
        entry = bar.convert_type(el, bar.SourceText("\n"), "f.vhd")
        self.assertEqual(entry["kind"], "enumeration")
        self.assertEqual(entry["literals"], ["red", "green", "blue"])

    def test_protected_type_with_methods(self):
        line = "    procedure set (value : integer);"
        xml = f"""
        <el kind="type_declaration" identifier="protected_t" line="1">
          <type_definition kind="protected_type_declaration">
            <declaration_chain>
              <el kind="procedure_declaration" identifier="set" line="1"
                  col="{_col(line, "set")}" has_body="false">
                <interface_declaration_chain>
                  <el kind="interface_constant_declaration" identifier="value" mode="in">
                    <subtype_indication line="1" col="{_col(line, "integer")}" file="f.vhd"/>
                  </el>
                </interface_declaration_chain>
              </el>
            </declaration_chain>
          </type_definition>
        </el>
        """
        el = ElementTree.fromstring(xml)
        source = bar.SourceText(line + "\n")
        entry = bar.convert_type(el, source, "f.vhd")
        self.assertEqual(entry["kind"], "protected")
        self.assertEqual(len(entry["subprograms"]), 1)
        method = entry["subprograms"][0]
        self.assertEqual(method["name"], "set")
        self.assertIsNone(method["doc"])

    def test_other_types(self):
        for line, keyword, definition in (
            ("  type vec_t is array (natural range <>) of rec_t;", "array", "array (natural range <>) of rec_t"),
            ("  type ptr_t is access rec_t;", "access", "access rec_t"),
        ):
            with self.subTest(keyword=keyword):
                xml = f"""
                <el kind="type_declaration" identifier="t" line="1">
                  <type_definition kind="{keyword}_type_definition" line="1" col="{_col(line, keyword)}" file="f.vhd"/>
                </el>
                """
                entry = bar.convert_type(ElementTree.fromstring(xml), bar.SourceText(line + "\n"), "f.vhd")
                self.assertEqual(entry["kind"], "other")
                self.assertEqual(entry["definition"], definition)


class TestConvertSubtypeConstantObject(unittest.TestCase):
    def test_subtype(self):
        line = "  subtype small_t is integer range 0 to 15;"
        xml = f"""
        <el identifier="small_t" line="1">
          <subtype_indication line="1" col="{_col(line, "integer")}" file="f.vhd"/>
        </el>
        """
        el = ElementTree.fromstring(xml)
        source = bar.SourceText(line + "\n")
        entry = bar.convert_subtype(el, source, "f.vhd")
        self.assertEqual(entry["definition"], "integer range 0 to 15")

    def test_constant_with_value(self):
        line = "  constant c_max : integer := 15;"
        xml = f"""
        <el identifier="c_max" line="1">
          <subtype_indication line="1" col="{_col(line, "integer")}" file="f.vhd"/>
          <default_value line="1" col="{_col(line, "15")}" file="f.vhd"/>
        </el>
        """
        el = ElementTree.fromstring(xml)
        source = bar.SourceText(line + "\n")
        entry = bar.convert_constant(el, source, "f.vhd")
        self.assertEqual(entry["type"], "integer")
        self.assertEqual(entry["value"], "15")

    def test_deferred_constant_has_no_value(self):
        line = "  constant c_deferred : boolean;"
        xml = f"""
        <el identifier="c_deferred" line="1">
          <subtype_indication line="1" col="{_col(line, "boolean")}" file="f.vhd"/>
        </el>
        """
        el = ElementTree.fromstring(xml)
        source = bar.SourceText(line + "\n")
        entry = bar.convert_constant(el, source, "f.vhd")
        self.assertIsNone(entry["value"])

    def test_objects(self):
        for line, kind, object_class, type_name in (
            ("  signal s_enabled : std_logic := '1';", "signal_declaration", "signal", "std_logic"),
            ("  shared variable v_shared : integer;", "variable_declaration", "shared variable", "integer"),
            ("  file f0 : text;", "file_declaration", "file", "text"),
        ):
            with self.subTest(kind=kind):
                xml = f"""
                <el kind="{kind}" identifier="x" line="1">
                  <subtype_indication line="1" col="{_col(line, type_name)}" file="f.vhd"/>
                </el>
                """
                entry = bar.convert_object(ElementTree.fromstring(xml), bar.SourceText(line + "\n"), "f.vhd")
                self.assertEqual(entry["class"], object_class)
                self.assertEqual(entry["type"], type_name)


class TestConvertPackage(unittest.TestCase):
    """
    Scope: only declarations whose file equals the input file, the ignored
    anonymous_type_declaration, the private-package flag, and the "unhandled
    declaration kind" error.
    """

    def _package_xml(self, decl_chain_xml, name="my_pkg", line="7"):
        return f"""
        <library_unit kind="package_declaration" file="/a/my_pkg.vhd" identifier="{name}" line="{line}">
          <declaration_chain>
            {decl_chain_xml}
          </declaration_chain>
        </library_unit>
        """

    def test_filters_declarations_by_file(self):
        line8 = "  constant local_c : integer := 1;"
        xml = self._package_xml(f"""
            <el kind="constant_declaration" identifier="local_c" line="8" file="/a/my_pkg.vhd">
              <subtype_indication line="8" col="{_col(line8, "integer")}" file="/a/my_pkg.vhd"/>
            </el>
            <el kind="constant_declaration" identifier="dep_c" line="3" file="/a/other_pkg.vhd">
              <subtype_indication line="3" col="10" file="/a/other_pkg.vhd"/>
            </el>
            """)
        el = ElementTree.fromstring(xml)
        source = bar.SourceText("\n" * 7 + line8 + "\n")
        pkg = bar.convert_package(el, source, "/a/my_pkg.vhd", "my_pkg.vhd")
        names = [c["name"] for c in pkg["constants"]]
        self.assertEqual(names, ["local_c"])

    def test_anonymous_type_declaration_is_ignored(self):
        xml = self._package_xml("""
            <el kind="anonymous_type_declaration" identifier="" line="8" file="/a/my_pkg.vhd"/>
            """)
        el = ElementTree.fromstring(xml)
        pkg = bar.convert_package(el, bar.SourceText("\n"), "/a/my_pkg.vhd", "my_pkg.vhd")
        for bucket in ("types", "subtypes", "constants", "objects", "subprograms", "aliases"):
            self.assertEqual(pkg[bucket], [])

    def test_unhandled_declaration_kind_raises(self):
        xml = self._package_xml("""
            <el kind="component_declaration" identifier="c" line="9" file="/a/my_pkg.vhd"/>
            """)
        el = ElementTree.fromstring(xml)
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            bar.convert_package(el, bar.SourceText("\n"), "/a/my_pkg.vhd", "my_pkg.vhd")
        self.assertIn("component_declaration", str(ctx.exception))
        self.assertIn("/a/my_pkg.vhd:9", str(ctx.exception))

    def test_private_package_flag(self):
        for name, private in (("data_types_private_pkg", True), ("queue_pkg", False)):
            with self.subTest(name=name):
                el = ElementTree.fromstring(self._package_xml("", name=name))
                pkg = bar.convert_package(el, bar.SourceText("\n"), "/a/my_pkg.vhd", "my_pkg.vhd")
                self.assertEqual(pkg["private"], private)

    def test_p_prefixed_names_not_flagged_private(self):
        line8 = "  constant p_internal : integer := 1;"
        xml = self._package_xml(f"""
            <el kind="constant_declaration" identifier="p_internal" line="8" file="/a/my_pkg.vhd">
              <subtype_indication line="8" col="{_col(line8, "integer")}" file="/a/my_pkg.vhd"/>
            </el>
            """)
        el = ElementTree.fromstring(xml)
        source = bar.SourceText("\n" * 7 + line8 + "\n")
        pkg = bar.convert_package(el, source, "/a/my_pkg.vhd", "my_pkg.vhd")
        self.assertFalse(pkg["private"])
        self.assertEqual(pkg["constants"][0]["name"], "p_internal")


class TestPackageScope(unittest.TestCase):
    """find_package_files: the vunit/vhdl/**/src/**/*.vhd scope filter."""

    def _make_tree(self, tmp_path, files):
        for relpath, content in files.items():
            path = tmp_path / relpath
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    def test_finds_package_declaration_files(self):
        tmp_path = Path(self._tmp_dir())
        self._make_tree(
            tmp_path,
            {
                "vunit/vhdl/data_types/src/queue_pkg.vhd": "package queue_pkg is\nend package;\n",
            },
        )
        found = bar.find_package_files(tmp_path)
        self.assertEqual([name for _, name in found], ["queue_pkg"])

    def test_excludes_package_body(self):
        tmp_path = Path(self._tmp_dir())
        self._make_tree(
            tmp_path,
            {
                "vunit/vhdl/foo/src/foo_pkg.vhd": (
                    "package foo_pkg is\nend package;\npackage body foo_pkg is\nend package body;\n"
                ),
            },
        )
        found = bar.find_package_files(tmp_path)
        self.assertEqual([name for _, name in found], ["foo_pkg"])

    def test_excludes_package_instantiation(self):
        tmp_path = Path(self._tmp_dir())
        self._make_tree(
            tmp_path,
            {
                "vunit/vhdl/foo/src/foo_pkg.vhd": (
                    "package foo_generic_pkg is\nend package;\n"
                    "package foo_pkg is new work.foo_generic_pkg generic map (t => integer);\n"
                ),
            },
        )
        found = bar.find_package_files(tmp_path)
        self.assertEqual([name for _, name in found], ["foo_generic_pkg"])

    def test_excludes_osvvm(self):
        tmp_path = Path(self._tmp_dir())
        self._make_tree(
            tmp_path,
            {
                "vunit/vhdl/osvvm/src/SomePkg.vhd": "package SomePkg is\nend package;\n",
            },
        )
        found = bar.find_package_files(tmp_path)
        self.assertEqual(found, [])

    _tmp_dirs = []

    def _tmp_dir(self):
        import tempfile

        tmp = tempfile.mkdtemp(prefix="vunit-api-scope-")
        self._tmp_dirs.append(tmp)
        return tmp

    def tearDown(self):
        import shutil

        for tmp in self._tmp_dirs:
            shutil.rmtree(tmp, ignore_errors=True)
        self._tmp_dirs = []


class TestCompleteness(unittest.TestCase):
    def test_passes_when_sets_match(self):
        bar.check_completeness(["a", "b"], ["b", "a"])

    def test_raises_listing_missing_and_extra(self):
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            bar.check_completeness(["a", "c"], ["a", "b"])
        message = str(ctx.exception)
        self.assertIn("'b'", message)
        self.assertIn("'c'", message)


class TestErrorHandling(unittest.TestCase):
    """The converter error conditions of design-spec section 6."""

    def test_ghdl_not_on_path(self):
        import shutil
        from unittest import mock

        with mock.patch.object(shutil, "which", return_value=None):
            with self.assertRaises(bar.ApiReferenceError) as ctx:
                bar.check_ghdl_available()
        self.assertEqual(
            str(ctx.exception),
            "GHDL is required to build the API reference; install GHDL or set VUNIT_DOCS_SKIP_API=1",
        )

    def test_file_to_xml_nonzero_exit(self):
        import subprocess
        from unittest import mock

        fake = subprocess.CompletedProcess(
            args=["ghdl"], returncode=1, stdout="", stderr="somefile.vhd:3:1:error: bad syntax\n"
        )
        with mock.patch.object(subprocess, "run", return_value=fake):
            with self.assertRaises(bar.ApiReferenceError) as ctx:
                bar.run_file_to_xml(Path("somefile.vhd"), Path("/libs/vunit_lib"), Path("/libs/osvvm"))
        message = str(ctx.exception)
        self.assertIn("somefile.vhd", message)
        self.assertIn("error: bad syntax", message)

    def test_xml_root_version_mismatch(self):
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            bar.parse_xml_root('<root version="0.12"></root>')
        self.assertIn("0.12", str(ctx.exception))
        self.assertIn("converter must be checked", str(ctx.exception))

    def test_xml_root_correct_version_parses(self):
        root = bar.parse_xml_root('<root version="0.13"></root>')
        self.assertEqual(root.tag, "root")

    def test_vunit_compile_failure_raises(self):
        import types
        from unittest import mock

        class FakeVUnitObj:
            def add_vhdl_builtins(self):
                pass

            def add_verification_components(self):
                pass

            def add_random(self):
                pass

            def add_osvvm(self):
                pass

            def main(self):
                raise SystemExit(1)

        class FakeVUnit:
            @staticmethod
            def from_argv(_args):
                return FakeVUnitObj()

        fake_module = types.ModuleType("vunit")
        fake_module.VUnit = FakeVUnit
        with mock.patch.dict(sys.modules, {"vunit": fake_module}):
            with self.assertRaises(bar.ApiReferenceError) as ctx:
                bar.compile_vunit_libraries("/tmp/does-not-matter")
        self.assertIn("exit code 1", str(ctx.exception))


class SampleClass:
    """A sample class for the Python API test."""

    def method_one(self, value):
        """Doubles value."""
        return value * 2

    @property
    def read_only(self):
        """A read-only property."""
        return 1

    def _private_method(self):
        pass


def sample_function(a, b=1):
    """Adds a and b."""
    return a + b


class TestPythonApi(unittest.TestCase):
    """
    docs/**/*.rst directive scanning and object collection, including the
    "no public objects found" error for an automodule with :members:.
    """

    def test_finds_autoclass_and_automodule_targets(self, tmp_path=None):
        import tempfile

        tmp_path = Path(tempfile.mkdtemp(prefix="vunit-api-rst-"))
        docs = tmp_path / "docs"
        docs.mkdir()
        (docs / "vunit.rst").write_text(
            ".. autoclass:: vunit.ui.VUnit()\n\n.. autoclass:: vunit.ui.library.Library()\n"
            "   :exclude-members: package\n",
            encoding="utf-8",
        )
        (docs / "ui.rst").write_text(".. automodule:: vunit.vunit_cli\n", encoding="utf-8")
        (docs / "opts.rst").write_text(
            ".. automodule:: tests.unit.test_api_reference\n   :members:\n", encoding="utf-8"
        )
        targets = bar.find_python_targets(tmp_path)
        as_dict = {(directive, dotted): has_members for directive, dotted, has_members in targets}
        self.assertEqual(as_dict[("autoclass", "vunit.ui.VUnit")], False)
        self.assertEqual(as_dict[("autoclass", "vunit.ui.library.Library")], False)
        self.assertEqual(as_dict[("automodule", "vunit.vunit_cli")], False)
        self.assertEqual(as_dict[("automodule", "tests.unit.test_api_reference")], True)

    def test_class_object_collects_public_members_defined_on_the_class(self):
        obj = bar.build_class_object(f"{__name__}.SampleClass", SampleClass)
        self.assertEqual(obj["kind"], "class")
        members = {m["name"]: m for m in obj["members"]}
        self.assertIn("method_one", members)
        self.assertIn("read_only", members)
        self.assertNotIn("_private_method", members)
        self.assertEqual(members["read_only"]["kind"], "property")
        self.assertEqual(members["method_one"]["kind"], "method")
        self.assertIn("(self, value)", members["method_one"]["signature"])
        self.assertEqual(members["method_one"]["doc"], "Doubles value.")

    def test_module_object_without_members_option_has_no_members(self):
        obj = bar.build_module_object(__name__, sys.modules[__name__], has_members=False)
        self.assertEqual(obj["kind"], "module")
        self.assertEqual(obj["members"], [])

    def test_module_object_with_members_option_collects_classes_and_functions(self):
        obj = bar.build_module_object(__name__, sys.modules[__name__], has_members=True)
        names = {m["name"] for m in obj["members"]}
        self.assertIn("SampleClass", names)
        self.assertIn("sample_function", names)

    def test_no_public_objects_found_raises(self):
        import types

        empty_module = types.ModuleType("vunit_test_empty_module")
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            bar.build_module_object("vunit_test_empty_module", empty_module, has_members=True)
        self.assertIn("vunit_test_empty_module", str(ctx.exception))

    def test_import_dotted_class(self):
        obj = bar.import_dotted(f"{__name__}.SampleClass")
        self.assertIs(obj, SampleClass)


if __name__ == "__main__":
    unittest.main()
