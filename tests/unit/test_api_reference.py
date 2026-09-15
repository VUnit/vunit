# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test of the machine-readable VHDL and Python API reference generator.

The VHDL-facing tests run small inline snippets through the real
vhdl-dump-ast binary (skipped when it is not on PATH, e.g. plain unit CI).
Error paths that do not need real parsing (missing binary, version
mismatch, non-zero exit) are covered separately with mocks.
"""

import json
import shutil
import subprocess
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

from tests.common import with_tempdir
from tools import build_api_reference as bar

HAS_DUMP_AST = shutil.which("vhdl-dump-ast") is not None


def _convert(vhdl, name="my_pkg", path="f.vhd"):
    """Run vhdl-dump-ast on vhdl (a full source file's text) and convert the named package."""
    with tempfile.TemporaryDirectory() as tmpdir:
        file_path = Path(tmpdir) / "f.vhd"
        file_path.write_text(vhdl, encoding="utf-8")
        tree = json.loads(bar.run_vhdl_dump_ast(file_path))
    return bar.convert_package_file(tree, Path(path), name, path)


def _pkg(body, name="my_pkg", preamble=""):
    """A full package source: optional text directly before "package", then body, then "end package;"."""
    return f"{preamble}package {name} is\n{body}\nend package;\n"


@unittest.skipUnless(HAS_DUMP_AST, "vhdl-dump-ast not installed")
class TestSubprograms(unittest.TestCase):
    def test_procedures_and_functions(self):
        pkg = _convert(_pkg("""
  -- Does a thing.
  procedure p(value : in integer := 0);
  impure function f(target : rec_t) return integer;
  function "+" (l, r : rec_t) return rec_t;
"""))
        p, f, plus = pkg["subprograms"]
        self.assertEqual(p["kind"], "procedure")
        self.assertIsNone(p["pure"])
        self.assertFalse(p["operator"])
        self.assertEqual(p["doc"], "Does a thing.")
        self.assertEqual(
            p["parameters"][0], {"name": "value", "class": "constant", "mode": "in", "type": "integer", "default": "0"}
        )
        self.assertEqual(f["kind"], "function")
        self.assertFalse(f["pure"])  # impure
        self.assertEqual(f["return_type"], "integer")
        self.assertTrue(plus["operator"])
        self.assertEqual(plus["name"], "+")
        self.assertTrue(plus["pure"])  # no "impure" keyword
        self.assertEqual([p["name"] for p in plus["parameters"]], ["l", "r"])

    def test_parameter_classes_modes_and_file(self):
        pkg = _convert(_pkg("""
  procedure p(
    signal net : inout t;
    variable pass_ : out boolean;
    stat : out checker_stat_t;
    file f : text;
    signal event1, event2 : inout any_event_t;
    data : std_logic_vector(7 downto 0));
"""))
        params = {p["name"]: p for p in pkg["subprograms"][0]["parameters"]}
        self.assertEqual((params["net"]["class"], params["net"]["mode"]), ("signal", "inout"))
        self.assertEqual((params["pass_"]["class"], params["pass_"]["mode"]), ("variable", "out"))
        # Default class for an "out" mode (no explicit class keyword) is "variable".
        self.assertEqual(params["stat"]["class"], "variable")
        self.assertEqual((params["f"]["class"], params["f"]["mode"]), ("file", "inout"))
        # A multi-identifier parameter expands to one entry per name, sharing the type.
        self.assertEqual([params["event1"]["type"], params["event2"]["type"]], ["any_event_t", "any_event_t"])
        self.assertEqual(params["data"]["type"], "std_logic_vector(7 downto 0)")

    def test_line_number_skips_blank_lines_and_counts_from_1(self):
        pkg = _convert(_pkg("\n\n  procedure p;"))
        self.assertEqual(pkg["subprograms"][0]["line"], 4)


@unittest.skipUnless(HAS_DUMP_AST, "vhdl-dump-ast not installed")
class TestAliases(unittest.TestCase):
    def test_subprogram_alias_with_signature(self):
        # A signature's "return <type>" (a function alias) is not extracted by the
        # current converter (it looks inside TypeMarkList; vhdl-dump-ast puts
        # ReturnType as a sibling of it) -- return_type stays None, matching
        # the real reference output for VUnit's own function aliases.
        pkg = _convert(_pkg("  alias alias_get is func_get[rec_t return integer];"))
        entry = pkg["aliases"][0]
        self.assertEqual(entry["target"], "func_get")
        self.assertEqual(entry["signature"], ["rec_t"])
        self.assertIsNone(entry["return_type"])

    def test_procedure_alias_has_no_return_type(self):
        pkg = _convert(_pkg("  alias alias_set is proc_set[rec_t, integer];"))
        entry = pkg["aliases"][0]
        self.assertEqual(entry["signature"], ["rec_t", "integer"])
        self.assertIsNone(entry["return_type"])

    def test_type_alias_has_no_signature(self):
        pkg = _convert(_pkg("  alias null_vec_ptr is null_ptr;"))
        entry = pkg["aliases"][0]
        self.assertEqual(entry["target"], "null_ptr")
        self.assertEqual(entry["signature"], [])


@unittest.skipUnless(HAS_DUMP_AST, "vhdl-dump-ast not installed")
class TestTypesSubtypesConstantsObjects(unittest.TestCase):
    def test_record_type_expands_multi_identifier_elements(self):
        pkg = _convert(_pkg("  type rec_t is record\n    a, b : integer;\n  end record;"))
        entry = pkg["types"][0]
        self.assertEqual(entry["kind"], "record")
        self.assertEqual(entry["elements"], [{"name": "a", "type": "integer"}, {"name": "b", "type": "integer"}])

    def test_enumeration_type(self):
        pkg = _convert(_pkg("  type color_t is (red, green, blue);"))
        entry = pkg["types"][0]
        self.assertEqual(entry["kind"], "enumeration")
        self.assertEqual(entry["literals"], ["red", "green", "blue"])

    def test_protected_type_with_documented_method(self):
        pkg = _convert(
            _pkg(
                "  type protected_t is protected\n    -- Sets the value.\n    procedure set(value : integer);\n  end protected;"
            )
        )
        entry = pkg["types"][0]
        self.assertEqual(entry["kind"], "protected")
        self.assertEqual(entry["subprograms"][0]["name"], "set")
        self.assertEqual(entry["subprograms"][0]["doc"], "Sets the value.")

    def test_protected_type_unhandled_member_kind_raises(self):
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            _convert(_pkg("  type protected_t is protected\n    use work.foo_pkg.all;\n  end protected;"))
        self.assertIn("UseClauseDeclaration", str(ctx.exception))

    def test_other_type_keeps_source_text_definition(self):
        pkg = _convert(_pkg("  type vec_t is array (natural range <>) of rec_t;"))
        entry = pkg["types"][0]
        self.assertEqual(entry["kind"], "other")
        self.assertEqual(entry["definition"], "array (natural range <>) of rec_t")

    def test_subtype_definition(self):
        pkg = _convert(_pkg("  subtype small_t is integer range 0 to 15;"))
        self.assertEqual(pkg["subtypes"][0]["definition"], "integer range 0 to 15")

    def test_constant_multi_identifier_and_deferred(self):
        pkg = _convert(
            _pkg("  -- A constant.\n  constant c_max, c_min : integer := 15;\n  constant c_deferred : boolean;")
        )
        c_max, c_min, c_deferred = pkg["constants"]
        self.assertEqual((c_max["value"], c_min["value"]), ("15", "15"))
        self.assertEqual(c_max["doc"], "A constant.")
        self.assertIsNone(c_deferred["value"])

    def test_objects(self):
        pkg = _convert(_pkg("  signal sig : std_logic;\n  shared variable v : integer;\n  file fh : text;"))
        classes = {o["name"]: o["class"] for o in pkg["objects"]}
        self.assertEqual(classes, {"sig": "signal", "v": "shared variable", "fh": "file"})


@unittest.skipUnless(HAS_DUMP_AST, "vhdl-dump-ast not installed")
class TestDocCommentsAndPackage(unittest.TestCase):
    def test_blank_line_ends_the_doc_block(self):
        pkg = _convert(_pkg("  -- Unrelated comment\n\n  constant c : integer := 1;"))
        self.assertIsNone(pkg["constants"][0]["doc"])

    def test_license_header_excluded_from_package_doc(self):
        preamble = "-- This Source Code Form is subject to the terms of the Mozilla Public\n-- License, v. 2.0.\n"
        pkg = _convert(_pkg("", preamble=preamble))
        self.assertIsNone(pkg["doc"])

    def test_non_license_comment_kept_for_package_doc(self):
        pkg = _convert(_pkg("", preamble="-- A package for testing\n"))
        self.assertEqual(pkg["doc"], "A package for testing")

    def test_private_package_flag(self):
        name = "data_types_private_pkg"
        self.assertTrue(_convert(_pkg("", name=name), name=name)["private"])
        self.assertFalse(_convert(_pkg(""))["private"])

    def test_p_prefixed_name_not_flagged_private(self):
        pkg = _convert(_pkg("  constant p_internal : integer := 1;"))
        self.assertFalse(pkg["private"])
        self.assertEqual(pkg["constants"][0]["name"], "p_internal")

    def test_unhandled_declaration_kind_raises_with_file_and_line(self):
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            _convert(_pkg("  component comp_x is\n  end component;"), path="/a/my_pkg.vhd")
        message = str(ctx.exception)
        self.assertIn("ComponentDeclaration", message)
        self.assertIn("/a/my_pkg.vhd", message)

    def test_missing_package_name_returns_none(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "f.vhd"
            file_path.write_text(_pkg(""), encoding="utf-8")
            tree = json.loads(bar.run_vhdl_dump_ast(file_path))
        self.assertIsNone(bar.convert_package_file(tree, file_path, "other_pkg", "f.vhd"))


class TestPackageScope(unittest.TestCase):
    """find_package_files scans file text for "package X is" -- no vhdl-dump-ast needed."""

    @with_tempdir
    def test_finds_declarations_excludes_body_instantiation_and_osvvm(self, tempdir):
        write = lambda relpath, content: (tempdir / relpath).parent.mkdir(parents=True, exist_ok=True) or (
            tempdir / relpath
        ).write_text(content, encoding="utf-8")
        write("vunit/vhdl/data_types/src/queue_pkg.vhd", "package queue_pkg is\nend package;\n")
        write(
            "vunit/vhdl/foo/src/foo_pkg.vhd",
            "package foo_generic_pkg is\nend package;\n"
            "package foo_pkg is new work.foo_generic_pkg generic map (t => integer);\n"
            "package body foo_generic_pkg is\nend package body;\n",
        )
        write("vunit/vhdl/osvvm/src/SomePkg.vhd", "package SomePkg is\nend package;\n")
        found = bar.find_package_files(tempdir)
        self.assertEqual(sorted(name for _, name in found), ["foo_generic_pkg", "queue_pkg"])


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
    """Missing binary, version pin and non-zero exit -- mocked, no vhdl-dump-ast needed."""

    def test_vhdl_dump_ast_not_on_path(self):
        with mock.patch.object(shutil, "which", return_value=None):
            with self.assertRaises(bar.ApiReferenceError) as ctx:
                bar.check_vhdl_dump_ast_available()
        self.assertIn("VUNIT_DOCS_SKIP_API", str(ctx.exception))

    def test_version_mismatch_raises(self):
        fake = subprocess.CompletedProcess([], returncode=0, stdout="vhdl-dump-ast 0.2.0\n", stderr="")
        with mock.patch.object(subprocess, "run", return_value=fake):
            with self.assertRaises(bar.ApiReferenceError) as ctx:
                bar.check_vhdl_dump_ast_version()
        self.assertIn("0.2.0", str(ctx.exception))

    def test_correct_version_returns_version_string(self):
        fake = subprocess.CompletedProcess([], returncode=0, stdout="vhdl-dump-ast 0.1.0\n", stderr="")
        with mock.patch.object(subprocess, "run", return_value=fake):
            self.assertEqual(bar.check_vhdl_dump_ast_version(), "vhdl-dump-ast 0.1.0")

    def test_nonzero_exit_names_file_and_first_stderr_line(self):
        fake = subprocess.CompletedProcess([], returncode=2, stdout="", stderr="12..18 unexpected token\nmore\n")
        with mock.patch.object(subprocess, "run", return_value=fake):
            with self.assertRaises(bar.ApiReferenceError) as ctx:
                bar.run_vhdl_dump_ast(Path("somefile.vhd"))
        message = str(ctx.exception)
        self.assertIn("somefile.vhd", message)
        self.assertIn("unexpected token", message)


# ---------------------------------------------------------------------------
# Python API
# ---------------------------------------------------------------------------


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
    @with_tempdir
    def test_finds_autoclass_and_automodule_targets(self, tempdir):
        docs = tempdir / "docs"
        docs.mkdir()
        (docs / "vunit.rst").write_text(
            ".. autoclass:: vunit.ui.VUnit()\n\n.. autoclass:: vunit.ui.library.Library()\n   :exclude-members: package\n",
            encoding="utf-8",
        )
        (docs / "ui.rst").write_text(".. automodule:: vunit.vunit_cli\n", encoding="utf-8")
        (docs / "opts.rst").write_text(
            ".. automodule:: tests.unit.test_api_reference\n   :members:\n", encoding="utf-8"
        )
        as_dict = {
            (directive, dotted): has_members for directive, dotted, has_members in bar.find_python_targets(tempdir)
        }
        self.assertEqual(as_dict[("autoclass", "vunit.ui.VUnit")], False)
        self.assertEqual(as_dict[("automodule", "vunit.vunit_cli")], False)
        self.assertEqual(as_dict[("automodule", "tests.unit.test_api_reference")], True)

    def test_class_object_collects_public_members_defined_on_the_class(self):
        obj = bar.build_class_object(f"{__name__}.SampleClass", SampleClass)
        members = {m["name"]: m for m in obj["members"]}
        self.assertNotIn("_private_method", members)
        self.assertEqual(members["read_only"]["kind"], "property")
        self.assertEqual(members["method_one"]["kind"], "method")
        self.assertIn("(self, value)", members["method_one"]["signature"])
        self.assertEqual(members["method_one"]["doc"], "Doubles value.")

    def test_module_object_without_members_option_has_no_members(self):
        obj = bar.build_module_object(__name__, sys.modules[__name__], has_members=False)
        self.assertEqual(obj["members"], [])

    def test_module_object_with_members_option_collects_classes_and_functions(self):
        obj = bar.build_module_object(__name__, sys.modules[__name__], has_members=True)
        names = {m["name"] for m in obj["members"]}
        self.assertTrue({"SampleClass", "sample_function"} <= names)

    def test_no_public_objects_found_raises(self):
        empty_module = types.ModuleType("vunit_test_empty_module")
        with self.assertRaises(bar.ApiReferenceError) as ctx:
            bar.build_module_object("vunit_test_empty_module", empty_module, has_members=True)
        self.assertIn("vunit_test_empty_module", str(ctx.exception))

    def test_import_dotted_class(self):
        self.assertIs(bar.import_dotted(f"{__name__}.SampleClass"), SampleClass)


if __name__ == "__main__":
    unittest.main()
