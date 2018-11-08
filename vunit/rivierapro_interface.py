# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards Aldec Riviera Pro
"""


from __future__ import print_function

from os.path import join, dirname, abspath
import os
import re
import logging
from vunit.ostools import Process, file_exists
from vunit.simulator_interface import (SimulatorInterface,
                                       ListOfStringOption,
                                       StringOption)
from vunit.exceptions import CompileError
from vunit.vsim_simulator_mixin import (VsimSimulatorMixin,
                                        fix_path)

LOGGER = logging.getLogger(__name__)


class RivieraProInterface(VsimSimulatorMixin, SimulatorInterface):
    """
    Riviera Pro interface
    """

    name = "rivierapro"
    supports_gui_flag = True
    package_users_depend_on_bodies = True

    compile_options = [
        ListOfStringOption("rivierapro.vcom_flags"),
        ListOfStringOption("rivierapro.vlog_flags"),
    ]

    sim_options = [
        ListOfStringOption("rivierapro.vsim_flags"),
        ListOfStringOption("rivierapro.vsim_flags.gui"),
        ListOfStringOption("rivierapro.init_files.after_load"),
        StringOption("rivierapro.init_file.gui"),
    ]

    @classmethod
    def from_args(cls, args, output_path, **kwargs):
        """
        Create new instance from command line arguments object
        """
        persistent = not (args.unique_sim or args.gui)

        return cls(prefix=cls.find_prefix(),
                   output_path=output_path,
                   persistent=persistent,
                   gui=args.gui)

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find RivieraPro toolchain.

        Must have vsim and vsimsa binaries but no avhdl.exe
        """
        def no_avhdl(path):
            return not file_exists(join(path, "avhdl.exe"))
        return cls.find_toolchain(["vsim",
                                   "vsimsa"],
                                  constraints=[no_avhdl])

    @classmethod
    def get_osvvm_coverage_api(cls):
        """
        Returns simulator name when OSVVM coverage API is supported, None otherwise.
        """
        proc = Process([join(cls.find_prefix(), 'vcom'), '-version'],
                       env=cls.get_env())
        consumer = VersionConsumer()
        proc.consume_output(consumer)
        if consumer.year is not None:
            if (consumer.year == 2016 and consumer.month >= 10) or (consumer.year > 2016):
                return cls.name

        return None

    @classmethod
    def supports_vhdl_package_generics(cls):
        """
        Returns True when this simulator supports VHDL package generics
        """
        return True

    def __init__(self, prefix, output_path, persistent=False, gui=False):
        SimulatorInterface.__init__(self, output_path, gui)
        VsimSimulatorMixin.__init__(self, prefix, persistent,
                                    sim_cfg_file_name=join(output_path, "library.cfg"))
        self._create_library_cfg()
        self._libraries = []
        self._coverage_files = set()

    def add_simulator_specific(self, project):
        """
        Add builtin (global) libraries
        """
        built_in_libraries = self._get_mapped_libraries(self._builtin_library_cfg)

        for library_name in built_in_libraries:
            # A user might shadow a built in library with their own version
            if not project.has_library(library_name):
                project.add_builtin_library(library_name)

    def setup_library_mapping(self, project):
        """
        Setup library mapping
        """
        mapped_libraries = self._get_mapped_libraries(self._sim_cfg_file_name)
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

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a VHDL file
        """
        return ([join(self._prefix, 'vcom'), '-quiet', '-j', dirname(self._sim_cfg_file_name)]
                + source_file.compile_options.get("rivierapro.vcom_flags", [])
                + ['-' + source_file.get_vhdl_standard(), '-work', source_file.library.name, source_file.name])

    def compile_verilog_file_command(self, source_file):
        """
        Returns the command to compile a Verilog file
        """
        args = [join(self._prefix, 'vlog'), '-quiet', '-lc', self._sim_cfg_file_name]
        if source_file.is_system_verilog:
            args += ['-sv2k12']
        args += source_file.compile_options.get("rivierapro.vlog_flags", [])
        args += ['-work', source_file.library.name, source_file.name]
        for library in self._libraries:
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
            proc = Process([join(self._prefix, 'vlib'), library_name, path],
                           cwd=dirname(self._sim_cfg_file_name),
                           env=self.get_env())
            proc.consume_output(callback=None)

        if library_name in mapped_libraries and mapped_libraries[library_name] == path:
            return

        proc = Process([join(self._prefix, 'vmap'), library_name, path],
                       cwd=dirname(self._sim_cfg_file_name),
                       env=self.get_env())
        proc.consume_output(callback=None)

    def _create_library_cfg(self):
        """
        Create the library.cfg file if it does not exist
        """
        if file_exists(self._sim_cfg_file_name):
            return

        with open(self._sim_cfg_file_name, "w") as ofile:
            ofile.write('$INCLUDE = "%s"\n' % self._builtin_library_cfg)

    @property
    def _builtin_library_cfg(self):
        return join(self._prefix, "..", "vlib", "library.cfg")

    _library_re = re.compile(r'([a-zA-Z_0-9]+)\s=\s(.*)')

    def _get_mapped_libraries(self, library_cfg_file):
        """
        Get mapped libraries by running vlist on the working directory
        """
        lines = []
        proc = Process([join(self._prefix, 'vlist')], cwd=dirname(library_cfg_file))
        proc.consume_output(callback=lines.append)

        libraries = {}
        for line in lines:
            match = self._library_re.match(line)
            if match is None:
                continue
            key = match.group(1)
            value = match.group(2)
            libraries[key] = abspath(join(dirname(library_cfg_file), dirname(value)))
        return libraries

    def _create_load_function(self,
                              test_suite_name,  # pylint: disable=unused-argument
                              config, output_path):
        """
        Create the vunit_load TCL function that runs the vsim command and loads the design
        """
        set_generic_str = " ".join(('-g/%s/%s=%s' % (config.entity_name,
                                                     name,
                                                     format_generic(value))
                                    for name, value in config.generics.items()))
        pli_str = " ".join("-pli \"%s\"" % fix_path(name) for name in config.sim_options.get('pli', []))

        vsim_flags = ["-dataset {%s}" % fix_path(join(output_path, "dataset.asdb")),
                      pli_str,
                      set_generic_str]

        if config.sim_options.get("enable_coverage", False):
            coverage_file_path = join(output_path, "coverage.acdb")
            self._coverage_files.add(coverage_file_path)
            vsim_flags += ["-acdb_file {%s}" % coverage_file_path]

        vsim_flags += [self._vsim_extra_args(config)]

        if config.sim_options.get("disable_ieee_warnings", False):
            vsim_flags.append("-ieee_nowarn")

        # Add the the testbench top-level unit last as coverage is
        # only collected for the top-level unit specified last
        vsim_flags += ["-lib",
                       config.library_name,
                       config.entity_name]

        if config.architecture_name is not None:
            vsim_flags.append(config.architecture_name)

        tcl = """
proc vunit_load {{}} {{
    # Make the variable 'aldec' visible; otherwise, the Matlab interface
    # is broken because vsim does not find the library aldec_matlab_cosim.
    global aldec

    set vsim_failed [catch {{
        eval vsim {{{vsim_flags}}}
    }}]

    if {{${{vsim_failed}}}} {{
        return true
    }}

    if {{[_vunit_source_init_files_after_load]}} {{
        return true
    }}

    vhdlassert.break {break_level}
    vhdlassert.break -builtin {break_level}

    return false
}}
""".format(vsim_flags=" ".join(vsim_flags),
           break_level=config.vhdl_assert_stop_level)

        return tcl

    def _vsim_extra_args(self, config):
        """
        Determine vsim_extra_args
        """
        vsim_extra_args = []
        vsim_extra_args = config.sim_options.get("rivierapro.vsim_flags",
                                                 vsim_extra_args)

        if self._gui:
            vsim_extra_args = config.sim_options.get("rivierapro.vsim_flags.gui",
                                                     vsim_extra_args)

        return " ".join(vsim_extra_args)

    @staticmethod
    def _create_run_function():
        """
        Create the vunit_run function to run the test bench
        """
        return """
proc _vunit_run_failure {} {
    catch {
        # tb command can fail when error comes from pli
        echo "Stack trace result from 'bt' command"
        bt
    }
}

proc _vunit_run {} {
    proc on_break {} {
        resume
    }
    onbreak {on_break}

    run -all
}

proc _vunit_sim_restart {} {
    restart
}
"""

    def merge_coverage(self, file_name, args=None):
        """
        Merge coverage from all test cases,
        """

        # Teardown to ensure acdb file was written.
        self._persistent_shell.teardown()

        merge_command = "acdb merge"

        for coverage_file in self._coverage_files:
            if file_exists(coverage_file):
                merge_command += " -i {%s}" % coverage_file.replace('\\', '/')
            else:
                LOGGER.warning("Missing coverage file: %s", coverage_file)

        if args is not None:
            merge_command += " " + " ".join("{%s}" % arg for arg in args)

        merge_command += " -o {%s}" % file_name.replace('\\', '/')

        merge_script_name = join(self._output_path, "acdb_merge.tcl")
        with open(merge_script_name, "w") as fptr:
            fptr.write(merge_command + "\n")

        vcover_cmd = [join(self._prefix, 'vsim'), '-c', '-do',
                      'source %s; quit;' % merge_script_name.replace('\\', '/')]

        print("Merging coverage files into %s..." % file_name)
        vcover_merge_process = Process(vcover_cmd,
                                       env=self.get_env())
        vcover_merge_process.consume_output()
        print("Done merging coverage files")


def format_generic(value):
    """
    Generic values with space in them need to be quoted
    """
    value_str = str(value)
    if " " in value_str:
        return '"%s"' % value_str
    return value_str


class VersionConsumer(object):
    """
    Consume version information
    """
    def __init__(self):
        self.year = None
        self.month = None

    _version_re = re.compile(r'(?P<year>\d+)\.(?P<month>\d+)\.\d+')

    def __call__(self, line):
        match = self._version_re.search(line)
        if match is not None:
            self.year = int(match.group('year'))
            self.month = int(match.group('month'))
        return True
