# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from __future__ import print_function

from vunit.ostools import Process, write_file, file_exists, read_file
import re
from os.path import join, dirname, abspath
import os

from vunit.exceptions import CompileError

class ModelSimInterface:

    name = "modelsim"

    @staticmethod
    def is_available():
        """
        Return True if ModelSim is installed
        """
        try:
            proc = Process(['vsim', '-c', '-help'])
            proc.consume_output(callback=None)
            return True
        except:
            return False

    def __init__(self, modelsim_ini="modelsim.ini", persistent=False, gui=False):
        self._modelsim_ini = modelsim_ini

        # Workarround for Microsemi 10.3a which does not
        # respect MODELSIM environment variable when set within .do script
        # Microsemi bug reference id: dvt64978
        os.environ["MODELSIM"] = self._modelsim_ini

        self._create_modelsim_ini()
        self._vsim_process = None
        self._gui = gui
        assert not (persistent and gui)

        if persistent:
            self._create_vsim_process()

    def _teardown(self):
        if self._vsim_process is not None:
            self._send_command("quit")
            self._vsim_process.terminate()
            self._vsim_process = None


    def __del__(self):
        self._teardown()

    def _create_vsim_process(self):
        """
        Create the vsim process
        """

        self._vsim_process = Process(["vsim", "-c",
                                      "-l", join(dirname(self._modelsim_ini), "transcript")])
        self._vsim_process.write("#VUNIT_RETURN\n")
        self._vsim_process.consume_output(OutputConsumer(silent=True))

    def _create_modelsim_ini(self):
        if not file_exists(self._modelsim_ini):
            proc = Process(args=['vmap', '-c'], cwd=dirname(self._modelsim_ini))
            proc.consume_output(callback=None)

    def compile_project(self, project, vhdl_standard):
        for library in project.get_libraries():
            self.create_library(library.name, library.directory)

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
        try:
            proc = Process(['vcom', '-quiet', '-modelsimini', self._modelsim_ini,
                            '-' + vhdl_standard, '-work', library_name, source_file_name])
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def compile_verilog_file(self, source_file_name, library_name):
        try:
            proc = Process(['vlog', '-sv', '-quiet', '-modelsimini', self._modelsim_ini,
                            '-work', library_name, source_file_name])
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True


    _vmap_pattern = re.compile('maps to directory (?P<dir>.*?)\.')
    def create_library(self, library_name, path):

        if not file_exists(dirname(path)):
            os.makedirs(dirname(path))

        if not file_exists(path):
            proc = Process(['vlib', '-unix', path])
            proc.consume_output(callback=None)

        try:
            proc = Process(['vmap', '-modelsimini', self._modelsim_ini, library_name])
            proc.consume_output(callback=None)
        except Process.NonZeroExitCode:
            pass

        match = self._vmap_pattern.search(proc.output)
        if match:
            do_vmap = not file_exists(match.group('dir'))
        else:
            do_vmap = False

        if 'No mapping for library' in proc.output:
            do_vmap = True

        if do_vmap:
            proc = Process(['vmap','-modelsimini', self._modelsim_ini, library_name, path])
            proc.consume_output(callback=None)

    def _create_load_function(self, library_name, entity_name, architecture_name, generics, pli, output_path):
        set_generic_str = "".join(('    set vunit_generic_%s {%s}\n' % (name, value) for name, value in generics.items()))
        set_generic_name_str = " ".join(('-g%s="${vunit_generic_%s}"' % (name, name) for name in generics))
        pli_str = " ".join("-pli {%s}" %  fix_path(name) for name in pli)
        if architecture_name is None:
            architecture_suffix = ""
        else:
            architecture_suffix = "(%s)" % architecture_name

        tcl = """
proc vunit_load {{}} {{
    {set_generic_str}

    # Workaround -modelsimini flag not respected in some versions of modelsim
    # however, Microsemi 10.3a corrupts the enviromnent variable (see dvt64978)
    if {{[string first "Microsemi vsim 10.3a" [vsimVersionString]] eq -1}} {{
        global env
        set env(MODELSIM) "{modelsimini}"
    }}
    vsim -wlf "{wlf_file_name}" -quiet -t ps {pli_str} {set_generic_name_str} {library_name}.{entity_name}{architecture_suffix}
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
""".format(modelsimini=fix_path(self._modelsim_ini),
           pli_str=pli_str,
           set_generic_str=set_generic_str,
           set_generic_name_str=set_generic_name_str,
           library_name=library_name,
           entity_name=entity_name,
           architecture_suffix=architecture_suffix,
           wlf_file_name=fix_path(join(output_path, "vsim.wlf")))

        return tcl

    def _create_run_function(self, fail_on_warning=False):
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


    def _create_common_script(self, library_name, entity_name, architecture_name, generics, pli, fail_on_warning, output_path):
        """
        Create tcl script with functions common to interactive and batch modes
        """
        tcl = """
proc vunit_help {} {
    echo {vunit_help - Prints this help}
    echo {vunit_load - Load design with correct generics for the test}
    echo {vunit_run  - Run test, must do vunit_load first}
}
"""
        tcl += self._create_load_function(library_name, entity_name, architecture_name, generics, pli, output_path)
        tcl += self._create_run_function(fail_on_warning)
        return tcl

    def _create_batch_script(self, common_file_name, load_only=False):
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

    def _create_user_script(self, common_file_name):
        tcl = "do %s\n" % fix_path(common_file_name)
        tcl += "vunit_help\n"
        return tcl

    def _run_batch_file(self, batch_file_name, gui=False):
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
        self._vsim_process.write("%s\n" % cmd)
        self._vsim_process._next()
        self._vsim_process.write("#VUNIT_RETURN\n")
        self._vsim_process.consume_output(OutputConsumer())

    def _read_var(self, varname):
        self._vsim_process.write("echo $%s #VUNIT_READVAR\n" % varname)
        self._vsim_process._next()
        self._vsim_process.write("#VUNIT_RETURN\n")
        consumer = OutputConsumer(silent=True)
        self._vsim_process.consume_output(consumer)
        return consumer.var

    def _run_persistent(self, common_file_name, load_only=False):
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

    def simulate(self, output_path, library_name, entity_name, architecture_name=None, generics=None, pli=None, load_only=None, fail_on_warning=False):
        generics = {} if generics is None else generics
        pli = [] if pli is None else pli
        msim_output_path = abspath(join(output_path, "msim"))
        common_file_name = join(msim_output_path, "common.do")
        user_file_name = join(msim_output_path, "user.do")
        batch_file_name = join(msim_output_path, "batch.do")

        common_do = self._create_common_script(library_name, entity_name, architecture_name, generics, pli,
                                               fail_on_warning=fail_on_warning,
                                               output_path=msim_output_path)
        user_do = self._create_user_script(common_file_name)
        batch_do = self._create_batch_script(common_file_name, load_only)
        write_file(common_file_name, common_do)
        write_file(user_file_name, user_do)
        write_file(batch_file_name, batch_do)

        if self._gui:
            success = self._run_batch_file(user_file_name, gui=True)
        elif self._vsim_process is None:
            success = self._run_batch_file(batch_file_name)
        else:
            success = self._run_persistent(common_file_name, load_only)

        return success

    def load(self, output_path, library_name, entity_name, architecture_name=None, generics=None, pli=None):
        return self.simulate(output_path, library_name, entity_name, architecture_name, generics, pli, load_only=True)

    def __del__(self):
        if self._vsim_process is not None:
            del self._vsim_process

class OutputConsumer:
    """
    Consume output from modelsim and print with indentation
    """
    def __init__(self, silent=False):
        self.var = None
        self.silent = silent

    def __call__(self, line):
        stripline = line.strip()

        if stripline.endswith("#VUNIT_RETURN"):
            return True

        if stripline.endswith("#VUNIT_READVAR"):
            self.var = line.split("#VUNIT_READVAR")[0][1:].strip()
            return

        if not self.silent:
            print(line)

def fix_path(path):
    """ Modelsim does not like backslash """
    return path.replace("\\", "/").replace(" ", "\\ ")
