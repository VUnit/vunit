# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-lines

"""
.. autoclass:: vunit.ui.VUnit()
   :members:
   :exclude-members: add_preprocessor,
      enable_location_preprocessing,
      enable_check_preprocessing
      add_builtins

.. autoclass:: vunit.ui.Library()
   :members:
   :exclude-members: package

.. autoclass:: vunit.ui.SourceFileList()
   :members:

.. autoclass:: vunit.ui.SourceFile()
   :members:

.. autoclass:: vunit.ui.TestBench()
   :members:

.. autoclass:: vunit.ui.Test()
   :members:

.. _compile_options:

Compilation Options
-------------------
Compilation options allow customization of compilation behavior. Since simulators have
differing options available, generic options may be specified through this interface.
The following compilation options are known.

``ghdl.flags``
   Extra arguments passed to ``ghdl -a`` command during compilation.
   Must be a list of strings.

``modelsim.vcom_flags``
   Extra arguments passed to ModelSim ``vcom`` command.
   Must be a list of strings.

``modelsim.vlog_flags``
   Extra arguments passed to ModelSim ``vlog`` command.
   Must be a list of strings.

``rivierapro.vcom_flags``
   Extra arguments passed to Riviera PRO ``vcom`` command.
   Must be a list of strings.

``rivierapro.vlog_flags``
   Extra arguments passed to Riviera PRO ``vlog`` command.
   Must be a list of strings.

``activehdl.vcom_flags``
   Extra arguments passed to Active HDL ``vcom`` command.
   Must be a list of strings.

``activehdl.vlog_flags``
   Extra arguments passed to Active HDL ``vcom`` command.
   Must be a list of strings.

.. note::
   Only affects source files added *before* the option is set.

.. _sim_options:

Simulation Options
-------------------
Simulation options allow customization of simulation behavior. Since simulators have
differing options available, generic options may be specified through this interface.
The following simulation options are known.

``modelsim.vsim_flags``
   Extra arguments passed to ``vsim`` when loading the design.
   Must be a list of strings.

``modelsim.vsim_flags.gui``
   Extra arguments passed to ``vsim`` when loading the design in GUI
   mode where it takes precedence over ``modelsim.vsim_flags``.
   Must be a list of strings.

``rivierapro.vsim_flags``
   Extra arguments passed to ``vsim`` when loading the design.
   Must be a list of strings.

``rivierapro.vsim_flags.gui``
   Extra arguments passed to ``vsim`` when loading the design in GUI
   mode where it takes precedence over ``rivierapro.vsim_flags``.
   Must be a list of strings.

``ghdl.elab_flags``
   Extra elaboration flags passed to ``ghdl --elab-run``.
   Must be a list of strings.

``ghdl.sim_flags``
   Extra simulation flags passed to ``ghdl --elab-run``.
   Must be a list of strings.

.. |compile_option| replace::
   The name of the compile option (See :ref:`Compilation options <compile_options>`)

.. |simulation_options| replace::
   The name of the simulation option (See :ref:`Simulation options <sim_options>`)

"""


from __future__ import print_function

import sys
import traceback
import logging
import os
from os.path import exists, abspath, join, basename, splitext
from glob import glob
from fnmatch import fnmatch
from vunit.database import PickledDataBase, DataBase
import vunit.ostools as ostools
from vunit.vunit_cli import VUnitCLI
from vunit.simulator_factory import SimulatorFactory
from vunit.color_printer import (COLOR_PRINTER,
                                 NO_COLOR_PRINTER)
from vunit.project import Project, file_type_of, check_vhdl_standard
from vunit.test_runner import TestRunner
from vunit.test_report import TestReport
from vunit.test_scanner import TestScanner, TestScannerError, tb_filter
from vunit.test_configuration import TestConfiguration, create_scope
from vunit.exceptions import CompileError
from vunit.location_preprocessor import LocationPreprocessor
from vunit.check_preprocessor import CheckPreprocessor
from vunit.vhdl_parser import CachedVHDLParser
from vunit.parsing.verilog.parser import VerilogParser
from vunit.builtins import (add_vhdl_builtins,
                            add_verilog_include_dir,
                            add_array_util,
                            add_osvvm,
                            add_com)
from vunit.com import codec_generator

LOGGER = logging.getLogger(__name__)


class VUnit(object):  # pylint: disable=too-many-instance-attributes, too-many-public-methods
    """
    The public interface of VUnit

    :example:

    .. code-block:: python

       from vunit import VUnit
    """

    @classmethod
    def from_argv(cls, argv=None, compile_builtins=True):
        """
        Create VUnit instance from command line arguments.

        :param argv: Use explicit argv instead of actual command line argument
        :param compile_builtins: Do not compile builtins. Used for VUnit internal testing.
        :returns: A :class:`.VUnit` object instance

        :example:

        .. code-block:: python

           from vunit import VUnit
           prj = VUnit.from_argv()

        """
        args = VUnitCLI().parse_args(argv=argv)
        return cls.from_args(args, compile_builtins=compile_builtins)

    @classmethod
    def from_args(cls, args, compile_builtins=True):
        """
        Create VUnit instance from args namespace.
        Intended for users who adds custom command line options.
        See :class:`vunit.vunit_cli.VUnitCLI` class to learn about
        adding custom command line options.

        :param args: The parsed argument namespace object
        :param compile_builtins: Do not compile builtins. Used for VUnit internal testing.
        :returns: A :class:`.VUnit` object instance
        """
        def test_filter(name):
            return any(fnmatch(name, pattern) for pattern in args.test_patterns)

        return cls(output_path=args.output_path,
                   clean=args.clean,
                   vhdl_standard=select_vhdl_standard(),
                   use_debug_codecs=args.use_debug_codecs,
                   no_color=args.no_color,
                   verbose=args.verbose,
                   xunit_xml=args.xunit_xml,
                   log_level=args.log_level,
                   test_filter=test_filter,
                   list_only=args.list,
                   list_files_only=args.files,
                   compile_only=args.compile,
                   keep_compiling=args.keep_compiling,
                   elaborate_only=args.elaborate,
                   compile_builtins=compile_builtins,
                   simulator_factory=SimulatorFactory(args),
                   num_threads=args.num_threads,
                   exit_0=args.exit_0)

    def __init__(self,  # pylint: disable=too-many-locals, too-many-arguments
                 output_path,
                 simulator_factory,
                 clean=False,
                 use_debug_codecs=False,
                 no_color=False,
                 verbose=False,
                 xunit_xml=None,
                 log_level="warning",
                 test_filter=None,
                 list_only=False,
                 list_files_only=False,
                 compile_only=False,
                 keep_compiling=False,
                 elaborate_only=False,
                 vhdl_standard='2008',
                 compile_builtins=True,
                 num_threads=1,
                 exit_0=False):

        self._configure_logging(log_level)
        self._elaborate_only = elaborate_only
        self._output_path = abspath(output_path)

        if no_color:
            self._printer = NO_COLOR_PRINTER
        else:
            self._printer = COLOR_PRINTER

        self._verbose = verbose
        self._xunit_xml = xunit_xml

        self._test_filter = test_filter if test_filter is not None else lambda name: True
        self._list_only = list_only
        self._list_files_only = list_files_only
        self._compile_only = compile_only
        self._keep_compiling = keep_compiling
        self._vhdl_standard = vhdl_standard

        self._tb_filter = tb_filter
        self._configuration = TestConfiguration()
        self._external_preprocessors = []
        self._location_preprocessor = None
        self._check_preprocessor = None
        self._use_debug_codecs = use_debug_codecs

        self._simulator_factory = simulator_factory
        self._create_output_path(clean)

        self._project = None
        self._create_project()
        self._num_threads = num_threads
        self._exit_0 = exit_0
        self._library_facades = {}

        if compile_builtins:
            self.add_builtins(library_name="vunit_lib")

    def _create_project(self):
        """
        Create Project instance
        """
        database = self._create_database()
        self._project = Project(
            vhdl_parser=CachedVHDLParser(database=database),
            verilog_parser=VerilogParser(database=database),
            depend_on_package_body=self._simulator_factory.package_users_depend_on_bodies())

    def _create_database(self):
        """
        Create a persistent database to store expensive parse results

        Check for Python version used to create the database is the
        same as the running python instance or re-create
        """
        project_database_file_name = join(self._output_path, "project_database")
        create_new = False
        key = b"version"
        version = str((6, sys.version)).encode()
        database = None
        try:
            database = DataBase(project_database_file_name)
            create_new = (key not in database) or (database[key] != version)
        except KeyboardInterrupt:
            raise
        except:  # pylint: disable=bare-except
            traceback.print_exc()
            create_new = True

        if create_new:
            database = DataBase(project_database_file_name, new=True)
        database[key] = version

        return PickledDataBase(database)

    @staticmethod
    def _configure_logging(log_level):
        """
        Configure logging based on log_level string
        """
        level = getattr(logging, log_level.upper())
        logging.basicConfig(filename=None, format='%(levelname)7s - %(message)s', level=level)

    def add_external_library(self, library_name, path):
        """
        Add an externally compiled library as a black-box

        :param library_name: The name of the external library
        :param path: The path to the external library
        :returns: The created :class:`.Library` object

        :example:

        .. code-block:: python

           prj.add_external_library("unisim", "path/to/unisim/")

        """
        self._project.add_library(library_name, abspath(path), is_external=True)
        return self._create_library_facade(library_name)

    def add_library(self, library_name, vhdl_standard=None):
        """
        Add a library managed by VUnit.

        :param library_name: The name of the library
        :param vhdl_standard: The VHDL standard used to compile files into this library,
                              if None the VUNIT_VHDL_STANDARD environment variable is used
        :returns: The created :class:`.Library` object

        :example:

        .. code-block:: python

           library = prj.add_library("lib")

        """
        if vhdl_standard is None:
            vhdl_standard = self._vhdl_standard
        path = join(self._simulator_factory.simulator_output_path, "libraries", library_name)
        self._project.add_library(library_name, abspath(path))
        return self._create_library_facade(library_name, vhdl_standard)

    def library(self, library_name):
        """
        Get a library

        :param library_name: The name of the library
        :returns: A :class:`.Library` object
        """
        if not self._project.has_library(library_name):
            raise KeyError(library_name)
        return self._create_library_facade(library_name)

    def _create_library_facade(self, library_name, vhdl_standard=None):
        """
        Create a Library object to be exposed to users

        Re-use Library facade instances internally since vhdl_standard is contained in them
        """
        if library_name in self._library_facades:
            return self._library_facades[library_name]
        facade = Library(library_name, self, self._project, self._configuration, vhdl_standard)
        self._library_facades[library_name] = facade
        return facade

    def set_generic(self, name, value):
        """
        Globally set a value of generic

        :param name: The name of the generic
        :param value: The value of the generic

        :example:

        .. code-block:: python

           prj.set_generic("data_width", 16)

        """
        self._configuration.set_generic(name.lower(), value, scope=create_scope())

    def set_parameter(self, name, value):
        """
        Globally set value of parameter

        :param name: The name of the parameter
        :param value: The value of the parameter

        :example:

        .. code-block:: python

           prj.set_parameter("data_width", 16)

        """
        self._configuration.set_generic(name, value, scope=create_scope())

    def set_sim_option(self, name, value):
        """
        Globally set simulation option

        :param name: |simulation_options|
        :param value: The value of the simulation option

        :example:

        .. code-block:: python

           prj.set_sim_option("ghdl.flags", ["--no-vital-checks"])

        """
        self._configuration.set_sim_option(name, value, scope=create_scope())

    def set_compile_option(self, name, value):
        """
        Globally set compile option

        :param name: |compile_option|
        :param value: The value of the compile option

        :example:

        .. code-block:: python

           prj.set_compile_option("ghdl.flags", ["--no-vital-checks"])

        """
        for source_file in self._project.get_source_files_in_order():
            source_file.set_compile_option(name, value)

    def add_compile_option(self, name, value):
        """
        Globally add compile option

        :param name: |compile_option|
        :param value: The value of the compile option
        """
        for source_file in self._project.get_source_files_in_order():
            source_file.add_compile_option(name, value)

    def set_pli(self, value):
        """
        Globally Set pli

        :param value: A list of PLI object file names
        """
        self._configuration.set_pli(value, scope=create_scope())

    def disable_ieee_warnings(self):
        """
        Globally disable ieee warnings
        """
        self._configuration.disable_ieee_warnings(scope=create_scope())

    def get_source_file(self, file_name, library_name=None):
        """
        Get a source file

        :param file_name: The name of the file as a relative or absolute path
        :param library_name: The name of a specific library to search if not all libraries
        :returns: A :class:`.SourceFile` object
        """

        files = self.get_source_files(file_name, library_name, allow_empty=True)
        if len(files) > 1:
            raise ValueError("Found file named '%s' in multiple-libraries, "
                             "add explicit library_name." % file_name)
        elif len(files) == 0:
            if library_name is None:
                raise ValueError("Found no file named '%s'" % file_name)
            else:
                raise ValueError("Found no file named '%s' in library '%s'"
                                 % (file_name, library_name))
        return files[0]

    def get_source_files(self, pattern="*", library_name=None, allow_empty=False):
        """
        Get a list of source files

        :param pattern: A wildcard pattern matching either an absolute or relative path
        :param library_name: The name of a specific library to search if not all libraries
        :param allow_empty: To disable an error if no files matched the pattern
        :returns: A :class:`.SourceFileList` object
        """
        results = []
        for source_file in self._project.get_source_files_in_order():
            if library_name is not None:
                if source_file.library.name != library_name:
                    continue

            if not (fnmatch(abspath(source_file.name), pattern) or
                    fnmatch(ostools.simplify_path(source_file.name), pattern)):
                continue

            results.append(SourceFile(source_file, self._project, self))

        if (not allow_empty) and len(results) == 0:
            raise ValueError(("Pattern %r did not match any file. "
                              "Use allow_empty=True to avoid exception,") % pattern)

        return SourceFileList(results)

    def add_source_files(self,   # pylint: disable=too-many-arguments
                         files, library_name, preprocessors=None, include_dirs=None, defines=None, allow_empty=False,
                         vhdl_standard=None):
        """
        Add source files matching wildcard pattern to library

        :param files: A wildcard pattern matching the files to add or a list of files
        :param library_name: The name of the library to add files into
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param allow_empty: To disable an error if no files matched the pattern
        :param vhdl_standard: The VHDL standard used to compile these files,
                              if None VUNIT_VHDL_STANDARD environment variable is used
        :returns: A list of files (:class:`.SourceFileList`) which were added

        :example:

        .. code-block:: python

           prj.add_source_files("*.vhd", "lib")

        """
        if _is_iterable_not_string(files):
            files = [files]

        if vhdl_standard is None:
            vhdl_standard = self._vhdl_standard

        file_names = []
        for pattern in files:
            new_file_names = glob(pattern)

            if (not allow_empty) and len(new_file_names) == 0:
                raise ValueError(("Pattern %r did not match any file. "
                                  "Use allow_empty=True to avoid exception,") % pattern)
            file_names += new_file_names

        return SourceFileList(source_files=[
            self.add_source_file(file_name, library_name, preprocessors, include_dirs, defines, vhdl_standard)
            for file_name in file_names])

    def add_source_file(self,   # pylint: disable=too-many-arguments
                        file_name, library_name, preprocessors=None, include_dirs=None, defines=None,
                        vhdl_standard=None):
        """
        Add source file to library

        :param file_name: The name of the file
        :param library_name: The name of the library to add the file into
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param vhdl_standard: The VHDL standard used to compile this file,
                              if None VUNIT_VHDL_STANDARD environment variable is used
        :returns: The :class:`.SourceFile` which was added

        :example:

        .. code-block:: python

           prj.add_source_file("file.vhd", "lib")

        """
        file_type = file_type_of(file_name)

        if file_type == "verilog":
            include_dirs = include_dirs if include_dirs is not None else []
            include_dirs = add_verilog_include_dir(include_dirs)

        if vhdl_standard is None:
            vhdl_standard = self._vhdl_standard

        file_name = self._preprocess(library_name, abspath(file_name), preprocessors)
        return SourceFile(self._project.add_source_file(file_name,
                                                        library_name,
                                                        file_type=file_type,
                                                        include_dirs=include_dirs,
                                                        defines=defines,
                                                        vhdl_standard=vhdl_standard),
                          self._project,
                          self)

    def _preprocess(self, library_name, file_name, preprocessors):
        """
        Preprocess file_name within library_name using explicit preprocessors
        if preprocessors is None then use implicit globally defined processors
        """
        # @TODO dependency checking etc...

        if preprocessors is None:
            preprocessors = [self._location_preprocessor, self._check_preprocessor]
            preprocessors = [p for p in preprocessors if p is not None]
            preprocessors = self._external_preprocessors + preprocessors

        if len(preprocessors) == 0:
            return file_name

        code = ostools.read_file(file_name)
        for preprocessor in preprocessors:
            code = preprocessor.run(code, basename(file_name))

        pp_file_name = join(self._preprocessed_path, library_name, basename(file_name))

        idx = 1
        while ostools.file_exists(pp_file_name):
            LOGGER.debug("Preprocessed file exists '%s', adding prefix", pp_file_name)
            pp_file_name = join(self._preprocessed_path,
                                library_name, "%i_%s" % (idx, basename(file_name)))
            idx += 1

        ostools.write_file(pp_file_name, code)
        return pp_file_name

    def add_preprocessor(self, preprocessor):
        """
        Add a custom preprocessor to be used on all files, must be called before adding any files
        """
        self._external_preprocessors.append(preprocessor)

    def enable_location_preprocessing(self, additional_subprograms=None):
        """
        Enable location preprocessing, must be called before adding any files
        """
        preprocessor = LocationPreprocessor()
        if additional_subprograms is not None:
            for subprogram in additional_subprograms:
                preprocessor.add_subprogram(subprogram)
        self._location_preprocessor = preprocessor

    def enable_check_preprocessing(self):
        """
        Enable check preprocessing, must be called before adding any files
        """
        self._check_preprocessor = CheckPreprocessor()

    def main(self):
        """
        Run vunit main function and exit
        """
        try:
            all_ok = self._main()
        except KeyboardInterrupt:
            exit(1)
        except CompileError:
            exit(1)
        except TestScannerError:
            exit(1)
        except SystemExit:
            exit(1)
        except:  # pylint: disable=bare-except
            traceback.print_exc()
            exit(1)

        if (not all_ok) and (not self._exit_0):
            exit(1)

        exit(0)

    def _main(self):
        """
        Base vunit main function without performing exit
        """
        if self._list_only:
            return self._main_list_only()

        if self._list_files_only:
            return self._main_list_files_only()

        if self._compile_only:
            return self._main_compile_only()

        simulator_if = self._create_simulator_if()
        test_cases = self._create_tests(simulator_if)

        self._compile(simulator_if)

        start_time = ostools.get_time()
        report = TestReport(printer=self._printer)
        try:
            self._run_test(test_cases, report)
            simulator_if.post_process(self._simulator_factory.simulator_output_path)
        except KeyboardInterrupt:
            print()
            LOGGER.debug("_main: Caught Ctrl-C shutting down")
        finally:
            del test_cases
            del simulator_if

        report.set_real_total_time(ostools.get_time() - start_time)
        self._post_process(report)

        return report.all_ok()

    def _main_list_only(self):
        """
        Main function when only listing test cases
        """
        simulator_if = None
        test_suites = self._create_tests(simulator_if)

        for test_suite in test_suites:
            for name in test_suite.test_cases:
                print(name)
        print("Listed %i tests" % test_suites.num_tests())
        return True

    def _main_list_files_only(self):
        """
        Main function when only listing files
        """
        files = self.get_compile_order()
        for source_file in files:
            print("%s, %s" % (source_file.library.name, source_file.name))
        print("Listed %i files" % len(files))
        return True

    def _main_compile_only(self):
        """
        Main function when only compiling
        """
        simulator_if = self._create_simulator_if()
        self._compile(simulator_if)
        return True

    def _create_output_path(self, clean):
        """
        Create or re-create the output path if necessary
        """
        if clean:
            ostools.renew_path(self._output_path)
        elif not exists(self._output_path):
            os.makedirs(self._output_path)

        ostools.renew_path(self._preprocessed_path)

    def _create_simulator_if(self):
        """
        Create a simulator interface instance
        """
        return self._simulator_factory.create()

    @property
    def vhdl_standard(self):
        return self._vhdl_standard

    @property
    def _preprocessed_path(self):
        return join(self._output_path, "preprocessed")

    @property
    def codecs_path(self):
        return join(self._output_path, "codecs")

    @property
    def use_debug_codecs(self):
        return self._use_debug_codecs

    def _create_tests(self, simulator_if):
        """
        Create the test suites by scanning the project
        """
        scanner = TestScanner(simulator_if,
                              self._configuration,
                              elaborate_only=self._elaborate_only)
        test_list = scanner.from_project(self._project, entity_filter=self._tb_filter)

        if test_list.num_tests() == 0:
            LOGGER.warning("Test scanner found no test benches using current filter rule:\n%s",
                           self._tb_filter.__doc__)

        test_list.keep_matches(self._test_filter)
        return test_list

    def _compile(self, simulator_if):
        """
        Compile entire project
        """
        simulator_if.compile_project(self._project,
                                     continue_on_error=self._keep_compiling)

    def _run_test(self, test_cases, report):
        """
        Run the test suites and return the report
        """
        runner = TestRunner(report,
                            join(self._output_path, "test_output"),
                            verbose=self._verbose,
                            num_threads=self._num_threads)
        runner.run(test_cases)

    def _post_process(self, report):
        """
        Print the report to stdout and optionally write it to an XML file
        """
        report.print_str()

        if self._xunit_xml is not None:
            xml = report.to_junit_xml_str()
            ostools.write_file(self._xunit_xml, xml)

    def add_builtins(self, library_name="vunit_lib", mock_lang=False, mock_log=False):
        """
        Add vunit VHDL builtin libraries
        """
        library = self.add_library(library_name)
        supports_context = self._simulator_factory.supports_vhdl_2008_contexts()
        add_vhdl_builtins(library, self._vhdl_standard, mock_lang, mock_log,
                          supports_context=supports_context)

    def add_com(self, library_name="vunit_lib", use_debug_codecs=None):
        """
        Add communication package

        :param use_debug_codecs: Use human readable debug codecs

           `None`: Use command line argument setting

           `False`: Never use debug codecs

           `True`: Always use debug codecs
        """
        if not self._project.has_library(library_name):
            library = self.add_library(library_name)
        else:
            library = self.library(library_name)

        if use_debug_codecs is not None:
            self._use_debug_codecs = use_debug_codecs

        supports_context = self._simulator_factory.supports_vhdl_2008_contexts()

        add_com(library, self._vhdl_standard,
                use_debug_codecs=self._use_debug_codecs,
                supports_context=supports_context)

    def add_array_util(self, library_name="vunit_lib"):
        """
        Add array utility package
        """
        library = self.library(library_name)
        add_array_util(library, self._vhdl_standard)

    def add_osvvm(self, library_name="osvvm"):
        """
        Add osvvm library
        """
        if not self._project.has_library(library_name):
            library = self.add_library(library_name)
        else:
            library = self.library(library_name)
        add_osvvm(library)

    def get_compile_order(self, source_files=None):
        """
        Get the compile order of all or specific source files and
        their dependencies

        :param source_files: A list of :class:`.SourceFile` objects or `None` meaing all
        :returns: A list of :class:`.SourceFile` objects in compile order.
        """
        if source_files is None:
            source_files = self.get_source_files()

        target_files = [source_file._source_file  # pylint: disable=protected-access
                        for source_file in source_files]
        source_files = self._project.get_dependencies_in_compile_order(target_files)
        return SourceFileList([SourceFile(source_file, self._project, self)
                               for source_file in source_files])


class Library(object):
    """
    User interface of a library
    """
    def __init__(self, library_name, parent, project, configuration, vhdl_standard):
        self._library_name = library_name
        self._parent = parent
        self._project = project
        self._configuration = configuration
        self._vhdl_standard = vhdl_standard
        self._scope = create_scope(self._library_name)

    @property
    def name(self):
        """
        The name of the library
        """
        return self._library_name

    def set_generic(self, name, value):
        """
        Set a value of generic within all test benches of this library

        :param name: The name of the generic
        :param value: The value of the generic

        :example:

        .. code-block:: python

           lib.set_generic("data_width", 16)

        """
        self._configuration.set_generic(name.lower(), value, scope=self._scope)

    def set_parameter(self, name, value):
        """
        Set a value of parameter within all test benches of this library

        :param name: The name of the parameter
        :param value: The value of the parameter

        :example:

        .. code-block:: python

           lib.set_parameter("data_width", 16)

        """
        self._configuration.set_generic(name, value, scope=self._scope)

    def set_sim_option(self, name, value):
        """
        Set simulation option of all test benches within this library

        :param name: |simulation_options|
        :param value: The value of the simulation option

        :example:

        .. code-block:: python

           lib.set_sim_option("ghdl.flags", ["--no-vital-checks"])

        """
        self._configuration.set_sim_option(name, value, scope=self._scope)

    def set_compile_option(self, name, value):
        """
        Set compile option for all files within the library

        :param name: |compile_option|
        :param value: The value of the compile option

        :example:

        .. code-block:: python

           lib.set_compile_option("ghdl.flags", ["--no-vital-checks"])

        """
        for source_file in self._project.get_source_files_in_order():
            if source_file.library.name == self._library_name:
                source_file.set_compile_option(name, value)

    def add_compile_option(self, name, value):
        """
        Add compile option to all files within the library

        :param name: |compile_option|
        :param value: The value of the compile option
        """
        for source_file in self._project.get_source_files_in_order():
            if source_file.library.name == self._library_name:
                source_file.add_compile_option(name, value)

    def set_pli(self, value):
        """
        Set pli within library

        :param value: A list of PLI object file names
        """
        self._configuration.set_pli(value, scope=self._scope)

    def disable_ieee_warnings(self):
        """
        Disable ieee warnings within library
        """
        self._configuration.disable_ieee_warnings(scope=self._scope)

    def get_source_file(self, file_name):
        return self._parent.get_source_files(file_name, self._library_name)

    def get_source_files(self, pattern="*", allow_empty=False):
        return self._parent.get_source_files(pattern, self._library_name, allow_empty)

    def add_source_files(self,   # pylint: disable=too-many-arguments
                         pattern, preprocessors=None, include_dirs=None, defines=None, allow_empty=False,
                         vhdl_standard=None):
        """
        Add source files matching wildcard pattern to library

        :param pattern: A wildcard pattern match the files to add
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param allow_empty: To disable an error if no files matched the pattern
        :param vhdl_standard: The VHDL standard used to compile these files, if None library default is used
        :returns: A list of files (:class:`.SourceFileList`) which were added

        :example:

        .. code-block:: python

           library.add_source_files("*.vhd")

        """

        if vhdl_standard is None:
            vhdl_standard = self._vhdl_standard

        return self._parent.add_source_files(pattern, self._library_name, preprocessors, include_dirs, defines,
                                             allow_empty=allow_empty, vhdl_standard=vhdl_standard)

    def add_source_file(self, pattern, preprocessors=None, include_dirs=None, defines=None, vhdl_standard=None):
        """
        Add source file to library

        :param file_name: The name of the file
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param vhdl_standard: The VHDL standard used to compile this file, if None library default is used
        :returns: The :class:`.SourceFile` which was added

        :example:

        .. code-block:: python

           library.add_source_file("file.vhd")

        """
        if vhdl_standard is None:
            vhdl_standard = self._vhdl_standard

        return self._parent.add_source_file(pattern, self._library_name, preprocessors, include_dirs, defines,
                                            vhdl_standard)

    def package(self, name):
        """
        Get a package within the library
        """
        library = self._project.get_library(self._library_name)
        design_unit = library.primary_design_units.get(name)

        if design_unit is None:
            raise KeyError(name)
        if design_unit.unit_type is not 'package':
            raise KeyError(name)

        return PackageFacade(self._parent, self._library_name, name, design_unit)

    def entity(self, name):
        """
        Get an entity within the library

        :param name: The name of the entity
        :returns: A :class:`.TestBench` object
        :raises: KeyError
        """
        library = self._project.get_library(self._library_name)
        if not library.has_entity(name):
            raise KeyError(name)

        return TestBench(self._library_name, name,
                         self._configuration)

    def module(self, name):
        """
        Get a module within the library

        :param name: The name of the module
        :returns: A :class:`.TestBench` object
        :raises: KeyError
        """
        library = self._project.get_library(self._library_name)
        if name not in library.modules:
            raise KeyError(name)

        return TestBench(self._library_name, name,
                         self._configuration)


class TestBench(object):
    """
    User interface of a test bench.
    A test bench consists of one or more :class:`.Test` cases. Setting options for a test
    bench will apply that option all test cases belonging to that test bench.
    """
    def __init__(self, library_name, entity_name, config):
        self._library_name = library_name
        self._entity_name = entity_name
        self._config = config
        self._scope = create_scope(library_name, entity_name)

    def set_generic(self, name, value):
        """
        Set a value of generic within this test bench

        :param name: The name of the generic
        :param value: The value of the generic

        :example:

        .. code-block:: python

           test_bench.set_generic("data_width", 16)

        """
        self._config.set_generic(name.lower(), value, scope=self._scope)

    def set_parameter(self, name, value):
        """
        Set a value of parameter within this test bench

        :param name: The name of the parameter
        :param value: The value of the parameter

        :example:

        .. code-block:: python

           test_bench.set_parameter("data_width", 16)

        """
        self._config.set_generic(name, value, scope=self._scope)

    def set_sim_option(self, name, value):
        """
        Set simulation option of this test bench

        :param name: |simulation_options|
        :param value: The value of the simulation option

        :example:

        .. code-block:: python

           test_bench.set_sim_option("ghdl.flags", ["--no-vital-checks"])

        """
        self._config.set_sim_option(name, value, scope=self._scope)

    def set_pli(self, value):
        """
        Set pli for test bench

        :param value: A list of PLI object file names
        """
        self._config.set_pli(value, scope=self._scope)

    def add_config(self,  # pylint: disable=too-many-arguments
                   name="", generics=None, parameters=None, pre_config=None, post_check=None):
        """
        Add a configuration of this test bench.
        Multiple configuration may be added one after another.
        If no configurations are added the default configuration is used.

        :param name: The name of the configuration. Will be added as a suffix on the test name
        :param generics: A `dict` containing the generics to be set
        :param parameters: A `dict` containing the parameters to be set
        :param pre_config: A function to be called before test execution.
           The function may accept a string which is the filesystem path to the
           directory where test outputs are stored.
           The function must return `True` or the test will fail
        :param post_check: A function to be called after test execution.
           The function must accept a string which is the filesystem path to the
           directory where test outputs are stored.
           The function must return `True` or the test will fail

        :example:

        Given a test bench that by default gives rise to the test
        ``lib.test_bench`` and the following ``add_config`` calls:

        .. code-block:: python

           for data_width in range(14, 15+1):
               for sign in [False, True]:
                   test_bench.add_config(
                       name="data_width=%s,sign=%s" % (data_width, sign),
                       generics=dict(data_width=data_width, sign=sign))

        The following tests will be created:

        * ``lib.test_bench.data_width=14,sign=False``

        * ``lib.test_bench.data_width=14,sign=True``

        * ``lib.test_bench.data_width=15,sign=False``

        * ``lib.test_bench.data_width=15,sign=True``

        """
        generics = {} if generics is None else generics
        generics = lower_generics(generics)
        parameters = {} if parameters is None else parameters
        generics.update(parameters)
        self._config.add_config(scope=self._scope,
                                name=name,
                                generics=generics,
                                pre_config=pre_config,
                                post_check=post_check)

    def disable_ieee_warnings(self):
        """
        Disable ieee warnings within test bench
        """
        self._config.disable_ieee_warnings(scope=self._scope)

    def test(self, name):
        """
        Get a test within this test bench

        :param name: The name of the test
        :returns: A :class:`.Test` object
        """
        # @TODO we cannot check that test exists at this point since tests are scanned in main
        # @TODO assumes there is only one architecture for test benchs
        # @TODO makes sense to have multiple architectures of a test bench?

        return Test(self._library_name, self._entity_name, name, self._config)

    def scan_tests_from_file(self, file_name):
        """
        Scan tests from another file than the one containg the test
        bench.  Useful for when the top level test bench does not
        contain the tests.

        Such a structure is not the preferred way of doing things in
        VUnit but this method exists to accommodate legacy needs.

        :param file_name: The name of another file to scan for tests

        .. warning::
           The nested module containing the tests needs to be given
           the ``runner_cfg`` parameter or generic by the
           instantiating top level test bench. The nested module
           should not call its parameter or generic `runner_cfg` but
           rather `nested_runner_cfg` to avoid the VUnit test scanner
           detecting and running it as a test bench. In SystemVerilog
           the ``NESTED_TEST_SUITE`` macro should be used instead of
           the ``TEST_SUITE`` macro.
        """
        if not ostools.file_exists(file_name):
            raise ValueError("File %r does not exist" % file_name)
        self._config.scan_tests_from_file(self._scope, file_name)


class PackageFacade(object):
    """
    User interface of a Package
    """
    def __init__(self, parent, library_name, package_name, design_unit):
        self._parent = parent
        self._library_name = library_name
        self._package_name = package_name
        self._design_unit = design_unit

    def generate_codecs(self, codec_package_name=None, used_packages=None, output_file_name=None):
        """
        Generates codecs for the datatypes in this Package
        """
        if codec_package_name is None:
            codec_package_name = self._package_name + '_codecs'

        if output_file_name is None:
            codecs_path = join(self._parent.codecs_path, self._library_name)
            file_extension = splitext(self._design_unit.source_file.name)[1]
            output_file_name = join(codecs_path, codec_package_name + file_extension)

        codec_generator.generate_codecs(self._design_unit,
                                        codec_package_name,
                                        used_packages,
                                        output_file_name,
                                        self._parent.use_debug_codecs)

        return self._parent.add_source_files(output_file_name, self._library_name)


class Test(object):
    """
    User interface of a single test case

    """
    def __init__(self, library_name, entity_name, test_name, config):
        self._library_name = library_name
        self._entity_name = entity_name
        self._test_name = test_name
        self._config = config
        self._scope = create_scope(library_name, entity_name, test_name)

    def add_config(self,  # pylint: disable=too-many-arguments
                   name="", generics=None, parameters=None, pre_config=None, post_check=None):
        """
        Add a configuration of this test.
        Multiple configuration may be added one after another.
        If no configurations are added the default configuration is used.

        :param name: The name of the configuration. Will be added as a suffix on the test name
        :param generics: A `dict` containing the generics to be set
        :param parameters: A `dict` containing the parameters to be set
        :param pre_config: A function to be called before test execution.
           The function may accept a string which is the filesystem path to the
           directory where test outputs are stored.
           The function must return `True` or the test will fail
        :param post_check: A function to be called after test execution.
           The function must accept a string which is the filesystem path to the
           directory where test outputs are stored.
           The function must return `True` or the test will fail

        :example:

        Given the ``lib.test_bench.test`` test and the following ``add_config`` calls:

        .. code-block:: python

           for data_width in range(14, 15+1):
               for sign in [False, True]:
                   test.add_config(
                       name="data_width=%s,sign=%s" % (data_width, sign),
                       generics=dict(data_width=data_width, sign=sign))

        The following tests will be created:

        * ``lib.test_bench.test.data_width=14,sign=False``

        * ``lib.test_bench.test.data_width=14,sign=True``

        * ``lib.test_bench.test.data_width=15,sign=False``

        * ``lib.test_bench.test.data_width=15,sign=True``

        """
        generics = {} if generics is None else generics
        generics = lower_generics(generics)
        parameters = {} if parameters is None else parameters
        generics.update(parameters)
        self._config.add_config(scope=self._scope,
                                name=name,
                                generics=generics,
                                pre_config=pre_config,
                                post_check=post_check)

    def set_generic(self, name, value):
        """
        Set a value of generic within this test

        :param name: The name of the generic
        :param value: The value of the generic

        :example:

        .. code-block:: python

           test.set_generic("data_width", 16)

        """
        self._config.set_generic(name.lower(), value, scope=self._scope)

    def set_parameter(self, name, value):
        """
        Set a value of parameter within this test

        :param name: The name of the parameter
        :param value: The value of the parameter

        :example:

        .. code-block:: python

           test.set_parameter("data_width", 16)

        """
        self._config.set_generic(name, value, scope=self._scope)

    def set_sim_option(self, name, value):
        """
        Set simulation option of this test

        :param name: |simulation_options|
        :param value: The value of the simulation option

        :example:

        .. code-block:: python

           test.set_sim_option("ghdl.flags", ["--no-vital-checks"])

        """
        self._config.set_sim_option(name, value, scope=self._scope)

    def disable_ieee_warnings(self):
        """
        Disable ieee warnings for test case
        """
        self._config.disable_ieee_warnings(scope=self._scope)


class SourceFileList(list):
    """
    A list of :class:`.SourceFile`
    """

    def __init__(self, source_files):
        list.__init__(self, source_files)

    def set_compile_option(self, name, value):
        """
        Set compile option for all files in the list

        :param name: |compile_option|
        :param value: The value of the compile option

        :example:

        .. code-block:: python

           files.set_compile_option("ghdl.flags", ["--no-vital-checks"])
        """
        for source_file in self:
            source_file.set_compile_option(name, value)

    def add_compile_option(self, name, value):
        """
        Add compile option to all files in the list

        :param name: |compile_option|
        :param value: The value of the compile option
        """
        for source_file in self:
            source_file.add_compile_option(name, value)

    def depends_on(self, source_file):
        """
        Add manual dependency of these files on other file(s)

        :param source_file: The file(s) which this file depends on

        :example:

        .. code-block:: python

           other_file = lib.get_source_file("other_file.vhd")
           files.depends_on(other_file)
        """
        for my_source_file in self:
            my_source_file.depends_on(source_file)


class SourceFile(object):
    """
    A single file
    """
    def __init__(self, source_file, project, ui):
        self._source_file = source_file
        self._project = project
        self._ui = ui

    @property
    def name(self):
        """
        The name of the SourceFile
        """
        return ostools.simplify_path(self._source_file.name)

    @property
    def vhdl_standard(self):
        """
        The VHDL standard applicable to the file,
        None if not a VHDL file
        """
        if self._source_file.file_type == "vhdl":
            return self._source_file.get_vhdl_standard()
        else:
            return None

    @property
    def library(self):
        """
        The library of the source file
        """
        return self._ui.library(self._source_file.library.name)

    def set_compile_option(self, name, value):
        """
        Set compile option for this file

        :param name: |compile_option|
        :param value: The value of the compile option

        :example:

        .. code-block:: python

           my_file.set_compile_option("ghdl.flags", ["--no-vital-checks"])
        """
        self._source_file.set_compile_option(name, value)

    def add_compile_option(self, name, value):
        """
        Add compile option to this file

        :param name: |compile_option|
        :param value: The value of the compile option
        """
        self._source_file.add_compile_option(name, value)

    def get_compile_option(self, name):
        """
        Return compile option of this file

        :param name: |compile_option|
        """
        return self._source_file.get_compile_option(name)

    def depends_on(self, source_file):
        """
        Add manual dependency of this file other file(s)

        :param source_file: The file(s) which this file depends on

        :example:

        .. code-block:: python

           other_files = lib.get_source_files("*.vhd")
           my_file.depends_on(other_files)
        """
        if isinstance(source_file, SourceFile):
            private_source_file = source_file._source_file  # pylint: disable=protected-access
            self._project.add_manual_dependency(self._source_file,
                                                depends_on=private_source_file)
        elif hasattr(source_file, "__iter__"):
            for element in source_file:
                self.depends_on(element)
        else:
            raise ValueError(source_file)


def select_vhdl_standard():
    """
    Select VHDL standard according to environment variable VUNIT_VHDL_STANDARD
    """
    vhdl_standard = os.environ.get('VUNIT_VHDL_STANDARD', '2008')
    check_vhdl_standard(vhdl_standard, from_str="VUNIT_VHDL_STANDARD environment variable")
    return vhdl_standard


def lower_generics(generics):
    """
    Convert all generics names to lower case to match internal representation.
    @TODO Maybe warn in case of conflict. VHDL forbids this though so the user will notice anyway.
    """
    return dict((name.lower(), value) for name, value in generics.items())


def _is_iterable_not_string(value):
    """
    Returns True if value is an iterable that is not a string
    """
    if sys.version_info.major == 3:
        return isinstance(value, str)
    else:
        return isinstance(value, (str, unicode))  # pylint: disable=undefined-variable
