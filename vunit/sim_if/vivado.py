# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards Mentor Graphics Vivado
"""

from pathlib import Path
import os
import logging
import io
from configparser import RawConfigParser
from ..exceptions import CompileError
from ..ostools import Process, file_exists
from ..vhdl_standard import VHDL
from . import SimulatorInterface, run_command, ListOfStringOption, StringOption

LOGGER = logging.getLogger(__name__)


class VivadoInterface(
    SimulatorInterface
):  # pylint: disable=too-many-instance-attributes
    """
    Xilinx Vivado interface

    The interface supports both running each simulation in separate xsim processes or
    re-using the same xsim process to avoid startup-overhead (persistent=True)
    """

    name = "vivado"
    supports_gui_flag = True
    package_users_depend_on_bodies = False

    compile_options = [
        ListOfStringOption("vivado.vcom_flags"),
        ListOfStringOption("vivado.vlog_flags"),
    ]

    sim_options = [
        ListOfStringOption("vivado.xsim_flags"),
        ListOfStringOption("vivado.xsim_flags.gui"),
        ListOfStringOption("vivado.init_files.after_load"),
        ListOfStringOption("vivado.init_files.before_run"),
        StringOption("vivado.init_file.gui"),
    ]

    @classmethod
    def from_args(cls, args, output_path, **kwargs):
        """
        Create new instance from command line arguments object
        """
        persistent = not (args.unique_sim or args.gui)

        return cls(
            prefix=cls.find_prefix(),
            output_path=output_path,
            persistent=persistent,
            gui=args.gui,
        )

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find first valid Vivado toolchain prefix
        """
        return cls.find_toolchain(["xsim", "xelab", "xvhdl", "xvlog"])

    @classmethod
    def supports_vhdl_package_generics(cls):
        """
        Returns True when this simulator supports VHDL package generics
        """
        return True

    @staticmethod
    def supports_coverage():
        """
        Returns True when the simulator supports coverage
        """
        return False

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group(
            "Xilinx Vivado", description="Xilinx Vivado xsim-specific flags"
        )
        group.add_argument(
            "--foobar",
            default=None,
            help="The cds.lib file to use. If not given, VUnit maintains its own cds.lib file.",
        )

    def __init__(self, prefix, output_path, persistent=False, gui=False):
        SimulatorInterface.__init__(self, output_path, gui)
        self._libraries = []
        self._coverage_files = set()
        self._prefix = prefix
        assert not (persistent and gui)

    def compile_source_file_command(self, source_file):
        """
        Returns the command to compile a single source file
        """
        if source_file.is_vhdl:
            return self.compile_vhdl_file_command(source_file)

        if source_file.is_any_verilog:
            return self.compile_verilog_file_command(source_file)

        LOGGER.error("Unknown file type: %s", source_file.file_type)
        raise CompileError

    @staticmethod
    def _std_str(vhdl_standard):
        """
        Convert standard to format of Modelsim command line flag
        """
        if vhdl_standard <= VHDL.STD_2008:
            return "-%s" % vhdl_standard

        raise ValueError("Invalid VHDL standard %s" % vhdl_standard)

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a vhdl file
        """
        args = [
            str(Path(self._prefix) / "xvhdl"),
            "-log", str(Path(self.output_path) / f"{source_file.name}_xvhdl.log")
        ]
        args += source_file.compile_options.get("vivado.vcom_flags", [])
        args += [self._std_str(source_file.get_vhdl_standard())]
        args += ["-work", f"{source_file.library.name}={source_file.library.directory}"]
        args += [source_file.name]
        for library in self._libraries:
            args += ["-L", f"{library.name}={library.directory}"]
        return args

    def compile_verilog_file_command(self, source_file):
        """
        Returns the command to compile a verilog file
        """
        args = [
            str(Path(self._prefix) / "xvlog"),
            "-log", str(Path(self.output_path) / f"{source_file.name}_xvlog.log")
        ]
        if source_file.is_system_verilog:
            args += ["-sv"]
        args += source_file.compile_options.get("vivado.vlog_flags", [])
        args += ["-work", source_file.library.name, source_file.name]

        for library in self._libraries:
            args += ["-L", f"{library.name}={library.directory}"]
        for include_dir in source_file.include_dirs:
            args += ["-i", include_dir]
        for key, value in source_file.defines.items():
            args += ["-d %s=%s" % (key, value)]

        return args

    def setup_library_mapping(self, project):
        """
        Setup library mapping
        """
        for library in project.get_libraries():
            self._libraries.append(library)

    def simulate(self, output_path, test_suite_name, config, elaborate_only):
        """
        Simulate
        """
        launch_gui = self._gui is not False and not elaborate_only

        cmd = str(Path(self._prefix) / "xelab")

        args = []
        args += ['-log', str(Path(output_path) / "xelab.log")]
        
        args += self._generic_args(config.generics)
        for library in self._libraries:
            args += ['-L', f"{library.name}={library.directory}"]
        args += ['-debug']
        if launch_gui:
            args += ['typical']
        else:
            args += ['off']
        
        if not elaborate_only and not launch_gui:
            args += ["-R"]
            args += ["-a"]

        # We do not support architectures in Vivado
        args += ["%s.%s" % (config.library_name, config.entity_name)]

        # Run elaboration and optional simulation
        if not run_command(
            [cmd] + args,
            cwd=str(Path(self.output_path)),
            env=self.get_env(),
        ):
            return False

        # Run simulation in GUI mode
        if not elaborate_only and launch_gui:
            cmd = str(Path(self._prefix) / "xsim")
            args = []
            args += ['-gui']
            args += ['-wdb', f"{config.library_name}.{config.entity_name}.{test_suite_name}.wdb"]
            args += ["%s.%s" % (config.library_name, config.entity_name)]
          
            # Run simulation with GUI
            if not run_command(
                [cmd] + args,
                cwd=str(Path(self.output_path)),
                env=self.get_env(),
            ):
                return False

    @staticmethod
    def _generic_args(generics):
        """
        Create xelab arguments for generics/parameters
        """
        args = []
        for name, value in generics.items():
            if _generic_needs_quoting(value):
                args += ['-generic_top', '%s="%s"' % (name, value)]
            else:
                args += ['-generic_top', '%s=%s' % (name, value)]
        return args

    def _xsim_extra_args(self, config):
        """
        Determine xsim_extra_args
        """
        xsim_extra_args = []
        xsim_extra_args = config.sim_options.get("vivado.xsim_flags", xsim_extra_args)

        if self._gui:
            xsim_extra_args = config.sim_options.get(
                "vivado.xsim_flags.gui", xsim_extra_args
            )

        return " ".join(xsim_extra_args)

def _generic_needs_quoting(value):  # pylint: disable=missing-docstring
    return isinstance(value, (str, bool))

def encode_generic_value(value):
    """
    Ensure values with space in them are quoted
    """
    s_value = str(value)
    if " " in s_value:
        return '{"%s"}' % s_value
    if "," in s_value:
        return '"%s"' % s_value
    return s_value

