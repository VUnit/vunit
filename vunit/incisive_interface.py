# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, 2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for the Cadence Incisive simulator
"""

from __future__ import print_function
import logging
LOGGER = logging.getLogger(__name__)

from vunit.ostools import Process, write_file, read_file, file_exists
from vunit.simulator_interface import SimulatorInterface
from vunit.exceptions import CompileError
from vunit.cds_file import CDSFile

from os.path import exists, join, dirname, abspath, relpath
import os
from distutils.spawn import find_executable
from sys import stdout  # To avoid output catched in non-verbose mode
import sys

class IncisiveInterface(SimulatorInterface):
    """
    Interface for the Cadence Incisive simulator
    """

    name = "incisive"
    supports_gui_flag = True
    package_users_depend_on_bodies = False

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group("Incisive irun",
                                          description="Incisive irun-specific flags")
        group.add_argument("--cdslib",
                           default=None,
                           help="The cds.lib file to use. If not given, VUnit maintains its own cds.lib file.")
        group.add_argument("--hdlvar",
                           default=None,
                           help="The hdl.var file to use. If not given, VUnit does not use a hdl.var file.")

    @classmethod
    def from_args(cls, output_path, args):
        """
        Create new instance from command line arguments object
        """
        return cls(output_path=output_path,
                   log_level=args.log_level,
                   gui=args.gui,
                   cdslib=args.cdslib,
                   hdlvar=args.hdlvar)

    @staticmethod
    def is_available():
        """
        Return True if irun is installed
        """
        return find_executable('irun') is not None

    @staticmethod
    def supports_vhdl_2008_contexts():
        """
        Returns True when this simulator supports VHDL 2008 contexts
        """
        return False

    def __init__(self, output_path, gui=False, log_level=None, cdslib=None, hdlvar=None):
        self._libraries = {}
        self._output_path = output_path
        self._vhdl_standard = None
        self._gui = gui
        self._log_level = log_level
        if cdslib == None:
            self._cdslib = abspath(join(output_path, 'cds.lib'))
        else:
            self._cdslib = abspath(cdslib)
        self._hdlvar = hdlvar
        self._cds_root_irun = Process(['cds_root', 'irun']).next_line()
        self._cds_root_virtuoso = Process(['cds_root', 'virtuoso']).next_line()
        self._create_cdslib()

    def _create_cdslib(self):
        """
        Create the cds.lib file in the output directory if it does not exist
        """
        if file_exists(self._cdslib):
            return
        if self._cds_root_virtuoso.startswith('ERROR'):
            write_file(self._cdslib, """## cds.lib: Defines the locations of compiled libraries.
softinclude {0}/tools/inca/files/cds.lib
# needed for referencing the library 'basic' for cells 'cds_alias', 'cds_thru' etc. in analog models:
# NOTE: 'virtuoso' executable not found!
# define basic ".../tools/dfII/etc/cdslib/basic"
define work "{1}/libraries/work"
""".format(self._cds_root_irun, self._output_path))
        else:
            write_file(self._cdslib, """## cds.lib: Defines the locations of compiled libraries.
softinclude {0}/tools/inca/files/cds.lib
# needed for referencing the library 'basic' for cells 'cds_alias', 'cds_thru' etc. in analog models:
define basic "{1}/tools/dfII/etc/cdslib/basic"
define work "{2}/libraries/work"
""".format(self._cds_root_irun, self._cds_root_virtuoso, self._output_path))

    def compile_project(self, project, vhdl_standard):
        """
        Compile project using vhdl_standard
        """
        self._vhdl_standard = vhdl_standard
        mapped_libraries = self._get_mapped_libraries()

        for library in project.get_libraries():
            self._libraries[library.name] = library
            self.create_library(library.name, library.directory, dirname(library.directory),
                                mapped_libraries)

        for source_file in project.get_files_in_compile_order():
            print('Compiling "' + source_file.name + '" into "' + source_file.library.name + '" ...')

            if source_file.file_type == 'vhdl':
                success = self.compile_vhdl_file(source_file.name,
                                                 source_file.library.name,
                                                 source_file.library.directory,
                                                 vhdl_standard,
                                                 source_file.compile_options)
            elif source_file.file_type == 'verilog':
                success = self.compile_verilog_file(source_file)
            else:
                raise RuntimeError("Unkown file type: " + source_file.file_type)

            if not success:
                raise CompileError("Failed to compile '%s'" % source_file.name)
            project.update(source_file)

    def _vhdl_std_opt(self):
        """
        Convert standard to format of irun command line flag
        """
        if self._vhdl_standard == "2002":
            return "-v200x -extv200x"
        elif self._vhdl_standard == "2008":
            return "-v200x -extv200x"
        elif self._vhdl_standard == "93":
            return "-v93"
        else:
            assert False

    def compile_vhdl_file(self,  # pylint: disable=too-many-arguments
                          source_file_name,
                          library_name,
                          library_path,
                          vhdl_standard,
                          compile_options):
        """
        Compiles a VHDL file
        """
        try:
            cmd = 'irun'
            args = []
            args += ['-compile']
            args += ['-nocopyright']
            args += ['-licqueue']
            args += ['-nowarn DLCPTH'] # "cds.lib Invalid path"
            args += ['-nowarn DLCVAR'] # "cds.lib Invalid environment variable ''."
            args += ['%s' % self._vhdl_std_opt()]
            args += ['-work work']
            args += ['-cdslib "%s"' % self._cdslib]
            if not self._hdlvar == None:
                args += ['-hdlvar "%s"' % self._hdlvar]
            args += ['-log "%s/irun_compile_vhdl_file.log"' % self._output_path]
            if not self._log_level == "debug":
                args += ['-quiet']
            else:
                args += ['-messages']
                args += ['-libverbose']
            args += compile_options.get('incisive_irun_vhdl_flags', [])
            args += ['-nclibdirname "%s"' % dirname(library_path)]
            args += ['-makelib %s' % library_path]
            args += ['"%s"' % source_file_name]
            args += ['-endlib']
            argsfile = "%s/irun_compile_vhdl_file.args" % self._output_path
            write_file(argsfile, "\n".join(args))
            proc = Process([cmd, '-f', argsfile])
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def compile_verilog_file(self, source_file):
        """
        Compiles a Verilog file
        """
        try:
            cmd = 'irun'
            args = []
            args += ['-compile']
            args += ['-nocopyright']
            args += ['-licqueue']
            args += ['-nowarn UEXPSC'] # "Ignored unexpected semicolon following SystemVerilog description keyword (endfunction)."
            args += ['-nowarn DLCPTH'] # "cds.lib Invalid path"
            args += ['-nowarn DLCVAR'] # "cds.lib Invalid environment variable ''."
            args += ['-work work']
            args += source_file.compile_options.get('incisive_irun_verilog_flags', [])
            args += ['-cdslib "%s"' % self._cdslib]
            if not self._hdlvar == None:
                args += ['-hdlvar "%s"' % self._hdlvar]
            args += ['-log "%s/irun_compile_verilog_file.log"' % self._output_path]
            if not self._log_level == "debug":
                args += ['-quiet']
            else:
                args += ['-messages']
                args += ['-libverbose']
            for include_dir in source_file.include_dirs:
                args += ['-incdir "%s"' % include_dir]
            args += ['-incdir "%s/tools/spectre/etc/ahdl/"' % self._cds_root_irun] # for "disciplines.vams" etc.
            for key, value in source_file.defines.items():
                args += ["-define %s=%s" % (key, value)]
            args += ['-nclibdirname "%s"' % dirname(source_file.library.directory)]
            args += ['-makelib %s' % source_file.library.name]
            args += ['"%s"' % source_file.name]
            args += ['-endlib']
            argsfile = "%s/irun_compile_verilog_file.args" % self._output_path
            write_file(argsfile, "\n".join(args))
            proc = Process([cmd, '-f', argsfile])
            proc.consume_output()
        except Process.NonZeroExitCode:
            return False
        return True

    def create_library(self, library_name, library_path, output_path, mapped_libraries=None):
        """
        Create and map a library_name to library_path
        """
        mapped_libraries = mapped_libraries if mapped_libraries is not None else {}

        if not file_exists(dirname(library_path)):
            os.makedirs(dirname(library_path))

        if not file_exists(library_path):
            proc = Process(['mkdir', '-p', library_path])
            proc.consume_output(callback=None)

        if library_name in mapped_libraries and mapped_libraries[library_name] == library_path:
            return

        cds = CDSFile.parse(self._cdslib)
        cds[library_name] = library_path
        cds.write(self._cdslib)

    def _get_mapped_libraries(self):
        """
        Get mapped libraries from cds.lib file
        """
        cds = CDSFile.parse(self._cdslib)
        return cds

    def simulate(self,  # pylint: disable=too-many-arguments, too-many-locals
                 output_path, library_name, entity_name, architecture_name, config):
        """
        Elaborates and Simulates with entity as top level using generics
        """

        launch_gui = self._gui is not False and not config.elaborate_only

        status = True
        if config.elaborate_only:
            steps = ['elaborate']
        else:
            steps = ['elaborate', 'simulate']
        for step in steps:
            try:
                cmd = 'irun'
                args = []
                if step == 'elaborate':
                    args += ['-elaborate']
                args += ['-nocopyright']
                args += ['-licqueue']
                #args += ['-dumpstack']
                #args += ['-gdbsh']
                #args += ['-rebuild']
                #args += ['-gdb']
                #args += ['-gdbelab']
                args += ['-errormax 10']
                args += ['-nowarn WRMNZD']
                args += ['-nowarn DLCPTH'] # "cds.lib Invalid path"
                args += ['-nowarn DLCVAR'] # "cds.lib Invalid environment variable ''."
                args += ['-ncerror EVBBOL'] # promote to error: "bad boolean literal in generic association"
                args += ['-ncerror EVBSTR'] # promote to error: "bad string literal in generic association"
                args += ['-ncerror EVBNAT'] # promote to error: "bad natural literal in generic association"
                args += ['-work work']
                args += ['-nclibdirname "%s"' % (join(self._output_path, "libraries"))] # FIXME: ugly
                if config.options.get('incisive_irun_sim_flags'):
                    args +=  config.options.get('incisive_irun_sim_flags')
                args += ['-cdslib "%s"' % self._cdslib]
                if not self._hdlvar == None:
                    args += ['-hdlvar "%s"' % self._hdlvar]
                args += ['-log "%s/irun_%s.log"' % (self._output_path, step)]
                if not self._log_level == "debug":
                    args += ['-quiet']
                else:
                    args += ['-messages']
                    #args += ['-libverbose']
                for name, value in config.generics.items():
                    if _generic_needs_quoting(value):
                        args += ['''-gpg "%s.%s => \\"%s\\""''' % (entity_name, name, value)]
                    else:
                        args += ['''-gpg "%s.%s => %s"''' % (entity_name, name, value)]
                for library in self._libraries.values():
                    args += ['-reflib "%s"' % library.directory]
                if launch_gui:
                    args += ['-access +rwc']
                    args += ['-gui']
                else:
                    args += ['-access +r']
                    args += ['-input "@stop -delta 10000 -timestep -delbreak 1"']
                    args += ['-input "@run"']
                    # Try hierarchical path formats for both VHDL and Verilog, but don't throw an error if not found.
                    #args += ['-input "@catch {puts #vunit_pkg::__runner__.exit_without_errors}"']
                    #args += ['-input "@catch {puts #run_base_pkg.runner.exit_without_errors}"']
                    # NOTE: do not exit with 1 or 2 in case of error, that seems to mean something special to Incisive:
                    args += ['-input "@catch {if {#vunit_pkg::__runner__.exit_without_errors == 1} {exit 0} else {exit 42}}"']
                    args += ['-input "@catch {if {#run_base_pkg.runner.exit_without_errors == \\"TRUE\\"} {exit 0} else {exit 42}}"']
                if architecture_name is None:
                    # we have a SystemVerilog toplevel:
                    args += ['-top %s' % join('%s.%s:sv' % (library_name, entity_name))]
                else:
                    # we have a VHDL toplevel:
                    args += ['-top %s' % join('%s.%s:%s' % (library_name, entity_name, architecture_name))]
                argsfile = "%s/irun_%s.args" % (self._output_path, step)
                write_file(argsfile, "\n".join(args))
                proc = Process([cmd, '-f', argsfile])
                proc.consume_output()
            except Process.NonZeroExitCode:
                status = False

        return status

def _generic_needs_quoting(value):
    if sys.version_info.major == 2:
        if isinstance(value, str) or isinstance(value, bool) or isinstance(value, unicode):
            return True
        else:
            return False
    else:
        if isinstance(value, str) or isinstance(value, bool):
            return True
        else:
            return False
