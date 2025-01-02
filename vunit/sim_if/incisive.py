# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for the Cadence Incisive simulator
"""

from pathlib import Path
from os.path import relpath
import os
import subprocess
import logging
from ..exceptions import CompileError
from ..ostools import write_file, file_exists
from ..vhdl_standard import VHDL
from . import SimulatorInterface, run_command, ListOfStringOption
from .cds_file import CDSFile

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

    sim_options = [ListOfStringOption("incisive.irun_sim_flags")]

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group("Incisive irun", description="Incisive irun-specific flags")
        group.add_argument(
            "--cdslib",
            default=None,
            help="The cds.lib file to use. If not given, VUnit maintains its own cds.lib file.",
        )
        group.add_argument(
            "--hdlvar",
            default=None,
            help="The hdl.var file to use. If not given, VUnit does not use a hdl.var file.",
        )

    @classmethod
    def from_args(cls, args, output_path, **kwargs):
        """
        Create new instance from command line arguments object
        """
        return cls(
            prefix=cls.find_prefix(),
            output_path=output_path,
            log_level=args.log_level,
            gui=args.gui,
            cdslib=args.cdslib,
            hdlvar=args.hdlvar,
        )

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find incisive simulator from PATH environment variable
        """
        return cls.find_toolchain(["irun"])

    @staticmethod
    def supports_vhdl_contexts():
        """
        Returns True when this simulator supports VHDL 2008 contexts
        """
        return False

    def __init__(  # pylint: disable=too-many-arguments
        self, prefix, output_path, *, gui=False, log_level=None, cdslib=None, hdlvar=None
    ):
        SimulatorInterface.__init__(self, output_path, gui)
        self._prefix = prefix
        self._libraries = []
        self._log_level = log_level
        if cdslib is None:
            self._cdslib = str((Path(output_path) / "cds.lib").resolve())
        else:
            self._cdslib = str(Path(cdslib).resolve())
        self._hdlvar = hdlvar
        self._cds_root_irun = self.find_cds_root_irun()
        self._create_cdslib()

    def find_cds_root_irun(self):
        """
        Finds irun cds root
        """
        return subprocess.check_output([str(Path(self._prefix) / "cds_root"), "irun"]).splitlines()[0]

    def find_cds_root_virtuoso(self):
        """
        Finds virtuoso cds root
        """
        try:
            return subprocess.check_output([str(Path(self._prefix) / "cds_root"), "virtuoso"]).splitlines()[0]
        except subprocess.CalledProcessError:
            return None

    def _create_cdslib(self):
        """
        Create the cds.lib file in the output directory if it does not exist
        """
        cds_root_virtuoso = self.find_cds_root_virtuoso()

        contents = (
            f"""\
## cds.lib: Defines the locations of compiled libraries.
softinclude {self._cds_root_irun}/tools/inca/files/cds.lib
# needed for referencing the library 'basic' for cells 'cds_alias', 'cds_thru' etc. in analog models:
# NOTE: 'virtuoso' executable not found!
# define basic ".../tools/dfII/etc/cdslib/basic"
define work "{self._output_path}/libraries/work"
"""
            if cds_root_virtuoso is None
            else f"""\
## cds.lib: Defines the locations of compiled libraries.
softinclude {self._cds_root_irun}/tools/inca/files/cds.lib
# needed for referencing the library 'basic' for cells 'cds_alias', 'cds_thru' etc. in analog models:
define basic "{cds_root_virtuoso}/tools/dfII/etc/cdslib/basic"
define work "{self._output_path}/libraries/work"
"""
        )

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
        if vhdl_standard == VHDL.STD_2002:
            return "-v200x -extv200x"

        if vhdl_standard == VHDL.STD_2008:
            return "-v200x -extv200x"

        if vhdl_standard == VHDL.STD_1993:
            return "-v93"

        raise ValueError(f"Invalid VHDL standard {vhdl_standard!s}")

    def compile_vhdl_file_command(self, source_file):
        """
        Returns command to compile a VHDL file
        """
        cmd = str(Path(self._prefix) / "irun")
        args = []
        args += ["-compile"]
        args += ["-nocopyright"]
        args += ["-licqueue"]
        args += ["-nowarn DLCPTH"]  # "cds.lib Invalid path"
        args += ["-nowarn DLCVAR"]  # "cds.lib Invalid environment variable ''."
        args += [str(self._vhdl_std_opt(source_file.get_vhdl_standard()))]
        args += ["-work work"]
        args += [f'-cdslib "{self._cdslib!s}"']
        args += self._hdlvar_args()
        args += [f'-log "{(Path(self._output_path) / f"irun_compile_vhdl_file_{source_file.library.name!s}.log")!s}"']
        if not self._log_level == "debug":
            args += ["-quiet"]
        else:
            args += ["-messages"]
            args += ["-libverbose"]
        args += source_file.compile_options.get("incisive.irun_vhdl_flags", [])
        args += [f'-nclibdirname "{Path(source_file.library.directory).parent!s}"']
        args += [f"-makelib {source_file.library.directory!s}"]
        args += [f'"{source_file.name!s}"']
        args += ["-endlib"]
        argsfile = str(Path(self._output_path) / f"irun_compile_vhdl_file_{source_file.library.name!s}.args")
        write_file(argsfile, "\n".join(args))
        return [cmd, "-f", argsfile]

    def compile_verilog_file_command(self, source_file):
        """
        Returns commands to compile a Verilog file
        """
        cmd = str(Path(self._prefix) / "irun")
        args = []
        args += ["-compile"]
        args += ["-nocopyright"]
        args += ["-licqueue"]
        # "Ignored unexpected semicolon following SystemVerilog description keyword (endfunction)."
        args += ["-nowarn UEXPSC"]
        # "cds.lib Invalid path"
        args += ["-nowarn DLCPTH"]
        # "cds.lib Invalid environment variable ''."
        args += ["-nowarn DLCVAR"]
        args += ["-work work"]
        args += source_file.compile_options.get("incisive.irun_verilog_flags", [])
        args += [f'-cdslib "{self._cdslib!s}"']
        args += self._hdlvar_args()
        args += [
            f'-log "{(Path(self._output_path) / f"irun_compile_verilog_file_{source_file.library.name!s}.log")!s}"'
        ]
        if not self._log_level == "debug":
            args += ["-quiet"]
        else:
            args += ["-messages"]
            args += ["-libverbose"]
        for include_dir in source_file.include_dirs:
            args += [f'-incdir "{include_dir!s}"']

        # for "disciplines.vams" etc.
        args += [f'-incdir "{self._cds_root_irun!s}/tools/spectre/etc/ahdl/"']

        for key, value in source_file.defines.items():
            val = value.replace('"', '\\"')
            args += [f"-define {key!s}={val!s}"]
        args += [f'-nclibdirname "{Path(source_file.library.directory).parent!s}"']
        args += [f"-makelib {source_file.library.name!s}"]
        args += [f'"{source_file.name!s}"']
        args += ["-endlib"]
        argsfile = str(Path(self._output_path) / f"irun_compile_verilog_file_{source_file.library.name!s}.args")
        write_file(argsfile, "\n".join(args))
        return [cmd, "-f", argsfile]

    def create_library(self, library_name, library_path, mapped_libraries=None):
        """
        Create and map a library_name to library_path
        """
        mapped_libraries = mapped_libraries if mapped_libraries is not None else {}

        lpath = str(Path(library_path).resolve().parent)

        if not file_exists(lpath):
            os.makedirs(lpath)

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

    @staticmethod
    def _select_vhdl_top(config):
        "Select VHDL configuration or entity as top."
        if config.vhdl_configuration_name is None:
            return f"{config.library_name!s}.{config.entity_name!s}:{config.architecture_name!s}"

        return f"{config.vhdl_configuration_name!s}"

    def simulate(
        self, output_path, test_suite_name, config, elaborate_only=False
    ):  # pylint: disable=too-many-locals,too-many-branches
        """
        Elaborates and Simulates with entity as top level using generics
        """

        script_path = str(Path(output_path) / self.name)
        launch_gui = self._gui is not False and not elaborate_only

        if elaborate_only:
            steps = ["elaborate"]
        else:
            steps = ["elaborate", "simulate"]

        for step in steps:
            cmd = str(Path(self._prefix) / "irun")
            args = []
            if step == "elaborate":
                args += ["-elaborate"]
            args += ["-nocopyright"]
            args += ["-licqueue"]
            # args += ['-dumpstack']
            # args += ['-gdbsh']
            # args += ['-rebuild']
            # args += ['-gdb']
            # args += ['-gdbelab']
            args += ["-errormax 10"]
            args += ["-nowarn WRMNZD"]
            args += ["-nowarn DLCPTH"]  # "cds.lib Invalid path"
            args += ["-nowarn DLCVAR"]  # "cds.lib Invalid environment variable ''."
            args += ["-ncerror EVBBOL"]  # promote to error: "bad boolean literal in generic association"
            args += ["-ncerror EVBSTR"]  # promote to error: "bad string literal in generic association"
            args += ["-ncerror EVBNAT"]  # promote to error: "bad natural literal in generic association"
            args += ["-work work"]
            args += [f'-nclibdirname "{Path(self._output_path) / "libraries"!s}"']  # @TODO: ugly
            args += config.sim_options.get("incisive.irun_sim_flags", [])
            args += [f'-cdslib "{self._cdslib!s}"']
            args += self._hdlvar_args()
            args += [f'-log "{(Path(script_path) / f"irun_{step!s}.log")!s}"']
            if not self._log_level == "debug":
                args += ["-quiet"]
            else:
                args += ["-messages"]
                # args += ['-libverbose']
            args += self._generic_args(config.entity_name, config.generics)
            for library in self._libraries:
                args += [f'-reflib "{library.directory!s}"']
            if launch_gui:
                args += ["-access +rwc"]
                # args += ['-linedebug']
                args += ["-gui"]
            else:
                args += ["-access +r"]
                args += ['-input "@run"']

            if config.architecture_name is None:
                # we have a SystemVerilog toplevel:
                args += [f"-top {config.library_name!s}.{config.entity_name!s}:sv"]
            else:
                # we have a VHDL toplevel:
                args += [f"-top {self._select_vhdl_top(config)}"]

            argsfile = f"{script_path!s}/irun_{step!s}.args"
            write_file(argsfile, "\n".join(args))
            if not run_command(
                [cmd, "-f", relpath(argsfile, script_path)],
                cwd=script_path,
                env=self.get_env(),
            ):
                return False
        return True

    def _hdlvar_args(self):
        """
        Return hdlvar argument if available
        """
        if self._hdlvar is None:
            return []
        return [f'-hdlvar "{self._hdlvar!s}"']

    @staticmethod
    def _generic_args(entity_name, generics):
        """
        Create irun arguments for generics/parameters
        """
        args = []
        for name, value in generics.items():
            args += (
                [f'''-gpg "{entity_name!s}.{name!s} => \\"{value!s}\\""''']
                if _generic_needs_quoting(value)
                else [f'''-gpg "{entity_name!s}.{name!s} => {value!s}"''']
            )
        return args


def _generic_needs_quoting(value):  # pylint: disable=missing-docstring
    return isinstance(value, (str, bool))
