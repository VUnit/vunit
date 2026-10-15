# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Simulator interface(s)
"""

import sys
import os
from os import environ, listdir, pathsep
import locale
import subprocess
from collections import Counter
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from pathlib import Path
from typing import List, Optional
from ..ostools import Process, simplify_path
from ..exceptions import CompileError
from ..color_printer import NO_COLOR_PRINTER


class Option(object):
    """
    A compile or sim option
    """

    def __init__(self, name):
        self._name = name

    @property
    def name(self):
        return self._name

    def validate(self, value):
        pass


def add_extension(executable_name):
    """
    Add .exe extension on Windows platforms if not already present
    """
    ext = Path(executable_name).suffix

    if (sys.platform == "win32" or os.name == "os2") and (ext != ".exe"):
        executable_name = executable_name + ".exe"

    return executable_name


class SimulatorInterface(object):  # pylint: disable=too-many-public-methods
    """
    Generic simulator interface
    """

    name: str = "none"
    supports_gui_flag = False
    package_users_depend_on_bodies = False
    compile_options: List[Option] = []
    sim_options: List[Option] = []

    # True if simulator supports ANSI colors in GUI mode
    supports_colors_in_gui = False

    # True if VHDL files of a library, with the same compile options, can be compiled in one call
    supports_batch_compile = False

    # True if a library can be compiled into while it is compiled into or read by another
    # compile. Most compilers update the index of a library without locking it, so concurrent
    # updates lose units and a compile reading it during an update fails.
    supports_concurrent_compiles_into_library = False

    # The path prefix the interface was built with, set by the interfaces having one
    _prefix: Optional[str] = None

    def __init__(self, output_path, gui):
        self._output_path = output_path
        self._gui = gui

    @property
    def prefix(self) -> Optional[str]:
        """
        The path prefix the executables of the simulator were found in, None for an
        interface not built with one.

        A simulator hook of a VUnit package is given this interface and can use the prefix
        to reach what the simulator installation itself provides.
        """
        return self._prefix

    @property
    def output_path(self):
        return self._output_path

    @property
    def use_color(self):
        return (not self._gui) or self.supports_colors_in_gui

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """

    @staticmethod
    def supports_vhdl_contexts():
        """
        Returns True when this simulator supports VHDL contexts
        """
        return True

    @classmethod
    def supports_vhdl_call_paths(cls):
        """
        Returns True when this simulator supports VHDL-2019 call paths
        """
        return False

    @staticmethod
    def find_executable(executable):
        """
        Return a list of all executables found in PATH
        """
        path = environ.get("PATH", None)
        if path is None:
            return []

        paths = path.split(pathsep)
        executable = add_extension(executable)

        result = []
        if isfile(executable):
            result.append(executable)

        for prefix in paths:
            file_name = str(Path(prefix) / executable)
            if isfile(file_name):
                # the file exists, we have a shot at spawn working
                result.append(file_name)
        return result

    @classmethod
    def find_prefix(cls):
        """
        Find prefix by looking at VUNIT_<SIMULATOR_NAME>_PATH environment variable
        """
        prefix = os.environ.get("VUNIT_" + cls.name.upper() + "_PATH", None)
        if prefix is not None:
            return prefix
        return cls.find_prefix_from_path()

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find simulator toolchain prefix from PATH environment variable
        """

    @classmethod
    def is_available(cls):
        """
        Returns True if simulator is available
        """
        return cls.find_prefix() is not None

    @classmethod
    def find_toolchain(cls, executables, constraints=None):
        """
        Find the first path prefix containing all executables
        """
        constraints = [] if constraints is None else constraints

        if not executables:
            return None

        all_paths = [
            [str(Path(executables).parent.resolve()) for executables in cls.find_executable(name)]
            for name in executables
        ]

        for path0 in all_paths[0]:
            if all([path0 in paths for paths in all_paths] + [constraint(path0) for constraint in constraints]):
                return path0
        return None

    @classmethod
    def get_osvvm_coverage_api(cls):
        """
        Returns simulator name when OSVVM coverage API is supported, None otherwise.
        """

    @classmethod
    def supports_vhdl_package_generics(cls):
        """
        Returns True when this simulator supports VHDL package generics
        """
        return False

    @staticmethod
    def has_valid_exit_code():
        """
        Return if the simulation should fail with nonzero exit codes
        """
        return False

    @staticmethod
    def supports_vhpi():
        """
        Returns True when the simulator supports VHPI
        """
        return False

    @staticmethod
    def supports_coverage():
        """
        Returns True when the simulator supports coverage
        """
        return False

    def merge_coverage(self, file_name, args):  # pylint: disable=unused-argument
        """
        Hook for simulator interface to creating coverage reports
        """
        raise RuntimeError("This simulator does not support merging coverage")

    def add_simulator_specific(self, project):
        """
        Hook for the simulator interface to add simulator specific things to the project
        """

    def compile_project(
        self,
        project,
        printer=NO_COLOR_PRINTER,
        continue_on_error=False,
        target_files=None,
        num_threads=1,
        *,
        batch=False,
    ):  # pylint: disable=too-many-arguments
        """
        Compile the project
        param: target_files: Given a list of SourceFiles only these and dependent files are compiled
        param: num_threads: The number of files compiled at the same time, 0 for all logical CPUs
        param: batch: Compile files that are ready at the same time in one call, see compile_source_files
        """
        self.add_simulator_specific(project)
        self.setup_library_mapping(project)
        self.compile_source_files(
            project, printer, continue_on_error, target_files=target_files, num_threads=num_threads, batch=batch
        )

    def simulate(self, output_path, test_suite_name, config, elaborate_only):
        """
        Simulate
        """

    def setup_library_mapping(self, project):
        """
        Implemented by specific simulators
        """

    def _compile_source_file(self, source_file, printer):
        """
        Compiles a single source file and prints status information
        """
        try:
            command = self.compile_source_file_command(source_file)
        except CompileError:
            command = None
            printer.write("failed", fg="ri")
            printer.write("\n")
            printer.write(f"File type not supported by {self.name!s} simulator\n")

            return False

        try:
            output = check_output(command, env=self.get_env())
            printer.write("passed", fg="gi")
            printer.write("\n")
            printer.write(output)

        except subprocess.CalledProcessError as err:
            printer.write("failed", fg="ri")
            printer.write("\n")
            printer.write(f"=== Command used: ===\n{subprocess.list2cmdline(command)!s}\n")
            printer.write("\n")
            printer.write(f"=== Command output: ===\n{err.output!s}\n")

            return False

        return True

    def compile_source_files(
        self,
        project,
        printer=NO_COLOR_PRINTER,
        continue_on_error=False,
        target_files=None,
        num_threads=1,
        *,
        batch=False,
    ):  # pylint: disable=too-many-arguments
        """
        Use compile_source_file_command to compile all source_files
        param: target_files: Given a list of SourceFiles only these and dependent files are compiled
        param: num_threads: The number of files compiled at the same time, 0 for all logical CPUs
        param: batch: Compile the VHDL files of a library that are ready at the same time, and have the
        same compile options, in one call if supports_batch_compile. A batch that fails is compiled
        again one file at a time to find the file that fails.
        """
        dependency_graph = project.create_dependency_graph()

        if target_files is None:
            source_files = project.get_files_in_compile_order(dependency_graph=dependency_graph)
        else:
            source_files = project.get_minimal_file_set_in_compile_order(target_files)

        failures = self._compile_in_dependency_order(
            project,
            source_files,
            dependency_graph=dependency_graph,
            printer=printer,
            continue_on_error=continue_on_error,
            num_threads=num_threads or os.cpu_count() or 1,
            batch=batch and self.supports_batch_compile,
        )

        if failures:
            printer.write("Compile failed\n", fg="ri")
            if continue_on_error:
                return
            raise CompileError

        if source_files:
            printer.write("Compile passed\n", fg="gi")
        else:
            printer.write("Re-compile not needed\n")

    def _compile_in_dependency_order(
        self, project, source_files, *, dependency_graph, printer, continue_on_error, num_threads, batch
    ):  # pylint: disable=too-many-arguments,too-many-locals,too-many-statements
        """
        Compile source_files, num_threads at a time, and return the files that failed. A file is
        compiled once its dependencies are. Unless supports_concurrent_compiles_into_library, it is
        not compiled while its library is compiled into or read, or while a library it reads, that of
        any of its dependencies, is compiled into. The dependents of a failed file are skipped.
        """
        max_library_name = max((len(source_file.library.name) for source_file in source_files), default=0)
        max_source_file_name = max((len(simplify_path(source_file.name)) for source_file in source_files), default=0)

        def write_header(source_file, output):
            output.write(
                f"Compiling into {(source_file.library.name + ':').ljust(max_library_name + 1)!s} "
                f"{simplify_path(source_file.name).ljust(max_source_file_name)!s} "
            )

        def compile_files(files, output):
            if len(files) > 1:
                return self._compile_batch(files, output, write_header)
            write_header(files[0], output)
            sys.stdout.flush()
            return self._compile_source_file(files[0], output)

        batch_commands = {}

        def batch_command(source_file):
            """The command compiling source_file without its file name, None if it cannot be batched"""
            if source_file not in batch_commands:
                batch_commands[source_file] = self._batch_command(source_file) if batch else None
            return batch_commands[source_file]

        def batch_of(source_file):
            """source_file and the files that are ready to be compiled with it in one call"""
            files = [source_file]
            if batch_command(source_file) is None:
                return files
            for other in to_compile:
                if (
                    other.library.name == source_file.library.name
                    and batch_command(other) == batch_command(source_file)
                    and all(compiled.get(dependency) or dependency in files for dependency in dependencies[other])
                    and not is_busy(other)
                ):
                    files.append(other)
            return files

        def is_busy(source_file):
            """Whether a running compile keeps source_file from being compiled now"""
            library = source_file.library.name
            return not self.supports_concurrent_compiles_into_library and bool(
                libraries_written[library]
                or libraries_being_read[library]
                or any(libraries_written[read] for read in libraries_read[source_file])
            )

        def finish(files, passed):
            if len(files) > 1 and not passed:
                # Compiled again one at a time, in compile order, to find the file that fails
                for source_file in files:
                    batch_commands[source_file] = None
                waiting = set(to_compile) | set(files)
                to_compile[:] = [source_file for source_file in source_files if source_file in waiting]
                return

            for source_file in files:
                compiled[source_file] = passed
                if passed:
                    project.update(source_file)
                else:
                    failures.append(source_file)

        to_compile = list(source_files)
        dependencies = {
            source_file: dependency_graph.get_direct_dependencies(source_file) & set(source_files)
            for source_file in source_files
        }
        # ponytail: a bare library clause, with nothing used from the library, is not a read
        libraries_read = {
            source_file: {dependency.library.name for dependency in dependency_graph.get_dependencies([source_file])}
            for source_file in source_files
        }
        compiled = {}  # Whether a finished file was compiled, rather than failed or skipped
        failures = []
        running = {}
        libraries_written = Counter()
        libraries_being_read = Counter()

        with ThreadPoolExecutor(max_workers=num_threads) as executor:
            while to_compile or running:
                # ponytail: scans every waiting file per completed one, fine for thousands of files
                for source_file in list(to_compile):
                    if len(running) == num_threads or (failures and not continue_on_error):
                        break

                    # Taken by a batch, or waiting for its dependencies
                    if source_file not in to_compile or not dependencies[source_file] <= compiled.keys():
                        continue

                    if not all(compiled[dependency] for dependency in dependencies[source_file]):
                        to_compile.remove(source_file)
                        compiled[source_file] = False
                        write_header(source_file, printer)
                        printer.write("skipped", fg="rgi")
                        printer.write("\n")
                        continue

                    if is_busy(source_file):
                        continue

                    to_compile.remove(source_file)
                    files = batch_of(source_file)
                    for other in files[1:]:
                        to_compile.remove(other)
                    libraries_written[source_file.library.name] += 1
                    for other in files:
                        libraries_being_read.update(libraries_read[other])
                    # The output of a file is written once it is compiled, so that outputs do not mix
                    output = printer if num_threads == 1 else _BufferedPrinter()
                    running[executor.submit(compile_files, files, output)] = (files, output)

                if not running:
                    break

                done, _ = wait(running, return_when=FIRST_COMPLETED)
                for future in done:
                    files, output = running.pop(future)
                    libraries_written[files[0].library.name] -= 1
                    for source_file in files:
                        libraries_being_read.subtract(libraries_read[source_file])
                    if output is not printer:
                        output.write_to(printer)

                    finish(files, future.result())

        return failures

    def compile_source_file_command(self, source_file):  # pylint: disable=unused-argument
        raise NotImplementedError

    def _batch_command(self, source_file):
        """
        The command compiling source_file without its file name, or None if source_file cannot be
        compiled with other files. Files with the same command are compiled in one call.
        """
        if not source_file.is_vhdl:
            return None
        try:
            command = self.compile_source_file_command(source_file)
        except CompileError:
            return None
        return tuple(command[:-1]) if command[-1] == source_file.name else None

    def _compile_batch(self, source_files, printer, write_header):
        """
        Compile source_files in one call. The output of a batch that fails is not written, since
        its files are compiled again one at a time.
        """
        command = list(self._batch_command(source_files[0])) + [source_file.name for source_file in source_files]
        try:
            output = check_output(command, env=self.get_env())
        except subprocess.CalledProcessError:
            first = source_files[0]
            printer.write(
                f"Compiling {len(source_files)} files into {first.library.name} in one call failed, "
                "compiling them one at a time\n"
            )
            return False

        for source_file in source_files:
            write_header(source_file, printer)
            printer.write("passed", fg="gi")
            printer.write("\n")
        printer.write(output)
        return True

    @staticmethod
    def get_env():
        """
        Allows inheriting classes to overload this to modify environment variables. Return None for default environment
        """


class _BufferedPrinter(object):
    """
    Printer keeping what is written until it is written to another printer
    """

    def __init__(self):
        self._writes = []

    def write(self, text, output_file=None, fg=None, bg=None):
        self._writes.append((text, output_file, fg, bg))

    def write_to(self, printer):
        for text, output_file, fg, bg in self._writes:
            printer.write(text, output_file=output_file, fg=fg, bg=bg)


def isfile(file_name):
    """
    Case insensitive Path.is_file()
    """
    fpath = Path(file_name)
    try:
        if not fpath.is_file():
            return False
    except PermissionError:
        return False

    return str(fpath.name) in listdir(str(fpath.parent))


def run_command(command, cwd=None, env=None):
    """
    Run a command
    """
    try:
        proc = Process(command, cwd=cwd, env=env)
        proc.consume_output()
        return True
    except Process.NonZeroExitCode:
        pass
    return False


def check_output(command, env=None):
    """
    Wrapper arround subprocess.check_output
    """
    def _decode(data: bytes) -> str:
        """Decode tool output robustly across platforms.

        Some simulators on Windows emit output in a legacy code page (e.g. cp1252),
        which can raise UnicodeDecodeError if decoded as strict UTF-8.
        """

        # Deduplicate via dict.fromkeys to avoid trying utf-8 twice
        # when locale.getpreferredencoding() returns "UTF-8".
        encodings_to_try = dict.fromkeys([
            "utf-8",
            locale.getpreferredencoding(False),
        ])

        for encoding in encodings_to_try:
            try:
                return data.decode(encoding)
            except UnicodeDecodeError:
                continue

        return data.decode("utf-8", errors="backslashreplace")

    try:
        output = subprocess.check_output(  # pylint: disable=unexpected-keyword-arg
            command, env=env, stderr=subprocess.STDOUT
        )
    except subprocess.CalledProcessError as err:
        err.output = _decode(err.output)
        raise err
    return _decode(output)


def check_executable(simulator_name, prefix, executable_name):
    """
    Check that the executable exists.

    This helps to identify the case where the environment variable named after the simulator is used for
    other purposes than naming the executable. Issue #1149.
    """
    env_name = environ.get(simulator_name)

    # If environment variable isn't used for executable naming and VUNIT_<SIMULATOR_NAME>_PATH isn't set, the prefix
    # will be invalid since the toolchain search didn't find anything.
    try:
        prefix_path = Path(prefix)
    except TypeError as exc:
        error_message = f"{simulator_name} executable not found."
        if env_name is not None:
            error_message += (
                f" The {simulator_name} environment variable, if set, must be the executable name."
                f" Current value is {env_name}."
            )

        raise FileNotFoundError(error_message) from exc

    executable_name = add_extension(executable_name)

    executable_path = prefix_path / executable_name
    if not executable_path.is_file():
        error_message = f"{simulator_name} executable not found at {executable_path}."
        if env_name is not None:
            error_message += (
                f" The {simulator_name} environment variable, if set, must be the executable name."
                f" Current value is {env_name}."
            )

        raise FileNotFoundError(error_message)


class BooleanOption(Option):
    """
    Must be a boolean
    """

    def validate(self, value):
        if value not in (True, False):
            raise ValueError(f"Option {self.name!r} must be a boolean. Got {value!r}")


class StringOption(Option):
    """
    Must be a string
    """

    def validate(self, value):
        if not is_string_not_iterable(value):
            raise ValueError(f"Option {self.name!r} must be a string. Got {value!r}")


class ListOfStringOption(Option):
    """
    Must be a list of strings
    """

    def validate(self, value):
        def fail():
            raise ValueError(f"Option {self.name!r} must be a list of strings. Got {value!r}")

        if is_string_not_iterable(value):
            fail()

        try:
            for elem in value:
                if not is_string_not_iterable(elem):
                    fail()
        except TypeError:
            fail()


class VHDLAssertLevelOption(Option):
    """
    VHDL assert level
    """

    _legal_values = ("warning", "error", "failure")

    def __init__(self):
        Option.__init__(self, "vhdl_assert_stop_level")

    def validate(self, value):
        if value not in self._legal_values:
            raise ValueError(f"Option {self.name!r} must be one of {self._legal_values!s}. Got {value!r}")


def is_string_not_iterable(value):
    """
    Returns True if value is a string and not another iterable
    """
    return isinstance(value, str)
