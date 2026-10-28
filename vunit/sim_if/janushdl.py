# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for the JanusHDL simulator
"""

from pathlib import Path
from os import environ, makedirs
import logging
import subprocess
import sys
from ..exceptions import CompileError
from ..ostools import Process, write_file
from ..color_printer import NO_COLOR_PRINTER
from . import SimulatorInterface, ListOfStringOption
from . import check_executable, check_output
from ..vhdl_standard import VHDL

LOGGER = logging.getLogger(__name__)


class JanusHDLInterface(SimulatorInterface):  # pylint: disable=abstract-method
    """
    Interface for the JanusHDL simulator

    JanusHDL keeps no libraries on disk: all files are analyzed in one call into
    an analysis cache, which every simulation then loads.
    """

    name = "janushdl"
    executable = environ.get("JHDL", "jhdl")
    supports_gui_flag = True

    compile_options = [
        ListOfStringOption("janushdl.a_flags"),
    ]

    sim_options = [
        ListOfStringOption("janushdl.sim_flags"),
    ]

    @classmethod
    def from_args(cls, args, output_path, **kwargs):
        """
        Create instance from args namespace
        """
        if args.elaborate:
            raise RuntimeError("JanusHDL cannot elaborate without running, so --elaborate is not supported")
        prefix = cls.find_prefix()
        check_executable("JanusHDL", prefix, cls.executable)
        return cls(output_path=output_path, prefix=prefix, gui=args.gui)

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find first valid JanusHDL toolchain prefix
        """
        return cls.find_toolchain([cls.executable])

    def __init__(self, output_path, prefix, gui=False):
        SimulatorInterface.__init__(self, output_path, gui)
        self._prefix = prefix
        self._project = None
        self._vhdl_standard = None
        self._a_flags = []
        self._work_path = Path(output_path)
        self._file_list = self._work_path / "files.f"
        self._cache = self._work_path / "analysis.jcache"

    def has_valid_exit_code(self):  # pylint: disable=arguments-differ
        """
        Return if the simulation should fail with nonzero exit codes
        """
        return self._vhdl_standard >= VHDL.STD_2008

    def setup_library_mapping(self, project):
        """
        Check the project fits a single JanusHDL analysis and write its file list
        """
        self._project = project

        external = sorted(library.name for library in project.get_libraries() if library.is_external)
        if external:
            raise RuntimeError(
                f"JanusHDL cannot use external libraries {external!r}: it keeps no libraries on disk. "
                "Add their sources with add_library() instead."
            )

        source_files = project.get_files_in_compile_order(incremental=False)
        not_vhdl = [source_file.name for source_file in source_files if not source_file.is_vhdl]
        if not_vhdl:
            raise RuntimeError(f"JanusHDL only supports VHDL, found {not_vhdl!r}")

        vhdl_standards = set(source_file.get_vhdl_standard() for source_file in source_files)
        if len(vhdl_standards) > 1:
            raise RuntimeError(f"JanusHDL cannot handle mixed VHDL standards, found {vhdl_standards!r}")
        self._vhdl_standard = vhdl_standards.pop() if vhdl_standards else VHDL.STD_2008

        # The simulations must pass the same analysis flags, or they analyze again into the shared cache
        a_flags = set(tuple(source_file.compile_options.get("janushdl.a_flags", [])) for source_file in source_files)
        if len(a_flags) > 1:
            raise RuntimeError(
                f"JanusHDL analyzes all files in one call, so janushdl.a_flags must be the same for all files, "
                f"found {sorted(a_flags)!r}"
            )
        self._a_flags = list(a_flags.pop()) if a_flags else []

        lines = []
        library_name = None
        for source_file in source_files:
            if source_file.library.name != library_name:
                library_name = source_file.library.name
                lines.append(f"library {library_name}")
            lines.append(str(Path(source_file.name).resolve()))
        makedirs(self._work_path, exist_ok=True)
        write_file(str(self._file_list), "\n".join(lines) + "\n")

    def _analysis_command(self):
        """
        The command line part that loads the analysis, shared by compile and simulate
        """
        return [
            str(Path(self._prefix) / self.executable),
            "-f",
            str(self._file_list),
            "--cache",
            str(self._cache),
            "--std",
            str(self._vhdl_standard)[-2:],
        ] + self._a_flags

    def compile_source_files(self, project, printer=NO_COLOR_PRINTER, continue_on_error=False, target_files=None):
        """
        Analyze the whole project in one call into the analysis cache
        """
        if target_files is None:
            source_files = project.get_files_in_compile_order()
        else:
            source_files = project.get_minimal_file_set_in_compile_order(target_files)

        # Always run: jhdl reloads a fresh cache in milliseconds and alone knows whether it is stale
        command = self._analysis_command() + ["--analyze-only"]
        printer.write(f"Compiling {len(source_files)} changed files with JanusHDL\n")
        sys.stdout.flush()
        try:
            printer.write(check_output(command, env=self.get_env()))
        except subprocess.CalledProcessError as err:
            printer.write(f"=== Command used: ===\n{subprocess.list2cmdline(command)!s}\n\n")
            printer.write(f"=== Command output: ===\n{err.output!s}\n")
            printer.write("Compile failed\n", fg="ri")
            if continue_on_error:
                return
            raise CompileError from err

        for source_file in source_files:
            project.update(source_file)
        printer.write("Compile passed\n", fg="gi")

    def simulate(self, output_path, test_suite_name, config, elaborate_only):  # pylint: disable=unused-argument
        """
        Simulate with entity as top level using generics
        """
        # VUnit allows one architecture per test bench, which is the one JanusHDL binds
        top = config.vhdl_configuration_name or config.entity_name
        cmd = self._analysis_command() + ["--top", f"{config.library_name}.{top}"]
        for name, value in config.generics.items():
            cmd += [f"-g{name}={value}"]

        level = config.vhdl_assert_stop_level
        cmd += ["--stop-level", level, "--exit-level", level]
        if config.sim_options.get("disable_ieee_warnings", False):
            cmd += ["--ieee-warnings", "off"]

        wave_file = Path(output_path) / self.name / f"{config.entity_name}.jhw"
        if self._gui:
            makedirs(wave_file.parent, exist_ok=True)
            cmd += ["--wave", str(wave_file)]

        cmd += config.sim_options.get("janushdl.sim_flags", [])

        print(subprocess.list2cmdline(cmd))
        status = True
        try:
            proc = Process(cmd, env=self.get_env())
            proc.consume_output()
        except Process.NonZeroExitCode:
            status = False

        if self._gui:
            subprocess.call([str(Path(self._prefix) / "jhdlw"), str(wave_file)])

        return status
