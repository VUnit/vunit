# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the SimulatorInterface class
"""

import unittest
from vunit.project import Project
from vunit.simulator_interface import SimulatorInterface
from vunit.test.mock_2or3 import mock
from vunit.exceptions import CompileError


class TestSimulatorInterface(unittest.TestCase):
    """
    Test the SimulatorInterface class
    """

    @staticmethod
    def test_compile_source_files():
        simif = create_simulator_interface()
        source_files = [create_mock_source_file("file.vhd", "lib", ["command"])]
        project = create_mock_project(source_files)

        with mock.patch("vunit.simulator_interface.run_command", autospec=True) as run_command:
            run_command.return_value = True
            simif.compile_source_files(project)
            run_command.assert_called_once_with(source_files[0].command)
        project.update.assert_called_once_with(source_files[0])

    def test_compile_source_files_run_command_error(self):
        simif = create_simulator_interface()
        source_files = [create_mock_source_file("file.vhd", "lib", ["command"])]
        project = create_mock_project(source_files)

        with mock.patch("vunit.simulator_interface.run_command", autospec=True) as run_command:
            run_command.return_value = False
            self.assertRaises(CompileError, simif.compile_source_files, project)
            run_command.assert_called_once_with(source_files[0].command)
        self.assertFalse(project.update.called)

    def test_compile_source_files_create_command_error(self):
        simif = create_simulator_interface()
        source_files = [create_mock_source_file("file.vhd", "lib", CompileError)]
        project = create_mock_project(source_files)

        with mock.patch("vunit.simulator_interface.run_command", autospec=True) as run_command:
            run_command.return_value = False
            self.assertRaises(CompileError, simif.compile_source_files, project)
        self.assertFalse(project.update.called)


def create_simulator_interface():
    """
    Create a simulator interface with fake method
    """
    simif = SimulatorInterface()

    def compile_source_file_command(source_file):
        if source_file.command == CompileError:
            raise CompileError
        else:
            return source_file.command

    simif.compile_source_file_command = compile_source_file_command
    return simif


def create_mock_project(source_files):
    """
    Create a mock project containing source_files
    """
    project = mock.create_autospec(Project)

    def get_files_in_compile_order():
        return source_files

    project.get_files_in_compile_order.side_effect = get_files_in_compile_order
    return project


def create_mock_source_file(name, library_name, command):
    """
    Createa mock SourceFile
    """
    class MockLibrary(object):
        def __init__(self, name):
            self.name = name

    class MockSourceFile(object):

        def __init__(self, name, command, library_name):
            self.name = name
            self.command = command
            self.library = MockLibrary(library_name)

    return MockSourceFile(name, command, library_name)
