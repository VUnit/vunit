# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test builtins.py
"""

from tempfile import tempdir
import unittest
import re
from unittest import mock
from vunit import VUnit
from vunit.builtins import Builtins, BuiltinsAdder
from vunit.about import version
from vunit.vhdl_standard import VHDLStandard
from vunit.project import Project
from tests.common import create_tempdir
from contextlib import contextmanager
from importlib.machinery import ModuleSpec


@contextmanager
def pkg_env(tempdir):
    spec = ModuleSpec(name="foo", loader=None, origin=str(tempdir / "__init__.py"))
    spec.submodule_search_locations = [str(tempdir)]
    with mock.patch("vunit.builtins.importlib.util.find_spec", return_value=spec):
        yield


class TestBuiltins(unittest.TestCase):
    """
    Test Builtins class
    """

    def setUp(self):
        self.vu = mock.create_autospec(VUnit, instance=True)
        self.vu._project = mock.create_autospec(Project, instance=True)
        self.vu._project._libraries = []
        self.library_mock = mock.Mock()

        def add_library(name):
            self.vu._project._libraries.append(name)
            return self.library_mock

        self.vu.add_library.side_effect = add_library

        self.builtins = Builtins(self.vu, VHDLStandard("2002"), None)

    def _assertLogContent(self, log, level, msg):
        self.assertEqual(len(log.records), 1)
        record = log.records[0]
        self.assertEqual(record.levelname, level)
        self.assertEqual(record.getMessage(), msg)

    def _write_toml(self, tempdir, text: str):
        (tempdir / "vunit_pkg.toml").write_text(text, encoding="utf-8")

    def test_raises_if_package_not_found(self):
        with (
            mock.patch("vunit.builtins.importlib.util.find_spec", return_value=None),
            self.assertRaisesRegex(RuntimeError, re.escape("Could not find package foo.")),
        ):
            self.builtins.add_package("foo")

    def test_normalizes_package_name(self):
        with (
            mock.patch("vunit.builtins.importlib.util.find_spec", return_value=None),
            self.assertRaisesRegex(RuntimeError, re.escape("Could not find package a_b_c_d.")),
        ):
            self.builtins.add_package("a-b.c-d")

    def test_raises_if_toml_not_in_package(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertRaisesRegex(
                RuntimeError, re.escape(f"Could not find vunit_pkg.toml for package foo in {tempdir}.")
            ),
        ):
            (tempdir / "not_vunit_pkg.toml").write_text("")
            self.builtins.add_package("foo")

    def test_raises_if_invalid_toml_format(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertRaisesRegex(RuntimeError, re.escape("vunit_pkg.toml for package foo is not a valid TOML file")),
        ):
            self._write_toml(
                tempdir,
                """\
[package
""",
            )
            self.builtins.add_package("foo")

    def test_raises_if_missing_package(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertRaisesRegex(RuntimeError, re.escape("Invalid vunit_pkg.toml: 2 error(s) found.")),
        ):
            self._write_toml(
                tempdir,
                """\
[pkg]
""",
            )
            self.builtins.add_package("foo")

    def test_accepts_empty_toml_package(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
""",
            )
            self.builtins.add_package("foo")

    def test_raises_if_incompatible_vunit_version(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertRaisesRegex(
                RuntimeError,
                re.escape(f"Package foo requires VUnit version ==1000.0.0 but current version is {version()}."),
            ),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
requires-vunit="==1000.0.0"
""",
            )
            self.builtins.add_package("foo")

    def test_warns_if_multi_vhdl_standard(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertLogs("vunit.builtins", "WARNING") as mock_warning,
        ):
            self._write_toml(
                tempdir,
                """\
[package]
requires-vhdl=">=2008"
""",
            )
            self.builtins.add_package("foo")

        self._assertLogContent(
            mock_warning,
            "WARNING",
            "Package foo requires VHDL standard >=2008 but current standard is 2002. "
            "Proceeding with mixed-language compilation using VHDL standard 2008 for the package.",
        )

    def test_raises_if_no_compatible_vhdl_standard(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertRaisesRegex(
                RuntimeError,
                re.escape("Package foo requires VHDL standard <2008,>2008. Failed to find a compatible standard."),
            ),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
requires-vhdl="<2008,>2008"
""",
            )
            self.builtins.add_package("foo")

    def test_accepts_compatible_vhdl_standard(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
requires-vhdl=">1993"
""",
            )
            self.builtins.add_package("foo")

    def test_raises_if_unsupported_version_specifier_operator(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertRaisesRegex(
                RuntimeError,
                re.escape("Unsupported version specifier operator: ===."),
            ),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
requires-vhdl="===2008"
""",
            )
            self.builtins.add_package("foo")

    def test_raises_if_invalid_version_specifier_operator(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertRaisesRegex(
                RuntimeError,
                re.escape(
                    "Invalid version requirement format: =!2008. Use <OPERATOR><VERSION> where "
                    "OPERATOR is one of <=, <, !=, ==, >=, and >."
                ),
            ),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
requires-vhdl="=!2008"
""",
            )
            self.builtins.add_package("foo")

    def test_raises_if_invalid_key(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertRaisesRegex(
                RuntimeError,
                re.escape("Invalid vunit_pkg.toml: 1 error(s) found."),
            ),
            self.assertLogs("vunit.builtins", "ERROR") as mock_error,
        ):
            self._write_toml(
                tempdir,
                """\
[package]
require-vhdl="<1993"
""",
            )
            self.builtins.add_package("foo")

        self._assertLogContent(
            mock_error,
            "ERROR",
            "package.require-vhdl: Unexpected string 'require-vhdl'.",
        )

    def test_raises_if_invalid_type(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertRaisesRegex(
                RuntimeError,
                re.escape("Invalid vunit_pkg.toml: 1 error(s) found."),
            ),
            self.assertLogs("vunit.builtins", "ERROR") as mock_error,
        ):
            self._write_toml(
                tempdir,
                """\
[package]
requires-vhdl=2002
""",
            )
            self.builtins.add_package("foo")

        self._assertLogContent(
            mock_error,
            "ERROR",
            "package.requires-vhdl: 'requires-vhdl' must be a string.",
        )

    def test_adding_package_to_library(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
requires-vhdl="<=2008"
library = "bar"
[[package.sources]]
include=["hdl/src1/*.vhd", "hdl/src2/*.vhd"]
[[package.sources]]
include=["hdl/src3/*.vhd"]
""",
            )

            self.builtins.add_package("foo")

            self.assertIn("bar", self.vu._project._libraries)
            self.library_mock.add_source_files.assert_has_calls(
                [
                    mock.call(tempdir / "hdl/src1/*.vhd", vhdl_standard=None),
                    mock.call(tempdir / "hdl/src2/*.vhd", vhdl_standard=None),
                    mock.call(tempdir / "hdl/src3/*.vhd", vhdl_standard=None),
                ]
            )

    def test_raises_if_missing_library(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertRaisesRegex(RuntimeError, re.escape("Invalid vunit_pkg.toml: 1 error(s) found.")),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
[[package.sources]]
include=["hdl/src1/*.vhd"]
""",
            )
            self.builtins.add_package("foo")

    def test_warns_if_package_already_added(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertLogs("vunit.builtins", "WARNING") as mock_warning,
        ):
            self._write_toml(
                tempdir,
                """\
[package]
requires-vhdl="!=93"
library = "bar"
[[package.sources]]
include=["hdl/src1/*.vhd"]
""",
            )
            self.builtins.add_package("foo")
            self.library_mock.add_source_files.assert_called_once_with(tempdir / "hdl/src1/*.vhd", vhdl_standard=None)
            self.builtins.add_package("foo")

            self._assertLogContent(
                mock_warning,
                "WARNING",
                "Library bar previously defined. Skipping addition of foo.",
            )
            self.library_mock.add_source_files.assert_called_once()


class TestBuiltinsAdder(unittest.TestCase):
    """
    Test BuiltinsAdder class
    """

    @staticmethod
    def test_add_type():
        adder = BuiltinsAdder()
        function = mock.Mock()
        adder.add_type("foo", function)
        adder.add("foo", dict(argument=1))
        function.assert_called_once_with(argument=1)

    def test_adds_dependencies(self):
        adder = BuiltinsAdder()
        function1 = mock.Mock()
        function2 = mock.Mock()
        function3 = mock.Mock()
        function4 = mock.Mock()
        adder.add_type("foo1", function1)
        adder.add_type("foo2", function2, ["foo1"])
        adder.add_type("foo3", function3, ["foo2"])
        adder.add_type("foo4", function4)
        adder.add("foo3", dict(argument=1))
        adder.add("foo2")
        function1.assert_called_once_with()
        function2.assert_called_once_with()
        function3.assert_called_once_with(argument=1)
        self.assertFalse(function4.called)

    def test_runtime_error_on_add_with_different_args(self):
        adder = BuiltinsAdder()
        function = mock.Mock()
        adder.add_type("foo", function)
        adder.add("foo", dict(argument=1))
        try:
            adder.add("foo", dict(argument=2))
        except RuntimeError as exc:
            self.assertEqual(
                str(exc),
                "Optional builtin %r added with arguments %r has already been added with arguments %r"
                % ("foo", dict(argument=2), dict(argument=1)),
            )
        else:
            self.fail("RuntimeError not raised")
