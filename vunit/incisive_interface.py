# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for the Cadence Incisive simulator
"""

from __future__ import print_function
import os
from os.path import join, dirname, abspath, relpath
import subprocess
import sys
import logging
from vunit.ostools import write_file, file_exists
from vunit.simulator_interface import (SimulatorInterface,
                                       run_command,
                                       ListOfStringOption)
from vunit.exceptions import CompileError
from vunit.cds_file import CDSFile
LOGGER = logging.getLogger(__name__)


class IncisiveInterface(SimulatorInterface):  # pylint: disable=too-many-instance-attributes
    """
    Interface for the Cadence Incisive simulator
    """

    name = "incisive"
    supports_gui_flag = True
    package_users_depend_on_bodies = False

    compile_options = [
        ListOfStringOption("incisive.irun_vhdl_flags"),
        ListOfStringOption("incisive.irun_verilog_flags"),
    ]

    sim_options = [
        ListOfStringOption("incisive.irun_sim_flags")
    ]

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
    def from_args(cls, args, output_path, **kwargs):
        """
        Create new instance from command line arguments object
        """
        return cls(prefix=cls.find_prefix(),
                   output_path=output_path,
                   log_level=args.log_level,
                   gui=args.gui,
                   cdslib=args.cdslib,
                   hdlvar=args.hdlvar)

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find incisive simulator from PATH environment variable
        """
        return cls.find_toolchain(['irun'])

    @staticmethod
    def supports_vhdl_2008_contexts():
        """
        Returns True when this simulator supports VHDL 2008 contexts
        """
        return False

    def __init__(self,  # pylint: disable=too-many-arguments
                 prefix, output_path, gui=False, log_level=None, cdslib=None, hdlvar=None):
        SimulatorInterface.__init__(self, output_path, gui)
        self._prefix = prefix
        self._libraries = []
        self._log_level = log_level
        if cdslib is None:
            self._cdslib = abspath(join(output_path, 'cds.lib'))
        else:
            self._cdslib = abspath(cdslib)
        self._hdlvar = hdlvar
        self._cds_root_irun = self.find_cds_root_irun()
        self._create_cdslib()

    def find_cds_root_irun(self):
        """
        Finds irun cds root
        """
        return subprocess.check_output([join(self._prefix, 'cds_root'), 'irun']).splitlines()[0]

    def find_cds_root_virtuoso(self):
        """
        Finds virtuoso cds root
        """
        try:
            return subprocess.check_output([join(self._prefix, 'cds_root'), 'virtuoso']).splitlines()[0]
        except subprocess.CalledProcessError:
            return None

    def _create_cdslib(self):
        """
        Create the cds.lib file in the output directory if it does not exist
        """
        cds_root_virtuoso = self.find_cds_root_virtuoso()

        if cds_root_virtuoso is None:
            contents = """\
## cds.lib: Defines the locations of compiled libraries.
softinclude {0}/tools/inca/files/cds.lib
# needed for referencing the library 'basic' for cells 'cds_alias', 'cds_thru' etc. in analog models:
# NOTE: 'virtuoso' executable not found!
# define basic ".../tools/dfII/etc/cdslib/basic"
define work "{1}/libraries/work"
""".format(self._cds_root_irun, self._output_path)
        else:
            contents = """\
## cds.lib: Defines the locations of compiled libraries.
softinclude {0}/tools/inca/files/cds.lib
# needed for referencing the library 'basic' for cells 'cds_alias', 'cds_thru' etc. in analog models:
define basic "{1}/tools/dfII/etc/cdslib/basic"
define work "{2}/libraries/work"
""".format(self._cds_root_irun, cds_root_virtuoso, self._output_path)

        write_file(self._cdslib, contents)

    def setup_library_mapping(self, project):
        """
        Compile project using vhdl_standard
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

        if source_file.is_any_verilog:
            return self.compile_verilog_file_command(source_file)

        raise CompileError

    @staticmethod
    def _vhdl_std_opt(vhdl_standard):
        """
        Convert standard to format of irun command line flag
        """
        if vhdl_standard == "2002":
            return "-v200x -extv200x"

        if vhdl_standard == "2008":
            return "-v200x -extv200x"

        if vhdl_standard == "93":
            return "-v93"

        raise ValueError("Invalid VHDL standard %s" % vhdl_standard)

    def compile_vhdl_file_command(self, source_file):
        """
        Returns command to compile a VHDL file
        """
        cmd = join(self._prefix, 'irun')
        args = []
        args += ['-compile']
        args += ['-nocopyright']
        args += ['-licqueue']
        args += ['-nowarn DLCPTH']  # "cds.lib Invalid path"
        args += ['-nowarn DLCVAR']  # "cds.lib Invalid environment variable ''."
        args += ['%s' % self._vhdl_std_opt(source_file.get_vhdl_standard())]
        args += ['-work work']
        args += ['-cdslib "%s"' % self._cdslib]
        args += self._hdlvar_args()
        args += ['-log "%s"' % join(self._output_path, "irun_compile_vhdl_file_%s.log" % source_file.library.name)]
        if not self._log_level == "debug":
            args += ['-quiet']
        else:
            args += ['-messages']
            args += ['-libverbose']
        args += source_file.compile_options.get('incisive.irun_vhdl_flags', [])
        args += ['-nclibdirname "%s"' % dirname(source_file.library.directory)]
        args += ['-makelib %s' % source_file.library.directory]
        args += ['"%s"' % source_file.name]
        args += ['-endlib']
        argsfile = join(self._output_path, "irun_compile_vhdl_file_%s.args" % source_file.library.name)
        write_file(argsfile, "\n".join(args))
        return [cmd, '-f', argsfile]

    def compile_verilog_file_command(self, source_file):
        """
        Returns commands to compile a Verilog file
        """
        cmd = join(self._prefix, 'irun')
        args = []
        args += ['-compile']
        args += ['-nocopyright']
        args += ['-licqueue']
        # "Ignored unexpected semicolon following SystemVerilog description keyword (endfunction)."
        args += ['-nowarn UEXPSC']
        # "cds.lib Invalid path"
        args += ['-nowarn DLCPTH']
        # "cds.lib Invalid environment variable ''."
        args += ['-nowarn DLCVAR']
        args += ['-work work']
        args += source_file.compile_options.get('incisive.irun_verilog_flags', [])
        args += ['-cdslib "%s"' % self._cdslib]
        args += self._hdlvar_args()
        args += ['-log "%s"' % join(self._output_path, "irun_compile_verilog_file_%s.log" % source_file.library.name)]
        if not self._log_level == "debug":
            args += ['-quiet']
        else:
            args += ['-messages']
            args += ['-libverbose']
        for include_dir in source_file.include_dirs:
            args += ['-incdir "%s"' % include_dir]

        # for "disciplines.vams" etc.
        args += ['-incdir "%s/tools/spectre/etc/ahdl/"' % self._cds_root_irun]

        for key, value in source_file.defines.items():
            args += ['-define %s=%s' % (key, value.replace('"', '\\"'))]
        args += ['-nclibdirname "%s"' % dirname(source_file.library.directory)]
        args += ['-makelib %s' % source_file.library.name]
        args += ['"%s"' % source_file.name]
        args += ['-endlib']
        argsfile = join(self._output_path, "irun_compile_verilog_file_%s.args" % source_file.library.name)
        write_file(argsfile, "\n".join(args))
        return [cmd, '-f', argsfile]

    def create_library(self, library_name, library_path, mapped_libraries=None):
        """
        Create and map a library_name to library_path
        """
        mapped_libraries = mapped_libraries if mapped_libraries is not None else {}

        if not file_exists(dirname(abspath(library_path))):
            os.makedirs(dirname(abspath(library_path)))

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

    def simulate(self,  # pylint: disable=too-many-locals
                 output_path, test_suite_name, config, elaborate_only=False):
        """
        Elaborates and Simulates with entity as top level using generics
        """

        script_path = join(output_path, self.name)
        launch_gui = self._gui is not False and not elaborate_only

        if elaborate_only:
            steps = ['elaborate']
        else:
            steps = ['elaborate', 'simulate']

        for step in steps:
            cmd = join(self._prefix, 'irun')
            args = []
            if step == 'elaborate':
                args += ['-elaborate']
            args += ['-nocopyright']
            args += ['-licqueue']
            # args += ['-dumpstack']
            # args += ['-gdbsh']
            # args += ['-rebuild']
            # args += ['-gdb']
            # args += ['-gdbelab']
            args += ['-errormax 10']
            args += ['-nowarn WRMNZD']
            args += ['-nowarn DLCPTH']  # "cds.lib Invalid path"
            args += ['-nowarn DLCVAR']  # "cds.lib Invalid environment variable ''."
            args += ['-ncerror EVBBOL']  # promote to error: "bad boolean literal in generic association"
            args += ['-ncerror EVBSTR']  # promote to error: "bad string literal in generic association"
            args += ['-ncerror EVBNAT']  # promote to error: "bad natural literal in generic association"
            args += ['-work work']
            args += ['-nclibdirname "%s"' % (join(self._output_path, "libraries"))]  # @TODO: ugly
            args += config.sim_options.get('incisive.irun_sim_flags', [])
            args += ['-cdslib "%s"' % self._cdslib]
            args += self._hdlvar_args()
            args += ['-log "%s"' % join(script_path, "irun_%s.log" % step)]
            if not self._log_level == "debug":
                args += ['-quiet']
            else:
                args += ['-messages']
                # args += ['-libverbose']
            args += self._generic_args(config.entity_name, config.generics)
            for library in self._libraries:
                args += ['-reflib "%s"' % library.directory]
            if launch_gui:
                args += ['-access +rwc']
                # args += ['-linedebug']
                args += ['-gui']
            else:
                args += ['-access +r']
                args += ['-input "@run"']

            if config.architecture_name is None:
                # we have a SystemVerilog toplevel:
                args += ['-top %s' % join('%s.%s:sv' % (config.library_name, config.entity_name))]
            else:
                # we have a VHDL toplevel:
                args += ['-top %s' % join('%s.%s:%s' % (config.library_name, config.entity_name,
                                                        config.architecture_name))]
            argsfile = "%s/irun_%s.args" % (script_path, step)
            write_file(argsfile, "\n".join(args))
            if not run_command([cmd, '-f', relpath(argsfile, script_path)], cwd=script_path, env=self.get_env()):
                return False
        return True

    def _hdlvar_args(self):
        """
        Return hdlvar argument if available
        """
        if self._hdlvar is None:
            return []
        return ['-hdlvar "%s"' % self._hdlvar]

    @staticmethod
    def _generic_args(entity_name, generics):
        """
        Create irun arguments for generics/parameters
        """
        args = []
        for name, value in generics.items():
            if _generic_needs_quoting(value):
                args += ['''-gpg "%s.%s => \\"%s\\""''' % (entity_name, name, value)]
            else:
                args += ['''-gpg "%s.%s => %s"''' % (entity_name, name, value)]
        return args


def _generic_needs_quoting(value):  # pylint: disable=missing-docstring
    if sys.version_info.major == 2:
        return isinstance(value, (str, bool, unicode))  # pylint: disable=undefined-variable

    return isinstance(value, (str, bool))
