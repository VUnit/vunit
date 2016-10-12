# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards Aldec Active HDL
"""


from __future__ import print_function

from os.path import join, dirname, abspath
import os
import re
import logging
from vunit.ostools import Process, write_file, file_exists, renew_path
from vunit.simulator_interface import SimulatorInterface
from vunit.exceptions import CompileError

LOGGER = logging.getLogger(__name__)


class ActiveHDLInterface(SimulatorInterface):
    """
    Active HDL interface
    """

    name = "activehdl"
    supports_gui_flag = True
    package_users_depend_on_bodies = True
    compile_options = [
        "activehdl.vcom_flags",
        "activehdl.vlog_flags",
    ]

    @classmethod
    def from_args(cls, output_path, args):
        """
        Create new instance from command line arguments object
        """
        return cls(prefix=cls.find_prefix(),
                   library_cfg=join(output_path, "library.cfg"),
                   gui=args.gui)

    @classmethod
    def find_prefix_from_path(cls):
        return cls.find_toolchain(["vsim",
                                   "avhdl"])

    def __init__(self, prefix, library_cfg="library.cfg", gui=False):
        self._library_cfg = abspath(library_cfg)
        self._prefix = prefix
        self._gui = gui
        self._create_library_cfg()
        self._libraries = {}

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
        Returns the command to compile a single source_file
        """
        if source_file.file_type == 'vhdl':
            return self.compile_vhdl_file_command(source_file)
        elif source_file.file_type == 'verilog':
            return self.compile_verilog_file_command(source_file)

        LOGGER.error("Unknown file type: %s", source_file.file_type)
        raise CompileError

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a VHDL file
        """
        return ([join(self._prefix, 'vcom'), '-quiet', '-j', dirname(self._library_cfg)] +
                source_file.compile_options.get("activehdl.vcom_flags", []) +
                ['-' + source_file.get_vhdl_standard(), '-work', source_file.library.name, source_file.name])

    def compile_verilog_file_command(self, source_file):
        """
        Returns the command to compile a Verilog file
        """
        args = [join(self._prefix, 'vlog'), '-quiet', '-sv2k12', '-lc', self._library_cfg]
        args += source_file.compile_options.get("activehdl.vlog_flags", [])
        args += ['-work', source_file.library.name, source_file.name]
        for library in self._libraries.values():
            args += ["-l", library.name]
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
            proc = Process([join(self._prefix, 'vlib'), library_name, path], cwd=dirname(self._library_cfg))
            proc.consume_output(callback=None)

        if library_name in mapped_libraries and mapped_libraries[library_name] == path:
            return

        proc = Process([join(self._prefix, 'vmap'), library_name, path], cwd=dirname(self._library_cfg))
        proc.consume_output(callback=None)

    def _create_library_cfg(self):
        """
        Create the library.cfg file if it does not exist
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

    @staticmethod
    def _create_load_function(library_name, entity_name, architecture_name,
                              config, disable_ieee_warnings):
        """
        Create the vunit_load TCL function that runs the vsim command and loads the design
        """
        set_generic_str = "\n    ".join(('set vunit_generic_%s {%s}' % (name, value)
                                         for name, value in config.generics.items()))
        set_generic_name_str = " ".join(('-g/%s/%s=${vunit_generic_%s}' % (entity_name, name, name)
                                         for name in config.generics))
        pli_str = " ".join("-pli \"%s\"" % fix_path(name) for name in config.pli)

        vsim_flags = [pli_str,
                      set_generic_name_str,
                      "-lib",
                      library_name,
                      entity_name,
                      architecture_name]

        if disable_ieee_warnings:
            vsim_flags.append("-ieee_nowarn")

        tcl = """
proc vunit_load {{}} {{
    {set_generic_str}
    set vsim_failed [catch {{
        vsim {vsim_flags}
    }}]
    if {{${{vsim_failed}}}} {{
        return 1
    }}

    global breakassertlevel
    set breakassertlevel {breaklevel}

    global builtinbreakassertlevel
    set builtinbreakassertlevel $breakassertlevel

    set no_vhdl_test_runner_exit [catch {{examine /run_base_pkg/runner.exit_simulation}}]
    if {{${{no_vhdl_test_runner_exit}}}}  {{
        echo {{Error: No vunit test runner package used}}
        return 1
    }}
    return 0
}}
""".format(set_generic_str=set_generic_str,
           vsim_flags=" ".join(vsim_flags),
           breaklevel=1 if config.fail_on_warning else 2)

        return tcl

    @staticmethod
    def _create_run_function():
        """
        Create the vunit_run function to run the test bench
        """
        return """
proc vunit_run {} {
    set has_vhdl_runner [expr ![catch {examine /run_base_pkg/runner}]]

    if {${has_vhdl_runner}} {
        set status_boolean "/run_base_pkg/runner.exit_without_errors"
        set true_value true
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
"""

    def _create_common_script(self,   # pylint: disable=too-many-arguments
                              library_name, entity_name, architecture_name,
                              config):
        """
        Create tcl script with functions common to interactive and batch modes
        """
        tcl = ""
        tcl += self._create_load_function(library_name, entity_name, architecture_name,
                                          config,
                                          config.disable_ieee_warnings)
        tcl += self._create_run_function()
        return tcl

    @staticmethod
    def _create_batch_script(common_file_name, load_only=False):
        """
        Create tcl script to run in batch mode
        """
        batch_do = ""
        batch_do += "source \"%s\"\n" % fix_path(common_file_name)
        batch_do += "set failed [vunit_load]\n"
        batch_do += "if {$failed} {quit -code 1}\n"
        if not load_only:
            batch_do += "set failed [vunit_run]\n"
            batch_do += "if {$failed} {quit -code 1}\n"
        batch_do += "quit -code 0\n"
        return batch_do

    def _create_gui_script(self, common_file_name):
        """
        Create the user facing script which loads common functions and prints a help message
        """
        library_mapping = ""
        for library in self._libraries.values():
            library_mapping += "vmap %s %s\n" % (library.name,
                                                 fix_path(library.directory))

        tcl = """
source "%s"
workspace create workspace
design create -a design .
%s
vunit_load
puts "VUnit help: Design already loaded. Use run -all to run the test."
""" % (fix_path(common_file_name), library_mapping)
        return tcl

    def _run_batch_file(self, batch_file_name, gui, cwd):
        """
        Run a test bench in batch by invoking a new vsim process from the command line
        """

        todo = "@do -tcl \"\"%s\"\"" % fix_path(batch_file_name)
        if not gui:
            todo = "@onerror {quit -code 1};" + todo

        try:
            args = [join(self._prefix, "vsim"), "-gui" if gui else "-c",
                    "-l", join(dirname(batch_file_name), "transcript"),
                    '-do', todo]

            proc = Process(args, cwd=cwd)
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def simulate(self, output_path,  # pylint: disable=too-many-arguments
                 library_name, entity_name, architecture_name, config, elaborate_only):
        """
        Run a test bench
        """
        sim_output_path = abspath(join(output_path, self.name))
        common_file_name = join(sim_output_path, "common.tcl")
        batch_file_name = join(sim_output_path, "batch.tcl")
        gui_file_name = join(sim_output_path, "gui.tcl")

        write_file(common_file_name,
                   self._create_common_script(library_name,
                                              entity_name,
                                              architecture_name,
                                              config))
        write_file(gui_file_name,
                   self._create_gui_script(common_file_name))
        write_file(batch_file_name,
                   self._create_batch_script(common_file_name, elaborate_only))

        if self._gui:
            gui_path = join(sim_output_path, "gui")
            renew_path(gui_path)
            return self._run_batch_file(gui_file_name, gui=True,
                                        cwd=gui_path)
        else:
            return self._run_batch_file(batch_file_name, gui=False,
                                        cwd=dirname(self._library_cfg))


def fix_path(path):
    """ Remove backslash """
    return path.replace("\\", "/")
