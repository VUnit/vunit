# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards Aldec Active HDL
"""

from functools import total_ordering
from pathlib import Path
import os
import re
import logging
import sys
from ..exceptions import CompileError
from ..ostools import Process, write_file, file_exists, renew_path
from ..test.suites import get_result_file_name
from . import SimulatorInterface, ListOfStringOption, StringOption
from .vsim_simulator_mixin import get_is_test_suite_done_tcl, fix_path

LOGGER = logging.getLogger(__name__)


class ActiveHDLInterface(SimulatorInterface):
    """
    Active HDL interface
    """

    name = "activehdl"
    supports_gui_flag = True
    package_users_depend_on_bodies = True
    compile_options = [
        ListOfStringOption("activehdl.vcom_flags"),
        ListOfStringOption("activehdl.vlog_flags"),
    ]

    sim_options = [
        ListOfStringOption("activehdl.vsim_flags"),
        ListOfStringOption("activehdl.vsim_flags.gui"),
        StringOption("activehdl.init_file.gui"),
    ]

    @classmethod
    def from_args(cls, args, output_path, **kwargs):
        """
        Create new instance from command line arguments object
        """
        return cls(prefix=cls.find_prefix(), output_path=output_path, gui=args.gui)

    @classmethod
    def find_prefix_from_path(cls):
        return cls.find_toolchain(["vsim", "avhdl"])

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
        proc = Process([str(Path(cls.find_prefix()) / "vcom"), "-version"], env=cls.get_env())
        consumer = VersionConsumer()
        proc.consume_output(consumer)
        if consumer.version is not None:
            return consumer.version >= Version(10, 1)

        return False

    @staticmethod
    def supports_coverage():
        """
        Returns True when the simulator supports coverage
        """
        return True

    def __init__(self, prefix, output_path, gui=False):
        SimulatorInterface.__init__(self, output_path, gui)
        self._library_cfg = str(Path(output_path) / "library.cfg")
        self._prefix = prefix
        self._create_library_cfg()
        self._libraries = []
        self._coverage_files = set()

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
        Returns the command to compile a single source_file
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
        Convert standard to format of Active-HDL command line flag
        """
        return f"-{vhdl_standard!s}"

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a VHDL file
        """
        return (
            [
                str(Path(self._prefix) / "vcom"),
                "-quiet",
                "-j",
                str(Path(self._library_cfg).parent),
            ]
            + source_file.compile_options.get("activehdl.vcom_flags", [])
            + [
                self._std_str(source_file.get_vhdl_standard()),
                "-work",
                source_file.library.name,
                source_file.name,
            ]
        )

    def compile_verilog_file_command(self, source_file):
        """
        Returns the command to compile a Verilog file
        """
        args = [str(Path(self._prefix) / "vlog"), "-quiet", "-lc", self._library_cfg]
        args += source_file.compile_options.get("activehdl.vlog_flags", [])
        args += ["-work", source_file.library.name, source_file.name]
        for library in self._libraries:
            args += ["-l", library.name]
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
            proc = Process(
                [str(Path(self._prefix) / "vlib"), library_name, path],
                cwd=str(Path(self._library_cfg).parent),
                env=self.get_env(),
            )
            proc.consume_output(callback=None)

        if library_name in mapped_libraries and mapped_libraries[library_name] == path:
            return

        proc = Process(
            [str(Path(self._prefix) / "vmap"), library_name, path],
            cwd=str(Path(self._library_cfg).parent),
            env=self.get_env(),
        )
        proc.consume_output(callback=None)

    def _create_library_cfg(self):
        """
        Create the library.cfg file if it does not exist
        """
        if file_exists(self._library_cfg):
            return

        with Path(self._library_cfg).open("w", encoding="utf-8") as ofile:
            ofile.write(f'$INCLUDE = "{str(Path(self._prefix).parent / "vlib" / "library.cfg")}"\n')

    _library_re = re.compile(r'([a-zA-Z_]+)\s=\s"(.*)"')

    def _get_mapped_libraries(self):
        """
        Get mapped libraries from library.cfg file
        """
        with Path(self._library_cfg).open("r", encoding="utf-8") as fptr:
            text = fptr.read()

        libraries = {}
        for line in text.splitlines():
            match = self._library_re.match(line)
            if match is None:
                continue
            key = match.group(1)
            value = match.group(2)
            libraries[key] = str((Path(self._library_cfg).parent / Path(value).parent).resolve())
        return libraries

    def _vsim_extra_args(self, config):
        """
        Determine vsim_extra_args
        """
        vsim_extra_args = []
        vsim_extra_args = config.sim_options.get("activehdl.vsim_flags", vsim_extra_args)

        if self._gui:
            vsim_extra_args = config.sim_options.get("activehdl.vsim_flags.gui", vsim_extra_args)

        return " ".join(vsim_extra_args)

    def _create_load_function(self, config, output_path):
        """
        Create the vunit_load TCL function that runs the vsim command and loads the design
        """
        set_generic_str = "\n    ".join(
            (f"set vunit_generic_{name!s} {{{value!s}}}" for name, value in config.generics.items())
        )
        set_generic_name_str = " ".join(
            (f"-g/{config.entity_name!s}/{name!s}=${{vunit_generic_{name!s}}}" for name in config.generics)
        )
        pli_str = " ".join(f'-pli "{fix_path(name)}"' for name in config.sim_options.get("pli", []))

        vsim_flags = [
            pli_str,
            set_generic_name_str,
            "-lib",
            config.library_name,
        ]

        if config.vhdl_configuration_name is None:
            vsim_flags.append(config.entity_name)
            if config.architecture_name is not None:
                vsim_flags.append(config.architecture_name)
        else:
            vsim_flags.append(config.vhdl_configuration_name)

        if config.sim_options.get("enable_coverage", False):
            coverage_file_path = str(Path(output_path) / "coverage.acdb")
            self._coverage_files.add(coverage_file_path)
            vsim_flags += [f"-acdb_file {{{fix_path(coverage_file_path)!s}}}"]

        vsim_flags += [self._vsim_extra_args(config)]

        if config.sim_options.get("disable_ieee_warnings", False):
            vsim_flags.append("-ieee_nowarn")

        # Add the the testbench top-level unit last as coverage is
        # only collected for the top-level unit specified last

        vhdl_assert_stop_level_mapping = {"warning": 1, "error": 2, "failure": 3}

        tcl = f"""
proc vunit_load {{}} {{
    {set_generic_str}
    set vsim_failed [catch {{
        vsim {' '.join(vsim_flags)}
    }}]
    if {{${{vsim_failed}}}} {{
        return true
    }}

    global breakassertlevel
    set breakassertlevel {{{vhdl_assert_stop_level_mapping[config.vhdl_assert_stop_level]}}}

    global builtinbreakassertlevel
    set builtinbreakassertlevel $breakassertlevel

    return false
}}
"""

        return tcl

    @staticmethod
    def _create_run_function():
        """
        Create the vunit_run function to run the test bench
        """
        return """
proc vunit_run {} {
    run -all
    if {![is_test_suite_done]} {
        catch {
            # tb command can fail when error comes from pli
            echo ""
            echo "Stack trace result from 'bt' command"
            bt
        }
        return true;
    }
    return false;
}
"""

    def merge_coverage(self, file_name, args=None):
        """
        Merge coverage from all test cases,
        """

        merge_command = "onerror {quit -code 1}\n"
        merge_command += "acdb merge"

        for coverage_file in self._coverage_files:
            if file_exists(coverage_file):
                merge_command += f" -i {{{fix_path(coverage_file)!s}}}"
            else:
                LOGGER.warning("Missing coverage file: %s", coverage_file)

        if args is not None:
            merge_command += " " + " ".join(f"{{{arg!s}}}" for arg in args)

        merge_command += f" -o {{{fix_path(file_name)!s}}}\n"

        merge_script_name = str(Path(self._output_path) / "acdb_merge.tcl")
        with Path(merge_script_name).open("w", encoding="utf-8") as fptr:
            fptr.write(merge_command + "\n")

        vcover_cmd = [
            str(Path(self._prefix) / "vsimsa"),
            "-tcl",
            str(fix_path(merge_script_name)),
        ]

        print(f"Merging coverage files into {file_name!s}...")
        vcover_merge_process = Process(vcover_cmd, env=self.get_env())
        vcover_merge_process.consume_output()
        print("Done merging coverage files")

    @staticmethod
    def _create_restart_function():
        """ "
        Create the vunit_restart function to recompile and restart the simulation

        This function is quite complicated to work around limitations
        of modelsim not being able to change working directory.

        Thus python is called with an explicit command string that in
        turn call the python command we actually wanted but in the
        correct working directory using subprocess.call

        -u flag is needed for continuous output
        """
        recompile_command = [sys.executable, "-u", sys.argv[0], "--compile"]

        # Strip --clean from re-compile command
        # Leave other arguments intact since users can add custom CLI options
        recompile_command += [arg for arg in sys.argv[1:] if arg != "--clean"]

        recompile_command_visual = " ".join(recompile_command)

        # stderr is intentionally re-directed to stdout so that the tcl's catch
        # relies on the return code from the python process rather than being
        # tricked by output going to stderr.  See issue #228.
        recompile_command_eval = [
            str(sys.executable),
            "-u",
            "-c",
            (
                "import sys;"
                "import subprocess;"
                f"exit(subprocess.call({recompile_command!r}, "
                f"cwd={str(Path(os.getcwd()).resolve())!r}, "
                "bufsize=0, "
                "universal_newlines=True, "
                "stdout=sys.stdout, "
                "stderr=sys.stdout))"
            ),
        ]
        recompile_command_eval_tcl = " ".join([f"{{{part}}}" for part in recompile_command_eval])

        return f"""
proc vunit_compile {{}} {{
    set cmd_show {{{recompile_command_visual!s}}}
    puts "Re-compiling using command ${{cmd_show}}"

    set chan [open |[list {recompile_command_eval_tcl!s}] r]
    echo $chan
    while {{[gets $chan line] >= 0}} {{
        puts $line
    }}

    if {{[catch {{close $chan}} error_msg]}} {{
        puts "Re-compile failed"
        puts ${{error_msg}}
        return true
    }} else {{
        puts "Re-compile finished"
        return false
    }}
}}

proc vunit_restart {{}} {{
    if {{![vunit_compile]}} {{
        restart
        vunit_run
    }}
}}
"""

    def _create_common_script(self, config, output_path):
        """
        Create tcl script with functions common to interactive and batch modes
        """
        tcl = """
proc vunit_help {} {
    puts {List of VUnit commands:}
    puts {vunit_help}
    puts {  - Prints this help}
    puts {vunit_load}
    puts {  - Load design with correct generics for the test}
    puts {vunit_user_init}
    puts {  - Re-runs the user defined init file}
    puts {vunit_run}
    puts {  - Run test, must do vunit_load first}
    puts {vunit_compile}
    puts {  - Recompiles the source files}
    puts {vunit_restart}
    puts {  - Recompiles the source files}
    puts {  - and re-runs the simulation if the compile was successful}
}
"""

        tcl += get_is_test_suite_done_tcl(get_result_file_name(output_path))
        tcl += self._create_load_function(config, output_path)
        tcl += self._create_run_function()
        tcl += self._create_restart_function()
        tcl += "scripterconf -tcl\n"
        return tcl

    @staticmethod
    def _create_batch_script(common_file_name, load_only=False):
        """
        Create tcl script to run in batch mode
        """
        batch_do = ""
        batch_do += f'source "{fix_path(common_file_name)!s}"\n'
        batch_do += "set failed [vunit_load]\n"
        batch_do += "if {$failed} {quit -code 1}\n"
        if not load_only:
            batch_do += "set failed [vunit_run]\n"
            batch_do += "if {$failed} {quit -code 1}\n"
        batch_do += "quit -code 0\n"
        return batch_do

    def _create_user_init_function(self, config):
        """
        Create the vunit_user_init function which sources the user defined TCL file in
        simulator_name.init_file.gui.
        Also defines the vunit_tb_path and the vunit_tb_name variable.
        """
        opt_name = self.name + ".init_file.gui"
        init_file = config.sim_options.get(opt_name, None)
        tcl = "proc vunit_user_init {} {\n"
        if init_file is not None:
            tcl += f"set vunit_tb_name {config.design_unit_name}\n"
            tcl += f"set vunit_tb_path {fix_path(str(Path(config.tb_path).resolve()))}\n"
            tcl += f'source "{fix_path(str(Path(init_file).resolve()))!s}"\n'
        tcl += "    return 0\n"
        tcl += "}\n"
        return tcl

    def _create_gui_script(self, common_file_name, config):
        """
        Create the user facing script which loads common functions and prints a help message.
        Also defines the vunit_tb_path and the vunit_tb_name variable.
        """

        tcl = ""
        tcl += f'source "{fix_path(common_file_name)!s}"\n'
        tcl += "workspace create workspace\n"
        tcl += "design create -a design .\n"

        for library in self._libraries:
            tcl += f"vmap {library.name!s} {fix_path(library.directory)!s}\n"

        tcl += self._create_user_init_function(config)
        tcl += "if {![vunit_load]} {\n"
        tcl += "  vunit_user_init\n"
        tcl += "  vunit_help\n"
        tcl += "}\n"

        return tcl

    def _run_batch_file(self, batch_file_name, gui, cwd):
        """
        Run a test bench in batch by invoking a new vsim process from the command line
        """

        todo = f'@do -tcl ""{fix_path(batch_file_name)!s}""'
        if not gui:
            todo = "@onerror {quit -code 1};" + todo

        try:
            args = [
                str(Path(self._prefix) / "vsim"),
                "-gui" if gui else "-c",
                "-l",
                str(Path(batch_file_name).parent / "transcript"),
                "-do",
                todo,
            ]

            proc = Process(args, cwd=cwd, env=self.get_env())
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def simulate(self, output_path, test_suite_name, config, elaborate_only):
        """
        Run a test bench
        """
        script_path = Path(output_path) / self.name
        common_file_name = script_path / "common.tcl"
        batch_file_name = script_path / "batch.tcl"
        gui_file_name = script_path / "gui.tcl"

        write_file(common_file_name, self._create_common_script(config, output_path))
        write_file(gui_file_name, self._create_gui_script(str(common_file_name), config))
        write_file(
            str(batch_file_name),
            self._create_batch_script(str(common_file_name), elaborate_only),
        )

        if self._gui:
            gui_path = str(script_path / "gui")
            renew_path(gui_path)
            return self._run_batch_file(str(gui_file_name), gui=True, cwd=gui_path)

        return self._run_batch_file(str(batch_file_name), gui=False, cwd=str(Path(self._library_cfg).parent))


@total_ordering
class Version(object):
    """
    Simulator version
    """

    def __init__(self, major=0, minor=0, minor_letter=""):
        self.major = major
        self.minor = minor
        self.minor_letter = minor_letter

    def _compare(self, other, greater_than, less_than, equal_to):
        """
        Compares this object with another
        """
        if self.major > other.major:
            result = greater_than
        elif self.major < other.major:
            result = less_than
        elif self.minor > other.minor:
            result = greater_than
        elif self.minor < other.minor:
            result = less_than
        elif self.minor_letter > other.minor_letter:
            result = greater_than
        elif self.minor_letter < other.minor_letter:
            result = less_than
        else:
            result = equal_to

        return result

    def __lt__(self, other):
        return self._compare(other, greater_than=False, less_than=True, equal_to=False)

    def __eq__(self, other):
        return self._compare(other, greater_than=False, less_than=False, equal_to=True)


class VersionConsumer(object):
    """
    Consume version information
    """

    def __init__(self):
        self.version = None

    _version_re = re.compile(r"(?P<major>\d+)\.(?P<minor>\d+)(?P<minor_letter>[a-zA-Z]?)\.\d+\.\d+")

    def __call__(self, line):
        match = self._version_re.search(line)
        if match is not None:
            major = int(match.group("major"))
            minor = int(match.group("minor"))
            minor_letter = match.group("minor_letter")
            self.version = Version(major, minor, minor_letter)
        return True
