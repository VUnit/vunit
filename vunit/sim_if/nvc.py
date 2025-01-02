# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for NVC simulator
"""

from multiprocessing import cpu_count
from pathlib import Path
from os import environ, makedirs, remove
import logging
import subprocess
import shlex
import re
from sys import stdout  # To avoid output catched in non-verbose mode
from ..exceptions import CompileError
from ..ostools import Process
from . import SimulatorInterface, ListOfStringOption, StringOption
from . import run_command
from ._viewermixin import ViewerMixin
from ..vhdl_standard import VHDL

LOGGER = logging.getLogger(__name__)


class NVCInterface(SimulatorInterface, ViewerMixin):  # pylint: disable=too-many-instance-attributes
    """
    Interface for NVC simulator
    """

    name = "nvc"
    executable = environ.get("NVC", "nvc")
    supports_gui_flag = True
    supports_colors_in_gui = True

    compile_options = [
        ListOfStringOption("nvc.global_flags"),
        ListOfStringOption("nvc.a_flags"),
    ]

    sim_options = [
        ListOfStringOption("nvc.global_flags"),
        ListOfStringOption("nvc.sim_flags"),
        ListOfStringOption("nvc.elab_flags"),
        StringOption("nvc.heap_size"),
        StringOption("nvc.viewer_script.gui"),
        StringOption("nvc.viewer.gui"),
    ]

    @classmethod
    def from_args(cls, args, output_path, **kwargs):
        """
        Create instance from args namespace
        """
        prefix = cls.find_prefix()
        return cls(
            output_path=output_path,
            prefix=prefix,
            gui=args.gui,
            num_threads=args.num_threads,
            viewer_fmt=args.viewer_fmt,
            viewer_args=args.viewer_args,
            viewer=args.viewer,
        )

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find first valid NVC toolchain prefix
        """
        return cls.find_toolchain([cls.executable])

    def __init__(  # pylint: disable=too-many-arguments
        self, output_path, prefix, *, num_threads, gui=False, viewer_fmt=None, viewer_args="", viewer=None
    ):
        SimulatorInterface.__init__(self, output_path, gui)
        if viewer_fmt == "ghw":
            LOGGER.warning("NVC does not support ghw, defaulting to fst")
            viewer_fmt = None  # Defaults to FST later
        ViewerMixin.__init__(self, gui=gui, viewer=viewer, viewer_fmt=viewer_fmt, viewer_args=viewer_args)

        self._prefix = prefix
        self._project = None

        self._vhdl_standard = None
        self._coverage_test_dirs = set()
        (major, minor) = self.determine_version(prefix)
        self._supports_jit = major > 1 or (major == 1 and minor >= 9)

        if self.use_color:
            environ["NVC_COLORS"] = "always"

        # Allow NVC to scale its worker thread count based on the number
        # of VUnit threads and the number of available CPUs.
        environ["NVC_CONCURRENT_JOBS"] = str(num_threads or cpu_count())

    def has_valid_exit_code(self):  # pylint: disable=arguments-differ
        """
        Return if the simulation should fail with nonzero exit codes
        """
        return self._vhdl_standard >= VHDL.STD_2008

    @classmethod
    def _get_version_output(cls, prefix):
        """
        Get the output of 'nvc --version'
        """
        return subprocess.check_output([str(Path(prefix) / cls.executable), "--version"]).decode()

    @classmethod
    def determine_version(cls, prefix):
        """
        Determine the NVC version
        """
        raw = cls._get_version_output(prefix)
        match = re.match(r"nvc ([0-9]+)\.([0-9]+).*", raw)
        if not match:
            raise RuntimeError(f"Cannot determine NVC version: {raw}")

        return (int(match.group(1)), int(match.group(2)))

    @classmethod
    def supports_vhpi(cls):
        """
        Returns True when the simulator supports VHPI
        """
        return True

    @classmethod
    def supports_coverage(cls):
        """
        Returns True when the simulator supports coverage
        """
        return False

    @classmethod
    def supports_vhdl_call_paths(cls):
        """
        Returns True when this simulator supports VHDL-2019 call paths
        """
        return True

    @classmethod
    def supports_vhdl_package_generics(cls):
        """
        Returns True when this simulator supports VHDL package generics
        """
        return True

    def setup_library_mapping(self, project):
        """
        Setup library mapping
        """
        self._project = project

        for library in project.get_libraries():
            path = Path(library.directory)
            if not path.exists():
                if not path.parent.exists():
                    makedirs(path.parent)

                if not run_command(
                    [str(Path(self._prefix) / self.executable), "--work=" + library.directory, "--init"],
                    env=self.get_env(),
                ):
                    raise RuntimeError("Failed to initialise library " + library.directory)

        vhdl_standards = set(
            source_file.get_vhdl_standard()
            for source_file in project.get_source_files_in_order()
            if source_file.is_vhdl
        )

        if not vhdl_standards:
            self._vhdl_standard = VHDL.STD_2008
        elif len(vhdl_standards) != 1:
            raise RuntimeError(f"NVC cannot handle mixed VHDL standards, found {vhdl_standards!r}")
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
        Convert standard to format of NVC command line flag
        """
        if vhdl_standard == VHDL.STD_1993:
            return "1993"

        if vhdl_standard == VHDL.STD_2002:
            return "2002"

        if vhdl_standard == VHDL.STD_2008:
            return "2008"

        if vhdl_standard == VHDL.STD_2019:
            return "2019"

        raise ValueError(f"Invalid VHDL standard {vhdl_standard}")

    def _get_command(self, std, worklib, workpath):
        """
        Get basic NVC command with global options
        """
        cmd = [
            str(Path(self._prefix) / self.executable),
            f"--work={worklib}:{workpath!s}",
            f"--std={self._std_str(std)}",
        ]

        for library in self._project.get_libraries():
            cmd += [f"--map={library.name}:{library.directory}"]

        return cmd

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a VHDL file
        """
        cmd = self._get_command(
            source_file.get_vhdl_standard(), source_file.library.name, source_file.library.directory
        )

        cmd += source_file.compile_options.get("nvc.global_flags", [])

        cmd += ["-a"]
        cmd += source_file.compile_options.get("nvc.a_flags", [])

        cmd += [source_file.name]
        return cmd

    def simulate(
        self, output_path, test_suite_name, config, elaborate_only
    ):  # pylint: disable=too-many-branches, disable=too-many-statements
        """
        Simulate with entity as top level using generics
        """

        script_path = Path(output_path) / self.name

        if not script_path.exists():
            makedirs(script_path)

        libdir = self._project.get_library(config.library_name).directory
        cmd = self._get_command(self._vhdl_standard, config.library_name, libdir)

        if self._gui:
            wave_file = script_path / (f"{config.entity_name}.{self._viewer_fmt or 'fst'}")
            if wave_file.exists():
                remove(wave_file)
        else:
            wave_file = None

        cmd += ["-H", config.sim_options.get("nvc.heap_size", "64m")]
        cmd += config.sim_options.get("nvc.global_flags", [])

        cmd += ["-e"]

        cmd += config.sim_options.get("nvc.elab_flags", [])
        if config.vhdl_configuration_name is not None:
            cmd += [config.vhdl_configuration_name]
        else:
            cmd += [f"{config.entity_name}-{config.architecture_name}"]

        for name, value in config.generics.items():
            cmd += [f"-g{name}={value}"]

        if not elaborate_only:
            cmd += ["--no-save"]
            if self._supports_jit:
                cmd += ["--jit"]
            cmd += ["-r"]
            cmd += config.sim_options.get("nvc.sim_flags", [])
            cmd += [f"--exit-severity={config.vhdl_assert_stop_level}"]

            if config.sim_options.get("disable_ieee_warnings", False):
                cmd += ["--ieee-warnings=off"]

            if wave_file:
                cmd += [f"--wave={wave_file}"]

            if self._viewer_fmt:
                cmd += [f"--format={self._viewer_fmt}"]

        print(" ".join([f"'{word}'" if " " in word else word for word in cmd]))

        status = True

        try:
            proc = Process(cmd)
            proc.consume_output()
        except Process.NonZeroExitCode:
            status = False

        if config.sim_options.get(self.name + ".gtkwave_script.gui", None):
            LOGGER.warning(
                "%s.gtkwave_script.gui is deprecated and will be removed "
                "in a future version, use %s.viewer_script.gui instead",
                self.name,
                self.name,
            )

        if self._gui and not elaborate_only:
            cmd = [self._get_viewer(config)] + shlex.split(self._viewer_args) + [str(wave_file)]

            init_file = config.sim_options.get(
                self.name + ".viewer_script.gui", config.sim_options.get(self.name + ".gtkwave_script.gui", None)
            )
            if init_file is not None:
                cmd += ["--script", str(Path(init_file).resolve())]

            stdout.write(f'{" ".join(cmd)}\n')
            subprocess.call(cmd)

        return status
