# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the SimulatorInterface class
"""

import unittest
from pathlib import Path
from os import chdir, getcwd
import subprocess
from shutil import rmtree
from unittest import mock
from vunit.project import Project
from vunit.sim_if import (
    SimulatorInterface,
    BooleanOption,
    ListOfStringOption,
    StringOption,
    VHDLAssertLevelOption,
)
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

        with mock.patch("vunit.sim_if.check_output", autospec=True) as check_output:
            check_output.side_effect = iter(["", ""])
            printer = MockPrinter()
            simif.compile_source_files(project, printer=printer)
            check_output.assert_has_calls(
                [
                    mock.call(["command1"], env=simif.get_env()),
                    mock.call(["command2"], env=simif.get_env()),
                ]
            )
            self.assertEqual(
                printer.output,
                """\
Compiling into lib: file1.vhd passed
Compiling into lib: file2.vhd passed
Compile passed
""",
            )
        self.assertEqual(project.get_files_in_compile_order(incremental=True), [])

    def test_compile_source_files_minimal_subset(self):
        simif = create_simulator_interface()
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file1.vhd", "")
        file1 = project.add_source_file("file1.vhd", "lib", file_type="vhdl")

        with mock.patch(
            "vunit.project.Project.get_minimal_file_set_in_compile_order", autospec=True
        ) as target_function:
            target_function.return_value = []
            printer = MockPrinter()
            simif.compile_source_files(project, printer=printer, target_files=[file1])
            simif.compile_source_files(project, printer=printer, target_files=[file1])
            self.assertTrue(target_function.called)

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
            """
            Dummy compile command
            """
            if source_file == file1:
                return ["command1"]

            if source_file == file2:
                return ["command2"]

            if source_file == file3:
                return ["command3"]

            raise AssertionError

        def check_output_side_effect(command, env=None):  # pylint: disable=missing-docstring, unused-argument
            if command == ["command1"]:
                raise subprocess.CalledProcessError(returncode=-1, cmd=command, output="bad stuff")

            return ""

        simif.compile_source_file_command.side_effect = compile_source_file_command

        with mock.patch("vunit.sim_if.check_output", autospec=True) as check_output:
            check_output.side_effect = check_output_side_effect
            printer = MockPrinter()
            simif.compile_source_files(project, printer=printer, continue_on_error=True)
            self.assertEqual(
                printer.output,
                """\
Compiling into lib: file3.vhd passed
Compiling into lib: file1.vhd failed
=== Command used: ===
command1

=== Command output: ===
bad stuff
Compiling into lib: file2.vhd skipped
Compile failed
""",
            )
            self.assertEqual(len(check_output.mock_calls), 2)
            check_output.assert_has_calls(
                [
                    mock.call(["command1"], env=simif.get_env()),
                    mock.call(["command3"], env=simif.get_env()),
                ],
                any_order=True,
            )
        self.assertEqual(project.get_files_in_compile_order(incremental=True), [file1, file2])

    def test_compile_source_files_check_output_error(self):
        simif = create_simulator_interface()
        simif.compile_source_file_command.return_value = ["command"]
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")

        with mock.patch("vunit.sim_if.check_output", autospec=True) as check_output:

            def check_output_side_effect(command, env=None):  # pylint: disable=missing-docstring, unused-argument
                raise subprocess.CalledProcessError(returncode=-1, cmd=command, output="bad stuff")

            check_output.side_effect = check_output_side_effect
            printer = MockPrinter()
            self.assertRaises(CompileError, simif.compile_source_files, project, printer=printer)
            self.assertEqual(
                printer.output,
                """\
Compiling into lib: file.vhd failed
=== Command used: ===
command

=== Command output: ===
bad stuff
Compile failed
""",
            )
            check_output.assert_called_once_with(["command"], env=simif.get_env())
        self.assertEqual(project.get_files_in_compile_order(incremental=True), [source_file])

    def test_compile_source_files_create_command_error(self):
        simif = create_simulator_interface()
        project = Project()
        project.add_library("lib", "lib_path")
        write_file("file.vhd", "")
        source_file = project.add_source_file("file.vhd", "lib", file_type="vhdl")

        with mock.patch("vunit.sim_if.check_output", autospec=True) as check_output:
            check_output.return_value = ""

            def raise_compile_error(source_file):  # pylint: disable=unused-argument
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

        simif = MySimulatorInterface(output_path="output_path", gui=False)
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
        self.output_path = str(Path(__file__).parent / "test_simulator_interface__out")
        renew_path(self.output_path)
        self.project = Project()
        self.cwd = getcwd()
        chdir(self.output_path)

    def tearDown(self):
        chdir(self.cwd)
        if Path(self.output_path).exists():
            rmtree(self.output_path)


class TestOptions(unittest.TestCase):
    """
    The the compile and simulation options validators
    """

    def test_boolean_option(self):
        option = BooleanOption("optname")
        self._test_ok(option, True)
        self._test_ok(option, False)
        self._test_not_ok(option, None, "Option 'optname' must be a boolean. Got None")

    def test_string_option(self):
        option = StringOption("optname")
        self._test_ok(option, "hello")
        self._test_ok(option, "hello")
        self._test_not_ok(option, False, "Option 'optname' must be a string. Got False")
        self._test_not_ok(option, ["foo"], "Option 'optname' must be a string. Got ['foo']")

    def test_list_of_string_option(self):
        option = ListOfStringOption("optname")
        self._test_ok(option, ["hello", "foo"])
        self._test_ok(option, ["hello"])
        self._test_not_ok(option, [True], "Option 'optname' must be a list of strings. " "Got [True]")
        self._test_not_ok(
            option,
            [["foo"]],
            "Option 'optname' must be a list of strings. " "Got [['foo']]",
        )
        self._test_not_ok(option, "foo", "Option 'optname' must be a list of strings. " "Got 'foo'")

    def test_vhdl_assert_level(self):
        option = VHDLAssertLevelOption()
        self._test_ok(option, "warning")
        self._test_ok(option, "error")
        self._test_ok(option, "failure")

        self._test_not_ok(
            option,
            "foo",
            "Option 'vhdl_assert_stop_level' must be one of " "('warning', 'error', 'failure'). Got 'foo'",
        )

    @staticmethod
    def _test_ok(option, value):
        option.validate(value)

    def _test_not_ok(self, option, value, message):
        """
        Test taht setting option to value is not OK with message
        """
        try:
            option.validate(value)
        except ValueError as err:
            self.assertEqual(str(err), message)
        else:
            assert False


def create_simulator_interface():
    """
    Create a simulator interface with fake method
    """
    simif = SimulatorInterface(output_path="output_path", gui=False)
    simif.compile_source_file_command = mock.create_autospec(simif.compile_source_file_command)
    return simif


class MockPrinter(object):
    """
    Mock printer that accumulates the calls as a string
    """

    def __init__(self):
        self.output = ""

    def write(self, text, output_file=None, fg=None, bg=None):  # pylint: disable=unused-argument
        self.output += text
