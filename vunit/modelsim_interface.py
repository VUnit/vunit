# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards Mentor Graphics ModelSim
"""


from __future__ import print_function

import logging
import threading
import sys
import os
from os.path import join, dirname, abspath
from argparse import ArgumentTypeError
try:
    # Python 3
    from configparser import RawConfigParser
except ImportError:
    # Python 2
    from ConfigParser import RawConfigParser  # pylint: disable=import-error

from vunit.ostools import Process, write_file, file_exists
from vunit.simulator_interface import SimulatorInterface
from vunit.exceptions import CompileError
from vunit.test_runner import HASH_TO_TEST_NAME

LOGGER = logging.getLogger(__name__)


class ModelSimInterface(SimulatorInterface):  # pylint: disable=too-many-instance-attributes
    """
    Mentor Graphics ModelSim interface

    The interface supports both running each simulation in separate vsim processes or
    re-using the same vsim process to avoid startup-overhead (persistent=True)
    """
    name = "modelsim"
    supports_gui_flag = True
    package_users_depend_on_bodies = False

    compile_options = [
        "modelsim.vcom_flags",
        "modelsim.vlog_flags",
    ]

    sim_options = [
        "modelsim.vsim_flags",
        "modelsim.vsim_flags.gui",
    ]

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group("modelsim",
                                          description="ModelSim specific flags")
        group.add_argument("--new-vsim",
                           action="store_true",
                           default=False,
                           help="Do not re-use the same vsim process for running different test cases (slower)")
        group.add_argument("--coverage",
                           default=None,
                           nargs="?",
                           const="all",
                           type=argparse_coverage_type,
                           help=('Enable code coverage. '
                                 'Choose any combination of "bcestf". '
                                 'When the flag is given with no argument, everything is enabled. '
                                 'Remember to run --clean when changing this as re-compilation is not triggered. '
                                 'Experimental feature not supported by VUnit main developers.'))

    @classmethod
    def from_args(cls, output_path, args):
        """
        Create new instance from command line arguments object
        """
        persistent = not (args.new_vsim or args.gui)

        return cls(prefix=cls.find_prefix(),
                   modelsim_ini=join(output_path, "modelsim.ini"),
                   persistent=persistent,
                   coverage=args.coverage,
                   gui_mode="load" if args.gui else None)

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find first valid modelsim toolchain prefix
        """
        def has_modelsim_ini(path):
            return os.path.isfile(join(path, "..", "modelsim.ini"))

        return cls.find_toolchain(["vsim"],
                                  constraints=[has_modelsim_ini])

    def __init__(self, prefix, modelsim_ini="modelsim.ini", persistent=False, gui_mode=None, coverage=None):
        self._modelsim_ini = abspath(modelsim_ini)

        # Workaround for Microsemi 10.3a which does not
        # respect the MODELSIM environment variable when set within .do script
        # Microsemi bug reference id: dvt64978
        # Also a problem with ALTERA STARTER EDITION 10.3c
        os.environ["MODELSIM"] = self._modelsim_ini

        self._vsim_processes = {}
        self._lock = threading.Lock()
        self._transcript_id = 0
        self._prefix = prefix
        self._libraries = {}

        self._persistent = persistent
        self._gui_mode = gui_mode
        assert gui_mode in (None, "run", "load")
        self._coverage = coverage
        self._coverage_files = set()
        assert not (persistent and (gui_mode is not None))
        self._create_modelsim_ini()

    def _create_vsim_process(self):
        """
        Create the vsim process
        """
        ident = threading.current_thread().ident

        with self._lock:
            try:
                vsim_process = self._vsim_processes[ident]
                if vsim_process.is_alive():
                    return vsim_process
            except KeyError:
                pass

            transcript_id = self._transcript_id
            self._transcript_id += 1
            vsim_process = Process([join(self._prefix, "vsim"), "-c",
                                    "-l", join(dirname(self._modelsim_ini), "transcript%i" % transcript_id)])
            self._vsim_processes[ident] = vsim_process

        vsim_process.write("#VUNIT_RETURN\n")
        vsim_process.consume_output(silent_output_consumer)
        return vsim_process

    def _create_modelsim_ini(self):
        """
        Create the modelsim.ini file if it does not exist
        """
        if file_exists(self._modelsim_ini):
            return

        parent = dirname(self._modelsim_ini)
        if not file_exists(parent):
            os.makedirs(parent)

        with open(join(self._prefix, "..", "modelsim.ini"), 'rb') as fread:
            with open(self._modelsim_ini, 'wb') as fwrite:
                fwrite.write(fread.read())

    def setup_library_mapping(self, project):
        """
        Setup library mapping
        """
        mapped_libraries = self._get_mapped_libraries()

        for library in project.get_libraries():
            self._libraries[library.name] = library
            self.create_library(library.name, library.directory, mapped_libraries)

    def compile_source_file_command(self, source_file):
        """
        Returns the command to compile a single source file
        """
        if source_file.file_type == 'vhdl':
            return self.compile_vhdl_file_command(source_file)
        elif source_file.file_type == 'verilog':
            return self.compile_verilog_file_command(source_file)

        LOGGER.error("Unknown file type: %s", source_file.file_type)
        raise CompileError

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a vhdl file
        """
        if self._coverage is None:
            coverage_args = []
        else:
            coverage_args = ["+cover=" + to_coverage_args(self._coverage)]

        return ([join(self._prefix, 'vcom'), '-quiet', '-modelsimini', self._modelsim_ini] +
                coverage_args + source_file.compile_options.get("modelsim.vcom_flags", []) +
                ['-' + source_file.get_vhdl_standard(), '-work', source_file.library.name, source_file.name])

    def compile_verilog_file_command(self, source_file):
        """
        Returns the command to compile a verilog file
        """
        if self._coverage is None:
            coverage_args = []
        else:
            coverage_args = ["+cover=" + to_coverage_args(self._coverage)]

        args = [join(self._prefix, 'vlog'), '-sv', '-quiet', '-modelsimini', self._modelsim_ini]
        args += coverage_args
        args += source_file.compile_options.get("modelsim.vlog_flags", [])
        args += ['-work', source_file.library.name, source_file.name]

        for library in self._libraries.values():
            args += ["-L", library.name]
        for include_dir in source_file.include_dirs:
            args += ["+incdir+%s" % include_dir]
        for key, value in source_file.defines.items():
            args += ["+define+%s=%s" % (key, value)]
        return args

    def create_library(self, library_name, path, mapped_libraries=None):
        """
        Create and map a library_name to path
        """
        mapped_libraries = mapped_libraries if mapped_libraries is not None else {}

        if not file_exists(dirname(abspath(path))):
            os.makedirs(dirname(abspath(path)))

        if not file_exists(path):
            proc = Process([join(self._prefix, 'vlib'), '-unix', path])
            proc.consume_output(callback=None)

        if library_name in mapped_libraries and mapped_libraries[library_name] == path:
            return

        cfg = RawConfigParser()
        cfg.read(self._modelsim_ini)
        cfg.set("Library", library_name, path)
        with open(self._modelsim_ini, "w") as optr:
            cfg.write(optr)

    def _get_mapped_libraries(self):
        """
        Get mapped libraries from modelsim.ini file
        """
        cfg = RawConfigParser()
        cfg.read(self._modelsim_ini)
        libraries = dict(cfg.items("Library"))
        if "others" in libraries:
            del libraries["others"]
        return libraries

    def _create_load_function(self,  # pylint: disable=too-many-arguments,too-many-locals
                              library_name, entity_name, architecture_name,
                              config, output_path):
        """
        Create the vunit_load TCL function that runs the vsim command and loads the design
        """

        set_generic_str = " ".join(('-g/%s/%s=%s' % (entity_name, name, encode_generic_value(value))
                                    for name, value in config.generics.items()))
        pli_str = " ".join("-pli {%s}" % fix_path(name) for name in config.pli)

        if architecture_name is None:
            architecture_suffix = ""
        else:
            architecture_suffix = "(%s)" % architecture_name

        if self._coverage is None:
            coverage_save_cmd = ""
            coverage_args = ""
        else:
            coverage_file = join(output_path, "coverage.ucdb")
            self._coverage_files.add(coverage_file)
            coverage_save_cmd = "coverage save -onexit -testname {%s} -assert -directive -cvg -codeAll {%s}" % (
                # Ugly output path to test name translation until this is passed to simulator interfaces
                HASH_TO_TEST_NAME[os.path.basename(os.path.dirname(output_path))],
                fix_path(coverage_file))

            coverage_args = "-coverage=" + to_coverage_args(self._coverage)

        vsim_flags = ["-wlf {%s}" % fix_path(join(output_path, "vsim.wlf")),
                      "-quiet",
                      "-t ps",
                      # for correct handling of verilog fatal/finish
                      "-onfinish stop",
                      pli_str,
                      set_generic_str,
                      library_name + "." + entity_name + architecture_suffix,
                      coverage_args,
                      self._vsim_extra_args(config)]

        # There is a known bug in modelsim that prevents the -modelsimini flag from accepting
        # a space in the path even with escaping, see issue #36
        if " " not in self._modelsim_ini:
            vsim_flags.insert(0, "-modelsimini %s" % fix_path(self._modelsim_ini))

        for library in self._libraries.values():
            vsim_flags += ["-L", library.name]

        tcl = """
proc vunit_load {{{{vsim_extra_args ""}}}} {{
    set vsim_failed [catch {{
        eval vsim ${{vsim_extra_args}} {{{vsim_flags}}}
    }}]
    if {{${{vsim_failed}}}} {{
       echo Command 'vsim ${{vsim_extra_args}} {vsim_flags}' failed
       echo Bad flag from vsim_extra_args?
       return 1
    }}
    set no_finished_signal [catch {{examine -internal {{/vunit_finished}}}}]
    set no_vhdl_test_runner_exit [catch {{examine -internal {{/run_base_pkg/runner.exit_simulation}}}}]
    set no_verilog_test_runner_exit [catch {{examine -internal {{/vunit_pkg/__runner__}}}}]

    if {{${{no_finished_signal}} && ${{no_vhdl_test_runner_exit}} && ${{no_verilog_test_runner_exit}}}}  {{
        echo {{Error: Found none of either simulation shutdown mechanisms}}
        echo {{Error: 1) No vunit_finished signal on test bench top level}}
        echo {{Error: 2) No vunit test runner package used}}
        return 1
    }}

    {coverage_save_cmd}
    return 0
}}
""".format(coverage_save_cmd=coverage_save_cmd,
           vsim_flags=" ".join(vsim_flags))

        return tcl

    @staticmethod
    def _create_run_function(fail_on_warning=False, disable_ieee_warnings=False):
        """
        Create the vunit_run function to run the test bench
        """
        if disable_ieee_warnings:
            no_warnings = 1
        else:
            no_warnings = 0
        return """
proc _vunit_run {} {
    global BreakOnAssertion
    set BreakOnAssertion %i

    global NumericStdNoWarnings
    set NumericStdNoWarnings %i

    global StdArithNoWarnings
    set StdArithNoWarnings %i

    proc on_break {} {
        resume
    }
    onbreak {on_break}

    set has_vunit_finished_signal [expr ![catch {examine -internal {/vunit_finished}}]]
    set has_vhdl_runner [expr ![catch {examine -internal {/run_base_pkg/runner.exit_simulation}}]]
    set has_verilog_runner [expr ![catch {examine -internal {/vunit_pkg/__runner__}}]]

    if {${has_vunit_finished_signal}} {
        set exit_boolean {/vunit_finished}
        set status_boolean {/vunit_finished}
        set true_value TRUE
    } elseif {${has_vhdl_runner}} {
        set exit_boolean {/run_base_pkg/runner.exit_simulation}
        set status_boolean {/run_base_pkg/runner.exit_without_errors}
        set true_value TRUE
    } elseif {${has_verilog_runner}} {
        set exit_boolean {/vunit_pkg/__runner__.exit_simulation}
        set status_boolean {/vunit_pkg/__runner__.exit_without_errors}
        set true_value 1
    } else {
        echo "No finish mechanism detected"
        return 1;
    }

    when -fast "${exit_boolean} = ${true_value}" {
        echo "Finished"
        stop
        resume
    }

    run -all
    set failed [expr [examine -radix unsigned -internal ${status_boolean}]!=${true_value}]
    if {$failed} {
        catch {
            # tb command can fail when error comes from pli
            echo
            echo "Stack trace result from 'tb' command"
            echo [tb]
            echo
            echo "Surrounding code from 'see' command"
            echo [see]
        }
    }
    return $failed
}

proc vunit_run {} {
    if {[catch {_vunit_run} failed_or_err]} {
        echo $failed_or_err
        return 1;
    }
    return $failed_or_err;
}
""" % (1 if fail_on_warning else 2, no_warnings, no_warnings)

    @staticmethod
    def _create_restart_function():
        """"
        Create the vunit_restart function to recompile and restart the simulation
        """
        tcl = """
proc vunit_restart {} {
    echo [exec -ignorestderr %s %s --compile]
    restart -f
    vunit_run
}
""" % (fix_path(sys.executable), fix_path(sys.argv[0]))
        return tcl

    def _vsim_extra_args(self, config):
        """
        Determine vsim_extra_args
        """
        vsim_extra_args = []
        vsim_extra_args = config.options.get("modelsim.vsim_flags",
                                             vsim_extra_args)

        if self._gui_mode is not None:
            vsim_extra_args = config.options.get("modelsim.vsim_flags.gui",
                                                 vsim_extra_args)

        return " ".join(vsim_extra_args)

    def _create_common_script(self,   # pylint: disable=too-many-arguments
                              library_name, entity_name, architecture_name,
                              config,
                              output_path):
        """
        Create tcl script with functions common to interactive and batch modes
        """
        tcl = """
proc vunit_help {} {
    echo {List of VUnit modelsim commands:}
    echo {vunit_help}
    echo {  - Prints this help}
    echo {vunit_load [vsim_extra_args]}
    echo {  - Load design with correct generics for the test}
    echo {  - Optional first argument are passed as extra flags to vsim}
    echo {vunit_run}
    echo {  - Run test, must do vunit_load first}
    echo {vunit_restart}
    echo {  - Recompiles the source files}
    echo {  - Restarts the simulation and does vunit_run}
}
"""
        tcl += self._create_load_function(library_name, entity_name, architecture_name,
                                          config, output_path)
        tcl += self._create_run_function(config.fail_on_warning,
                                         config.disable_ieee_warnings)
        tcl += self._create_restart_function()
        return tcl

    @staticmethod
    def _create_batch_script(common_file_name, load_only=False):
        """
        Create tcl script to run in batch mode
        """
        batch_do = "do " + fix_path(common_file_name) + "\n"
        batch_do += "quietly set failed [vunit_load]\n"
        batch_do += "if {$failed} {quit -f -code 1}\n"
        if not load_only:
            batch_do += "quietly set failed [vunit_run]\n"
            batch_do += "if {$failed} {quit -f -code 1}\n"
        batch_do += "quit -f -code 0\n"
        return batch_do

    @staticmethod
    def _create_gui_load_script(common_file_name):
        """
        Create the user facing script which loads common functions and prints a help message
        """
        tcl = """
do %s
if {![vunit_load]} {
  vunit_help
}
""" % fix_path(common_file_name)
        return tcl

    @staticmethod
    def _create_gui_run_script(common_file_name):
        """
        Create the user facing script which loads common functions and prints a help message
        """
        tcl = """\
do %s
# Do not exclude variables from log
if {![vunit_load -vhdlvariablelogging]} {
  quietly set WildcardFilter [lsearch -not -all -inline $WildcardFilter Process]
  quietly set WildcardFilter [lsearch -not -all -inline $WildcardFilter Variable]
  quietly set WildcardFilter [lsearch -not -all -inline $WildcardFilter Constant]
  quietly set WildcardFilter [lsearch -not -all -inline $WildcardFilter Generic]
  log -recursive /*"
  quietly set WildcardFilter default
  vunit_run
}
""" % fix_path(common_file_name)
        return tcl

    def _run_batch_file(self, batch_file_name, gui=False):
        """
        Run a test bench in batch by invoking a new vsim process from the command line
        """

        try:
            args = [join(self._prefix, 'vsim'), '-quiet',
                    "-l", join(dirname(batch_file_name), "transcript"),
                    '-do', "do %s" % fix_path(batch_file_name)]

            if gui:
                args.append('-gui')
            else:
                args.append('-c')

            proc = Process(args)
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def _send_command(self, cmd):
        """
        Send a command to the persistent vsim process
        """
        vsim_process = self._create_vsim_process()

        vsim_process.write("%s\n" % cmd)
        vsim_process.next_line()
        vsim_process.write("#VUNIT_RETURN\n")
        vsim_process.consume_output(output_consumer)

    def _read_var(self, varname):
        """
        Read a TCL variable from the persistent vsim process
        """
        vsim_process = self._create_vsim_process()

        vsim_process.write("echo $%s #VUNIT_READVAR\n" % varname)
        vsim_process.next_line()
        vsim_process.write("#VUNIT_RETURN\n")
        consumer = ReadVarOutputConsumer()
        vsim_process.consume_output(consumer)
        return consumer.var

    def _run_persistent(self, common_file_name, load_only=False):
        """
        Run a test bench using the persistent vsim process
        """
        try:
            self._send_command("quit -sim")
            self._send_command("do " + fix_path(common_file_name))
            self._send_command("quietly set failed [vunit_load]")
            if self._read_var("failed") == '1':
                return False

            if not load_only:
                self._send_command("quietly set failed [vunit_run]")
                if self._read_var("failed") == '1':
                    return False

            return True
        except Process.NonZeroExitCode:
            return False

    def simulate(self, output_path,  # pylint: disable=too-many-arguments
                 library_name, entity_name, architecture_name, config, elaborate_only):
        """
        Run a test bench
        """
        sim_output_path = abspath(join(output_path, self.name))
        common_file_name = join(sim_output_path, "common.do")
        gui_load_file_name = join(sim_output_path, "gui_load.do")
        gui_run_file_name = join(sim_output_path, "gui_run.do")
        batch_file_name = join(sim_output_path, "batch.do")

        write_file(common_file_name,
                   self._create_common_script(library_name,
                                              entity_name,
                                              architecture_name,
                                              config,
                                              output_path=sim_output_path))
        write_file(gui_load_file_name,
                   self._create_gui_load_script(common_file_name))
        write_file(gui_run_file_name,
                   self._create_gui_run_script(common_file_name))
        write_file(batch_file_name,
                   self._create_batch_script(common_file_name, elaborate_only))

        if self._gui_mode == "load":
            return self._run_batch_file(gui_load_file_name, gui=True)
        elif self._gui_mode == "run":
            return self._run_batch_file(gui_run_file_name, gui=True)
        elif self._persistent:
            return self._run_persistent(common_file_name, elaborate_only)
        else:
            return self._run_batch_file(batch_file_name)

    def teardown(self):
        """
        Teardown all active vsim processes before shutdown
        """
        with self._lock:
            for proc in self._vsim_processes.values():
                if proc.is_alive():
                    proc.write("quit -f -code 0\n")

            for proc in self._vsim_processes.values():
                if proc.is_alive():
                    proc.wait()
            self._vsim_processes = {}

    def __del__(self):
        self.teardown()

    def post_process(self, output_path):
        """
        Merge coverage from all test cases,
        top hierarchy level is removed since it has different name in each test case
        """
        if self._coverage is None:
            return

        # Teardown to ensure ucdb file was written.
        self.teardown()

        merged_coverage_file = join(output_path, "merged_coverage.ucdb")
        vcover_cmd = [join(self._prefix, 'vcover'), 'merge', '-strip', '1', merged_coverage_file]

        for coverage_file in self._coverage_files:
            if file_exists(coverage_file):
                vcover_cmd.append(coverage_file)
            else:
                LOGGER.warning("Missing coverage ucdb file: %s", coverage_file)

        print("Merging coverage files into %s..." % merged_coverage_file)
        vcover_merge_process = Process(vcover_cmd)
        vcover_merge_process.consume_output()
        print("Done merging coverage files")


def output_consumer(line):
    """
    Consume output until reaching #VUNIT_RETURN
    """
    if line.endswith("#VUNIT_RETURN"):
        return True

    print(line)


def silent_output_consumer(line):
    """
    Consume output until reaching #VUNIT_RETURN, silent
    """
    if line.endswith("#VUNIT_RETURN"):
        return True


class ReadVarOutputConsumer(object):
    """
    Consume output from modelsim and print with indentation
    """
    def __init__(self):
        self.var = None

    def __call__(self, line):
        line = line.strip()
        if line.endswith("#VUNIT_RETURN"):
            return True

        if line.endswith("#VUNIT_READVAR"):
            self.var = line.split("#VUNIT_READVAR")[0][1:].strip()
            return


def fix_path(path):
    """ Modelsim does not like backslash """
    return path.replace("\\", "/").replace(" ", "\\ ")


def to_coverage_args(coverage):
    """
    Returns bcestf enabled by coverage string
    """
    if coverage == "all":
        return "bcestf"
    else:
        return coverage


def argparse_coverage_type(value):
    """
    Validate that coverage value is "all" or any combination of "bcestf"
    """
    if value != "all" and not set(value).issubset(set("bcestf")):
        raise ArgumentTypeError("'%s' is not 'all' or any combination of 'bcestf'" % value)

    return value


def encode_generic_value(value):
    """
    Ensure values with space in them are quoted
    """
    s_value = str(value)
    if " " in s_value:
        return '{"%s"}' % s_value
    else:
        return s_value
