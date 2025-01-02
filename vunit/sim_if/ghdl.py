# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

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
from ..exceptions import CompileError
from ..ostools import Process
from . import SimulatorInterface, ListOfStringOption, StringOption, BooleanOption
from ..vhdl_standard import VHDL
from ._viewermixin import ViewerMixin

LOGGER = logging.getLogger(__name__)


class GHDLInterface(SimulatorInterface, ViewerMixin):  # pylint: disable=too-many-instance-attributes
    """
    Interface for GHDL simulator
    """

    name = "ghdl"
    executable = environ.get("GHDL", "ghdl")
    supports_gui_flag = True
    supports_colors_in_gui = True

    compile_options = [
        ListOfStringOption("ghdl.a_flags"),
        ListOfStringOption("ghdl.flags"),  # Removed in v5.0.0
    ]

    sim_options = [
        ListOfStringOption("ghdl.sim_flags"),
        ListOfStringOption("ghdl.elab_flags"),
        StringOption("ghdl.gtkwave_script.gui"),  # Deprecated in v5.1.0
        StringOption("ghdl.viewer_script.gui"),
        StringOption("ghdl.viewer.gui"),
        BooleanOption("ghdl.elab_e"),
    ]

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group("ghdl/nvc", description="GHDL/NVC specific flags")
        group.add_argument(
            "--viewer-fmt",
            "--gtkwave-fmt",
            choices=["vcd", "fst", "ghw"],
            default=None,
            help="Save .vcd, .fst, or .ghw to open in waveform viewer. NVC does not support ghw.",
        )
        group.add_argument("--viewer-args", "--gtkwave-args", default="", help="Arguments to pass to waveform viewer")
        group.add_argument("--viewer", default=None, help="Waveform viewer to use")

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
            viewer_fmt=args.viewer_fmt,
            viewer_args=args.viewer_args,
            viewer=args.viewer,
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
        *,
        gui=False,
        viewer_fmt=None,
        viewer_args="",
        viewer=None,
        backend="llvm",
    ):
        SimulatorInterface.__init__(self, output_path, gui)
        ViewerMixin.__init__(
            self,
            gui=gui,
            viewer=viewer,
            viewer_fmt="ghw" if gui and viewer_fmt is None else viewer_fmt,
            viewer_args=viewer_args,
        )

        self._prefix = prefix
        self._project = None

        self._backend = backend
        self._vhdl_standard = None
        self._coverage_test_dirs = set()  # For gcov
        self._coverage_files = set()  # For --coverage

    def has_valid_exit_code(self):  # pylint: disable=arguments-differ
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
    def _get_help_output(cls, prefix):
        """
        Get the output of 'ghdl --help'
        """
        return subprocess.check_output([str(Path(prefix) / cls.executable), "--help"]).decode()

    @classmethod
    def determine_coverage(cls, prefix):
        """
        Determine if GHDL has builtin coverage support
        """
        return not re.match(r"coverage ", cls._get_help_output(prefix)) is None

    @classmethod
    def determine_backend(cls, prefix):
        """
        Determine the GHDL backend
        """
        mapping = {
            r"mcode (JIT )?code generator": "mcode",
            r"llvm (\d+\.\d+\.\d+ )?code generator": "llvm",
            r"GCC (back-end|\d+\.\d+\.\d+) code generator": "gcc",
        }
        output = cls._get_version_output(prefix)
        for name, backend in mapping.items():
            match = re.search(name, output)
            if match:
                LOGGER.debug("Detected GHDL %s", match.group(0))
                return backend

        LOGGER.error("Could not detect known backend by parsing 'ghdl --version'")
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
        prefix = cls.find_prefix_from_path()
        return cls.determine_backend(prefix) == "gcc" or cls.determine_coverage(prefix)

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
        if source_file.compile_options.get("ghdl.flags", []) != []:
            raise RuntimeError("'ghdl.flags was removed in v5.0.0; use 'ghdl.a_flags' instead")

        cmd = [
            str(Path(self._prefix) / self.executable),
            "-a",
            f"--workdir={source_file.library.directory!s}",
            f"--work={source_file.library.name!s}",
            f"--std={self._std_str(source_file.get_vhdl_standard())!s}",
        ]
        for library in self._project.get_libraries():
            cmd += [f"-P{library.directory!s}"]

        cmd += source_file.compile_options.get("ghdl.a_flags", [])

        if source_file.compile_options.get("enable_coverage", False) and self._backend == "gcc":
            # Add gcc compilation flags for coverage
            #   -ftest-coverages creates .gcno notes files needed by gcov
            #   -fprofile-arcs creates branch profiling in .gcda database files
            cmd += ["-fprofile-arcs", "-ftest-coverage"]
        cmd += [source_file.name]
        return cmd

    def _get_command(
        self, config, output_path, elaborate_only, ghdl_e, test_suite_name, wave_file
    ):  # pylint: disable=too-many-branches,too-many-arguments,too-many-positional-arguments
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
            if self._backend == "gcc":
                # Enable coverage in linker
                cmd += ["-Wl,-lgcov"]
            else:
                coverage_file = str(Path(output_path) / f"{test_suite_name!s}.json")
                cmd += ["--coverage", f"--coverage-output={coverage_file!s}"]

        if config.vhdl_configuration_name is not None:
            cmd += [config.vhdl_configuration_name]
        else:
            cmd += [config.entity_name, config.architecture_name]

        sim = config.sim_options.get("ghdl.sim_flags", [])
        for name, value in config.generics.items():
            sim += [f"-g{name!s}={value!s}"]
        sim += [f"--assert-level={config.vhdl_assert_stop_level!s}"]
        if config.sim_options.get("disable_ieee_warnings", False):
            sim += ["--ieee-asserts=disable"]

        if wave_file:
            if self._viewer_fmt == "ghw":
                sim += [f"--wave={wave_file!s}"]
            elif self._viewer_fmt == "vcd":
                sim += [f"--vcd={wave_file!s}"]
            elif self._viewer_fmt == "fst":
                sim += [f"--fst={wave_file!s}"]

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

        if self._viewer_fmt is not None:
            data_file_name = str(Path(script_path) / f"wave.{self._viewer_fmt!s}")
            if Path(data_file_name).exists():
                remove(data_file_name)
        else:
            data_file_name = None

        cmd = self._get_command(config, script_path, elaborate_only, ghdl_e, test_suite_name, data_file_name)

        status = True

        gcov_env = environ.copy()
        if config.sim_options.get("enable_coverage", False):
            if self._backend == "gcc":
                # Set environment variable to put the coverage output in the test_output folder
                coverage_dir = str(Path(output_path) / "coverage")
                gcov_env["GCOV_PREFIX"] = coverage_dir
                self._coverage_test_dirs.add(coverage_dir)
            else:
                self._coverage_files.add(str(Path(script_path) / f"{test_suite_name!s}.json"))

        try:
            proc = Process(cmd, env=gcov_env)
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
            cmd = [self._get_viewer(config)] + shlex.split(self._viewer_args) + [data_file_name]

            init_file = config.sim_options.get(
                self.name + ".viewer_script.gui", config.sim_options.get(self.name + ".gtkwave_script.gui", None)
            )
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
            if self._backend == "gcc":
                # GCOV gcno files are output to where the command is run,
                # move it back to the compilation folder
                source_path = Path(source_file.name)
                gcno_file = Path(source_path.stem + ".gcno")
                if Path(gcno_file).exists():
                    new_path = Path(source_file.library.directory) / gcno_file
                    gcno_file.rename(new_path)

        return compilation_ok

    def _merge_coverage_gcc(self, output_dir, args=None):
        """
        Merge coverage (for gcc backend)
        """
        # Loop over each .gcda output folder and merge them two at a time
        first_input = True
        for coverage_dir in self._coverage_test_dirs:
            if Path(coverage_dir).exists():
                merge_command = [
                    "gcov-tool",
                    "merge",
                    "-o",
                    str(output_dir),
                    coverage_dir if first_input else str(output_dir),
                    coverage_dir,
                ]
                subprocess.call(merge_command)
                first_input = False
            else:
                LOGGER.warning("Missing coverage directory: %s", coverage_dir)

        # Find actual output path of the .gcda files (they are deep in hierarchy)
        gcda_dirs = {x.parent for x in output_dir.glob("**/*.gcda")}
        assert len(gcda_dirs) == 1, "Expected exactly one folder with gcda files"
        gcda_dir = gcda_dirs.pop()

        # Add compile-time .gcno files as well, they are needed for the report
        for library in self._project.get_libraries():
            for gcno_file in Path(library.directory).glob("*.gcno"):
                shutil.copy(gcno_file, gcda_dir)

    def _merge_coverage_jit(self, output_dir, args=None):
        """
        Merge coverage (for jit backend)
        """
        cmd = [
            str(Path(self._prefix) / self.executable),
            "coverage",
            "--format=gcovr",
            "-o",
            str(output_dir / "gcovr.json"),
        ]
        cmd.extend(list(self._coverage_files))
        subprocess.call(cmd)

    def merge_coverage(self, file_name, args=None):
        """
        Merge coverage from all test cases
        """
        output_dir = Path(file_name)
        output_dir.mkdir(parents=True, exist_ok=True)
        if self._backend == "gcc":
            self._merge_coverage_gcc(output_dir, args)
        else:
            self._merge_coverage_jit(output_dir, args)
