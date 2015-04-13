# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards NVC simulator
https://github.com/nickg/nvc
"""

from __future__ import print_function
import os
from os.path import dirname, exists, join
import subprocess
from vunit.simulator_interface import SimulatorInterface
from vunit.exceptions import CompileError
from vunit.ostools import Process


class NvcInterface(SimulatorInterface):
    """
    Interface towards NVC simulator
    """
    name = "nvc"

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        pass

    @classmethod
    def from_args(cls, output_path, args):  # pylint: disable=unused-argument
        return cls(prefix=cls.find_prefix())

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find nvc executable prefix from PATH environment variable
        """
        return cls.find_toolchain(['nvc'])

    def __init__(self, prefix):
        self._prefix = prefix
        self._libraries = {}
        self._vhdl_standard = None

    def setup_library_mapping(self, project, vhdl_standard):
        """
        Setup the library mapping according to project
        """

        libraries = project.get_libraries()
        self._libraries = libraries
        self._vhdl_standard = vhdl_standard
        for library in libraries:
            if not exists(dirname(library.directory)):
                os.makedirs(dirname(library.directory))
            args = ['--std=%s' % vhdl_standard]
            args += ['--ignore-time']
            args += ['--work=%s:%s' % (library.name, library.directory)]
            args += ['-a']
            subprocess.check_output(['nvc'] + args)

    def compile_source_file_command(self, source_file):
        """
        Returns command to compile source file
        """
        if source_file.file_type == 'vhdl':
            return self.compile_vhdl_file_command(source_file)

        raise CompileError

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the commands to compile a vhdl file
        """
        args = [join(self._prefix, 'nvc'), '--std=%s' % self._vhdl_standard]
        args += ['--ignore-time']
        for library in self._libraries:
            args += ['--map=%s:%s' % (library.name, library.directory)]
            if library.name == source_file.library.name:
                args += ['--work=%s:%s' % (library.name, library.directory)]
        args += ['-a', source_file.name]
        for design_unit in source_file.design_units:
            if design_unit.unit_type == "package body":
                args += ['--codegen', design_unit.name]
        return args

    def simulate(self, output_path,  # pylint: disable=too-many-arguments
                 library_name, entity_name, architecture_name, config, elaborate_only):
        """
        Simulate top level
        """
        # @TODO disable_ieee_warnings
        try:
            args = []
            args += ['--std=%s' % "2008"]
            args += ['--ignore-time']
            for library in self._libraries:
                args += ['--map=%s:%s' % (library.name, library.directory)]
                if library.name == library_name:
                    args += ['--work=%s:%s' % (library.name, library.directory)]
            args += ['--work', library_name]
            args += ['-e', entity_name, architecture_name]
            for item in config.generics.items():
                args += ['-g%s=%s' % item]

            if elaborate_only:
                proc = Process([join(self._prefix, 'nvc')] + args)
                proc.consume_output()
                return True

            args += ['-r', entity_name, architecture_name]

            if config.fail_on_warning:
                args += ["--exit-severity=warning"]
            else:
                args += ["--exit-severity=error"]

            proc = Process([join(self._prefix, 'nvc')] + args)
            proc.consume_output()

        except Process.NonZeroExitCode:
            return False

        return True
