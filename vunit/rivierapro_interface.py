# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards Aldec Riviera Pro
"""


from __future__ import print_function

from vunit.ostools import Process, write_file, file_exists
from vunit.simulator_interface import SimulatorInterface
from os.path import join, dirname, abspath
import os
import re

from vunit.exceptions import CompileError

import logging
LOGGER = logging.getLogger(__name__)


class RivieraProInterface(SimulatorInterface):
    """
    Riviera Pro interface
    """

    name = "rivierapro"

    @staticmethod
    def package_users_depend_on_bodies():
        """
        With this simulator package users depend on package bodies
        """
        return True

    @classmethod
    def from_args(cls, output_path, args):
        """
        Create new instance from command line arguments object
        """
        return cls(join(output_path, "library.cfg"),
                   gui=args.gui)

    @classmethod
    def _find_prefix(cls):
        return cls.find_toolchain(["vsim",
                                   "vsimsa"])

    @classmethod
    def is_available(cls):
        """
        Return True if installed
        """
        return cls._find_prefix() is not None

    def __init__(self, library_cfg="library.cfg", gui=False):
        self._library_cfg = abspath(library_cfg)
        self._prefix = self._find_prefix()
        self._gui = gui
        self._create_library_cfg()
        self._libraries = {}

    def compile_project(self, project, vhdl_standard):
        """
        Compile the project using vhdl_standard
        """
        mapped_libraries = self._get_mapped_libraries()

        for library in project.get_libraries():
            self._libraries[library.name] = library
            self.create_library(library.name, library.directory, mapped_libraries)

        for source_file in project.get_files_in_compile_order():
            print('Compiling ' + source_file.name + ' into ' + source_file.library.name + ' ...')

            if source_file.file_type == 'vhdl':
                success = self.compile_vhdl_file(source_file.name, source_file.library.name, vhdl_standard)
            elif source_file.file_type == 'verilog':
                success = self.compile_verilog_file(source_file.name,
                                                    source_file.library.name,
                                                    source_file.include_dirs)
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
            proc = Process([join(self._prefix, 'vcom'), '-dbg', '-quiet', '-j', dirname(self._library_cfg),
                            '-' + vhdl_standard, '-work', library_name, source_file_name])
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def compile_verilog_file(self, source_file_name, library_name, include_dirs):
        """
        Compiles a verilog file into a specific library
        """
        args = [join(self._prefix, 'vlog'), '-quiet', '-sv2k12', '-lc', self._library_cfg,
                '-work', library_name, source_file_name]
        for library in self._libraries.values():
            args += ["-l", library.name]
        for include_dir in include_dirs:
            args += ["+incdir+%s" % include_dir]
        try:
            proc = Process(args)
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
            proc = Process([join(self._prefix, 'vlib'), library_name, path], cwd=dirname(self._library_cfg))
            proc.consume_output(callback=None)

        if library_name in mapped_libraries and mapped_libraries[library_name] == path:
            return

        proc = Process([join(self._prefix, 'vmap'), library_name, path], cwd=dirname(self._library_cfg))
        proc.consume_output(callback=None)

    def _create_library_cfg(self):
        """
        Create the modelsim.ini file if it does not exist
        """
        if file_exists(self._library_cfg):
            return

        with open(self._library_cfg, "w") as ofile:
            ofile.write('$INCLUDE = "%s"\n' % join(self._prefix, "..", "vlib", "library.cfg"))

    _library_re = re.compile(r'([a-zA-Z_]+)\s=\s"(.*)"')

    def _get_mapped_libraries(self):
        """
        Get mapped libraries from library.cfg file
        """
        with open(self._library_cfg, "r") as fptr:
            text = fptr.read()

        libraries = {}
        for line in text.splitlines():
            match = self._library_re.match(line)
            if match is None:
                continue
            key = match.group(1)
            value = match.group(2)
            libraries[key] = abspath(join(dirname(self._library_cfg), dirname(value)))
        return libraries

    def _create_load_function(self,  # pylint: disable=too-many-arguments
                              library_name, entity_name, architecture_name,
                              config, output_path,
                              disable_ieee_warnings):
        """
        Create the vunit_load TCL function that runs the vsim command and loads the design
        """
        set_generic_str = " ".join(('-g/%s/%s=%s' % (entity_name, name, format_generic(value))
                                    for name, value in config.generics.items()))
        pli_str = " ".join("-pli \"%s\"" % fix_path(name) for name in config.pli)

        vsim_flags = [pli_str,
                      set_generic_str,
                      "-lib",
                      library_name,
                      entity_name]

        if architecture_name is not None:
            vsim_flags.append(architecture_name)

        if disable_ieee_warnings:
            vsim_flags.append("-ieee_nowarn")

        tcl = """
proc vunit_load {{}} {{
    set vsim_failed [catch {{
        vsim {vsim_flags}
    }}]
    if {{${{vsim_failed}}}} {{
        return 1
    }}

    set no_vhdl_test_runner_exit [catch {{examine /vunit_lib.run_base_pkg/runner.exit_simulation}}]
    set no_verilog_test_runner_exit [catch {{examine /\\\\package vunit_lib.vunit_pkg\\\\/__runner__}}]
    if {{${{no_vhdl_test_runner_exit}} && ${{no_verilog_test_runner_exit}}}}  {{
        echo {{Error: No vunit test runner package used}}
        return 1
    }}
    return 0
}}
""".format(vsim_flags=" ".join(vsim_flags))

        return tcl

    @staticmethod
    def _create_run_function(fail_on_warning=False):
        """
        Create the vunit_run function to run the test bench
        """
        breaklevel = "warning" if fail_on_warning else "error"
        return """
proc vunit_run {} {
    vhdlassert.break %s
    vhdlassert.break -builtin %s

    proc on_break {} {
        resume
    }
    onbreak {on_break}

    set has_vhdl_runner [expr ![catch {examine /vunit_lib.run_base_pkg/runner}]]
    set has_verilog_runner [expr ![catch {examine /\\\\package vunit_lib.vunit_pkg\\\\/__runner__}]]

    if {${has_vhdl_runner}} {
        set status_boolean "/vunit_lib.run_base_pkg/runner.exit_without_errors"
        set true_value true
    } elseif {${has_verilog_runner}} {
        set status_boolean "/\\\\package vunit_lib.vunit_pkg\\\\/__runner__.exit_without_errors"
        set true_value 1
    } else {
        echo "No finish mechanism detected"
        return 1;
    }

    run -all
    set failed [expr [examine ${status_boolean}]!=${true_value}]
    if {$failed} {
        catch {
            # tb command can fail when error comes from pli
            echo ""
            echo "Stack trace result from 'bt' command"
            bt
        }
    }
    return $failed
}
""" % (breaklevel, breaklevel)

    def _create_common_script(self,   # pylint: disable=too-many-arguments
                              library_name, entity_name, architecture_name,
                              config,
                              output_path):
        """
        Create tcl script with functions common to interactive and batch modes
        """
        tcl = """
proc vunit_help {} {
    echo {List of VUnit commands:}
    echo {vunit_help}
    echo {  - Prints this help}
    echo {vunit_load}
    echo {  - Load design with correct generics for the test}
    echo {  - Optional first argument are passed as extra flags to vsim}
    echo {vunit_run}
    echo {  - Run test, must do vunit_load first}
}
"""
        tcl += self._create_load_function(library_name, entity_name, architecture_name,
                                          config, output_path,
                                          config.disable_ieee_warnings)
        tcl += self._create_run_function(config.fail_on_warning)
        return tcl

    @staticmethod
    def _create_batch_script(common_file_name, load_only=False):
        """
        Create tcl script to run in batch mode
        """
        batch_do = ""
        batch_do += "onerror {quit -code 1}\n"
        batch_do += "source \"%s\"\n" % fix_path(common_file_name)
        batch_do += "set failed [vunit_load]\n"
        batch_do += "if {$failed} {quit -code 1}\n"
        if not load_only:
            batch_do += "set failed [vunit_run]\n"
            batch_do += "if {$failed} {quit -code 1}\n"
        batch_do += "quit -code 0\n"
        return batch_do

    @staticmethod
    def _create_gui_script(common_file_name):
        """
        Create tcl script to run in batch mode
        """
        batch_do = ""
        batch_do += "source \"%s\"\n" % fix_path(common_file_name)
        batch_do += "vunit_load\n"
        batch_do += "vunit_help\n"
        return batch_do

    def _run_batch_file(self, batch_file_name, gui):
        """
        Run a test bench in batch by invoking a new vsim process from the command line
        """

        try:
            args = [join(self._prefix, "vsim"), "-gui" if gui else "-c",
                    "-l", join(dirname(batch_file_name), "transcript"),
                    '-do', "source \"%s\"" % fix_path(batch_file_name)]

            os.environ["VSIMSALIBRARYCFG"] = dirname(self._library_cfg)
            proc = Process(args, cwd=dirname(self._library_cfg))
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def simulate(self, output_path,  # pylint: disable=too-many-arguments
                 library_name, entity_name, architecture_name, config):
        """
        Run a test bench
        """
        sim_output_path = abspath(join(output_path, self.name))
        common_file_name = join(sim_output_path, "common.do")
        batch_file_name = join(sim_output_path, "batch.do")
        gui_file_name = join(sim_output_path, "gui.do")

        write_file(common_file_name,
                   self._create_common_script(library_name,
                                              entity_name,
                                              architecture_name,
                                              config,
                                              output_path=sim_output_path))
        write_file(gui_file_name,
                   self._create_gui_script(common_file_name))
        write_file(batch_file_name,
                   self._create_batch_script(common_file_name, config.elaborate_only))

        if self._gui:
            return self._run_batch_file(gui_file_name, gui=True)
        else:
            return self._run_batch_file(batch_file_name, gui=False)


def fix_path(path):
    """ Remove backslash """
    return path.replace("\\", "/")


def format_generic(value):
    """
    Generic values with space in them need to be quoted
    """
    value_str = str(value)
    if " " in value_str:
        return '"%s"' % value_str
    else:
        return value_str
