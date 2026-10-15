# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Test the SimulatorInterface class
"""

import unittest
from pathlib import Path
from os import chdir, getcwd
import subprocess
import threading
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

    def _compile_concurrently(self, libraries, supports_concurrent_compiles_into_library=False, fail=None):
        """
        Compile one file per library name in libraries with 4 threads, the compile commands
        waiting for each other in pairs. Return the printer output and the compile commands
        that ran at the same time as another.
        """
        simif = create_simulator_interface()
        simif.supports_concurrent_compiles_into_library = supports_concurrent_compiles_into_library
        simif.compile_source_file_command.side_effect = lambda source_file: [Path(source_file.name).stem]
        project = Project()
        for library in sorted(set(libraries)):
            project.add_library(library, library + "_path")
        for idx, library in enumerate(libraries):
            write_file(f"file{idx}.vhd", "")
            project.add_source_file(f"file{idx}.vhd", library, file_type="vhdl")

        barrier = threading.Barrier(2, timeout=1)
        concurrent = set()

        def check_output_side_effect(command, env=None):  # pylint: disable=unused-argument
            try:
                barrier.wait()
                concurrent.add(command[0])
            except threading.BrokenBarrierError:
                pass
            if command[0] == fail:
                raise subprocess.CalledProcessError(returncode=-1, cmd=command, output="bad stuff")
            return command[0] + " output\n"

        with mock.patch("vunit.sim_if.check_output", autospec=True) as check_output:
            check_output.side_effect = check_output_side_effect
            printer = MockPrinter()
            simif.compile_source_files(project, printer=printer, num_threads=4, continue_on_error=True)
        return printer.output, concurrent

    def test_compile_source_files_of_different_libraries_concurrently(self):
        _, concurrent = self._compile_concurrently(["lib1", "lib2"])
        self.assertEqual(concurrent, {"file0", "file1"})

    def test_compile_source_files_of_a_library_one_at_a_time(self):
        _, concurrent = self._compile_concurrently(["lib", "lib"])
        self.assertEqual(concurrent, set())

    def test_compile_source_files_of_a_library_concurrently_when_supported(self):
        _, concurrent = self._compile_concurrently(["lib", "lib"], supports_concurrent_compiles_into_library=True)
        self.assertEqual(concurrent, {"file0", "file1"})

    def test_compile_source_files_concurrently_writes_the_output_of_a_file_at_once(self):
        output, _ = self._compile_concurrently(["lib1", "lib2"], fail="file1")
        self.assertIn("Compiling into lib1: file0.vhd passed\nfile0 output\n", output)
        self.assertIn("Compiling into lib2: file1.vhd failed\n=== Command used: ===\nfile1\n", output)
        self.assertTrue(output.endswith("Compile failed\n"))

    def test_compile_source_files_waits_for_dependencies(self):
        simif = create_simulator_interface()
        simif.compile_source_file_command.side_effect = lambda source_file: [Path(source_file.name).stem]
        project = Project()
        project.add_library("lib1", "lib1_path")
        project.add_library("lib2", "lib2_path")
        write_file("file1.vhd", "")
        file1 = project.add_source_file("file1.vhd", "lib1", file_type="vhdl")
        write_file("file2.vhd", "")
        file2 = project.add_source_file("file2.vhd", "lib2", file_type="vhdl")
        write_file("file3.vhd", "")
        file3 = project.add_source_file("file3.vhd", "lib1", file_type="vhdl")
        project.add_manual_dependency(file3, depends_on=file2)

        def check_output_side_effect(command, env=None):  # pylint: disable=unused-argument
            if command == ["file2"]:
                raise subprocess.CalledProcessError(returncode=-1, cmd=command, output="bad stuff")
            return ""

        with mock.patch("vunit.sim_if.check_output", autospec=True) as check_output:
            check_output.side_effect = check_output_side_effect
            printer = MockPrinter()
            simif.compile_source_files(project, printer=printer, num_threads=4, continue_on_error=True)
            self.assertIn("Compiling into lib1: file3.vhd skipped\n", printer.output)
            self.assertEqual(len(check_output.mock_calls), 2)
        self.assertEqual(project.get_files_in_compile_order(incremental=True), [file2, file3])
        self.assertNotIn(file1, project.get_files_in_compile_order(incremental=True))

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

    def test_prefix_is_a_read_only_property(self):
        class MySimulatorInterface(SimulatorInterface):  # pylint: disable=abstract-method
            """
            Dummy simulator interface built with a prefix
            """

            name = "simname"

            def __init__(self, output_path, prefix, gui=False):
                SimulatorInterface.__init__(self, output_path, gui)
                self._prefix = prefix

        simif = MySimulatorInterface(output_path="output_path", prefix="simname/bin")
        self.assertEqual(simif.prefix, "simname/bin")
        self.assertRaises(AttributeError, setattr, simif, "prefix", "other/bin")

        self.assertIsNone(SimulatorInterface(output_path="output_path", gui=False).prefix)

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
