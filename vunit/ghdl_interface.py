# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for GHDL simulator
"""

from __future__ import print_function
import logging
from os.path import exists, join
import os
import subprocess
import shlex
from sys import stdout  # To avoid output catched in non-verbose mode
from vunit.ostools import Process
from vunit.simulator_interface import (SimulatorInterface,
                                       ListOfStringOption)
from vunit.exceptions import CompileError
LOGGER = logging.getLogger(__name__)


class GHDLInterface(SimulatorInterface):
    """
    Interface for GHDL simulator
    """

    name = "ghdl"
    supports_gui_flag = True
    supports_colors_in_gui = True

    compile_options = [
        ListOfStringOption("ghdl.flags"),
    ]

    sim_options = [
        ListOfStringOption("ghdl.sim_flags"),
        ListOfStringOption("ghdl.elab_flags"),
    ]

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group("ghdl",
                                          description="GHDL specific flags")
        group.add_argument("--gtkwave-fmt", choices=["vcd", "ghw"],
                           default=None,
                           help="Save .vcd or .ghw to open in gtkwave")
        group.add_argument("--gtkwave-args",
                           default="",
                           help="Arguments to pass to gtkwave")

    @classmethod
    def from_args(cls, args, output_path, **kwargs):
        """
        Create instance from args namespace
        """
        prefix = cls.find_prefix()
        return cls(output_path=output_path,
                   prefix=prefix,
                   gui=args.gui,
                   gtkwave_fmt=args.gtkwave_fmt,
                   gtkwave_args=args.gtkwave_args,
                   backend=cls.determine_backend(prefix))

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find first valid ghdl toolchain prefix
        """
        return cls.find_toolchain(["ghdl"])

    def __init__(self,  # pylint: disable=too-many-arguments
                 output_path, prefix, gui=False, gtkwave_fmt=None, gtkwave_args="", backend="llvm"):
        SimulatorInterface.__init__(self, output_path, gui)
        self._prefix = prefix
        self._project = None

        if gui and (not self.find_executable('gtkwave')):
            raise RuntimeError(
                "Cannot find the gtkwave executable in the PATH environment variable. GUI not possible")

        self._gui = gui
        self._gtkwave_fmt = "ghw" if gui and gtkwave_fmt is None else gtkwave_fmt
        self._gtkwave_args = gtkwave_args
        self._backend = backend
        self._vhdl_standard = None

    @staticmethod
    def determine_backend(prefix):
        """
        Determine the GHDL backend
        """
        mapping = {
            "mcode code generator": "mcode",
            "llvm code generator": "llvm",
            "GCC back-end code generator": "gcc"
        }
        output = subprocess.check_output([join(prefix, "ghdl"), "--version"]).decode()
        for name, backend in mapping.items():
            if name in output:
                LOGGER.debug("Detected GHDL %s", name)
                return backend

        LOGGER.error("Could not detect known LLVM backend by parsing 'ghdl --version'")
        print("Expected to find one of %r" % mapping.keys())
        print("== Output of 'ghdl --version'" + ("=" * 60))
        print(output)
        print("=============================" + ("=" * 60))
        raise AssertionError("No known GHDL back-end could be detected from running 'ghdl --version'")

    def _has_output_flag(self):
        """
        Returns if backend supports output flag
        """
        return self._backend in ("llvm", "gcc")

    def setup_library_mapping(self, project):
        """
        Setup library mapping
        """
        self._project = project
        for library in project.get_libraries():
            if not exists(library.directory):
                os.makedirs(library.directory)

        vhdl_standards = set(source_file.get_vhdl_standard()
                             for source_file in project.get_source_files_in_order()
                             if source_file.is_vhdl)

        if not vhdl_standards:
            self._vhdl_standard = '2008'
        elif len(vhdl_standards) != 1:
            raise RuntimeError("GHDL cannot handle mixed VHDL standards, found %r" % list(vhdl_standards))
        else:
            self._vhdl_standard = list(vhdl_standards)[0]

    def compile_source_file_command(self, source_file):
        """
        Returns the command to compile a single source_file
        """
        if source_file.is_vhdl:
            return self.compile_vhdl_file_command(source_file)

        LOGGER.error("Unknown file type: %s", source_file.file_type)
        raise CompileError

    @staticmethod
    def _std_str(vhdl_standard):
        """
        Convert standard to format of GHDL command line flag
        """
        if vhdl_standard == "2002":
            return "02"

        if vhdl_standard == "2008":
            return "08"

        if vhdl_standard == "93":
            return "93"

        raise ValueError("Invalid VHDL standard %s" % vhdl_standard)

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a vhdl file
        """
        cmd = [join(self._prefix, 'ghdl'), '-a', '--workdir=%s' % source_file.library.directory,
               '--work=%s' % source_file.library.name,
               '--std=%s' % self._std_str(source_file.get_vhdl_standard())]
        for library in self._project.get_libraries():
            cmd += ["-P%s" % library.directory]
        cmd += source_file.compile_options.get("ghdl.flags", [])
        cmd += [source_file.name]
        return cmd

    def _get_sim_command(self, config, output_path):
        """
        Return GHDL simulation command
        """
        cmd = [join(self._prefix, 'ghdl')]
        cmd += ['--elab-run']
        cmd += ['--std=%s' % self._std_str(self._vhdl_standard)]
        cmd += ['--work=%s' % config.library_name]
        cmd += ['--workdir=%s' % self._project.get_library(config.library_name).directory]
        cmd += ['-P%s' % lib.directory for lib in self._project.get_libraries()]

        if self._has_output_flag():
            cmd += ['-o', join(output_path, "%s-%s" % (config.entity_name,
                                                       config.architecture_name))]
        cmd += config.sim_options.get("ghdl.elab_flags", [])
        cmd += [config.entity_name, config.architecture_name]
        cmd += config.sim_options.get("ghdl.sim_flags", [])

        for name, value in config.generics.items():
            cmd += ['-g%s=%s' % (name, value)]

        cmd += ['--assert-level=%s' % config.vhdl_assert_stop_level]

        if config.sim_options.get("disable_ieee_warnings", False):
            cmd += ["--ieee-asserts=disable"]
        return cmd

    def simulate(self,  # pylint: disable=too-many-locals
                 output_path,
                 test_suite_name,
                 config, elaborate_only):
        """
        Simulate with entity as top level using generics
        """

        script_path = join(output_path, self.name)

        if not exists(script_path):
            os.makedirs(script_path)

        cmd = self._get_sim_command(config, script_path)

        if elaborate_only:
            cmd += ["--no-run"]

        if self._gtkwave_fmt is not None:
            data_file_name = join(script_path, "wave.%s" % self._gtkwave_fmt)

            if exists(data_file_name):
                os.remove(data_file_name)

            if self._gtkwave_fmt == "ghw":
                cmd += ['--wave=%s' % data_file_name]
            elif self._gtkwave_fmt == "vcd":
                cmd += ['--vcd=%s' % data_file_name]

        else:
            data_file_name = None

        status = True
        try:
            proc = Process(cmd)
            proc.consume_output()
        except Process.NonZeroExitCode:
            status = False

        if self._gui and not elaborate_only:
            cmd = ["gtkwave"] + shlex.split(self._gtkwave_args) + [data_file_name]
            stdout.write("%s\n" % " ".join(cmd))
            subprocess.call(cmd)

        return status
