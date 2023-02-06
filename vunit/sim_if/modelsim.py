# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards Mentor Graphics ModelSim
"""

from pathlib import Path
import os
import logging
from configparser import RawConfigParser
from ..exceptions import CompileError
from ..ostools import Process, file_exists
from ..vhdl_standard import VHDL
from . import SimulatorInterface, ListOfStringOption, StringOption
from .vsim_simulator_mixin import VsimSimulatorMixin, fix_path

LOGGER = logging.getLogger(__name__)


class ModelSimInterface(VsimSimulatorMixin, SimulatorInterface):  # pylint: disable=too-many-instance-attributes
    """
    Mentor Graphics ModelSim interface

    The interface supports both running each simulation in separate vsim processes or
    re-using the same vsim process to avoid startup-overhead (persistent=True)
    """

    name = "modelsim"
    supports_gui_flag = True
    package_users_depend_on_bodies = False

    compile_options = [
        ListOfStringOption("modelsim.vcom_flags"),
        ListOfStringOption("modelsim.vlog_flags"),
    ]

    sim_options = [
        ListOfStringOption("modelsim.vsim_flags"),
        ListOfStringOption("modelsim.vsim_flags.gui"),
        ListOfStringOption("modelsim.init_files.after_load"),
        ListOfStringOption("modelsim.init_files.before_run"),
        StringOption("modelsim.init_file.gui"),
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
        Find first valid modelsim toolchain prefix
        """

        def has_modelsim_ini(path):
            return os.path.isfile(str(Path(path).parent / "modelsim.ini"))

        return cls.find_toolchain(["vsim"], constraints=[has_modelsim_ini])

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
        return True

    def __init__(self, prefix, output_path, persistent=False, gui=False):
        SimulatorInterface.__init__(self, output_path, gui)
        VsimSimulatorMixin.__init__(
            self,
            prefix,
            persistent,
            sim_cfg_file_name=str(Path(output_path) / "modelsim.ini"),
        )
        self._libraries = []
        self._coverage_files = set()
        assert not (persistent and gui)
        self._create_modelsim_ini()

    def _create_modelsim_ini(self):
        """
        Create the modelsim.ini file
        """
        parent = str(Path(self._sim_cfg_file_name).parent)
        if not file_exists(parent):
            os.makedirs(parent)

        original_modelsim_ini = os.environ.get("VUNIT_MODELSIM_INI", str(Path(self._prefix).parent / "modelsim.ini"))
        with Path(original_modelsim_ini).open("rb") as fread:
            with Path(self._sim_cfg_file_name).open("wb") as fwrite:
                fwrite.write(fread.read())

    def add_simulator_specific(self, project):
        """
        Add libraries from modelsim.ini file and add coverage flags
        """
        mapped_libraries = self._get_mapped_libraries()
        for library_name in mapped_libraries:
            if not project.has_library(library_name):
                project.add_builtin_library(library_name)

    def setup_library_mapping(self, project):
        """
        Setup library mapping
        """
        mapped_libraries = self._get_mapped_libraries()

        for library in project.get_libraries():
            self._libraries.append(library)
            self.create_library(library.name, library.directory, mapped_libraries)

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
            return f"-{vhdl_standard!s}"

        raise ValueError(f"Invalid VHDL standard {vhdl_standard!s}")

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a vhdl file
        """
        return (
            [
                str(Path(self._prefix) / "vcom"),
                "-quiet",
                "-modelsimini",
                self._sim_cfg_file_name,
            ]
            + source_file.compile_options.get("modelsim.vcom_flags", [])
            + [
                self._std_str(source_file.get_vhdl_standard()),
                "-work",
                source_file.library.name,
                source_file.name,
            ]
        )

    def compile_verilog_file_command(self, source_file):
        """
        Returns the command to compile a verilog file
        """
        args = [
            str(Path(self._prefix) / "vlog"),
            "-quiet",
            "-modelsimini",
            self._sim_cfg_file_name,
        ]
        if source_file.is_system_verilog:
            args += ["-sv"]
        args += source_file.compile_options.get("modelsim.vlog_flags", [])
        args += ["-work", source_file.library.name, source_file.name]

        for library in self._libraries:
            args += ["-L", library.name]
        for include_dir in source_file.include_dirs:
            args += [f"+incdir+{include_dir!s}"]
        for key, value in source_file.defines.items():
            args += [f"+define+{key!s}={value!s}"]
        return args

    def create_library(self, library_name, path, mapped_libraries=None):
        """
        Create and map a library_name to path
        """
        mapped_libraries = mapped_libraries if mapped_libraries is not None else {}

        apath = str(Path(path).parent.resolve())

        if not file_exists(apath):
            os.makedirs(apath)

        if not file_exists(path):
            proc = Process([str(Path(self._prefix) / "vlib"), "-unix", path], env=self.get_env())
            proc.consume_output(callback=None)

        if library_name in mapped_libraries and mapped_libraries[library_name] == path:
            return

        cfg = parse_modelsimini(self._sim_cfg_file_name)
        cfg.set("Library", library_name, path)
        write_modelsimini(cfg, self._sim_cfg_file_name)

    def _get_mapped_libraries(self):
        """
        Get mapped libraries from modelsim.ini file
        """
        cfg = parse_modelsimini(self._sim_cfg_file_name)
        libraries = dict(cfg.items("Library"))
        if "others" in libraries:
            del libraries["others"]
        return libraries

    def _create_load_function(self, test_suite_name, config, output_path):
        """
        Create the vunit_load TCL function that runs the vsim command and loads the design
        """

        set_generic_str = " ".join(
            (
                f"-g/{config.entity_name!s}/{name!s}={encode_generic_value(value)!s}"
                for name, value in config.generics.items()
            )
        )
        pli_str = " ".join(f"-pli {{{fix_path(name)!s}}}" for name in config.sim_options.get("pli", []))

        if config.architecture_name is None:
            architecture_suffix = ""
        else:
            architecture_suffix = f"({config.architecture_name!s})"

        if config.sim_options.get("enable_coverage", False):
            coverage_file = str(Path(output_path) / "coverage.ucdb")
            self._coverage_files.add(coverage_file)
            coverage_save_cmd = (
                f"coverage save -onexit -testname {{{test_suite_name!s}}} -assert -directive "
                f"-cvg -codeAll {{{fix_path(coverage_file)!s}}}"
            )
            coverage_args = "-coverage"
        else:
            coverage_save_cmd = ""
            coverage_args = ""

        vsim_flags = [
            f"-wlf {{{fix_path(str(Path(output_path) / 'vsim.wlf'))!s}}}",
            "-quiet",
            "-t ps",
            # for correct handling of verilog fatal/finish
            "-onfinish stop",
            pli_str,
            set_generic_str,
            config.library_name + "." + config.entity_name + architecture_suffix,
            coverage_args,
            self._vsim_extra_args(config),
        ]

        # There is a known bug in modelsim that prevents the -modelsimini flag from accepting
        # a space in the path even with escaping, see issue #36
        if " " not in self._sim_cfg_file_name:
            vsim_flags.insert(0, f"-modelsimini {fix_path(self._sim_cfg_file_name)!s}")

        for library in self._libraries:
            vsim_flags += ["-L", library.name]

        vhdl_assert_stop_level_mapping = {"warning": 1, "error": 2, "failure": 3}

        tcl = """
proc vunit_load {{{{vsim_extra_args ""}}}} {{
    set vsim_failed [catch {{
        eval vsim ${{vsim_extra_args}} {{{vsim_flags}}}
    }}]

    if {{${{vsim_failed}}}} {{
       echo Command 'vsim ${{vsim_extra_args}} {vsim_flags}' failed
       echo Bad flag from vsim_extra_args?
       return true
    }}

    if {{[_vunit_source_init_files_after_load]}} {{
        return true
    }}

    global BreakOnAssertion
    set BreakOnAssertion {break_on_assert}

    global NumericStdNoWarnings
    set NumericStdNoWarnings {no_warnings}

    global StdArithNoWarnings
    set StdArithNoWarnings {no_warnings}

    {coverage_save_cmd}
    return false
}}
""".format(
            coverage_save_cmd=coverage_save_cmd,
            vsim_flags=" ".join(vsim_flags),
            break_on_assert=vhdl_assert_stop_level_mapping[config.vhdl_assert_stop_level],
            no_warnings=1 if config.sim_options.get("disable_ieee_warnings", False) else 0,
        )

        return tcl

    @staticmethod
    def _create_run_function():
        """
        Create the vunit_run function to run the test bench
        """
        return """

proc _vunit_run_failure {} {
    catch {
        # tb command can fail when error comes from pli
        echo "Stack trace result from 'tb' command"
        echo [tb]
        echo
        echo "Surrounding code from 'see' command"
        echo [see]
    }
}

proc _vunit_run {} {
    if {[_vunit_source_init_files_before_run]} {
        return true
    }

    proc on_break {} {
        resume
    }
    onbreak {on_break}

    run -all
}

proc _vunit_sim_restart {} {
    restart -f
}
"""

    def _vsim_extra_args(self, config):
        """
        Determine vsim_extra_args
        """
        vsim_extra_args = []
        vsim_extra_args = config.sim_options.get("modelsim.vsim_flags", vsim_extra_args)

        if self._gui:
            vsim_extra_args = config.sim_options.get("modelsim.vsim_flags.gui", vsim_extra_args)

        return " ".join(vsim_extra_args)

    def merge_coverage(self, file_name, args=None):
        """
        Merge coverage from all test cases
        """
        if self._persistent_shell is not None:
            # Teardown to ensure ucdb file was written.
            self._persistent_shell.teardown()

        if args is None:
            args = []

        coverage_files = str(Path(self._output_path) / "coverage_files.txt")
        vcover_cmd = [str(Path(self._prefix) / "vcover"), "merge", "-inputs"] + [coverage_files] + args + [file_name]
        with Path(coverage_files).open("w", encoding="utf-8") as fptr:
            for coverage_file in self._coverage_files:
                if file_exists(coverage_file):
                    fptr.write(str(coverage_file) + "\n")
                else:
                    LOGGER.warning("Missing coverage file: %s", coverage_file)

        print(f"Merging coverage files into {file_name!s}...")
        vcover_merge_process = Process(vcover_cmd, env=self.get_env())
        vcover_merge_process.consume_output()
        print("Done merging coverage files")

    @staticmethod
    def get_env():
        """
        Remove MODELSIM environment variable
        """
        remove = ("MODELSIM",)
        env = os.environ.copy()
        for key in remove:
            if key in env.keys():
                del env[key]
        return env


def encode_generic_value(value):
    """
    Ensure values with space in them are quoted
    """
    s_value = str(value)
    if " " in s_value:
        return f'{{"{s_value!s}"}}'
    if "," in s_value:
        return f'"{s_value!s}"'
    return s_value


def parse_modelsimini(file_name):
    """
    Parse a modelsim.ini file
    :returns: A RawConfigParser object
    """
    cfg = RawConfigParser()
    with Path(file_name).open("r", encoding="utf-8") as fptr:
        cfg.read_file(fptr)
    return cfg


def write_modelsimini(cfg, file_name):
    """
    Writes a modelsim.ini file
    """
    with Path(file_name).open("w", encoding="utf-8") as optr:
        cfg.write(optr)
