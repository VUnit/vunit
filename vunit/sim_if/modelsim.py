# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards Mentor Graphics ModelSim
"""

from pathlib import Path
import os
import logging
from threading import Lock, Event
from time import sleep
from configparser import RawConfigParser
from ..exceptions import CompileError
from ..ostools import write_file, Process, file_exists
from ..vhdl_standard import VHDL
from . import SimulatorInterface, ListOfStringOption, StringOption, BooleanOption
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
        ListOfStringOption("modelsim.vopt_flags"),
        ListOfStringOption("modelsim.vopt_flags.gui"),
        ListOfStringOption("modelsim.init_files.after_load"),
        ListOfStringOption("modelsim.init_files.before_run"),
        StringOption("modelsim.init_file.gui"),
        BooleanOption("modelsim.three_step_flow"),
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
        # Contains design already optimized, i.e. the optimized design can be reused
        self._optimized_designs = {}
        # Contains locks for each library. If locked, a design belonging to the library
        # is being optimized and no other design in that library can be optimized at the
        # same time (from another thread)
        self._library_locks = {}
        # Lock to access the two shared variables above
        self._shared_state_lock = Lock()

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

    def _optimize_design(self, config):
        """
        Return True if design shall be optimized.
        """

        return config.sim_options.get("modelsim.three_step_flow", False)

    @staticmethod
    def _design_to_optimize(config):
        """
        Return the design to optimize.
        """
        if config.architecture_name is None:
            architecture_suffix = ""
        else:
            architecture_suffix = f"({config.architecture_name!s})"

        return (
            config.library_name + "." + config.entity_name + architecture_suffix
            if config.vhdl_configuration_name is None
            else config.library_name + "." + config.vhdl_configuration_name
        )

    @staticmethod
    def _to_optimized_design(design_to_optimize):
        """
        Return name for optimized design.

        vopt has limitations on how the optimized design can be named. Simply removing
        non-alphanumeric characters is a simple solution to that.
        """

        return "opt_" + "".join(ch for ch in design_to_optimize if ch.isalnum())

    def _create_optimize_function(self, config):
        """
        Create vopt script.
        """
        design_to_optimize = self._design_to_optimize(config)
        optimized_design = self._to_optimized_design(design_to_optimize)

        vopt_flags = [
            self._vopt_extra_args(config),
            f"{design_to_optimize}",
            f"-work {{{config.library_name}}}",
            "-quiet",
            f"-floatgenerics+{config.entity_name}.",
            f"-o {{{optimized_design}}}",
        ]

        # There is a known bug in modelsim that prevents the -modelsimini flag from accepting
        # a space in the path even with escaping, see issue #36
        if " " not in self._sim_cfg_file_name:
            modelsimini_option = f"-modelsimini {fix_path(self._sim_cfg_file_name)!s}"
            vopt_flags.insert(0, modelsimini_option)

        for library in self._libraries:
            vopt_flags += ["-L", library.name]

        tcl = """
proc vunit_optimize {{vopt_extra_args ""}} {"""
        tcl += """
    echo Optimizing using command 'vopt ${{vopt_extra_args}} {vopt_flags}'
    set vopt_failed [catch {{
        eval vopt ${{vopt_extra_args}} {{{vopt_flags}}}
    }}]

    if {{${{vopt_failed}}}} {{
        echo Command 'vopt ${{vopt_extra_args}} {vopt_flags}' failed
        echo Bad flag from vopt_extra_args?
        return true
    }}

    return false
}}
""".format(
            vopt_flags=" ".join(vopt_flags)
        )

        return tcl

    def _run_persistent_optimize(self, optimize_file_name):
        """
        Run a test bench using the persistent vsim process
        """
        try:
            self._persistent_shell.execute(f'source "{fix_path(str(optimize_file_name))!s}"')
            self._persistent_shell.execute("set failed [vunit_optimize]")
            if self._persistent_shell.read_bool("failed"):
                status = False
            else:
                status = True

        except Process.NonZeroExitCode:
            status = False

        return status

    def _run_optimize_batch_file(self, batch_file_name, script_path):
        """
        Run a test bench in batch by invoking a new vsim process from the command line
        """
        try:
            args = [
                str(Path(self._prefix) / "vsim"),
                "-c",
                "-l",
                str(script_path / "transcript"),
                "-do",
                f'source "{fix_path(str(batch_file_name))!s}"',
            ]

            proc = Process(args, cwd=str(Path(self._sim_cfg_file_name).parent))
            proc.consume_output()
            status = True
        except Process.NonZeroExitCode:
            status = False

        return status

    @staticmethod
    def _wait_for_file_lock(library):
        """
        Wait for any _lock file to be removed.
        """
        log_waiting = True
        while (Path(library.directory) / "_lock").exists():
            if log_waiting:
                LOGGER.debug("Waiting for %s to be removed.", Path(library.directory) / "_lock")
                log_waiting = False
            sleep(0.05)

    def _acquire_library_lock(self, library, config, design_to_optimize):
        """
        Acquire library lock and wait for any lock file to be removed.
        """
        with self._shared_state_lock:
            library_lock = self._library_locks[config.library_name]

        if library_lock.locked():
            LOGGER.debug("Waiting for library lock for %s to optimize %s.", config.library_name, design_to_optimize)
        # Do not completely block to allow for Ctrl+C
        while not library_lock.acquire(timeout=0.05):
            pass

        self._wait_for_file_lock(library)
        LOGGER.debug("Acquired library lock for %s to optimize %s.", config.library_name, design_to_optimize)

    def _release_library_lock(self, library, config):
        """
        Release library lock and wait for any lock file to be removed.
        """
        with self._shared_state_lock:
            self._wait_for_file_lock(library)
            self._library_locks[config.library_name].release()

    def _optimize(self, config, script_path):
        """
        Optimize design and return simulation target or False if optimization failed.
        """
        design_to_optimize = self._design_to_optimize(config)

        libraries = {lib.name: lib for lib in self._libraries}
        library = libraries[config.library_name]

        optimize = False
        with self._shared_state_lock:
            if design_to_optimize not in self._optimized_designs:
                LOGGER.debug("%s scheduled for optimization.", design_to_optimize)
                self._optimized_designs[design_to_optimize] = {
                    "optimized_design": None,
                    "optimization_completed": Event(),
                }
                optimize = True

                if config.library_name not in self._library_locks:
                    self._library_locks[config.library_name] = Lock()

            optimized_design, optimization_completed = self._optimized_designs[design_to_optimize].values()

        if optimize:
            self._acquire_library_lock(library, config, design_to_optimize)

            LOGGER.debug("Optimizing %s.", design_to_optimize)

            optimized_design = self._to_optimized_design(design_to_optimize)

            optimize_file_name = script_path / "optimize.do"
            write_file(str(optimize_file_name), self._create_optimize_function(config))

            if self._persistent_shell is not None:
                status = self._run_persistent_optimize(optimize_file_name)

            else:
                tcl = f"""\
onerror {{quit -code 1}}
source "{fix_path(str(optimize_file_name))!s}"
set failed [vunit_optimize]
if {{$failed}} {{quit -code 1}}
quit -code 0
        """
                batch_file_name = script_path / "batch_optimize.do"
                write_file(str(batch_file_name), tcl)

                status = self._run_optimize_batch_file(batch_file_name, script_path)

            self._release_library_lock(library, config)

            if not status:
                LOGGER.debug("Failed to optimize %s.", design_to_optimize)
                return False

            LOGGER.debug("%s optimization completed.", design_to_optimize)

            with self._shared_state_lock:
                self._optimized_designs[design_to_optimize]["optimized_design"] = optimized_design
                self._optimized_designs[design_to_optimize]["optimization_completed"].set()

        elif not optimized_design:
            LOGGER.debug("Waiting for %s to be optimized.", design_to_optimize)
            # Do not completely block to allow for Ctrl+C
            while not optimization_completed.wait(0.05):
                pass
            LOGGER.debug("Done waiting for %s to be optimized.", design_to_optimize)
            with self._shared_state_lock:
                optimized_design = self._optimized_designs[design_to_optimize]["optimized_design"]

        else:
            LOGGER.debug("Reusing optimized %s.", design_to_optimize)

        return True

    def _create_load_function(self, test_suite_name, config, output_path, optimize_design):
        """
        Create the vunit_load TCL function that runs the vsim command and loads the design
        """

        if optimize_design:
            simulation_target = self._to_optimized_design(self._design_to_optimize(config))
        else:
            simulation_target = self._design_to_optimize(config)

        set_generic_str = " ".join(
            (
                f"-g/{config.entity_name!s}/{name!s}={encode_generic_value(value)!s}"
                for name, value in config.generics.items()
            )
        )
        pli_str = " ".join(f"-pli {{{fix_path(name)!s}}}" for name in config.sim_options.get("pli", []))

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
            f"-work {{{config.library_name}}}",
            "-quiet",
            "-t ps",
            # for correct handling of verilog fatal/finish
            "-onfinish stop",
            pli_str,
            set_generic_str,
            simulation_target,
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
proc vunit_load {{vsim_extra_args ""}} {"""

        tcl += """
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

    def _vopt_extra_args(self, config):
        """
        Determine vopt_extra_args
        """
        vopt_extra_args = []
        vopt_extra_args = config.sim_options.get("modelsim.vopt_flags", vopt_extra_args)

        if self._gui:
            vopt_extra_args = config.sim_options.get("modelsim.vopt_flags.gui", vopt_extra_args)

        return " ".join(vopt_extra_args)

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
