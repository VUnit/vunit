# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Generic simulator interface
"""

from __future__ import print_function
import sys
import os
from vunit.ostools import Process, simplify_path
from vunit.exceptions import CompileError
from vunit.color_printer import NO_COLOR_PRINTER


class SimulatorInterface(object):
    """
    Generic simulator interface
    """

    name = None
    supports_gui_flag = False
    package_users_depend_on_bodies = False
    compile_options = []
    sim_options = []
    _printer = NO_COLOR_PRINTER

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        pass

    @staticmethod
    def supports_vhdl_2008_contexts():
        """
        Returns True when this simulator supports VHDL 2008 contexts
        """
        return True

    @staticmethod
    def find_executable(executable):
        """
        Return a list of all executables found in PATH
        """
        path = os.environ['PATH']
        paths = path.split(os.pathsep)
        _, ext = os.path.splitext(executable)

        if (sys.platform == 'win32' or os.name == 'os2') and (ext != '.exe'):
            executable = executable + '.exe'

        result = []
        if isfile(executable):
            result.append(executable)

        for prefix in paths:
            file_name = os.path.join(prefix, executable)
            if isfile(file_name):
                # the file exists, we have a shot at spawn working
                result.append(file_name)
        return result

    @staticmethod
    def _get_compilation_message_level(line):  # pylint: disable=unused-argument
        """
        Method should be overridden by child classes and return an
        identification of the line content. Supported values are:
        - None: won't add any color
        - 'error': triggers printing the line in red
        - 'warning': triggers printing the line in yellow
        """
        return None

    @staticmethod
    def get_vhdl_assertion_level(line):  # pylint: disable=unused-argument
        """
        Method should be overridden by child classes and return a string
        identifying the level of the VHDL assertion. If the line doesn't
        contains any assertion, it should return None
        """
        return None

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
        return None

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

        if len(executables) == 0:
            return None

        all_paths = [[os.path.abspath(os.path.dirname(executables))
                      for executables in cls.find_executable(name)]
                     for name in executables]

        for path0 in all_paths[0]:
            if all([path0 in paths for paths in all_paths] +
                   [constraint(path0) for constraint in constraints]):
                return path0

    def post_process(self, output_path):
        """
        Hook for simulator interface to perform post processing such as creating coverage reports
        """
        pass

    def compile_project(self, project, vhdl_standard, continue_on_error=False):
        """
        Compile the project
        """
        self.setup_library_mapping(project, vhdl_standard)
        self.compile_source_files(project, continue_on_error)

    def simulate(self, output_path,  # pylint: disable=too-many-arguments
                 library_name, entity_name, architecture_name, config, elaborate_only):
        """
        Simulate
        """
        pass

    def setup_library_mapping(self, project, vhdl_standard):
        """
        Implemented by specific simulators
        """
        pass

    def compile_source_files(self, project, continue_on_error=False):
        """
        Use compile_source_file_command to compile all source_files
        """
        dependency_graph = project.create_dependency_graph()
        all_ok = True
        failures = []
        source_files = project.get_files_in_compile_order(dependency_graph=dependency_graph)
        source_files_to_skip = set()
        for source_file in source_files:
            if source_file in source_files_to_skip:
                print("Skipping %s due to failed dependencies" % simplify_path(source_file.name))
                continue

            print('Compiling %s into %s ...' % (simplify_path(source_file.name), source_file.library.name))
            try:
                command = None
                command = self.compile_source_file_command(source_file)
                success = run_command(command, self._compile_output_consumer)

            except CompileError:
                success = False

            if success:
                project.update(source_file)
            else:
                source_files_to_skip.update(dependency_graph.get_dependent([source_file]))
                failures.append(source_file)

                if command is None:
                    print("Failed to compile %s. File type not supported by %s simulator"
                          % (simplify_path(source_file.name), self.name))
                else:
                    print("Failed to compile %s with command:\n%s"
                          % (simplify_path(source_file.name), " ".join(command)))

                all_ok = False
                if not continue_on_error:
                    break

        if not all_ok:
            if continue_on_error:
                print("Failed to compile some files")
            raise CompileError

    def compile_source_file_command(self, source_file):  # pylint: disable=unused-argument
        raise NotImplementedError

    def _compile_output_consumer(self, line):  # pylint: disable=unused-argument
        """
        Consumes the output of the compilation process.
        """
        if self._printer is NO_COLOR_PRINTER:
            # Avoid parsing simulator output if not configured with the color
            # printer
            self._printer.write(line, sys.stdout)
        else:
            # Use the return of the _get_compilation_message_level to colorize the
            # given line
            color_category = self._get_compilation_message_level(line)  # pylint: disable=assignment-from-none
            assert color_category in (None, 'error', 'warning')
            if color_category is None:
                print(line)
            elif color_category == 'warning':
                self._printer.write(line + '\n', sys.stdout, fg='rg', bg=None)
            elif color_category == 'error':
                self._printer.write(line + '\n', sys.stdout, fg='r', bg=None)


def isfile(file_name):
    """
    Case insensitive os.path.isfile
    """
    if not os.path.isfile(file_name):
        return False

    return os.path.basename(file_name) in os.listdir(os.path.dirname(file_name))


def run_command(command, callback=print):
    """
    Run a command
    """
    try:
        proc = Process(command)
        proc.consume_output(callback)
        return True
    except Process.NonZeroExitCode:
        pass
    return False
