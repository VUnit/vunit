# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the ActiveHDL interface
"""

import unittest
from pathlib import Path
import os
from shutil import rmtree
from unittest import mock
from vunit.sim_if.activehdl import ActiveHDLInterface, ActiveHDLVersion, VersionConsumer
from vunit.project import Project
from vunit.ostools import renew_path, write_file
from vunit.vhdl_standard import VHDL


class MockProcess(object):
    def __init__(self, args, cwd=None, env=None, version_line=None):
        self.args = args
        self.cwd = cwd
        self.env = env
        self.version_line = version_line

    def consume_output(self, callback):
        callback(self.version_line)


class MockProcessVersionWithoutPackageGenerics(MockProcess):
    def __init__(self, args, cwd=None, env=None):
        MockProcess.__init__(self, args, cwd, env, "10.0.12.6914")


class MockProcessVersionWithPackageGenerics(MockProcess):
    def __init__(self, args, cwd=None, env=None):
        MockProcess.__init__(self, args, cwd, env, "10.5a.12.6914")


class TestActiveHDLInterface(unittest.TestCase):
    """
    Test the ActiveHDL interface
    """

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.activehdl.Process", autospec=True)
    def _test_compile_project_vhdl(self, standard, process, check_output):
        simif = ActiveHDLInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard=VHDL.standard(standard))
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vcom"),
                "-quiet",
                "-j",
                self.output_path,
                f"-{standard}",
                "-work",
                "lib",
                "file.vhd",
            ],
            env=simif.get_env(),
        )

    def test_compile_project_vhdl_2019(self):
        self._test_compile_project_vhdl("2019")

    def test_compile_project_vhdl_2008(self):
        self._test_compile_project_vhdl("2008")

    def test_compile_project_vhdl_2002(self):
        self._test_compile_project_vhdl("2002")

    def test_compile_project_vhdl_93(self):
        self._test_compile_project_vhdl("93")

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.activehdl.Process", autospec=True)
    def test_compile_project_vhdl_extra_flags(self, process, check_output):
        simif = ActiveHDLInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")
        source_file.set_compile_option("activehdl.vcom_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vcom"),
                "-quiet",
                "-j",
                self.output_path,
                "custom",
                "flags",
                "-2008",
                "-work",
                "lib",
                "file.vhd",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.activehdl.Process", autospec=True)
    def test_compile_project_verilog(self, process, check_output):
        library_cfg = str(Path(self.output_path) / "library.cfg")
        simif = ActiveHDLInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog")
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vlog"),
                "-quiet",
                "-lc",
                library_cfg,
                "-work",
                "lib",
                "file.v",
                "-l",
                "lib",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.activehdl.Process", autospec=True)
    def test_compile_project_system_verilog(self, process, check_output):
        library_cfg = str(Path(self.output_path) / "library.cfg")
        simif = ActiveHDLInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.sv", "")
        project.add_source_file("file.sv", "lib", file_type="systemverilog")
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vlog"),
                "-quiet",
                "-lc",
                library_cfg,
                "-work",
                "lib",
                "file.sv",
                "-l",
                "lib",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.activehdl.Process", autospec=True)
    def test_compile_project_verilog_extra_flags(self, process, check_output):
        library_cfg = str(Path(self.output_path) / "library.cfg")
        simif = ActiveHDLInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        source_file = project.add_source_file("file.v", "lib", file_type="verilog")
        source_file.set_compile_option("activehdl.vlog_flags", ["custom", "flags"])
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vlog"),
                "-quiet",
                "-lc",
                library_cfg,
                "custom",
                "flags",
                "-work",
                "lib",
                "file.v",
                "-l",
                "lib",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.activehdl.Process", autospec=True)
    def test_compile_project_verilog_include(self, process, check_output):
        library_cfg = str(Path(self.output_path) / "library.cfg")
        simif = ActiveHDLInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", include_dirs=["include"])
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vlog"),
                "-quiet",
                "-lc",
                library_cfg,
                "-work",
                "lib",
                "file.v",
                "-l",
                "lib",
                "+incdir+include",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.check_output", autospec=True, return_value="")
    @mock.patch("vunit.sim_if.activehdl.Process", autospec=True)
    def test_compile_project_verilog_define(self, process, check_output):
        library_cfg = str(Path(self.output_path) / "library.cfg")
        simif = ActiveHDLInterface(prefix="prefix", output_path=self.output_path)
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.v", "")
        project.add_source_file("file.v", "lib", file_type="verilog", defines={"defname": "defval"})
        simif.compile_project(project)
        process.assert_any_call(
            [str(Path("prefix") / "vlib"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        process.assert_called_with(
            [str(Path("prefix") / "vmap"), "lib", "lib_path"],
            cwd=self.output_path,
            env=simif.get_env(),
        )
        check_output.assert_called_once_with(
            [
                str(Path("prefix") / "vlog"),
                "-quiet",
                "-lc",
                library_cfg,
                "-work",
                "lib",
                "file.v",
                "-l",
                "lib",
                "+define+defname=defval",
            ],
            env=simif.get_env(),
        )

    @mock.patch("vunit.sim_if.activehdl.ActiveHDLInterface.find_prefix")
    @mock.patch("vunit.sim_if.activehdl.Process", new=MockProcessVersionWithPackageGenerics)
    def test_supports_vhdl_package_generics_true(self, find_prefix):
        find_prefix.return_value = ""
        simif = ActiveHDLInterface(prefix="prefix", output_path=self.output_path)
        self.assertTrue(simif.supports_vhdl_package_generics())

    @mock.patch("vunit.sim_if.activehdl.ActiveHDLInterface.find_prefix")
    @mock.patch("vunit.sim_if.activehdl.Process", new=MockProcessVersionWithoutPackageGenerics)
    def test_supports_vhdl_package_generics_false(self, find_prefix):
        find_prefix.return_value = ""
        simif = ActiveHDLInterface(prefix="prefix", output_path=self.output_path)
        self.assertFalse(simif.supports_vhdl_package_generics())

    def setUp(self):
        self.output_path = str(Path(__file__).parent / "test_activehdl_out")
        renew_path(self.output_path)
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if Path(self.output_path).exists():
            rmtree(self.output_path)


class TestVersionConsumer(unittest.TestCase):
    """
    Test the VersionConsumer class
    """

    def _assert_version_correct(self, version_line, expected_major, expected_minor, expected_minor_letter):
        """
        Assertion function used by tests in this class
        """
        consumer = VersionConsumer()
        consumer(version_line)
        self.assertEqual(
            consumer.version,
            ActiveHDLVersion(f"{expected_major}.{expected_minor}{expected_minor_letter}"),
        )

    def test_version_string_without_letters(self):
        self._assert_version_correct(
            "10.5.216.6767",
            10,
            5,
            "",
        )

    def test_version_string_with_letters(self):
        self._assert_version_correct(
            "10.5a.12.6914",
            10,
            5,
            "a",
        )


class TestActiveHDLVersion(unittest.TestCase):
    """
    Test ActiveHDL version comparisons.
    Test cases = (assert true, assert false) x (with letters, without letters, mixed) x number_of_operations
    Where number_of_operations = 1 for <, and 2 for <=, etc
    """

    high_version_letter = ActiveHDLVersion("10.5b")
    low_version_letter = ActiveHDLVersion("10.5a")
    high_version_no_letter = ActiveHDLVersion("10.6")
    low_version_no_letter = ActiveHDLVersion("10.5")
    high_version_letter_for_mixed = ActiveHDLVersion("10.6")

    def test_versions_are_ordered_by_major_minor_and_minor_letter(self):
        self.assertLess(ActiveHDLVersion("10.5"), ActiveHDLVersion("10.5a"))
        self.assertLess(ActiveHDLVersion("10.5a"), ActiveHDLVersion("10.5b"))
        self.assertLess(ActiveHDLVersion("10.5b"), ActiveHDLVersion("10.6"))
        self.assertEqual(ActiveHDLVersion("10.5a.12.6914"), ActiveHDLVersion("10.5a"))
        self.assertEqual(str(ActiveHDLVersion("10.5a")), "10.5a")

    def test_from_output_extracts_versions_from_vendor_output(self):
        self.assertEqual(
            ActiveHDLVersion.from_output(
                "Aldec, Inc. VHDL compiler version 10.5.216.6767 built for Windows on January 20, 2018."
            ),
            ActiveHDLVersion("10.5"),
        )
        self.assertEqual(
            ActiveHDLVersion.from_output(
                "Aldec, Inc. VHDL compiler version 10.5a.12.6914 built for Windows on June 06, 2018."
            ),
            ActiveHDLVersion("10.5a"),
        )

    def test_from_output_returns_unknown_when_version_cannot_be_parsed(self):
        with self.assertWarnsRegex(RuntimeWarning, "version is unknown"):
            version = ActiveHDLVersion.from_output("Active-HDL version unavailable")

        self.assertFalse(version.is_valid)
        self.assertEqual(str(version), "unknown")

    def test_unknown_versions_cannot_be_ordered(self):
        with self.assertWarns(RuntimeWarning):
            version = ActiveHDLVersion("unknown")

        with self.assertRaisesRegex(ValueError, "Cannot order unknown ActiveHDL versions"):
            version < ActiveHDLVersion("10.5")

    def test_lt(self):
        # Test with letters
        self.assertTrue(TestActiveHDLVersion.low_version_letter < TestActiveHDLVersion.high_version_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_letter < TestActiveHDLVersion.low_version_letter)
        # Test without letters
        self.assertTrue(TestActiveHDLVersion.low_version_no_letter < TestActiveHDLVersion.high_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_no_letter < TestActiveHDLVersion.low_version_no_letter)
        # Both
        self.assertTrue(TestActiveHDLVersion.low_version_letter < TestActiveHDLVersion.high_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_letter < TestActiveHDLVersion.low_version_no_letter)

    def test_le(self):
        # Test equal
        # Test with letters
        self.assertTrue(TestActiveHDLVersion.high_version_letter <= TestActiveHDLVersion.high_version_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_letter <= TestActiveHDLVersion.low_version_letter)
        # Test without letters
        self.assertTrue(TestActiveHDLVersion.high_version_no_letter <= TestActiveHDLVersion.high_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_no_letter <= TestActiveHDLVersion.low_version_no_letter)
        # Both
        self.assertTrue(TestActiveHDLVersion.high_version_letter <= TestActiveHDLVersion.high_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_letter <= TestActiveHDLVersion.low_version_no_letter)

        # Test less than
        # Test with letters
        self.assertTrue(TestActiveHDLVersion.low_version_letter <= TestActiveHDLVersion.high_version_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_letter <= TestActiveHDLVersion.low_version_letter)
        # Test without letters
        self.assertTrue(TestActiveHDLVersion.low_version_no_letter <= TestActiveHDLVersion.high_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_no_letter <= TestActiveHDLVersion.low_version_no_letter)
        # Both
        self.assertTrue(TestActiveHDLVersion.low_version_letter <= TestActiveHDLVersion.high_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_letter <= TestActiveHDLVersion.low_version_no_letter)

    def test_gt(self):
        # Test with letters
        self.assertTrue(TestActiveHDLVersion.high_version_letter > TestActiveHDLVersion.low_version_letter)
        self.assertFalse(TestActiveHDLVersion.low_version_letter > TestActiveHDLVersion.high_version_letter)
        # Test without letters
        self.assertTrue(TestActiveHDLVersion.high_version_no_letter > TestActiveHDLVersion.low_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.low_version_no_letter > TestActiveHDLVersion.high_version_no_letter)
        # Both
        self.assertTrue(TestActiveHDLVersion.high_version_letter > TestActiveHDLVersion.low_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.low_version_letter > TestActiveHDLVersion.high_version_no_letter)

    def test_ge(self):
        # Test equal
        # Test with letters
        self.assertTrue(TestActiveHDLVersion.high_version_letter >= TestActiveHDLVersion.high_version_letter)
        self.assertFalse(TestActiveHDLVersion.low_version_letter >= TestActiveHDLVersion.high_version_letter)
        # Test without letters
        self.assertTrue(TestActiveHDLVersion.high_version_no_letter >= TestActiveHDLVersion.high_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.low_version_no_letter >= TestActiveHDLVersion.high_version_no_letter)
        # Both
        self.assertTrue(
            TestActiveHDLVersion.high_version_letter_for_mixed >= TestActiveHDLVersion.high_version_no_letter
        )
        self.assertFalse(TestActiveHDLVersion.low_version_letter >= TestActiveHDLVersion.high_version_no_letter)

        # Test greater than
        # Test with letters
        self.assertTrue(TestActiveHDLVersion.high_version_letter >= TestActiveHDLVersion.low_version_letter)
        self.assertFalse(TestActiveHDLVersion.low_version_letter >= TestActiveHDLVersion.high_version_letter)
        # Test without letters
        self.assertTrue(TestActiveHDLVersion.high_version_no_letter >= TestActiveHDLVersion.low_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.low_version_no_letter >= TestActiveHDLVersion.high_version_no_letter)
        # Both
        self.assertTrue(TestActiveHDLVersion.high_version_letter >= TestActiveHDLVersion.low_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.low_version_letter >= TestActiveHDLVersion.high_version_no_letter)

    def test_eq(self):
        # Test with letters
        self.assertTrue(TestActiveHDLVersion.high_version_letter == TestActiveHDLVersion.high_version_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_letter == TestActiveHDLVersion.low_version_letter)
        # Test without letters
        self.assertTrue(TestActiveHDLVersion.high_version_no_letter == TestActiveHDLVersion.high_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_no_letter == TestActiveHDLVersion.low_version_no_letter)
        # Both
        self.assertTrue(
            TestActiveHDLVersion.high_version_letter_for_mixed == TestActiveHDLVersion.high_version_no_letter
        )
        self.assertFalse(TestActiveHDLVersion.high_version_letter == TestActiveHDLVersion.low_version_no_letter)

    def test_ne(self):
        # Test with letters
        self.assertTrue(TestActiveHDLVersion.high_version_letter != TestActiveHDLVersion.low_version_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_letter != TestActiveHDLVersion.high_version_letter)
        # Test without letters
        self.assertTrue(TestActiveHDLVersion.high_version_no_letter != TestActiveHDLVersion.low_version_no_letter)
        self.assertFalse(TestActiveHDLVersion.high_version_no_letter != TestActiveHDLVersion.high_version_no_letter)
        # Both
        self.assertTrue(TestActiveHDLVersion.high_version_letter != TestActiveHDLVersion.low_version_no_letter)
        self.assertFalse(
            TestActiveHDLVersion.high_version_letter_for_mixed != TestActiveHDLVersion.high_version_no_letter
        )
