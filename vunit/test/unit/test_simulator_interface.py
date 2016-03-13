# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the SimulatorInterface class
"""

import unittest
from os.path import join, dirname, exists
import os
from shutil import rmtree
from vunit.project import Project
from vunit.simulator_interface import SimulatorInterface
from vunit.test.mock_2or3 import mock
from vunit.exceptions import CompileError
from vunit.ostools import renew_path, write_file


class TestSimulatorInterface(unittest.TestCase):
    """
    Test the SimulatorInterface class
    """

    def test_compile_source_files(self):
        simif = create_simulator_interface()
        simif.compile_source_file_command.side_effect = iter([["command1"], ["command2"]])
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file1.vhd", "")
        file1 = project.add_source_file("file1.vhd", "lib", file_type="vhdl")
        write_file("file2.vhd", "")
        file2 = project.add_source_file("file2.vhd", "lib", file_type="vhdl")
        project.add_manual_dependency(file2, depends_on=file1)

        with mock.patch("vunit.simulator_interface.run_command", autospec=True) as run_command:
            run_command.side_effect = iter([True, True])
            simif.compile_source_files(project)
            run_command.assert_has_calls([mock.call(["command1"]),
                                          mock.call(["command2"])])
        self.assertEqual(project.get_files_in_compile_order(incremental=True), [])

    def test_compile_source_files_continue_on_error(self):
        simif = create_simulator_interface()

        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file1.vhd", "")
        file1 = project.add_source_file("file1.vhd", "lib", file_type="vhdl")
        write_file("file2.vhd", "")
        file2 = project.add_source_file("file2.vhd", "lib", file_type="vhdl")
        write_file("file3.vhd", "")
        file3 = project.add_source_file("file3.vhd", "lib", file_type="vhdl")
        project.add_manual_dependency(file2, depends_on=file1)

        def compile_source_file_command(source_file):
            if source_file == file1:
                return ["command1"]
            elif source_file == file2:
                return ["command2"]
            elif source_file == file3:
                return ["command3"]

        def run_command_side_effect(command):
            if command == ["command1"]:
                return False
            else:
                return True

        simif.compile_source_file_command.side_effect = compile_source_file_command

        with mock.patch("vunit.simulator_interface.run_command", autospec=True) as run_command:
            run_command.side_effect = run_command_side_effect
            self.assertRaises(CompileError, simif.compile_source_files, project, continue_on_error=True)
            self.assertEqual(len(run_command.mock_calls), 2)
            run_command.assert_has_calls([mock.call(["command1"]),
                                          mock.call(["command3"])], any_order=True)
        self.assertEqual(project.get_files_in_compile_order(incremental=True), [file1, file2])

    def test_compile_source_files_run_command_error(self):
        simif = create_simulator_interface()
        simif.compile_source_file_command.return_value = ["command"]
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")

        with mock.patch("vunit.simulator_interface.run_command", autospec=True) as run_command:
            run_command.return_value = False
            self.assertRaises(CompileError, simif.compile_source_files, project)
            run_command.assert_called_once_with(["command"])
        self.assertEqual(project.get_files_in_compile_order(incremental=True), [source_file])

    def test_compile_source_files_create_command_error(self):
        simif = create_simulator_interface()
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")

        with mock.patch("vunit.simulator_interface.run_command", autospec=True) as run_command:
            run_command.return_value = True

            def raise_compile_error(*args, **kwargs):
                raise CompileError

            simif.compile_source_file_command.side_effect = raise_compile_error
            self.assertRaises(CompileError, simif.compile_source_files, project)
        self.assertEqual(project.get_files_in_compile_order(incremental=True), [source_file])

    @mock.patch("os.environ", autospec=True)
    def test_find_prefix(self, environ):

        class MySimulatorInterface(SimulatorInterface):  # pylint: disable=abstract-method
            """
            Dummy simulator interface for testing
            """
            name = "simname"
            prefix_from_path = None

            @classmethod
            def find_prefix_from_path(cls):
                return cls.prefix_from_path

        simif = MySimulatorInterface()
        simif.name = "simname"
        environ.get.return_value = None
        self.assertEqual(simif.find_prefix(), None)
        environ.get.assert_called_once_with("VUNIT_SIMNAME_PATH", None)

        environ.reset_mock()
        environ.get.return_value = "simname/bin"
        self.assertEqual(simif.find_prefix(), "simname/bin")
        environ.get.assert_called_once_with("VUNIT_SIMNAME_PATH", None)

        environ.reset_mock()
        environ.get.return_value = None
        MySimulatorInterface.prefix_from_path = "prefix_from_path"
        self.assertEqual(simif.find_prefix(), "prefix_from_path")
        environ.get.assert_called_once_with("VUNIT_SIMNAME_PATH", None)

    def setUp(self):
        self.output_path = join(dirname(__file__), "test_simulator_interface__out")
        renew_path(self.output_path)
        self.project = Project()
        self.cwd = os.getcwd()
        os.chdir(self.output_path)

    def tearDown(self):
        os.chdir(self.cwd)
        if exists(self.output_path):
            rmtree(self.output_path)


def create_simulator_interface():
    """
    Create a simulator interface with fake method
    """
    simif = SimulatorInterface()
    simif.compile_source_file_command = mock.create_autospec(simif.compile_source_file_command)
    return simif
