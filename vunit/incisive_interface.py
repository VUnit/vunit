# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, 2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for the Cadence Incisive simulator
"""

from __future__ import print_function
import logging
LOGGER = logging.getLogger(__name__)

from vunit.ostools import Process
from vunit.simulator_interface import SimulatorInterface
from vunit.exceptions import CompileError

from os.path import exists, join
import os
from distutils.spawn import find_executable
from sys import stdout  # To avoid output catched in non-verbose mode


class IncisiveInterface(SimulatorInterface):
    """
    Interface for the Cadence Incisive simulator
    """

    name = "incisive"

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group("irun",
                                          description="irun-specific flags")
        group.add_argument('-g', '--gui',
                           action="store_true",
                           default=None,
                           help=("Open test case(s) in simulator GUI with top level preloaded"))

    @classmethod
    def from_args(cls, output_path, args):
        return cls(gui=args.gui)

    @staticmethod
    def is_available():
        """
        Return True if irun is installed
        """
        return find_executable('irun') is not None

    def __init__(self, gui=None):
        self._libraries = {}
        self._vhdl_standard = None
        self._gui = gui

    def compile_project(self, project, vhdl_standard):
        """
        Compile project using vhdl_standard
        """
        self._libraries = {}
        self._vhdl_standard = vhdl_standard
        for library in project.get_libraries():
            if not exists(library.directory):
                os.makedirs(library.directory)
            self._libraries[library.name] = library.directory

        for source_file in project.get_files_in_compile_order():
            print('Compiling "' + source_file.name + '" into "' + source_file.library.name + '" ...')

            if source_file.file_type == 'vhdl':
                success = self.compile_vhdl_file(source_file.name,
                                                 source_file.library.name,
                                                 os.path.dirname(source_file.library.directory),
                                                 vhdl_standard,
                                                 source_file.compile_options)
            elif source_file.file_type == 'verilog':
                success = self.compile_verilog_file(source_file.name,
                                                    source_file.library.name,
                                                    os.path.dirname(source_file.library.directory),
                                                    source_file.include_dirs,
                                                    source_file.compile_options)

            if not success:
                raise CompileError("Failed to compile '%s'" % source_file.name)
            project.update(source_file)

    def _vhdl_std_opt(self):
        """
        Convert standard to format of irun command line flag
        """
        if self._vhdl_standard == "2002":
            return "-v200x -extv200x"
        elif self._vhdl_standard == "2008":
            return "-v200x -extv200x"
        elif self._vhdl_standard == "93":
            return "-v93"
        else:
            assert False

    def compile_vhdl_file(self,  # pylint: disable=too-many-arguments
                          source_file_name,
                          library_name,
                          library_path_root,
                          vhdl_standard,
                          compile_options):
        """
        Compiles a VHDL file
        """
        try:
            cmd = ['irun',
                   '-nocopyright',
                   '-licqueue',
                   '-cdslib cds.lib',
#                   '-prep',
#                   '+overwrite',
                   '-quiet',
                   '-compile',
#                   '-elaborate',
                   '-nowarn DLCPTH', # "cds.lib Invalid path"
                   '%s' % self._vhdl_std_opt(),
            ]
            cmd += compile_options.get('irun_flags', [])
            cmd += ['-nclibdirname %s' % library_path_root]
            cmd += ['-makelib %s' % library_name]
            cmd += ['-endlib']
            cmd += [source_file_name]
            proc = Process(cmd)
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def compile_verilog_file(self, source_file_name, library_name, library_path_root, include_dirs, compile_options):
        """
        Compiles a Verilog file
        """
        try:
            cmd = ['irun',
                   '-nocopyright',
                   '-licqueue',
                   '-cdslib cds.lib',
#                   '-prep',
#                   '+overwrite',
                   '-elaborate',
                   '-nowarn UEXPSC', # "Ignored unexpected semicolon following SystemVerilog description keyword (endfunction)."
                   '-nowarn DLCPTH', # "cds.lib Invalid path"
            ]
            cmd += compile_options.get('irun_flags', [])
            for include_dir in include_dirs:
                cmd += ['-incdir %s' % include_dir]
            cmd += ['-nclibdirname %s' % library_path_root]
            cmd += ['-makelib %s' % library_name]
            cmd += ['-endlib']
            cmd += [source_file_name]
            proc = Process(cmd)
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def simulate(self,  # pylint: disable=too-many-arguments, too-many-locals
                 output_path, library_name, entity_name, architecture_name, config):
        """
        Simulates with entity as top level using generics
        """

        launch_gui = self._gui is not None and not config.elaborate_only

        status = True
        try:
            cmd = ['irun',
                   '-nocopyright',
                   '-licqueue',
                   '-cdslib cds.lib',
#                   '-timescale 1ns/1ns',
                   '-nowarn WRMNZD',
                   '-wreal_resolution fourstate',
                   '-shm_dyn_probe',
                   '-mcdump',
            ]
            if config.elaborate_only:
                cmd += ['-elaborate']
            if launch_gui:
                cmd += ['-access +rwc']
                cmd += ['-gui']
            else:
                cmd += ['-access +r']
                cmd += ['-input "@stop -delta 10000 -timestep -delbreak 1"']
                cmd += ['-input "@run"']
                cmd += ['-input "@exit"']
#            cmd += ['-top %s' % join('%s.%s' % (entity_name, architecture_name))]
            cmd += ['-top %s' % join('%s' % (entity_name))] # FIXME: correct?
            proc = Process(cmd)
            proc.consume_output()
        except Process.NonZeroExitCode:
            status = False

        return status
