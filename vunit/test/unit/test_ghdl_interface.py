# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the GHDL interface
"""


import unittest
from os.path import join, dirname, exists
import os
from shutil import rmtree
from vunit.ghdl_interface import GHDLInterface
from vunit.test.mock_2or3 import mock
from vunit.project import Project
from vunit.ostools import renew_path, write_file
from vunit.exceptions import CompileError


class TestGHDLInterface(unittest.TestCase):
    """
    Test the GHDL interface
    """

    @mock.patch("vunit.ghdl_interface.GHDLInterface.find_executable")
    def test_runtime_error_on_missing_gtkwave(self, find_executable):
        executables = {}

        def find_executable_side_effect(name):
            return executables[name]

        find_executable.side_effect = find_executable_side_effect

        executables["gtkwave"] = ["path"]
        GHDLInterface(prefix="prefix")

        executables["gtkwave"] = []
        GHDLInterface(prefix="prefix")
        self.assertRaises(RuntimeError, GHDLInterface, prefix="prefix", gtkwave="ghw")

    @mock.patch('subprocess.check_output', autospec=True)
    def test_parses_llvm_backend(self, check_output):
        version = b"""\
GHDL 0.33dev (20141104) [Dunoon edition]
 Compiled with GNAT Version: 4.8
 llvm code generator
Written by Tristan Gingold.

Copyright (C) 2003 - 2014 Tristan Gingold.
GHDL is free software, covered by the GNU General Public License.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
"""
        check_output.return_value = version
        self.assertEqual(GHDLInterface.determine_backend("prefix"), "llvm")

    @mock.patch('subprocess.check_output', autospec=True)
    def test_parses_mcode_backend(self, check_output):
        version = b"""\
GHDL 0.33dev (20141104) [Dunoon edition]
 Compiled with GNAT Version: 4.9.2
 mcode code generator
Written by Tristan Gingold.

Copyright (C) 2003 - 2014 Tristan Gingold.
GHDL is free software, covered by the GNU General Public License.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
"""
        check_output.return_value = version
        self.assertEqual(GHDLInterface.determine_backend("prefix"), "mcode")

    @mock.patch('subprocess.check_output', autospec=True)
    def test_parses_gcc_backend(self, check_output):
        version = b"""\
GHDL 0.31 (20140108) [Dunoon edition]
 Compiled with GNAT Version: 4.8
 GCC back-end code generator
Written by Tristan Gingold.

Copyright (C) 2003 - 2014 Tristan Gingold.
GHDL is free software, covered by the GNU General Public License.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
"""
        check_output.return_value = version
        self.assertEqual(GHDLInterface.determine_backend("prefix"), "gcc")

    @mock.patch('subprocess.check_output', autospec=True)
    def test_assertion_on_unknown_backend(self, check_output):
        version = b"""\
GHDL 0.31 (20140108) [Dunoon edition]
 Compiled with GNAT Version: 4.8
 xyz code generator
Written by Tristan Gingold.

Copyright (C) 2003 - 2014 Tristan Gingold.
GHDL is free software, covered by the GNU General Public License.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE."""

        check_output.return_value = version
        self.assertRaises(AssertionError, GHDLInterface.determine_backend, "prefix")

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    def test_compile_project_2008(self, run_command):  # pylint: disable=no-self-use
        simif = GHDLInterface(prefix="prefix")
        write_file("file.vhd", "")

        project = Project()
        project.add_library("lib", "lib_path")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard="2008")
        simif.compile_project(project)
        run_command.assert_called_once_with(
            [join("prefix", 'ghdl'), '-a', '--workdir=lib_path', '--work=lib',
             '--std=08', '-Plib_path', 'file.vhd'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    def test_compile_project_2002(self, run_command):  # pylint: disable=no-self-use
        simif = GHDLInterface(prefix="prefix")
        write_file("file.vhd", "")

        project = Project()
        project.add_library("lib", "lib_path")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard="2002")
        simif.compile_project(project)
        run_command.assert_called_once_with(
            [join("prefix", 'ghdl'), '-a', '--workdir=lib_path', '--work=lib',
             '--std=02', '-Plib_path', 'file.vhd'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    def test_compile_project_93(self, run_command):  # pylint: disable=no-self-use
        simif = GHDLInterface(prefix="prefix")
        write_file("file.vhd", "")

        project = Project()
        project.add_library("lib", "lib_path")
        project.add_source_file("file.vhd", "lib", file_type="vhdl", vhdl_standard="93")
        simif.compile_project(project)
        run_command.assert_called_once_with(
            [join("prefix", 'ghdl'), '-a', '--workdir=lib_path', '--work=lib',
             '--std=93', '-Plib_path', 'file.vhd'])

    @mock.patch("vunit.simulator_interface.run_command", autospec=True, return_value=True)
    def test_compile_project_extra_flags(self, run_command):  # pylint: disable=no-self-use
        simif = GHDLInterface(prefix="prefix")
        write_file("file.vhd", "")

        project = Project()
        project.add_library("lib", "lib_path")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")
        source_file.set_compile_option("ghdl.flags", ["custom", "flags"])
        simif.compile_project(project)
        run_command.assert_called_once_with(
            [join("prefix", 'ghdl'), '-a', '--workdir=lib_path', '--work=lib', '--std=08',
             '-Plib_path', 'custom', 'flags', 'file.vhd'])

    def test_compile_project_verilog_error(self):
        simif = GHDLInterface(prefix="prefix")
        write_file("file.v", "")

        project = Project()
        project.add_library("lib", "lib_path")
        project.add_source_file("file.v", "lib", file_type="verilog")
        self.assertRaises(CompileError, simif.compile_project, project)

    def setUp(self):
        self.output_path = join(dirname(__file__), "test_ghdl_interface_out")
        renew_path(self.output_path)
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if exists(self.output_path):
            rmtree(self.output_path)
