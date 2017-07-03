# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards Aldec Riviera Pro
"""


from __future__ import print_function

from os.path import join, dirname, abspath
import os
import re
import logging
from vunit.ostools import Process, file_exists
from vunit.simulator_interface import SimulatorInterface
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
        "rivierapro.vcom_flags",
        "rivierapro.vlog_flags",
    ]

    sim_options = [
        "rivierapro.vsim_flags",
        "rivierapro.vsim_flags.gui",
        "rivierapro.init_file.gui",
    ]

    @classmethod
    def from_args(cls, output_path, args):
        """
        Create new instance from command line arguments object
        """
        persistent = not (args.unique_sim or args.gui)

        return cls(prefix=cls.find_prefix(),
                   library_cfg=join(output_path, "library.cfg"),
                   persistent=persistent,
                   coverage=args.coverage,
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

    def __init__(self, prefix, library_cfg="library.cfg", persistent=False, gui=False, coverage=None):
        SimulatorInterface.__init__(self)
        VsimSimulatorMixin.__init__(self, prefix, persistent, gui, library_cfg)
        self._create_library_cfg()
        self._libraries = []
        self._coverage = coverage
        self._coverage_files = set()

    def add_simulator_specific(self, project):
        """
        Add coverage flags
        """
        if self._coverage is None:
            return

        # Add coverage options
        for source_file in project.get_source_files_in_order():
            source_file.add_compile_option("rivierapro.vcom_flags", ['-coverage', self._coverage])
            source_file.add_compile_option("rivierapro.vlog_flags", ['-coverage', self._coverage])

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
        return ([join(self._prefix, 'vcom'), '-quiet', '-j', dirname(self._sim_cfg_file_name)] +
                source_file.compile_options.get("rivierapro.vcom_flags", []) +
                ['-' + source_file.get_vhdl_standard(), '-work', source_file.library.name, source_file.name])

    def compile_verilog_file_command(self, source_file):
        """
        Returns the command to compile a Verilog file
        """
        args = [join(self._prefix, 'vlog'), '-quiet', '-sv2k12', '-lc', self._sim_cfg_file_name]
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
            ofile.write('$INCLUDE = "%s"\n' % join(self._prefix, "..", "vlib", "library.cfg"))

    _library_re = re.compile(r'([a-zA-Z_0-9]+)\s=\s"(.*)"')

    def _get_mapped_libraries(self):
        """
        Get mapped libraries from library.cfg file
        """
        with open(self._sim_cfg_file_name, "r") as fptr:
            text = fptr.read()

        libraries = {}
        for line in text.splitlines():
            match = self._library_re.match(line)
            if match is None:
                continue
            key = match.group(1)
            value = match.group(2)
            libraries[key] = abspath(join(dirname(self._sim_cfg_file_name), dirname(value)))
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

        if self._coverage is None:
            coverage_args = ""
            coverage_file = ""
        else:
            coverage_args = "-acdb_cov " + self._coverage
            coverage_file_path = join(output_path, "coverage.acdb")
            self._coverage_files.add(coverage_file_path)
            coverage_file = "-acdb_file {%s}" % coverage_file_path

        vsim_flags = ["-dataset {%s}" % fix_path(join(output_path, "dataset.asdb")),
                      pli_str,
                      set_generic_str,
                      "-lib",
                      config.library_name,
                      config.entity_name,
                      coverage_args,
                      coverage_file,
                      self._vsim_extra_args(config)]

        if config.architecture_name is not None:
            vsim_flags.append(config.architecture_name)

        if config.sim_options.get("disable_ieee_warnings", False):
            vsim_flags.append("-ieee_nowarn")

        tcl = """
proc vunit_load {{}} {{
    # Make the variable 'aldec' visible; otherwise, the Matlab interface
    # is broken because vsim does not find the library aldec_matlab_cosim.
    global aldec
    set vsim_failed [catch {{
        eval vsim {{{vsim_flags}}}
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

    vhdlassert.break {break_level}
    vhdlassert.break -builtin {break_level}

    return 0
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
proc vunit_run {} {
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

proc _vunit_sim_restart {} {
    restart
}
"""

    def post_process(self, output_path):
        """
        Merge coverage from all test cases,
        """

        if self._coverage is None:
            return

        # Teardown to ensure acdb file was written.
        del self._persistent_shell

        merged_coverage_file = join(output_path, "merged_coverage.acdb")
        merge_command = "acdb merge"

        for coverage_file in self._coverage_files:
            if file_exists(coverage_file):
                merge_command += " -i {%s}" % coverage_file.replace('\\', '/')
            else:
                LOGGER.warning("Missing coverage file: %s", coverage_file)

        merge_command += " -o {%s}" % merged_coverage_file.replace('\\', '/')

        vcover_cmd = [join(self._prefix, 'vsim'), '-c', '-do', '%s; quit;' % merge_command]

        print("Merging coverage files into %s..." % merged_coverage_file)
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
