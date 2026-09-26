# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for Vivado XSim simulator
"""

from __future__ import print_function
import logging
import os
from os.path import join
from pathlib import Path
import shutil
import threading
from shutil import copyfile
from ..ostools import Process
from . import SimulatorInterface, StringOption, BooleanOption, ListOfStringOption
from ..exceptions import CompileError

LOGGER = logging.getLogger(__name__)


class XSimInterface(SimulatorInterface):
    """
    Interface for Vivado xsim simulator
    """

    name = "xsim"
    executable = os.environ.get("XSIM", "xsim")

    package_users_depend_on_bodies = True
    supports_gui_flag = True

    sim_options = [
        StringOption("xsim.timescale"),
        BooleanOption("xsim.enable_glbl"),
        ListOfStringOption("xsim.xelab_flags"),
        ListOfStringOption("xsim.xsim_flags"),
    ]

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group("xsim", description="Xsim specific flags")
        group.add_argument(
            "--xsim-vcd-path",
            default="",
            help="VCD waveform output path.",
        )
        group.add_argument("--xsim-vcd-enable", action="store_true", help="Enable VCD waveform generation.")
        group.add_argument(
            "--xsim-xelab-limit", action="store_true", help="Limit the xelab current processes to 1 thread."
        )

    @classmethod
    def from_args(cls, args, output_path, **kwargs):
        """
        Create instance from args namespace
        """
        prefix = cls.find_prefix()

        return cls(
            prefix=prefix,
            output_path=output_path,
            gui=args.gui,
            vcd_path=args.xsim_vcd_path,
            vcd_enable=args.xsim_vcd_enable,
            xelab_limit=args.xsim_xelab_limit,
        )

    @classmethod
    def supports_vhdl_package_generics(cls):
        """
        Returns True when this simulator supports VHDL package generics
        """
        return True

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find first valid xsim toolchain prefix
        """
        return cls.find_toolchain(["xsim"])

    def check_tool(self, tool_name):
        """
        Checks to see if a tool exists, with extensions both gor Windows and Linux
        """
        if os.path.exists(os.path.join(self._prefix, tool_name + ".bat")):
            return tool_name + ".bat"
        if os.path.exists(os.path.join(self._prefix, tool_name)):
            return tool_name
        raise Exception(f"Cannot find {tool_name}")

    def __init__(self, prefix, output_path, gui=False, vcd_path="", vcd_enable=False, xelab_limit=False):
        super().__init__(output_path, gui)
        self._prefix = prefix
        self._libraries = {}
        self._xvlog = self.check_tool("xvlog")
        self._xvhdl = self.check_tool("xvhdl")
        self._xelab = self.check_tool("xelab")
        self._vivado = self.check_tool("vivado")
        self._xsim = self.check_tool("xsim")
        self._vcd_path = vcd_path
        self._vcd_enable = vcd_enable
        self._xelab_limit = xelab_limit
        self._lock = threading.Lock()

    def setup_library_mapping(self, project):
        """
        Setup library mapping
        """

        for library in project.get_libraries():
            self._libraries[library.name] = library.directory

    def compile_source_file_command(self, source_file):
        """
        Returns the command to compile a single source_file
        """
        if source_file.file_type == "vhdl":
            return self.compile_vhdl_file_command(source_file)
        if source_file.file_type == "verilog":
            cmd = [join(self._prefix, self._xvlog), source_file.name]
            return self.compile_verilog_file_command(source_file, cmd)
        if source_file.file_type == "systemverilog":
            cmd = [join(self._prefix, self._xvlog), "--sv", source_file.name]
            return self.compile_verilog_file_command(source_file, cmd)

        LOGGER.error("Unknown file type: %s", source_file.file_type)
        raise CompileError

    def libraries_command(self):
        """
        Adds libraries on the command line
        """
        cmd = []
        for library_name, library_path in self._libraries.items():
            if library_path:
                cmd += ["-L", f"{library_name}={library_path}"]
            else:
                cmd += ["-L", library_name]
        return cmd

    @staticmethod
    def work_library_argument(source_file):
        return ["-work", f"{source_file.library.name}={source_file.library.directory}"]

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a vhdl file
        """
        cmd = [join(self._prefix, self._xvhdl), source_file.name, "-2008"]
        cmd += self.work_library_argument(source_file)
        cmd += self.libraries_command()
        return cmd

    def compile_verilog_file_command(self, source_file, cmd):
        """
        Returns the command to compile a vhdl file
        """
        cmd += self.work_library_argument(source_file)
        cmd += self.libraries_command()
        for include_dir in source_file.include_dirs:
            cmd += ["--include", f"{include_dir}"]
        for define_name, define_val in source_file.defines.items():
            cmd += ["--define", f"{define_name}={define_val}"]
        return cmd

    @staticmethod
    def _xelab_extra_args(config):
        """
        Determine xelab_extra_args
        """
        xelab_extra_args = []
        xelab_extra_args = config.sim_options.get("xsim.xelab_flags", xelab_extra_args)

        return xelab_extra_args

    @staticmethod
    def _xsim_extra_args(config):
        """
        Determine xsim_extra_args
        """
        xsim_extra_args = []
        xsim_extra_args = config.sim_options.get("xsim.xsim_flags", xsim_extra_args)

        return xsim_extra_args

    def simulate(self, output_path, test_suite_name, config, elaborate_only):
        """
        Simulate with entity as top level using generics
        """
        runpy_dir = os.path.abspath(str(Path(output_path)) + "../../../../")

        if self._vcd_path == "":
            vcd_path = os.path.abspath(str(Path(output_path))) + "/wave.vcd"
        else:
            if os.path.isabs(self._vcd_path):
                vcd_path = self._vcd_path
            else:
                vcd_path = os.path.abspath(str(Path(runpy_dir))) + "/" + self._vcd_path

        cmd = [join(self._prefix, self._xelab)]
        cmd += ["-debug", "typical"]
        cmd += self.libraries_command()

        cmd += ["--notimingchecks"]
        cmd += ["--nospecify"]
        cmd += ["--nolog"]
        cmd += ["--relax"]
        cmd += ["--incr"]
        cmd += ["--sdfnowarn"]
        cmd += ["--stats"]
        cmd += ["--O2"]

        snapshot = "vunit_test"
        cmd += ["--snapshot", snapshot]

        enable_glbl = config.sim_options.get(self.name + ".enable_glbl", None)

        if enable_glbl == True:
            cmd += [f"{config.library_name}.test_verilog"]
        else:
            cmd += [f"{config.library_name}.{config.entity_name}"]

        if enable_glbl == True:
            cmd += [f"{config.library_name}.glbl"]

        timescale = config.sim_options.get(self.name + ".timescale", None)
        if timescale:
            cmd += ["-timescale", timescale]
        dirname = os.path.dirname(self._libraries[config.library_name])
        shutil.copytree(dirname, os.path.join(output_path, os.path.basename(dirname)))
        for generic_name, generic_value in config.generics.items():
            cmd += ["--generic_top", f"{generic_name}={generic_value}"]
        if not os.path.exists(output_path):
            os.makedirs(output_path)

        cmd += self._xelab_extra_args(config)

        status = True
        try:
            if self._xelab_limit is True:
                with self._lock:
                    proc = Process(cmd, cwd=output_path)
                    proc.consume_output()
            else:
                proc = Process(cmd, cwd=output_path)
                proc.consume_output()

        except Process.NonZeroExitCode:
            status = False

        try:
            # Execute XSIM
            if not elaborate_only:
                tcl_file = os.path.join(output_path, "xsim_startup.tcl")

                # Gui support
                if self._gui:
                    # XSIM binary
                    vivado_cmd = [join(self._prefix, self._xsim)]
                    # Snapshot
                    vivado_cmd += [snapshot]
                    # Mode GUI
                    vivado_cmd += ["--gui"]
                    # Include tcl
                    vivado_cmd += ["--tclbatch", tcl_file]
                # Command line
                else:
                    # XSIM binary
                    vivado_cmd = [join(self._prefix, self._xsim)]
                    # Snapshot
                    vivado_cmd += [snapshot]
                    # Include tcl
                    vivado_cmd += ["--tclbatch", tcl_file]

                vivado_cmd += self._xsim_extra_args(config)

                with open(tcl_file, "w+") as xsim_startup_file:
                    if os.path.exists(vcd_path):
                        os.remove(vcd_path)

                    if self._gui == True:
                        if self._vcd_enable:
                            xsim_startup_file.write(f"open_vcd {vcd_path}\n")
                            xsim_startup_file.write("log_vcd *\n")
                    else:
                        if self._vcd_enable:
                            xsim_startup_file.write(f"open_vcd {vcd_path}\n")
                            xsim_startup_file.write("log_vcd [get_objects -recursive]\n")
                        xsim_startup_file.write("run all\n")
                        xsim_startup_file.write("quit\n")

                print(" ".join(vivado_cmd))

                # subprocess.call(vivado_cmd, cwd=output_path, stderr=subprocess.STDOUT)
                proc = Process(vivado_cmd, cwd=output_path)
                proc.consume_output()

        except Process.NonZeroExitCode:
            status = False
        return status
