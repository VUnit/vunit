# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2017, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface towards Mentor Graphics ModelSim
"""


from __future__ import print_function

import logging
import sys
import io
import os
from os.path import join, dirname, abspath
try:
    # Python 3
    from configparser import RawConfigParser
except ImportError:
    # Python 2
    from ConfigParser import RawConfigParser  # pylint: disable=import-error

from vunit.ostools import Process, file_exists
from vunit.simulator_interface import (SimulatorInterface,
                                       ListOfStringOption,
                                       StringOption)
from vunit.exceptions import CompileError
from vunit.vsim_simulator_mixin import (VsimSimulatorMixin,
                                        fix_path)

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
        StringOption("modelsim.init_file.gui"),
    ]

    @classmethod
    def from_args(cls, output_path, args):
        """
        Create new instance from command line arguments object
        """
        persistent = not (args.unique_sim or args.gui)

        return cls(prefix=cls.find_prefix(),
                   modelsim_ini=join(output_path, "modelsim.ini"),
                   persistent=persistent,
                   coverage=args.coverage,
                   gui=args.gui)

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find first valid modelsim toolchain prefix
        """
        def has_modelsim_ini(path):
            return os.path.isfile(join(path, "..", "modelsim.ini"))

        return cls.find_toolchain(["vsim"],
                                  constraints=[has_modelsim_ini])

    @classmethod
    def supports_vhdl_package_generics(cls):
        """
        Returns True when this simulator supports VHDL package generics
        """
        return True

    def __init__(self, prefix, modelsim_ini="modelsim.ini", persistent=False, gui=False, coverage=None):
        SimulatorInterface.__init__(self)
        VsimSimulatorMixin.__init__(self, prefix, persistent, gui, modelsim_ini)
        self._libraries = []
        self._coverage = coverage
        self._coverage_files = set()
        assert not (persistent and gui)
        self._create_modelsim_ini()

    def _create_modelsim_ini(self):
        """
        Create the modelsim.ini file if it does not exist
        """
        if file_exists(self._sim_cfg_file_name):
            return

        parent = dirname(self._sim_cfg_file_name)
        if not file_exists(parent):
            os.makedirs(parent)

        original_modelsim_ini = os.environ.get("VUNIT_MODELSIM_INI",
                                               join(self._prefix, "..", "modelsim.ini"))
        with open(original_modelsim_ini, 'rb') as fread:
            with open(self._sim_cfg_file_name, 'wb') as fwrite:
                fwrite.write(fread.read())

    def add_simulator_specific(self, project):
        """
        Add libraries from modelsim.ini file and add coverage flags
        """
        mapped_libraries = self._get_mapped_libraries()
        for library_name in mapped_libraries:
            if not project.has_library(library_name):
                project.add_builtin_library(library_name)

        if self._coverage is None:
            return

        # Add coverage options
        for source_file in project.get_source_files_in_order():
            source_file.add_compile_option("modelsim.vcom_flags", ["+cover=" + self._coverage])
            source_file.add_compile_option("modelsim.vlog_flags", ["+cover=" + self._coverage])

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
        elif source_file.is_any_verilog:
            return self.compile_verilog_file_command(source_file)

        LOGGER.error("Unknown file type: %s", source_file.file_type)
        raise CompileError

    def compile_vhdl_file_command(self, source_file):
        """
        Returns the command to compile a vhdl file
        """
        return ([join(self._prefix, 'vcom'), '-quiet', '-modelsimini', self._sim_cfg_file_name] +
                source_file.compile_options.get("modelsim.vcom_flags", []) +
                ['-' + source_file.get_vhdl_standard(), '-work', source_file.library.name, source_file.name])

    def compile_verilog_file_command(self, source_file):
        """
        Returns the command to compile a verilog file
        """
        args = [join(self._prefix, 'vlog'), '-quiet', '-modelsimini', self._sim_cfg_file_name]
        if source_file.is_system_verilog:
            args += ["-sv"]
        args += source_file.compile_options.get("modelsim.vlog_flags", [])
        args += ['-work', source_file.library.name, source_file.name]

        for library in self._libraries:
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
            proc = Process([join(self._prefix, 'vlib'), '-unix', path],
                           env=self.get_env())
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

    def _create_load_function(self,  # pylint: disable=too-many-arguments
                              test_suite_name, config, output_path):
        """
        Create the vunit_load TCL function that runs the vsim command and loads the design
        """

        set_generic_str = " ".join(('-g/%s/%s=%s' % (config.entity_name,
                                                     name,
                                                     encode_generic_value(value))
                                    for name, value in config.generics.items()))
        pli_str = " ".join("-pli {%s}" % fix_path(name) for name in config.sim_options.get('pli', []))

        if config.architecture_name is None:
            architecture_suffix = ""
        else:
            architecture_suffix = "(%s)" % config.architecture_name

        if self._coverage is None:
            coverage_save_cmd = ""
            coverage_args = ""
        else:
            coverage_file = join(output_path, "coverage.ucdb")
            self._coverage_files.add(coverage_file)
            coverage_save_cmd = (
                "coverage save -onexit -testname {%s} -assert -directive -cvg -codeAll {%s}"
                % (test_suite_name, fix_path(coverage_file)))

            coverage_args = "-coverage"

        vsim_flags = ["-wlf {%s}" % fix_path(join(output_path, "vsim.wlf")),
                      "-quiet",
                      "-t ps",
                      # for correct handling of verilog fatal/finish
                      "-onfinish stop",
                      pli_str,
                      set_generic_str,
                      config.library_name + "." + config.entity_name + architecture_suffix,
                      coverage_args,
                      self._vsim_extra_args(config)]

        # There is a known bug in modelsim that prevents the -modelsimini flag from accepting
        # a space in the path even with escaping, see issue #36
        if " " not in self._sim_cfg_file_name:
            vsim_flags.insert(0, "-modelsimini %s" % fix_path(self._sim_cfg_file_name))

        for library in self._libraries:
            vsim_flags += ["-L", library.name]

        vhdl_assert_stop_level_mapping = dict(warning=1, error=2, failure=3)

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

    if {{[_vunit_source_init_files_after_load]}} {{
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


    global BreakOnAssertion
    set BreakOnAssertion {break_on_assert}

    global NumericStdNoWarnings
    set NumericStdNoWarnings {no_warnings}

    global StdArithNoWarnings
    set StdArithNoWarnings {no_warnings}

    {coverage_save_cmd}
    return 0
}}
""".format(coverage_save_cmd=coverage_save_cmd,
           vsim_flags=" ".join(vsim_flags),
           break_on_assert=vhdl_assert_stop_level_mapping[config.vhdl_assert_stop_level],
           no_warnings=1 if config.sim_options.get("disable_ieee_warnings", False) else 0)

        return tcl

    @staticmethod
    def _create_run_function():
        """
        Create the vunit_run function to run the test bench
        """
        return """
proc _vunit_run {} {
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

proc _vunit_sim_restart {} {
    restart -f
}
"""

    def _vsim_extra_args(self, config):
        """
        Determine vsim_extra_args
        """
        vsim_extra_args = []
        vsim_extra_args = config.sim_options.get("modelsim.vsim_flags",
                                                 vsim_extra_args)

        if self._gui:
            vsim_extra_args = config.sim_options.get("modelsim.vsim_flags.gui",
                                                     vsim_extra_args)

        return " ".join(vsim_extra_args)

    def post_process(self, output_path):
        """
        Merge coverage from all test cases,
        top hierarchy level is removed since it has different name in each test case
        """
        if self._coverage is None:
            return

        # Teardown to ensure ucdb file was written.
        del self._persistent_shell

        merged_coverage_file = join(output_path, "merged_coverage.ucdb")
        vcover_cmd = [join(self._prefix, 'vcover'), 'merge', '-strip', '1', merged_coverage_file]

        for coverage_file in self._coverage_files:
            if file_exists(coverage_file):
                vcover_cmd.append(coverage_file)
            else:
                LOGGER.warning("Missing coverage file: %s", coverage_file)

        print("Merging coverage files into %s..." % merged_coverage_file)
        vcover_merge_process = Process(vcover_cmd,
                                       env=self.get_env())
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
        return '{"%s"}' % s_value
    if "," in s_value:
        return '"%s"' % s_value
    return s_value


def parse_modelsimini(file_name):
    """
    Parse a modelsim.ini file
    :returns: A RawConfigParser object
    """
    cfg = RawConfigParser()
    if sys.version_info.major == 2:
        # For Python 2 read modelsim.ini as binary file since ConfigParser
        # does not support unicode
        with io.open(file_name, "rb") as fptr:
            cfg.readfp(fptr)  # pylint: disable=deprecated-method
    else:
        with io.open(file_name, "r", encoding="utf-8") as fptr:
            cfg.read_file(fptr)
    return cfg


def write_modelsimini(cfg, file_name):
    """
    Writes a modelsim.ini file
    """
    if sys.version_info.major == 2:
        # For Python 2 write modelsim.ini as binary file since ConfigParser
        # does not support unicode
        with io.open(file_name, "wb") as optr:
            cfg.write(optr)
    else:
        with io.open(file_name, "w", encoding="utf-8") as optr:
            cfg.write(optr)
