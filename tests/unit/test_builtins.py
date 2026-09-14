# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test builtins.py
"""

from tempfile import tempdir
import sys
import unittest
import re
from pathlib import Path
from unittest import mock
from vunit import VUnit
from vunit.builtins import Builtins, BuiltinsAdder
from vunit.about import version
from vunit.vhdl_standard import VHDL, VHDLStandard
from vunit.project import Project
from vunit.sim_if import hooks
from tests.common import create_tempdir
from contextlib import contextmanager
from importlib.machinery import ModuleSpec


@contextmanager
def importable_module(tempdir, name, code):
    """Make a module importable from tempdir for the duration of the context."""
    (tempdir / f"{name}.py").write_text(code, encoding="utf-8")
    sys.path.insert(0, str(tempdir))
    try:
        yield
    finally:
        sys.path.remove(str(tempdir))
        sys.modules.pop(name, None)


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

        self.vu._output_path = "output_path"
        self.vu._run_script_path = Path("run.py")

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

    def test_raises_if_setup_is_not_allowed(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            importable_module(
                tempdir,
                "foo_setup",
                """\
contexts = []


def setup(context):
    contexts.append(context)
""",
            ),
            self.assertRaisesRegex(
                RuntimeError,
                re.escape(
                    "Package foo requires running Python code when it is added (foo_setup:setup). "
                    "Pass allow_setup=True to add_package to allow it."
                ),
            ),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
library = "bar"
setup = "foo_setup:setup"
[[package.sources]]
include=["hdl/src1/*.vhd"]
""",
            )

            try:
                self.builtins.add_package("foo")
            finally:
                import foo_setup  # pylint: disable=import-outside-toplevel

                self.assertEqual(foo_setup.contexts, [])
                self.library_mock.add_source_files.assert_called_once_with(
                    tempdir / "hdl/src1/*.vhd", vhdl_standard=None
                )

    def test_allowing_setup_of_package_without_setup_function(self):
        with create_tempdir() as tempdir, pkg_env(tempdir):
            self._write_toml(
                tempdir,
                """\
[package]
library = "bar"
[[package.sources]]
include=["hdl/src1/*.vhd"]
""",
            )

            self.builtins.add_package("foo", allow_setup=True)

            self.library_mock.add_source_files.assert_called_once_with(tempdir / "hdl/src1/*.vhd", vhdl_standard=None)

    def test_calls_setup_function(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            importable_module(
                tempdir,
                "foo_setup",
                """\
contexts = []


def setup(context):
    contexts.append(context)
""",
            ),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
requires-vhdl=">=2008"
library = "bar"
setup = "foo_setup:setup"
[[package.sources]]
include=["hdl/src1/*.vhd"]
""",
            )

            self.builtins.add_package("foo", allow_setup=True)

            import foo_setup  # pylint: disable=import-outside-toplevel

            self.assertEqual(len(foo_setup.contexts), 1)
            context = foo_setup.contexts[0]
            self.assertEqual(context.package_root, tempdir)
            self.assertEqual(context.library, self.library_mock)
            self.assertEqual(context.vhdl_standard, VHDL.standard("2008"))
            self.assertEqual(context.output_path, Path("output_path"))
            self.assertEqual(context.run_script_path, Path("run.py"))
            self.assertIsNone(context.simulator_name)
            self.assertIsNone(context.simulator_class)
            self.assertIsNone(context.simulator_prefix)
            self.assertIsNone(context.simulator_backend)

            context.add_library("baz")
            self.vu.add_library.assert_called_with("baz")

            context.add_source_files("baz", tempdir / "*.vhd")
            self.vu.add_source_files.assert_called_once_with(tempdir / "*.vhd", "baz", vhdl_standard="2008")

    def test_calls_setup_function_of_package_without_sources(self):
        simulator_class = mock.Mock()
        simulator_class.name = "ghdl"
        builtins = Builtins(self.vu, VHDLStandard("2008"), simulator_class)

        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            importable_module(
                tempdir,
                "foo_setup",
                """\
contexts = []


def setup(context):
    contexts.append(context)
""",
            ),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
setup = "foo_setup:setup"
""",
            )

            builtins.add_package("foo", allow_setup=True)

            import foo_setup  # pylint: disable=import-outside-toplevel

            context = foo_setup.contexts[0]
            self.assertIsNone(context.library)
            self.assertEqual(context.vhdl_standard, VHDL.standard("2008"))
            self.assertEqual(context.simulator_name, "ghdl")
            self.assertEqual(context.simulator_class, simulator_class)

    def test_setup_function_gets_simulator_prefix_and_backend(self):
        class SimulatorWithBackend:
            """A simulator interface class determining a backend from its prefix, like GHDL."""

            name = "ghdl"

            @classmethod
            def find_prefix(cls):
                return "ghdl/bin"

            @classmethod
            def determine_backend(cls, prefix):
                return {"ghdl/bin": "llvm"}[prefix]

        class SimulatorWithoutBackend:
            """A simulator interface class with no notion of a backend."""

            name = "nvc"

            @classmethod
            def find_prefix(cls):
                return "nvc/bin"

        for simulator_class, prefix, backend in (
            (SimulatorWithBackend, "ghdl/bin", "llvm"),
            (SimulatorWithoutBackend, "nvc/bin", None),
        ):
            with (
                create_tempdir() as tempdir,
                pkg_env(tempdir),
                importable_module(
                    tempdir,
                    "foo_setup",
                    """\
contexts = []


def setup(context):
    contexts.append(context)
""",
                ),
            ):
                self._write_toml(
                    tempdir,
                    """\
[package]
setup = "foo_setup:setup"
""",
                )

                Builtins(self.vu, VHDLStandard("2008"), simulator_class).add_package("foo", allow_setup=True)

                import foo_setup  # pylint: disable=import-outside-toplevel

                context = foo_setup.contexts[0]
                self.assertEqual(context.simulator_prefix, prefix)
                self.assertEqual(context.simulator_backend, backend)

    def test_setup_function_registers_simulator_hooks(self):
        self.addCleanup(hooks.clear_hooks)

        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            importable_module(
                tempdir,
                "foo_setup",
                """\
def setup(context):
    context.register_simulator_hooks(
        "ghdl",
        elab_flags=lambda simulator_interface: ["-Wl,-lfoo"],
        run_flags=lambda simulator_interface: ["--load=foo"],
        process_flags=lambda simulator_interface: ["-noautoldlibpath"],
        run_env=lambda simulator_interface, env: dict(env, FOO="1"),
    )
""",
            ),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
setup = "foo_setup:setup"
""",
            )

            self.builtins.add_package("foo", allow_setup=True)

            simulator_interface = mock.Mock()
            simulator_interface.name = "ghdl"
            self.assertEqual(hooks.get_flags(simulator_interface, "elab_flags"), ["-Wl,-lfoo"])
            self.assertEqual(hooks.get_flags(simulator_interface, "run_flags"), ["--load=foo"])
            self.assertEqual(hooks.get_flags(simulator_interface, "process_flags"), ["-noautoldlibpath"])
            self.assertEqual(hooks.get_run_env(simulator_interface, {}), {"FOO": "1"})

    def test_raises_if_setup_has_invalid_format(self):
        for setup in ["foo_setup", "foo_setup:", "foo setup:setup", "foo_setup.setup"]:
            with (
                create_tempdir() as tempdir,
                pkg_env(tempdir),
                self.assertLogs("vunit.builtins", "ERROR") as mock_error,
                self.assertRaisesRegex(RuntimeError, re.escape("Invalid vunit_pkg.toml: 1 error(s) found.")),
            ):
                self._write_toml(
                    tempdir,
                    f"""\
[package]
setup = "{setup}"
""",
                )
                try:
                    self.builtins.add_package("foo")
                finally:
                    self._assertLogContent(
                        mock_error,
                        "ERROR",
                        "package.setup: 'setup' must be on the format 'module:function'.",
                    )

    def test_raises_if_setup_is_not_a_string(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertLogs("vunit.builtins", "ERROR") as mock_error,
            self.assertRaisesRegex(RuntimeError, re.escape("Invalid vunit_pkg.toml: 1 error(s) found.")),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
setup = 17
""",
            )
            try:
                self.builtins.add_package("foo")
            finally:
                self._assertLogContent(mock_error, "ERROR", "package.setup: 'setup' must be a string.")

    def test_raises_if_setup_module_cannot_be_imported(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            self.assertRaisesRegex(
                RuntimeError,
                re.escape("Failed to import module missing_setup of the setup function for package foo."),
            ),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
setup = "missing_setup:setup"
""",
            )
            self.builtins.add_package("foo", allow_setup=True)

    def test_raises_if_setup_function_is_missing(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            importable_module(tempdir, "foo_setup", "not_a_function = 17\n"),
            self.assertRaisesRegex(
                RuntimeError,
                re.escape("Could not find setup function not_a_function in module foo_setup for package foo."),
            ),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
setup = "foo_setup:not_a_function"
""",
            )
            self.builtins.add_package("foo", allow_setup=True)

    def test_raises_if_setup_function_fails(self):
        with (
            create_tempdir() as tempdir,
            pkg_env(tempdir),
            importable_module(
                tempdir,
                "foo_setup",
                """\
def setup(context):
    raise ValueError("Something went wrong")
""",
            ),
            self.assertRaisesRegex(
                RuntimeError,
                re.escape("Setup function foo_setup:setup for package foo failed: Something went wrong"),
            ),
        ):
            self._write_toml(
                tempdir,
                """\
[package]
setup = "foo_setup:setup"
""",
            )
            self.builtins.add_package("foo", allow_setup=True)


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
