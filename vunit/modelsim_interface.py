# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards Mentor Graphics ModelSim
"""


from __future__ import print_function

from vunit.ostools import Process, write_file, file_exists
from os.path import join, dirname, abspath
import os

from vunit.exceptions import CompileError
from distutils.spawn import find_executable
try:
    # Python 3
    from configparser import RawConfigParser
except ImportError:
    # Python 2
    from ConfigParser import RawConfigParser  # pylint: disable=import-error


class ModelSimInterface(object):
    """
    Mentor Graphics ModelSim interface

    The interface supports both running each simulation in separate vsim processes or
    re-using the same vsim process to avoid startup-overhead (persistent=True)
    """
    name = "modelsim"

    @staticmethod
    def is_available():
        """
        Return True if ModelSim is installed
        """
        return find_executable('vsim') is not None

    def __init__(self, modelsim_ini="modelsim.ini", persistent=False, gui_mode=None):
        self._modelsim_ini = abspath(modelsim_ini)

        # Workarround for Microsemi 10.3a which does not
        # respect MODELSIM environment variable when set within .do script
        # Microsemi bug reference id: dvt64978
        # Also a problem with ALTERA STARTER EDITION 10.3c
        os.environ["MODELSIM"] = self._modelsim_ini

        self._create_modelsim_ini()
        self._vsim_process = None
        self._persistent = persistent
        self._gui_mode = gui_mode
        assert gui_mode in (None, "run", "load")
        assert not (persistent and (gui_mode is not None))

    def __del__(self):
        if self._vsim_process is not None:
            del self._vsim_process

    def _create_vsim_process(self):
        """
        Create the vsim process
        """

        self._vsim_process = Process(["vsim", "-c",
                                      "-l", join(dirname(self._modelsim_ini), "transcript")])
        self._vsim_process.write("#VUNIT_RETURN\n")
        self._vsim_process.consume_output(silent_output_consumer)

    def _create_modelsim_ini(self):
        """
        Create the modelsim.ini file if it does not exist
        """
        if not file_exists(self._modelsim_ini):
            proc = Process(args=['vmap', '-c'], cwd=dirname(self._modelsim_ini))
            proc.consume_output(callback=None)

    def compile_project(self, project, vhdl_standard):
        """
        Compile the project using vhdl_standard
        """
        mapped_libraries = self._get_mapped_libraries()

        for library in project.get_libraries():
            self.create_library(library.name, library.directory, mapped_libraries)

        for source_file in project.get_files_in_compile_order():
            print('Compiling ' + source_file.name + ' ...')

            if source_file.file_type == 'vhdl':
                success = self.compile_vhdl_file(source_file.name, source_file.library.name, vhdl_standard)
            elif source_file.file_type == 'verilog':
                success = self.compile_verilog_file(source_file.name, source_file.library.name)
            else:
                raise RuntimeError("Unkown file type: " + source_file.file_type)

            if not success:
                raise CompileError("Failed to compile '%s'" % source_file.name)
            project.update(source_file)

    def compile_vhdl_file(self, source_file_name, library_name, vhdl_standard):
        """
        Compiles a vhdl file into a specific library using a specfic vhdl_standard
        """
        try:
            proc = Process(['vcom', '-quiet', '-modelsimini', self._modelsim_ini,
                            '-' + vhdl_standard, '-work', library_name, source_file_name])
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def compile_verilog_file(self, source_file_name, library_name):
        """
        Compiles a verilog file into a specific library
        """
        try:
            proc = Process(['vlog', '-sv', '-quiet', '-modelsimini', self._modelsim_ini,
                            '-work', library_name, source_file_name])
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def create_library(self, library_name, path, mapped_libraries=None):
        """
        Create and map a library_name to path
        """
        mapped_libraries = mapped_libraries if mapped_libraries is not None else {}

        if not file_exists(dirname(path)):
            os.makedirs(dirname(path))

        if not file_exists(path):
            proc = Process(['vlib', '-unix', path])
            proc.consume_output(callback=None)

        if library_name in mapped_libraries and mapped_libraries[library_name] == path:
            return

        proc = Process(['vmap', '-modelsimini', self._modelsim_ini, library_name, path])
        proc.consume_output(callback=None)

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

    def _create_load_function(self,  # pylint: disable=too-many-arguments
                              library_name, entity_name, architecture_name,
                              generics, pli, output_path):
        """
        Create the vunit_load TCL function that runs the vsim command and loads the design
        """
        set_generic_str = "\n    ".join(('set vunit_generic_%s {%s}' % (name, value)
                                         for name, value in generics.items()))
        set_generic_name_str = " ".join(('-g%s="${vunit_generic_%s}"' % (name, name) for name in generics))
        pli_str = " ".join("-pli {%s}" % fix_path(name) for name in pli)
        if architecture_name is None:
            architecture_suffix = ""
        else:
            architecture_suffix = "(%s)" % architecture_name

        vsim_flags = ["-wlf {%s}" % fix_path(join(output_path, "vsim.wlf")),
                      "-quiet",
                      "-t ps",
                      pli_str,
                      set_generic_name_str,
                      library_name + "." + entity_name + architecture_suffix]

        # There is a known bug in modelsim that prevents the -modelsimini flag from accepting
        # a space in the path even with escaping, see issue #36
        if " " not in self._modelsim_ini:
            vsim_flags.insert(0, "-modelsimini %s" % fix_path(self._modelsim_ini))

        tcl = """
proc vunit_load {{{{vsim_extra_args ""}}}} {{
    {set_generic_str}
    vsim ${{vsim_extra_args}} {vsim_flags}
    set no_finished_signal [catch {{examine -internal {{/vunit_finished}}}}]
    set no_test_runner_exit [catch {{examine -internal {{/run_base_pkg/runner.exit_without_errors}}}}]

    if {{${{no_finished_signal}} && ${{no_test_runner_exit}}}}  {{
        echo {{Error: Found none of either simulation shutdown mechanisms}}
        echo {{Error: 1) No vunit_finished signal on test bench top level}}
        echo {{Error: 2) No vunit test runner package used}}
        return 1
    }}
    return 0
}}
""".format(set_generic_str=set_generic_str,
           vsim_flags=" ".join(vsim_flags))

        return tcl

    @staticmethod
    def _create_run_function(fail_on_warning=False):
        """
        Create the vunit_run function to run the test bench
        """
        return """
proc vunit_run {} {
    global BreakOnAssertion

    # Break on error
    set BreakOnAssertion %i

    proc on_break {} {
        resume
    }
    onbreak {on_break}

    set no_finished_signal [catch {examine -internal {/vunit_finished}}]

    if {${no_finished_signal}} {
        set exit_boolean {/run_base_pkg/runner.exit_without_errors}
    } {
        set exit_boolean {/vunit_finished}
    }

    when -fast "${exit_boolean} = TRUE" {
        echo "Finished"
        stop
        resume
    }

    run -all
    set failed [expr [examine -internal ${exit_boolean}]!=TRUE]
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
""" % (1 if fail_on_warning else 2)

    def _create_common_script(self,   # pylint: disable=too-many-arguments
                              library_name, entity_name, architecture_name,
                              generics, pli, fail_on_warning, output_path):
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
}
"""
        tcl += self._create_load_function(library_name, entity_name, architecture_name, generics, pli, output_path)
        tcl += self._create_run_function(fail_on_warning)
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
        tcl = "do %s\n" % fix_path(common_file_name)
        tcl += "vunit_load\n"
        tcl += "vunit_help\n"
        return tcl

    @staticmethod
    def _create_gui_run_script(common_file_name):
        """
        Create the user facing script which loads common functions and prints a help message
        """
        tcl = "do %s\n" % fix_path(common_file_name)
        # Do not exclude variables from log
        tcl += "vunit_load -vhdlvariablelogging\n"
        tcl += "quietly set WildcardFilter [lsearch -not -all -inline $WildcardFilter Process]\n"
        tcl += "quietly set WildcardFilter [lsearch -not -all -inline $WildcardFilter Variable]\n"
        tcl += "quietly set WildcardFilter [lsearch -not -all -inline $WildcardFilter Constant]\n"
        tcl += "quietly set WildcardFilter [lsearch -not -all -inline $WildcardFilter Generic]\n"
        tcl += "log -recursive /*\n"
        tcl += "quietly set WildcardFilter default\n"
        tcl += "vunit_run\n"
        return tcl

    @staticmethod
    def _run_batch_file(batch_file_name, gui=False):
        """
        Run a test bench in batch by invoking a new vsim process from the command line
        """
        try:
            args = ['vsim', '-quiet',
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
        if self._vsim_process is None:
            self._create_vsim_process()

        self._vsim_process.write("%s\n" % cmd)
        self._vsim_process.next_line()
        self._vsim_process.write("#VUNIT_RETURN\n")
        self._vsim_process.consume_output(output_consumer)

    def _read_var(self, varname):
        """
        Read a TCL variable from the persistent vsim process
        """
        if self._vsim_process is None:
            self._create_vsim_process()

        self._vsim_process.write("echo $%s #VUNIT_READVAR\n" % varname)
        self._vsim_process.next_line()
        self._vsim_process.write("#VUNIT_RETURN\n")
        consumer = ReadVarOutputConsumer()
        self._vsim_process.consume_output(consumer)
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
            self._create_vsim_process()
            return False

    def simulate(self, output_path,  # pylint: disable=too-many-arguments
                 library_name, entity_name, architecture_name=None,
                 generics=None, pli=None, load_only=None, fail_on_warning=False):
        """
        Run a test bench
        load_only -- Only load the design performing elaboration without simulating
        """
        generics = {} if generics is None else generics
        pli = [] if pli is None else pli
        msim_output_path = abspath(join(output_path, "msim"))
        common_file_name = join(msim_output_path, "common.do")
        gui_load_file_name = join(msim_output_path, "gui_load.do")
        gui_run_file_name = join(msim_output_path, "gui_run.do")
        batch_file_name = join(msim_output_path, "batch.do")

        write_file(common_file_name,
                   self._create_common_script(library_name, entity_name, architecture_name, generics, pli,
                                              fail_on_warning=fail_on_warning,
                                              output_path=msim_output_path))
        write_file(gui_load_file_name,
                   self._create_gui_load_script(common_file_name))
        write_file(gui_run_file_name,
                   self._create_gui_run_script(common_file_name))
        write_file(batch_file_name,
                   self._create_batch_script(common_file_name, load_only))

        if self._gui_mode == "load":
            return self._run_batch_file(gui_load_file_name, gui=True)
        elif self._gui_mode == "run":
            return self._run_batch_file(gui_run_file_name, gui=True)
        elif self._persistent:
            return self._run_persistent(common_file_name, load_only)
        else:
            return self._run_batch_file(batch_file_name)


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
