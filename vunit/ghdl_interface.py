# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for GHDL simulator
"""

from __future__ import print_function
import logging
from os.path import exists, join
import os
import re
import subprocess
import shlex
from sys import stdout  # To avoid output catched in non-verbose mode
from vunit.ostools import Process
from vunit.simulator_interface import SimulatorInterface
from vunit.exceptions import CompileError
from vunit.color_printer import (NO_COLOR_PRINTER, COLOR_PRINTER)
LOGGER = logging.getLogger(__name__)

_COMPILE_MSG_MATCH = re.compile(
    r"^(?P<filename>.*):(?=\d)"
    r"(?P<line_number>\d+):"
    r"(?P<column_number>\d+):"
    r"((?P<is_warning>warning:)\s*|\s*).*").match


class GHDLInterface(SimulatorInterface):
    """
    Interface for GHDL simulator
    """

    name = "ghdl"

    compile_options = [
        "ghdl.flags",
    ]

    sim_options = [
        "ghdl.flags",
    ]

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group("ghdl",
                                          description="GHDL specific flags")
        group.add_argument("--gtkwave", choices=["vcd", "ghw"],
                           default=None,
                           help="Save .vcd or .ghw and open in gtkwave")
        group.add_argument("--gtkwave-args",
                           default="",
                           help="Arguments to pass to gtkwave")

    @staticmethod
    def _get_compilation_message_level(line):
        match = _COMPILE_MSG_MATCH(line)
        if not match:
            return
        elif match.groupdict()['is_warning']:
            return 'warning'
        else:
            return 'error'

    @staticmethod
    def get_vhdl_assertion_level(line):
        _re = re.compile(
            r"^[^:]+:(?P<line_num>\d+):"
            r"(?P<column>\d+):"
            r"(?P<time>[^:]+):"
            r"\((report|assertion) (?P<severity_level>\w+)\):.*").search
        match = _re(line)
        if not match:
            return

        return match.groupdict()['severity_level']

    @classmethod
    def from_args(cls,
                  output_path,  # pylint: disable=unused-argument
                  args):
        """
        Create instance from args namespace
        """
        prefix = cls.find_prefix()
        cls._printer = NO_COLOR_PRINTER if args.no_color else COLOR_PRINTER
        return cls(prefix=prefix,
                   gtkwave=args.gtkwave,
                   gtkwave_args=args.gtkwave_args,
                   backend=cls.determine_backend(prefix))

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find first valid ghdl toolchain prefix
        """
        return cls.find_toolchain(["ghdl"])

    def __init__(self, prefix, gtkwave=None, gtkwave_args="", backend="llvm"):
        self._prefix = prefix
        self._libraries = {}
        self._vhdl_standard = None

        if gtkwave is not None and len(self.find_executable('gtkwave')) == 0:
            raise RuntimeError("Cannot find the gtkwave executable in the PATH environment variable.")

        self._gtkwave = gtkwave
        self._gtkwave_args = gtkwave_args
        self._backend = backend

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
                LOGGER.info("Detected GHDL %s", name)
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

    def setup_library_mapping(self, project, vhdl_standard):
        """
        Setup library mapping
        """
        self._libraries = {}
        self._vhdl_standard = vhdl_standard
        for library in project.get_libraries():
            if not exists(library.directory):
                os.makedirs(library.directory)
            self._libraries[library.name] = library.directory

    def compile_source_file_command(self, source_file):
        """
        Returns the command to compile a single source_file
        """
        if source_file.file_type == 'vhdl':
            return self.compile_vhdl_file_command(source_file.name,
                                                  source_file.library.name,
                                                  source_file.library.directory,
                                                  source_file.compile_options)

        LOGGER.error("Unknown file type: %s", source_file.file_type)
        raise CompileError

    def _std_str(self):
        """
        Convert standard to format of GHDL command line flag
        """
        if self._vhdl_standard == "2002":
            return "02"
        elif self._vhdl_standard == "2008":
            return "08"
        elif self._vhdl_standard == "93":
            return "93"
        else:
            assert False

    def compile_vhdl_file_command(self,
                                  source_file_name,
                                  library_name,
                                  library_path,
                                  compile_options):
        """
        Returns the command to compile a vhdl file
        """
        cmd = [join(self._prefix, 'ghdl'), '-a', '--workdir=%s' % library_path,
               '--work=%s' % library_name,
               '--std=%s' % self._std_str()]
        for library_name, library_path in self._libraries.items():
            cmd += ["-P%s" % library_path]
        cmd += compile_options.get("ghdl.flags", [])
        cmd += [source_file_name]
        return cmd

    def simulate(self,  # pylint: disable=too-many-arguments, too-many-locals
                 output_path, library_name, entity_name, architecture_name, config, elaborate_only):
        """
        Simulate with entity as top level using generics
        """
        assert config.pli == []

        ghdl_output_path = join(output_path, self.name)
        data_file_name = join(ghdl_output_path, "wave.%s" % self._gtkwave)
        if not exists(ghdl_output_path):
            os.makedirs(ghdl_output_path)

        launch_gtkwave = self._gtkwave is not None and not elaborate_only

        status = True
        try:
            cmd = []
            cmd += ['--elab-run']
            cmd += ['--std=%s' % self._std_str()]
            cmd += ['--work=%s' % library_name]
            cmd += ['--workdir=%s' % self._libraries[library_name]]
            cmd += ['-P%s' % path for path in self._libraries.values()]

            if self._has_output_flag():
                cmd += ['-o', join(ghdl_output_path, "%s-%s" % (entity_name, architecture_name))]
            cmd += config.options.get("ghdl.flags", [])

            cmd += [entity_name, architecture_name]

            for name, value in config.generics.items():
                cmd += ['-g%s=%s' % (name, value)]

            cmd += ['--assert-level=%s' % ("warning" if config.fail_on_warning else "error")]

            if config.disable_ieee_warnings:
                cmd += ["--ieee-asserts=disable"]

            if elaborate_only:
                cmd += ["--no-run"]

            if launch_gtkwave:
                if exists(data_file_name):
                    os.remove(data_file_name)
                if self._gtkwave == "ghw":
                    cmd += ['--wave=%s' % data_file_name]
                elif self._gtkwave == "vcd":
                    cmd += ['--vcd=%s' % data_file_name]

            proc = Process([join(self._prefix, 'ghdl')] + cmd)
            proc.consume_output()
        except Process.NonZeroExitCode:
            status = False

        if launch_gtkwave:
            cmd = ["gtkwave"] + shlex.split(self._gtkwave_args) + [data_file_name]
            stdout.write("%s\n" % " ".join(cmd))
            subprocess.call(cmd)

        return status
