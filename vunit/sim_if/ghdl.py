# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for GHDL simulator
"""

from pathlib import Path
from os import environ, makedirs, remove
import logging
import subprocess
import shlex
import re
import shutil
from json import dump
from sys import stdout  # To avoid output catched in non-verbose mode
from warnings import warn
from ..exceptions import CompileError
from ..ostools import Process
from . import SimulatorInterface, ListOfStringOption, StringOption, BooleanOption
from ..vhdl_standard import VHDL

LOGGER = logging.getLogger(__name__)


class GHDLInterface(SimulatorInterface):  # pylint: disable=too-many-instance-attributes
    """
    Interface for GHDL simulator
    """

    name = "ghdl"
    executable = environ.get("GHDL", "ghdl")
    supports_gui_flag = True
    supports_colors_in_gui = True

    compile_options = [
        ListOfStringOption("ghdl.a_flags"),
        ListOfStringOption("ghdl.flags"),
    ]

    sim_options = [
        ListOfStringOption("ghdl.sim_flags"),
        ListOfStringOption("ghdl.elab_flags"),
        StringOption("ghdl.gtkwave_script.gui"),
        BooleanOption("ghdl.elab_e"),
    ]

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group("ghdl", description="GHDL specific flags")
        group.add_argument(
            "--gtkwave-fmt",
            choices=["vcd", "ghw"],
            default=None,
            help="Save .vcd or .ghw to open in gtkwave",
        )
        group.add_argument("--gtkwave-args", default="", help="Arguments to pass to gtkwave")

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
            gtkwave_fmt=args.gtkwave_fmt,
            gtkwave_args=args.gtkwave_args,
            backend=cls.determine_backend(prefix),
        )

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find first valid ghdl toolchain prefix
        """
        return cls.find_toolchain([cls.executable])

    def __init__(  # pylint: disable=too-many-arguments
        self,
        output_path,
        prefix,
        gui=False,
        gtkwave_fmt=None,
        gtkwave_args="",
        backend="llvm",
    ):
        SimulatorInterface.__init__(self, output_path, gui)
        self._prefix = prefix
        self._project = None

        if gui and (not self.find_executable("gtkwave")):
            raise RuntimeError("Cannot find the gtkwave executable in the PATH environment variable. GUI not possible")

        self._gui = gui
        self._gtkwave_fmt = "ghw" if gui and gtkwave_fmt is None else gtkwave_fmt
        self._gtkwave_args = gtkwave_args
        self._backend = backend
        self._vhdl_standard = None
        self._coverage_test_dirs = set()

    def has_valid_exit_code(self):
        """
        Return if the simulation should fail with nonzero exit codes
        """
        return self._vhdl_standard >= VHDL.STD_2008

    @classmethod
    def _get_version_output(cls, prefix):
        """
        Get the output of 'ghdl --version'
        """
        return subprocess.check_output([str(Path(prefix) / cls.executable), "--version"]).decode()

    @classmethod
    def determine_backend(cls, prefix):
        """
        Determine the GHDL backend
        """
        mapping = {
            r"mcode code generator": "mcode",
            r"llvm (\d+\.\d+\.\d+ )?code generator": "llvm",
            r"GCC back-end code generator": "gcc",
        }
        output = cls._get_version_output(prefix)
        for name, backend in mapping.items():
            match = re.search(name, output)
            if match:
                LOGGER.debug("Detected GHDL %s", match.group(0))
                return backend

        LOGGER.error("Could not detect known LLVM backend by parsing 'ghdl --version'")
        print(f"Expected to find one of {mapping.keys()!r}")
        print("== Output of 'ghdl --version'" + ("=" * 60))
        print(output)
        print("=============================" + ("=" * 60))
        raise AssertionError("No known GHDL back-end could be detected from running 'ghdl --version'")

    @classmethod
    def determine_version(cls, prefix):
        """
        Determine the GHDL version
        """
        return float(
            re.match(
                r"GHDL ([0-9]*\.[0-9]*).*\(.*\) \[Dunoon edition\]",
                cls._get_version_output(prefix),
            ).group(1)
        )

    @classmethod
    def supports_vhdl_package_generics(cls):
        """
        Returns True when this simulator supports VHDL package generics
        """
        return True

    @classmethod
    def supports_vhpi(cls):
        """
        Returns True when the simulator supports VHPI
        """
        return (cls.determine_backend(cls.find_prefix_from_path()) != "mcode") or (
            cls.determine_version(cls.find_prefix_from_path()) > 0.36
        )

    @classmethod
    def supports_coverage(cls):
        """
        Returns True when the simulator supports coverage
        """
        return cls.determine_backend(cls.find_prefix_from_path()) == "gcc"

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
            if not Path(library.directory).exists():
                makedirs(library.directory)

        vhdl_standards = set(
            source_file.get_vhdl_standard()
            for source_file in project.get_source_files_in_order()
            if source_file.is_vhdl
        )

        if not vhdl_standards:
            self._vhdl_standard = VHDL.STD_2008
        elif len(vhdl_standards) != 1:
            raise RuntimeError(f"GHDL cannot handle mixed VHDL standards, found {list(vhdl_standards)!r}")
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
        if vhdl_standard == VHDL.STD_2002:
            return "02"

        if vhdl_standard == VHDL.STD_2008:
            return "08"

        if vhdl_standard == VHDL.STD_1993:
            return "93"

        raise ValueError(f"Invalid VHDL standard {vhdl_standard!s}")

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a vhdl file
        """
        cmd = [
            str(Path(self._prefix) / self.executable),
            "-a",
            f"--workdir={source_file.library.directory!s}",
            f"--work={source_file.library.name!s}",
            f"--std={self._std_str(source_file.get_vhdl_standard())!s}",
        ]
        for library in self._project.get_libraries():
            cmd += [f"-P{library.directory!s}"]

        a_flags = source_file.compile_options.get("ghdl.a_flags", [])
        flags = source_file.compile_options.get("ghdl.flags", [])
        if flags != []:
            warn(
                ("'ghdl.flags' is deprecated and it will be removed in future releases; " "use 'ghdl.a_flags' instead"),
                Warning,
            )
            a_flags += flags

        cmd += a_flags

        if source_file.compile_options.get("enable_coverage", False):
            # Add gcc compilation flags for coverage
            #   -ftest-coverages creates .gcno notes files needed by gcov
            #   -fprofile-arcs creates branch profiling in .gcda database files
            cmd += ["-fprofile-arcs", "-ftest-coverage"]
        cmd += [source_file.name]
        return cmd

    def _get_command(self, config, output_path, elaborate_only, ghdl_e, wave_file):  # pylint: disable=too-many-branches
        """
        Return GHDL simulation command
        """
        cmd = [str(Path(self._prefix) / self.executable)]

        cmd += ["-e"] if ghdl_e else ["--elab-run"]

        cmd += [f"--std={self._std_str(self._vhdl_standard)!s}"]
        cmd += [f"--work={config.library_name!s}"]
        cmd += [f"--workdir={self._project.get_library(config.library_name).directory!s}"]
        cmd += [f"-P{lib.directory!s}" for lib in self._project.get_libraries()]

        bin_path = str(Path(output_path) / f"{config.entity_name!s}-{config.architecture_name!s}")
        if self._has_output_flag():
            cmd += ["-o", bin_path]
        cmd += config.sim_options.get("ghdl.elab_flags", [])
        if config.sim_options.get("enable_coverage", False):
            # Enable coverage in linker
            cmd += ["-Wl,-lgcov"]
        cmd += [config.entity_name, config.architecture_name]

        sim = config.sim_options.get("ghdl.sim_flags", [])
        for name, value in config.generics.items():
            sim += [f"-g{name!s}={value!s}"]
        sim += [f"--assert-level={config.vhdl_assert_stop_level!s}"]
        if config.sim_options.get("disable_ieee_warnings", False):
            sim += ["--ieee-asserts=disable"]

        if wave_file:
            if self._gtkwave_fmt == "ghw":
                sim += [f"--wave={wave_file!s}"]
            elif self._gtkwave_fmt == "vcd":
                sim += [f"--vcd={wave_file!s}"]

        if not ghdl_e:
            cmd += sim
            if elaborate_only:
                cmd += ["--no-run"]
        else:
            try:
                makedirs(output_path, mode=0o777)
            except OSError:
                pass
            with (Path(output_path) / "args.json").open("w", encoding="utf-8") as fname:
                dump(
                    {
                        "bin": str(Path(output_path) / f"{config.entity_name!s}-{config.architecture_name!s}"),
                        "build": cmd[1:],
                        "sim": sim,
                    },
                    fname,
                )

        return cmd

    def simulate(self, output_path, test_suite_name, config, elaborate_only):  # pylint: disable=too-many-locals
        """
        Simulate with entity as top level using generics
        """

        script_path = str(Path(output_path) / self.name)

        if not Path(script_path).exists():
            makedirs(script_path)

        ghdl_e = elaborate_only and config.sim_options.get("ghdl.elab_e", False)

        if self._gtkwave_fmt is not None:
            data_file_name = str(Path(script_path) / f"wave.{self._gtkwave_fmt!s}")
            if Path(data_file_name).exists():
                remove(data_file_name)
        else:
            data_file_name = None

        cmd = self._get_command(config, script_path, elaborate_only, ghdl_e, data_file_name)

        status = True

        gcov_env = environ.copy()
        if config.sim_options.get("enable_coverage", False):
            # Set environment variable to put the coverage output in the test_output folder
            coverage_dir = str(Path(output_path) / "coverage")
            gcov_env["GCOV_PREFIX"] = coverage_dir
            self._coverage_test_dirs.add(coverage_dir)

        try:
            proc = Process(cmd, env=gcov_env)
            proc.consume_output()
        except Process.NonZeroExitCode:
            status = False

        if self._gui and not elaborate_only:
            cmd = ["gtkwave"] + shlex.split(self._gtkwave_args) + [data_file_name]

            init_file = config.sim_options.get(self.name + ".gtkwave_script.gui", None)
            if init_file is not None:
                cmd += ["--script", str(Path(init_file).resolve())]

            stdout.write(" ".join(cmd) + "\n")
            subprocess.call(cmd)

        return status

    def _compile_source_file(self, source_file, printer):
        """
        Runs parent command for compilation, and moves any .gcno files to the compilation output
        """
        compilation_ok = super()._compile_source_file(source_file, printer)

        if source_file.compile_options.get("enable_coverage", False):
            # GCOV gcno files are output to where the command is run,
            # move it back to the compilation folder
            source_path = Path(source_file.name)
            gcno_file = Path(source_path.stem + ".gcno")
            if Path(gcno_file).exists():
                new_path = Path(source_file.library.directory) / gcno_file
                gcno_file.rename(new_path)

        return compilation_ok

    def merge_coverage(self, file_name, args=None):
        """
        Merge coverage from all test cases
        """
        output_dir = file_name

        # Loop over each .gcda output folder and merge them two at a time
        first_input = True
        for coverage_dir in self._coverage_test_dirs:
            if Path(coverage_dir).exists():
                merge_command = [
                    "gcov-tool",
                    "merge",
                    "-o",
                    output_dir,
                    coverage_dir if first_input else output_dir,
                    coverage_dir,
                ]
                subprocess.call(merge_command)
                first_input = False
            else:
                LOGGER.warning("Missing coverage directory: %s", coverage_dir)

        # Find actual output path of the .gcda files (they are deep in hierarchy)
        dir_path = Path(output_dir)
        gcda_dirs = {x.parent for x in dir_path.glob("**/*.gcda")}
        assert len(gcda_dirs) == 1, "Expected exactly one folder with gcda files"
        gcda_dir = gcda_dirs.pop()

        # Add compile-time .gcno files as well, they are needed for the report
        for library in self._project.get_libraries():
            for gcno_file in Path(library.directory).glob("*.gcno"):
                shutil.copy(gcno_file, gcda_dir)
