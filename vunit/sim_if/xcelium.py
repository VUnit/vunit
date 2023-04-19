# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

"""
Interface for the Cadence Xcelium simulator
"""

from pathlib import Path
from os.path import relpath
from typing import Dict, List
from copy import copy
import sys
import os
import stat
import subprocess
import logging
from ..exceptions import CompileError
from ..ostools import write_file, file_exists, simplify_path
from ..vhdl_standard import VHDL
from . import SimulatorInterface, run_command, ListOfStringOption, check_output
from .cds_file import CDSFile
from ..color_printer import NO_COLOR_PRINTER
from ..configuration import Configuration
from ..project import Project
from vunit.source_file import SourceFile
from vunit.library import Library


LOGGER = logging.getLogger(__name__)


class XceliumInterface(  # pylint: disable=too-many-instance-attributes
    SimulatorInterface
):
    """
    Interface for the Cadence Xcelium simulator
    """

    name = "xcelium"
    supports_gui_flag = True
    package_users_depend_on_bodies = False
    incremental = False

    compile_options = [
        ListOfStringOption("xcelium.xrun_vhdl_flags"),
        ListOfStringOption("xcelium.xrun_verilog_flags"),
        ListOfStringOption("xcelium.xrun_cdslib"),
    ]

    sim_options = [ListOfStringOption("xcelium.xrun_sim_flags"),
                   ListOfStringOption("xcelium.xrun_sim_flags.gui")]

    _global_compile_options: Dict

    @staticmethod
    def add_arguments(parser):
        """
        Add command line arguments
        """
        group = parser.add_argument_group(
            "Xcelium/Incisive", description="Xcelium/Incisive specific flags"
        )
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
        group.add_argument(
            "--use_indago",
            default=False,
            help="Indicate whether to use Indago instead of Simvision when running in GUI mode.",
            action="store_true",
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
            use_indago=args.use_indago
        )

    @classmethod
    def find_prefix_from_path(cls):
        """
        Find xcelium simulator from PATH environment variable
        """
        return cls.find_toolchain(["xrun"])


    @staticmethod
    def supports_vhdl_contexts():
        """
        Returns True when this simulator supports VHDL 2008 contexts
        """
        return True

    def __init__(  # pylint: disable=too-many-arguments
        self, prefix, output_path, gui=False, log_level=None, cdslib=None, hdlvar=None, use_indago=False
    ):
        SimulatorInterface.__init__(self, output_path, gui)
        self._global_compile_options = {}
        self._prefix = prefix
        self._libraries = []
        self._log_level = log_level
        if cdslib is None:
            self._cdslib = str((Path(output_path) / "cds.lib").resolve())
        else:
            self._cdslib = str(Path(cdslib).resolve())
        self._hdlvar = hdlvar
        self._use_indago = use_indago
        self._cds_root_xrun = self.find_cds_root_xrun()


    def find_cds_root_xrun(self):
        """
        Finds xrun cds root
        """
        return subprocess.check_output(
            [str(Path(self._prefix) / "cds_root"), "xrun"]
        ).splitlines()[0].decode()

    def find_cds_root_virtuoso(self):
        """
        Finds virtuoso cds root
        """
        try:
            return subprocess.check_output(
                [str(Path(self._prefix) / "cds_root"), "virtuoso"],
                stderr=subprocess.STDOUT
            ).splitlines()[0].decode()
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

# user defined cds by changing: global.xcelium.xrun_cdslib
""".format(
                self._cds_root_xrun, self._output_path
            )
        else:
            contents = """\
## cds.lib: Defines the locations of compiled libraries.
softinclude {0}/tools/inca/files/cds.lib
# needed for referencing the library 'basic' for cells 'cds_alias', 'cds_thru' etc. in analog models:
define basic "{1}/tools/dfII/etc/cdslib/basic"
define work "{2}/libraries/work"

# user defined cds by changing: global.xcelium.xrun_cdslib
""".format(
                self._cds_root_xrun, cds_root_virtuoso, self._output_path
            )


        # add our cdslib customization
        xrun_cdslibs = self.get_global_compile_option("xcelium.xrun_cdslib")
        for xrun_cdslib in xrun_cdslibs:
            contents += xrun_cdslib + "\n"


        contents += "\n"
        contents += "# project libraries \n"
        write_file(self._cdslib, contents)

    def set_global_compile_options(self, global_options: Dict):
        self._global_compile_options = global_options

    def get_global_compile_option(self, name):
        """
        Return a copy of the compile option list
        """
        if name not in self._global_compile_options:
            self._global_compile_options[name] = []

        return copy(self._global_compile_options[name])

    def setup_library_mapping(self, project: Project):
        """
        Compile project using vhdl_standard
        """
        self._create_cdslib()
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

        LOGGER.error("Unknown file type: %s", source_file.file_type)
        raise CompileError

    def _compile_all_source_files(self, source_files_by_library: Dict[Library, List[SourceFile]], printer):
        """
        Compiles all source files and prints status information
        """
        try:
            command = self.compile_all_files_command(source_files_by_library)
        except CompileError:
            command = None
            printer.write("failed", fg="ri")
            printer.write("\n")
            printer.write(f"File type not supported by {self.name!s} simulator\n")

            return False

        try:
            output = check_output(command, env=self.get_env())
            printer.write("passed", fg="gi")
            printer.write("\n")
            printer.write(output)

        except subprocess.CalledProcessError as err:
            printer.write("failed", fg="ri")
            printer.write("\n")
            printer.write(f"=== Command used: ===\n{subprocess.list2cmdline(command)!s}\n")
            printer.write("\n")
            printer.write(f"=== Command output: ===\n{err.output!s}\n")

            return False

        return True

    def compile_source_files(
        self,
        project: Project,
        printer=NO_COLOR_PRINTER,
        continue_on_error=False,
        target_files=None,
    ):
        """
        Use compile_source_file_command to compile all source_files
        param: target_files: Given a list of SourceFiles only these and dependent files are compiled
        """
        dependency_graph = project.create_dependency_graph()
        failures = []

        if target_files is None:
            source_files: List[SourceFile] = project.get_files_in_compile_order(dependency_graph=dependency_graph)
        else:
            source_files: List[SourceFile] = project.get_minimal_file_set_in_compile_order(target_files)

        source_files_to_skip = set()

        max_library_name = 0
        max_source_file_name = 0
        if source_files:
            max_library_name = max(len(source_file.library.name) for source_file in source_files)
            max_source_file_name = max(len(simplify_path(source_file.name)) for source_file in source_files)

        source_files_by_library: Dict[Library, List[SourceFile]] = {}
        for source_file in source_files:
            if source_file.library in source_files_by_library:
                source_files_by_library[source_file.library].append(source_file)
            else:
                source_files_by_library[source_file.library] = [source_file]
        # import pprint
        # pprint.pprint(source_files_by_library)

        printer.write("Compiling all source files")
        sys.stdout.flush()
        if self._compile_all_source_files(source_files_by_library, printer):
            printer.write("All source files compiled!\n")
            printer.write("Compile passed\n", fg="gi")
        else:
            printer.write("One or more source files failed to compile.\n")
            printer.write("Compile failed\n", fg="ri")
            raise CompileError


    @staticmethod
    def _vhdl_std_opt(vhdl_standard):
        """
        Convert standard to format of xrun command line flag
        """
        if vhdl_standard == VHDL.STD_2002:
            return "-v200x -extv200x"

        if vhdl_standard == VHDL.STD_2008:
            return "-v200x -extv200x -inc_v200x_pkg"

        if vhdl_standard == VHDL.STD_1993:
            return "-v93"

        raise ValueError("Invalid VHDL standard %s" % vhdl_standard)

    def _compile_all_files_in_library_subcommand(self, library, source_files):
        """
        Return a command to compile all source files in a library
        """
        args = []
        args += ["-makelib %s" % library.directory]
        search_list = []

        for source_file in source_files:
            unique_args = []
            if source_file.is_vhdl:
                unique_args += ["%s" % self._vhdl_std_opt(source_file.get_vhdl_standard())]
                unique_args += source_file.get_compile_option("xcelium.xrun_vhdl_flags", include_global=False)

            if source_file.is_any_verilog:
                unique_args += source_file.get_compile_option("xcelium.xrun_verilog_flags", include_global=False)
                for include_dir in source_file.include_dirs:
                    if include_dir not in search_list:
                        search_list.append(include_dir)
                for key, value in source_file.defines.items():
                    unique_args += ["-define %s=%s" % (key, value.replace('"', '\\"'))]

            args += [source_file.name]
            if len(unique_args) > 0:
                # args += ["-filemap %s" % source_file.name]
                args += unique_args
                # args += ["-endfilemap"]
            else:
                # args += [source_file.name]
                pass

        for include_dir in search_list:
                args += ['-incdir "%s"' % include_dir]

        args += ["-endlib"]
        argsfile = str(
            Path(self._output_path)
            / ("xrun_compile_library_%s.args" % library.name)
        )
        write_file(argsfile, "\n".join(args))
        return ["-F", argsfile]


    def compile_all_files_command(self, source_files: Dict[Library, List[SourceFile]]):
        """
        Return a command to compile all source files
        """
        first_library = True
        launch_gui = self._gui is not False
        use_indago = self._use_indago is not False

        cmd = str(Path(self._prefix) / "xrun")
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
        args += ['-cdslib "%s"' % self._cdslib]
        args += self._hdlvar_args()
        args += [
            '-log "%s"'
            % str(
                Path(self._output_path)
                / ("xrun_compile_all.log")
            )
        ]
        if not self._log_level == "debug":
            args += ["-quiet"]
        else:
            args += ["-messages"]
            args += ["-libverbose"]
        # for "disciplines.vams" etc.
        args += ['-incdir "%s/tools/spectre/etc/ahdl/"' % self._cds_root_xrun]

        args += self.get_global_compile_option("xcelium.xrun_vhdl_flags")
        args += self.get_global_compile_option("xcelium.xrun_verilog_flags")

        args += ["-define XCELIUM "]
        if launch_gui and use_indago:
            args += ["-debug_opts indago_interactive"]
            args += ["-linedebug"]
            #args += ["-uvmlinedebug"]

        for library, _source_files in source_files.items():
            if first_library:
                args += ['-xmlibdirname "%s"' % str(Path(library.directory).parent)]
                first_library = False

            args += self._compile_all_files_in_library_subcommand(library, _source_files)

        argsfile = str(
            Path(self._output_path)
            / ("xrun_compile_all.args")
        )
        write_file(argsfile, "\n".join(args))
        return [cmd, "-F", argsfile, "-clean"]

    def compile_vhdl_file_command(self, source_file):
        """
        Returns command to compile a VHDL file
        """
        cmd = str(Path(self._prefix) / "xrun")
        args = []
        args += ["-compile"]
        args += ["-nocopyright"]
        args += ["-licqueue"]
        args += ["-nowarn DLCPTH"]  # "cds.lib Invalid path"
        args += ["-nowarn DLCVAR"]  # "cds.lib Invalid environment variable ''."
        args += ["%s" % self._vhdl_std_opt(source_file.get_vhdl_standard())]
        args += ['-cdslib "%s"' % self._cdslib]
        args += self._hdlvar_args()
        args += [
            '-log "%s"'
            % str(
                Path(self._output_path)
                / ("xrun_compile_vhdl_file_%s.log" % source_file.library.name)
            )
        ]
        if not self._log_level == "debug":
            args += ["-quiet"]
        else:
            args += ["-messages"]
            args += ["-libverbose"]
        args += source_file.compile_options.get("xcelium.xrun_vhdl_flags", [])
        args += ['-xmlibdirname "%s"' % str(Path(source_file.library.directory).parent)]
        args += ["-makelib %s" % source_file.library.directory]
        args += ['"%s"' % source_file.name]
        args += ["-endlib"]
        argsfile = str(
            Path(self._output_path)
            / ("xrun_compile_vhdl_file_%s.args" % source_file.library.name)
        )
        write_file(argsfile, "\n".join(args))
        return [cmd, "-F", argsfile]

    def compile_verilog_file_command(self, source_file):
        """
        Returns commands to compile a Verilog file
        """
        cmd = str(Path(self._prefix) / "xrun")
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
        args += source_file.compile_options.get("xcelium.xrun_verilog_flags", [])
        args += ['-cdslib "%s"' % self._cdslib]
        args += self._hdlvar_args()
        args += [
            '-log "%s"'
            % str(
                Path(self._output_path)
                / ("xrun_compile_verilog_file_%s.log" % source_file.library.name)
            )
        ]
        if not self._log_level == "debug":
            args += ["-quiet"]
        else:
            args += ["-messages"]
            args += ["-libverbose"]
        for include_dir in source_file.include_dirs:
            args += ['-incdir "%s"' % include_dir]

        # for "disciplines.vams" etc.
        args += ['-incdir "%s/tools/spectre/etc/ahdl/"' % self._cds_root_xrun]

        for key, value in source_file.defines.items():
            args += ["-define %s=%s" % (key, value.replace('"', '\\"'))]
        args += ['-xmlibdirname "%s"' % str(Path(source_file.library.directory).parent)]
        args += ["-makelib %s" % source_file.library.name]
        args += ['"%s"' % source_file.name]
        args += ["-endlib"]
        argsfile = str(
            Path(self._output_path)
            / ("xrun_compile_verilog_file_%s.args" % source_file.library.name)
        )
        write_file(argsfile, "\n".join(args))
        return [cmd, "-F", argsfile]

    def create_library(self, library_name, library_path, mapped_libraries=None):
        """
        Create and map a library_name to library_path
        """
        mapped_libraries = mapped_libraries if mapped_libraries is not None else {}

        lpath = str(Path(library_path).resolve().parent)

        if not file_exists(lpath):
            os.makedirs(lpath)

        if (
            library_name in mapped_libraries
            and mapped_libraries[library_name] == library_path
        ):
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

    def simulate(  # pylint: disable=too-many-locals, too-many-branches
        self, output_path, test_suite_name, config:Configuration, elaborate_only=False
    ):
        """
        Elaborates and Simulates with entity as top level using generics
        """

        script_path = str(Path(output_path) / self.name)
        launch_gui = self._gui is not False and not elaborate_only
        use_indago = self._use_indago is not False


        rerun_file_path="%s/rerun.sh" % script_path
        rerun_content=[]
        rerun_content+=["#/bin/bash"]
        rerun_content+=["set -euo pipefail"]
        rerun_content+=["echo 'running compile all'"]
        rerun_content+=["xrun -F %s/xrun_compile_all.args" % Path(self._output_path)]
        rerun_content+=["echo 'running elaborate'"]
        rerun_content+=["xrun -F %s/xrun_elaborate.args" % script_path]
        write_file(rerun_file_path, "\n".join(rerun_content))
        st = os.stat(rerun_file_path)
        os.chmod(rerun_file_path, st.st_mode | stat.S_IEXEC)


        if elaborate_only:
            steps = ["elaborate"]
        else:
            steps = ["elaborate", "simulate"]

        for step in steps:
            cmd = str(Path(self._prefix) / "xrun")
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
            args += [
                "-xmerror EVBBOL"
            ]  # promote to error: "bad boolean literal in generic association"
            args += [
                "-xmerror EVBSTR"
            ]  # promote to error: "bad string literal in generic association"
            args += [
                "-xmerror EVBNAT"
            ]  # promote to error: "bad natural literal in generic association"
            args += [
                '-xmlibdirname "%s"' % (str(Path(self._output_path) / "libraries"))
            ]  # @TODO: ugly
            args += config.sim_options.get("xcelium.xrun_sim_flags", [])

            args += ['-cdslib "%s"' % self._cdslib]
            args += self._hdlvar_args()
            args += ['-log "%s"' % str(Path(script_path) / ("xrun_%s.log" % step))]
            if not self._log_level == "debug":
                args += ["-quiet"]
            else:
                args += ["-messages"]
                # args += ['-libverbose']
            args += self._generic_args(config.entity_name, config.generics)
            for library in self._libraries:
                args += ['-reflib "%s"' % library.directory]
            args += ['-input "@set intovf_severity_level ignore"']
            if config.sim_options.get("disable_ieee_warnings", False):
                args += [
                    '-input "@set pack_assert_off { std_logic_arith numeric_std }"'
                ]
            args += [
                '-input "@set assert_stop_level %s"' % config.vhdl_assert_stop_level
            ]
            if launch_gui:
                args += ["-access +rwc"]
                args += ['-linedebug']
                args += ['-classlinedebug']
                if use_indago:
                    args += ["-debug_opts indago_interactive"]
                    if step == "elaborate":
                        args += ['-persistent_sources_debug']
                    else:
                        args += ["-nolock"]
                else:
                    # Use simvision
                    args += ["-gui"]

                if step == "elaborate":
                    pass
                    #args += ["-uvmlinedebug"]

                gui_options = config.sim_options.get("xcelium.xrun_sim_flags.gui", [])
                if gui_options is not None:
                    args = gui_options + args
                else:
                    args += ['-input "@run"']
            else:
                args += ["-access +r"]
                args += ['-input "@run"']

            if config.architecture_name is None:
                # we have a SystemVerilog toplevel:
                args += ["-top %s.%s:sv" % (config.library_name, config.entity_name)]
            else:
                # we have a VHDL toplevel:
                args += [
                    "-top %s.%s:%s"
                    % (
                        config.library_name,
                        config.entity_name,
                        config.architecture_name,
                    )
                ]
            argsfile = "%s/xrun_%s.args" % (script_path, step)
            write_file(argsfile, "\n".join(args))
            if not run_command(
                [cmd, "-F", relpath(argsfile, script_path)],
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
        return ['-hdlvar "%s"' % self._hdlvar]

    @staticmethod
    def _generic_args(entity_name, generics):
        """
        Create xrun arguments for generics/parameters
        """
        args = []
        for name, value in generics.items():
            if _generic_needs_quoting(value):
                args += ['''-gpg "%s.%s => \\"%s\\""''' % (entity_name, name, value)]
            else:
                args += ['''-gpg "%s.%s => %s"''' % (entity_name, name, value)]
        return args


def _generic_needs_quoting(value):  # pylint: disable=missing-docstring
    return isinstance(value, (str, bool))
