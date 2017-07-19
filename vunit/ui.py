# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2017, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-lines

"""
.. autoclass:: vunit.ui.VUnit()
   :members:
   :exclude-members: add_preprocessor,
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

``incisive.irun_vhdl_flags``
   Extra arguments passed to the Incisive ``irun`` command when compiling VHDL files.
   Must be a list of strings.

``incisive.irun_verilog_flags``
   Extra arguments passed to the Incisive ``irun`` command when compiling Verilog files.
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

``vhdl_assert_stop_level``
  Will stop a VHDL simulation for asserts on the provided severity level or higher.
  Valid values are ``"warning"``, ``"error"``, and ``"failure"``. This option takes
  precedence over the fail_on_warning pragma.

``disable_ieee_warnings``
  Disable ieee warnings
  Boolean

``pli``
  A list of PLI files
  A list of file names

``ghdl.flags``
   Extra arguments passed to ``ghdl --elab-run`` command *before* executable specific flags. Must be a list of strings.
   Must be a list of strings.

``incisive.irun_sim_flags``
   Extra arguments passed to the Incisive ``irun`` command when loading the design.
   Must be a list of strings.

``modelsim.vsim_flags``
   Extra arguments passed to ``vsim`` when loading the design.
   Must be a list of strings.

``modelsim.vsim_flags.gui``
   Extra arguments passed to ``vsim`` when loading the design in GUI
   mode where it takes precedence over ``modelsim.vsim_flags``.
   Must be a list of strings.

``modelsim.init_files.after_load``
   A list of user defined DO/TCL-files that is sourced after the design has been loaded.
   During script evaluation the ``vunit_tb_path`` variable is defined
   as the path of the folder containing the test bench.
   Must be a list of strings.

``modelsim.init_file.gui``
   A user defined TCL-file that is sourced after the design has been loaded in the GUI.
   For example this can be used to configure the waveform viewer.
   During script evaluation the ``vunit_tb_path`` variable is defined
   as the path of the folder containing the test bench.
   Must be a string.

``rivierapro.vsim_flags``
   Extra arguments passed to ``vsim`` when loading the design.
   Must be a list of strings.

``rivierapro.vsim_flags.gui``
   Extra arguments passed to ``vsim`` when loading the design in GUI
   mode where it takes precedence over ``rivierapro.vsim_flags``.
   Must be a list of strings.

``rivierapro.init_files.after_load``
   A list of user defined DO/TCL-files that is sourced after the design has been loaded.
   During script evaluation the ``vunit_tb_path`` variable is defined
   as the path of the folder containing the test bench.
   Must be a list of strings.

``rivierapro.init_file.gui``
   A user defined TCL-file that is sourced after the design has been loaded in the GUI.
   For example this can be used to configure the waveform viewer.
   During script evaluation the ``vunit_tb_path`` variable is defined
   as the path of the folder containing the test bench.
   Must be a string.

``activehdl.vsim_flags``
   Extra arguments passed to ``vsim`` when loading the design.
   Must be a list of strings.

``activehdl.vsim_flags.gui``
   Extra arguments passed to ``vsim`` when loading the design in GUI
   mode where it takes precedence over ``activehdl.vsim_flags``.
   Must be a list of strings.

``activehdl.init_file.gui``
   A user defined TCL-file that is sourced after the design has been loaded in the GUI.
   For example this can be used to configure the waveform viewer.
   Must be a string.

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

.. _configurations:

Configurations
--------------
In VUnit Python API the name ``configuration`` is used to denote the
user controllable configuration of one test run such as
generic/parameter settings, simulation options as well as the
pre_config and post_check callback functions.

Configurations can either be unique for each test case or must be
common for the entire test bench depending on the situation.  For test
benches without test such as `tb_example` in the User Guide the
configuration is common for the entire test bench. For test benches
containing tests such as `tb_example_many` the configuration is done
for each test case. If the ``run_all_in_same_sim`` pragma has been used
configuration is performed at the test bench level even if there are
individual test within since they must run in the same simulation.

In a VUnit all test benches and test cases are created with an unnamed default
configuration which is modified by different methods such as ``set_generic`` etc.
In addition to the unnamed default configuration multiple named configurations
can be derived from it by using the ``add_config`` method. The default
configuration is only run if there are no named configurations.

.. |configurations| replace::
    :ref:`configurations <configurations>`
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
from vunit.simulator_factory import SIMULATOR_FACTORY
from vunit.simulator_interface import is_string_not_iterable
from vunit.color_printer import (COLOR_PRINTER,
                                 NO_COLOR_PRINTER)
from vunit.project import (Project,
                           file_type_of,
                           check_vhdl_standard)
from vunit.test_runner import TestRunner
from vunit.test_report import TestReport
from vunit.test_bench_list import TestBenchList
from vunit.exceptions import CompileError
from vunit.location_preprocessor import LocationPreprocessor
from vunit.check_preprocessor import CheckPreprocessor
from vunit.builtins import (add_vhdl_builtins,
                            add_verilog_include_dir,
                            add_array_util,
                            add_osvvm,
                            add_com)
from vunit.parsing.encodings import HDL_FILE_ENCODING
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

        return cls(args, compile_builtins=compile_builtins)

    def __init__(self, args, compile_builtins=True):
        self._args = args
        self._configure_logging(args.log_level)
        self._output_path = abspath(args.output_path)

        if args.no_color:
            self._printer = NO_COLOR_PRINTER
        else:
            self._printer = COLOR_PRINTER

        def test_filter(name):
            return any(fnmatch(name, pattern) for pattern in args.test_patterns)

        self._test_filter = test_filter
        self._vhdl_standard = select_vhdl_standard()

        self._external_preprocessors = []
        self._location_preprocessor = None
        self._check_preprocessor = None
        self._use_debug_codecs = args.use_debug_codecs

        self._simulator_factory = SIMULATOR_FACTORY
        self._simulator_output_path = join(self._output_path, SIMULATOR_FACTORY.simulator_name)
        self._create_output_path(args.clean)

        database = self._create_database()
        self._project = Project(
            database=database,
            depend_on_package_body=self._simulator_factory.package_users_depend_on_bodies())

        self._test_bench_list = TestBenchList(database=database)

        if compile_builtins:
            self.add_builtins(library_name="vunit_lib")

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

    def add_external_library(self, library_name, path, vhdl_standard=None):
        """
        Add an externally compiled library as a black-box

        :param library_name: The name of the external library
        :param path: The path to the external library directory
        :param vhdl_standard: The VHDL standard used to compile files into this library,
                              if None the VUNIT_VHDL_STANDARD environment variable is used
        :returns: The created :class:`.Library` object

        :example:

        .. code-block:: python

           prj.add_external_library("unisim", "path/to/unisim/")

        """
        if vhdl_standard is None:
            vhdl_standard = self._vhdl_standard

        self._project.add_library(library_name, abspath(path), vhdl_standard, is_external=True)
        return self.library(library_name)

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
        path = join(self._simulator_output_path, "libraries", library_name)
        self._project.add_library(library_name, abspath(path), vhdl_standard)
        return self.library(library_name)

    def library(self, library_name):
        """
        Get a library

        :param library_name: The name of the library
        :returns: A :class:`.Library` object
        """
        if not self._project.has_library(library_name):
            raise KeyError(library_name)
        return Library(library_name, self, self._project, self._test_bench_list)

    def set_generic(self, name, value, allow_empty=False):
        """
        Set a value of generic in all |configurations|

        :param name: The name of the generic
        :param value: The value of the generic
        :param allow_empty: To disable an error when no test benches were found

        :example:

        .. code-block:: python

           prj.set_generic("data_width", 16)

        .. note::
           Only affects test benches added *before* the generic is set.
        """
        test_benches = self._test_bench_list.get_test_benches()
        for test_bench in check_not_empty(test_benches, allow_empty, "No test benches found"):
            test_bench.set_generic(name.lower(), value)

    def set_parameter(self, name, value, allow_empty=False):
        """
        Set value of parameter in all |configurations|

        :param name: The name of the parameter
        :param value: The value of the parameter
        :param allow_empty: To disable an error when no test benches were found

        :example:

        .. code-block:: python

           prj.set_parameter("data_width", 16)

        .. note::
           Only affects test benches added *before* the parameter is set.
        """
        test_benches = self._test_bench_list.get_test_benches()
        for test_bench in check_not_empty(test_benches, allow_empty, "No test benches found"):
            test_bench.set_generic(name, value)

    def set_sim_option(self, name, value, allow_empty=False):
        """
        Set simulation option in all |configurations|

        :param name: |simulation_options|
        :param value: The value of the simulation option
        :param allow_empty: To disable an error when no test benches were found

        :example:

        .. code-block:: python

           prj.set_sim_option("ghdl.flags", ["--no-vital-checks"])

        .. note::
           Only affects test benches added *before* the option is set.
        """
        test_benches = self._test_bench_list.get_test_benches()
        for test_bench in check_not_empty(test_benches, allow_empty, "No test benches found"):
            test_bench.set_sim_option(name, value)

    def set_compile_option(self, name, value, allow_empty=False):
        """
        Set compile option of all files

        :param name: |compile_option|
        :param value: The value of the compile option
        :param allow_empty: To disable an error when no source files were found

        :example:

        .. code-block:: python

           prj.set_compile_option("ghdl.flags", ["--no-vital-checks"])


        .. note::
           Only affects files added *before* the option is set.
        """
        source_files = self._project.get_source_files_in_order()
        for source_file in check_not_empty(source_files, allow_empty, "No source files found"):
            source_file.set_compile_option(name, value)

    def add_compile_option(self, name, value, allow_empty=False):
        """
        Add compile option to all files

        :param name: |compile_option|
        :param value: The value of the compile option
        :param allow_empty: To disable an error when no source files were found

        .. note::
           Only affects files added *before* the option is set.
        """
        source_files = self._project.get_source_files_in_order()
        for source_file in check_not_empty(source_files, allow_empty, "No source files found"):
            source_file.add_compile_option(name, value)

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
        elif not files:
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

        check_not_empty(results, allow_empty,
                        ("Pattern %r did not match any file" % pattern) +
                        (("within library %s" % library_name) if library_name is not None else ""))

        return SourceFileList(results)

    def add_source_files(self,   # pylint: disable=too-many-arguments
                         pattern, library_name, preprocessors=None, include_dirs=None, defines=None, allow_empty=False,
                         vhdl_standard=None, no_parse=False):
        """
        Add source files matching wildcard pattern to library

        :param pattern: A wildcard pattern matching the files to add or a list of files
        :param library_name: The name of the library to add files into
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param allow_empty: To disable an error if no files matched the pattern
        :param vhdl_standard: The VHDL standard used to compile these files,
                              if None VUNIT_VHDL_STANDARD environment variable is used
        :param no_parse: Do not parse file(s) for dependency or test scanning purposes
        :returns: A list of files (:class:`.SourceFileList`) which were added

        :example:

        .. code-block:: python

           prj.add_source_files("*.vhd", "lib")

        """
        return self.library(library_name).add_source_files(pattern=pattern,
                                                           preprocessors=preprocessors,
                                                           include_dirs=include_dirs,
                                                           defines=defines,
                                                           allow_empty=allow_empty,
                                                           vhdl_standard=vhdl_standard,
                                                           no_parse=no_parse)

    def add_source_file(self,   # pylint: disable=too-many-arguments
                        file_name, library_name, preprocessors=None, include_dirs=None, defines=None,
                        vhdl_standard=None, no_parse=False):
        """
        Add source file to library

        :param file_name: The name of the file
        :param library_name: The name of the library to add the file into
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param vhdl_standard: The VHDL standard used to compile this file,
                              if None VUNIT_VHDL_STANDARD environment variable is used
        :param no_parse: Do not parse file for dependency or test scanning purposes
        :returns: The :class:`.SourceFile` which was added

        :example:

        .. code-block:: python

           prj.add_source_file("file.vhd", "lib")

        """
        return self.library(library_name).add_source_file(file_name=file_name,
                                                          preprocessors=preprocessors,
                                                          include_dirs=include_dirs,
                                                          defines=defines,
                                                          vhdl_standard=vhdl_standard,
                                                          no_parse=no_parse)

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

        if not preprocessors:
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

        ostools.write_file(pp_file_name, code, encoding=HDL_FILE_ENCODING)
        return pp_file_name

    def add_preprocessor(self, preprocessor):
        """
        Add a custom preprocessor to be used on all files, must be called before adding any files
        """
        self._external_preprocessors.append(preprocessor)

    def enable_location_preprocessing(self, additional_subprograms=None, exclude_subprograms=None):
        """
        Inserts file name and line number information into VUnit check and log subprograms calls. Custom
        subprograms can also be added. Must be called before adding any files.

        :param additional_subprograms: List of custom subprograms to add the line_num and file_name parameters to.
        :param exclude_subprograms: List of VUnit subprograms to exclude from location preprocessing. Used to \
avoid location preprocessing of other functions sharing name with a VUnit log or check subprogram.

        :example:

        .. code-block:: python

           prj.enable_location_preprocessing(additional_subprograms=['my_check'],
                                             exclude_subprograms=['log'])

        """
        preprocessor = LocationPreprocessor()
        if additional_subprograms is not None:
            for subprogram in additional_subprograms:
                preprocessor.add_subprogram(subprogram)

        if exclude_subprograms is not None:
            for subprogram in exclude_subprograms:
                preprocessor.remove_subprogram(subprogram)
        self._location_preprocessor = preprocessor

    def enable_check_preprocessing(self):
        """
        Inserts error context information into VUnit check_relation calls
        """
        self._check_preprocessor = CheckPreprocessor()

    def main(self):
        """
        Run vunit main function and exit
        """
        try:
            all_ok = self._main()
        except KeyboardInterrupt:
            sys.exit(1)
        except CompileError:
            sys.exit(1)
        except SystemExit:
            sys.exit(1)
        except:  # pylint: disable=bare-except
            if self._args.dont_catch_exceptions:
                raise
            traceback.print_exc()
            sys.exit(1)

        if (not all_ok) and (not self._args.exit_0):
            sys.exit(1)

        sys.exit(0)

    def _create_tests(self, simulator_if):
        """
        Create the test cases
        """
        self._test_bench_list.warn_when_empty()
        test_list = self._test_bench_list.create_tests(simulator_if, self._args.elaborate)
        test_list.keep_matches(self._test_filter)
        return test_list

    def _main(self):
        """
        Base vunit main function without performing exit
        """

        if self._args.list:
            return self._main_list_only()

        elif self._args.files:
            return self._main_list_files_only()

        elif self._args.compile:
            return self._main_compile_only()

        return self._main_run()

    def _create_simulator_if(self):
        return self._simulator_factory.create(self._args, self._simulator_output_path)

    def _main_run(self):
        """
        Main with running tests
        """
        simulator_if = self._create_simulator_if()
        test_list = self._create_tests(simulator_if)
        self._compile(simulator_if)

        start_time = ostools.get_time()
        report = TestReport(printer=self._printer)
        try:
            self._run_test(test_list, report)
            simulator_if.post_process(self._simulator_output_path)
        except KeyboardInterrupt:
            print()
            LOGGER.debug("_main: Caught Ctrl-C shutting down")
        finally:
            del test_list
            del simulator_if

        report.set_real_total_time(ostools.get_time() - start_time)
        self._post_process(report)

        return report.all_ok()

    def _main_list_only(self):
        """
        Main function when only listing test cases
        """
        test_list = self._create_tests(simulator_if=None)
        for test_suite in test_list:
            for name in test_suite.test_cases:
                print(name)
        print("Listed %i tests" % test_list.num_tests())
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

    def _compile(self, simulator_if):
        """
        Compile entire project
        """
        simulator_if.compile_project(self._project,
                                     continue_on_error=self._args.keep_compiling)

    def _run_test(self, test_cases, report):
        """
        Run the test suites and return the report
        """
        runner = TestRunner(report,
                            join(self._output_path, "test_output"),
                            verbose=self._args.verbose,
                            num_threads=self._args.num_threads,
                            dont_catch_exceptions=self._args.dont_catch_exceptions)
        runner.run(test_cases)

    def _post_process(self, report):
        """
        Print the report to stdout and optionally write it to an XML file
        """
        report.print_str()

        if self._args.xunit_xml is not None:
            xml = report.to_junit_xml_str()
            ostools.write_file(self._args.xunit_xml, xml)

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
        simulator_coverage_api = self._simulator_factory.get_osvvm_coverage_api()
        supports_vhdl_package_generics = self._simulator_factory.supports_vhdl_package_generics()
        add_osvvm(library, simulator_coverage_api, supports_vhdl_package_generics)

    def get_compile_order(self, source_files=None):
        """
        Get the compile order of all or specific source files and
        their dependencies.

        A dependency of file **A** in terms of compile order is any
        file **B** which **must** be successfully compiled before **A**
        can be successfully compiled.

        This is **not** the same as all files required to successfully elaborate **A**.
        For example using component instantiation in VHDL there is no
        compile order dependency but the component instance will not
        elaborate if there is no binding component.

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

    def get_implementation_subset(self, source_files):
        """
        Get the subset of files which are required to successfully
        elaborate the list of input files without any missing
        dependencies.

        :param source_files: A list of :class:`.SourceFile` objects
        :returns: A list of :class:`.SourceFile` objects which is the implementation subset.
        """
        target_files = [source_file._source_file  # pylint: disable=protected-access
                        for source_file in source_files]
        source_files = self._project.get_dependencies_in_compile_order(
            target_files,
            implementation_dependencies=True)
        return SourceFileList([SourceFile(source_file, self._project, self)
                               for source_file in source_files])


class Library(object):
    """
    User interface of a library
    """
    def __init__(self, library_name, parent, project, test_bench_list):
        self._library_name = library_name
        self._parent = parent
        self._project = project
        self._test_bench_list = test_bench_list

    @property
    def name(self):
        """
        The name of the library
        """
        return self._library_name

    def set_generic(self, name, value, allow_empty=False):
        """
        Set a value of generic within all |configurations| of test benches and tests this library

        :param name: The name of the generic
        :param value: The value of the generic
        :param allow_empty: To disable an error when no test benches were found

        :example:

        .. code-block:: python

           lib.set_generic("data_width", 16)

        .. note::
           Only affects test benches added *before* the generic is set.
        """
        for test_bench in self.get_test_benches(allow_empty=allow_empty):
            test_bench.set_generic(name.lower(), value)

    def set_parameter(self, name, value, allow_empty=False):
        """
        Set a value of parameter within all |configurations| of test benches and tests this library

        :param name: The name of the parameter
        :param value: The value of the parameter
        :param allow_empty: To disable an error when no test benches were found

        :example:

        .. code-block:: python

           lib.set_parameter("data_width", 16)

        .. note::
           Only affects test benches added *before* the parameter is set.
        """
        for test_bench in self.get_test_benches(allow_empty=allow_empty):
            test_bench.set_generic(name, value)

    def set_sim_option(self, name, value, allow_empty=False):
        """
        Set simlation option within all |configurations| of test benches and tests this library

        :param name: |simulation_options|
        :param value: The value of the simulation option
        :param allow_empty: To disable an error when no test benches were found

        :example:

        .. code-block:: python

           lib.set_sim_option("ghdl.flags", ["--no-vital-checks"])

        .. note::
           Only affects test benches added *before* the option is set.
        """
        for test_bench in self.get_test_benches(allow_empty=allow_empty):
            test_bench.set_sim_option(name, value)

    def set_compile_option(self, name, value, allow_empty=False):
        """
        Set compile option for all files within the library

        :param name: |compile_option|
        :param value: The value of the compile option
        :param allow_empty: To disable an error when no source files were found

        :example:

        .. code-block:: python

           lib.set_compile_option("ghdl.flags", ["--no-vital-checks"])


        .. note::
           Only affects files added *before* the option is set.
        """
        for source_file in self.get_source_files(allow_empty=allow_empty):
            source_file.set_compile_option(name, value)

    def add_compile_option(self, name, value, allow_empty=False):
        """
        Add compile option to all files within the library

        :param name: |compile_option|
        :param value: The value of the compile option
        :param allow_empty: To disable an error when no source files were found

        .. note::
           Only affects files added *before* the option is set.
        """
        for source_file in self.get_source_files(allow_empty=allow_empty):
            source_file.add_compile_option(name, value)

    def get_source_file(self, file_name):
        """
        Get a source file within this library

        :param file_name: The name of the file as a relative or absolute path

        :returns: A :class:`.SourceFile` object
        """
        return self._parent.get_source_file(file_name, self._library_name)

    def get_source_files(self, pattern="*", allow_empty=False):
        """
        Get a list of source files within this libary

        :param pattern: A wildcard pattern matching either an absolute or relative path
        :param allow_empty: To disable an error if no files matched the pattern
        :returns: A :class:`.SourceFileList` object
        """
        return self._parent.get_source_files(pattern, self._library_name, allow_empty)

    def add_source_files(self,   # pylint: disable=too-many-arguments
                         pattern, preprocessors=None, include_dirs=None, defines=None, allow_empty=False,
                         vhdl_standard=None, no_parse=False):
        """
        Add source files matching wildcard pattern to library

        :param pattern: A wildcard pattern match the files to add
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param allow_empty: To disable an error if no files matched the pattern
        :param vhdl_standard: The VHDL standard used to compile these files, if None library default is used
        :param no_parse: Do not parse file(s) for dependency or test scanning purposes
        :returns: A list of files (:class:`.SourceFileList`) which were added

        :example:

        .. code-block:: python

           library.add_source_files("*.vhd")

        """
        if is_string_not_iterable(pattern):
            patterns = [pattern]
        else:
            patterns = pattern

        file_names = []
        for pattern_instance in patterns:
            new_file_names = glob(pattern_instance)
            check_not_empty(new_file_names, allow_empty, "Pattern %r did not match any file" % pattern_instance)
            file_names += new_file_names

        return SourceFileList(source_files=[
            self.add_source_file(file_name, preprocessors, include_dirs, defines, vhdl_standard, no_parse=no_parse)
            for file_name in file_names])

    def add_source_file(self,  # pylint: disable=too-many-arguments
                        file_name, preprocessors=None, include_dirs=None, defines=None,
                        vhdl_standard=None, no_parse=False):
        """
        Add source file to library

        :param file_name: The name of the file
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param vhdl_standard: The VHDL standard used to compile this file, if None library default is used
        :param no_parse: Do not parse file for dependency or test scanning purposes
        :returns: The :class:`.SourceFile` which was added

        :example:

        .. code-block:: python

           library.add_source_file("file.vhd")

        """

        file_type = file_type_of(file_name)

        if file_type == "verilog":
            include_dirs = include_dirs if include_dirs is not None else []
            include_dirs = add_verilog_include_dir(include_dirs)

        file_name = self._parent._preprocess(  # pylint: disable=protected-access
            self._library_name, abspath(file_name), preprocessors)

        source_file = self._project.add_source_file(file_name,
                                                    self._library_name,
                                                    file_type=file_type,
                                                    include_dirs=include_dirs,
                                                    defines=defines,
                                                    vhdl_standard=vhdl_standard,
                                                    no_parse=no_parse)
        self._test_bench_list.add_from_source_file(source_file)

        return SourceFile(source_file,
                          self._project,
                          self._parent)

    def package(self, name):
        """
        Get a package within the library
        """
        library = self._project.get_library(self._library_name)
        design_unit = library.primary_design_units.get(name)

        if design_unit is None:
            raise KeyError(name)
        if design_unit.unit_type != 'package':
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

        return self.test_bench(name)

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

        return self.test_bench(name)

    def test_bench(self, name):
        """
        Get a test bench within this library

        :param name: The name of the test bench
        :returns: A :class:`.TestBench` object
        :raises: KeyError
        """

        return TestBench(self._test_bench_list.get_test_bench(self._library_name, name), self)

    def get_test_benches(self, pattern="*", allow_empty=False):
        """
        Get a list of test benches

        :param pattern: A wildcard pattern matching the test_bench name
        :param allow_empty: To disable an error when no test benches were found
        :returns: A list of :class:`.TestBench` objects
        """
        results = []
        for test_bench in self._test_bench_list.get_test_benches_in_library(self._library_name):
            if not fnmatch(abspath(test_bench.name), pattern):
                continue

            results.append(TestBench(test_bench, self))

        return check_not_empty(results, allow_empty,
                               "No test benches found within library %s" % self._library_name)


class TestBench(object):
    """
    User interface of a test bench.
    A test bench consists of one or more :class:`.Test` cases. Setting options for a test
    bench will apply that option all test cases belonging to that test bench.
    """
    def __init__(self, test_bench, library):
        self._test_bench = test_bench
        self._library = library

    @property
    def name(self):
        """
        :returns: The entity or module name of the test bench
        """
        return self._test_bench.name

    @property
    def library(self):
        """
        :returns: The library that contains this test bench
        """
        return self._library

    def set_generic(self, name, value):
        """
        Set a value of generic within all |configurations| of this test bench or test cases within it

        :param name: The name of the generic
        :param value: The value of the generic

        :example:

        .. code-block:: python

           test_bench.set_generic("data_width", 16)

        """
        self._test_bench.set_generic(name.lower(), value)

    def set_parameter(self, name, value):
        """
        Set a value of parameter within all |configurations| of this test bench or test cases within it

        :param name: The name of the parameter
        :param value: The value of the parameter

        :example:

        .. code-block:: python

           test_bench.set_parameter("data_width", 16)

        """
        self._test_bench.set_generic(name, value)

    def set_sim_option(self, name, value):
        """
        Set simulation option within all |configurations| of this test bench or test cases within it

        :param name: |simulation_options|
        :param value: The value of the simulation option

        :example:

        .. code-block:: python

           test_bench.set_sim_option("ghdl.flags", ["--no-vital-checks"])

        """
        self._test_bench.set_sim_option(name, value)

    def set_pre_config(self, value):
        """
        Set pre_config function of all |configurations| of this test bench or test cases within it

        :param value: The pre_config function
        """
        self._test_bench.set_pre_config(value)

    def set_post_check(self, value):
        """
        Set post_check function of all |configurations| of this test bench or test cases within it

        :param value: The post_check function
        """
        self._test_bench.set_post_check(value)

    def add_config(self,  # pylint: disable=too-many-arguments
                   name, generics=None, parameters=None, pre_config=None, post_check=None, sim_options=None):
        """
        Add a configuration of this test bench or to all test cases within it by copying the default configuration.

        Multiple configuration may be added one after another.
        If no |configurations| are added the default configuration is used.

        :param name: The name of the configuration. Will be added as a suffix on the test name
        :param generics: A `dict` containing the generics to be set in addition to the default configuration
        :param parameters: A `dict` containing the parameters to be set in addition to the default configuration
        :param pre_config: A function to be called before test execution, replaces the default if not None
           The function accepts an optional first argument `output_path` which is the filesystem path to the
           directory where test outputs are stored. An optional second argument
           `simulator_output_path` is the filesystem path to the simulator working directory.
           Please note that `simulator_output_path` is shared by all test runs. The user must take
           care that test runs do not read or write the same files asynchronously. It is therefore
           recommended to use `output_path` in favor of `simulator_output_path`.
           The function must return `True` or the test will fail
        :param post_check: A function to be called after test execution, replaces the default if not None
           The function must accept a string which is the filesystem path to the
           directory where test outputs are stored.
           The function must return `True` or the test will fail
        :param sim_options: A `dict` containing the sim_options to be set in addition to the default configuration

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
        self._test_bench.add_config(name=name,
                                    generics=generics,
                                    pre_config=pre_config,
                                    post_check=post_check,
                                    sim_options=sim_options)

    def test(self, name):
        """
        Get a test within this test bench

        :param name: The name of the test
        :returns: A :class:`.Test` object
        """
        return Test(self._test_bench.get_test_case(name))

    def get_tests(self, pattern="*"):
        """
        Get a list of tests

        :param pattern: A wildcard pattern matching the test name
        :returns: A list of :class:`.Test` objects
        """
        results = []
        for test_case in self._test_bench.test_cases:
            if not fnmatch(abspath(test_case.name), pattern):
                continue

            results.append(Test(test_case))
        return results

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
        self._test_bench.scan_tests_from_file(file_name)


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
    def __init__(self, test_case):
        self._test_case = test_case

    @property
    def name(self):
        """
        :returns: the entity or module name of the test bench
        """
        return self._test_case.name

    def add_config(self,  # pylint: disable=too-many-arguments
                   name, generics=None, parameters=None, pre_config=None, post_check=None, sim_options=None):
        """
        Add a configuration to this test copying the default configuration.

        Multiple configuration may be added one after another.
        If no |configurations| are added the default configuration is used.

        :param name: The name of the configuration. Will be added as a suffix on the test name
        :param generics: A `dict` containing the generics to be set in addition to the default configuration.
        :param parameters: A `dict` containing the parameters to be set in addition to the default configuration.
        :param pre_config: A function to be called before test execution, replaces the default if not None.
           The function may accept a string which is the filesystem path to the
           directory where test outputs are stored.
           The function must return `True` or the test will fail
        :param post_check: A function to be called after test execution, replaces the default if not None.
           The function must accept a string which is the filesystem path to the
           directory where test outputs are stored.
           The function must return `True` or the test will fail
        :param sim_options: A `dict` containing the sim_options to be set in addition to the default configuration.

        :example:

        Given the ``lib.test_bench.test`` test and the following ``add_config`` calls:

        .. code-block:: python

           for data_width in range(14, 15+1):
               for sign in [False, True]:
                   test.add_config(
                       name="data_width=%s,sign=%s" % (data_width, sign),
                       generics=dict(data_width=data_width, sign=sign))

        The following tests will be created:

        * ``lib.test_bench.data_width=14,sign=False.test``

        * ``lib.test_bench.data_width=14,sign=True.test``

        * ``lib.test_bench.data_width=15,sign=False.test``

        * ``lib.test_bench.data_width=15,sign=True.test``

        """
        generics = {} if generics is None else generics
        generics = lower_generics(generics)
        parameters = {} if parameters is None else parameters
        generics.update(parameters)
        self._test_case.add_config(name=name,
                                   generics=generics,
                                   pre_config=pre_config,
                                   post_check=post_check,
                                   sim_options=sim_options)

    def set_generic(self, name, value):
        """
        Set a value of generic within all |configurations| of this test

        :param name: The name of the generic
        :param value: The value of the generic

        :example:

        .. code-block:: python

           test.set_generic("data_width", 16)

        """
        self._test_case.set_generic(name.lower(), value)

    def set_parameter(self, name, value):
        """
        Set a value of parameter within all |configurations| of this test

        :param name: The name of the parameter
        :param value: The value of the parameter

        :example:

        .. code-block:: python

           test.set_parameter("data_width", 16)

        """
        self._test_case.set_generic(name, value)

    def set_sim_option(self, name, value):
        """
        Set simulation option within all |configurations| of this test

        :param name: |simulation_options|
        :param value: The value of the simulation option

        :example:

        .. code-block:: python

           test.set_sim_option("ghdl.flags", ["--no-vital-checks"])

        """
        self._test_case.set_sim_option(name, value)

    def set_pre_config(self, value):
        """
        Set pre_config function of all |configurations| of this test

        :param value: The pre_config function
        """
        self._test_case.set_pre_config(value)

    def set_post_check(self, value):
        """
        Set post_check function of all |configurations| of this test

        :param value: The post_check function
        """
        self._test_case.set_post_check(value)


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

    def add_dependency_on(self, source_file):
        """
        Add manual dependency of these files on other file(s)

        :param source_file: The file(s) which this file depends on

        :example:

        .. code-block:: python

           other_file = lib.get_source_file("other_file.vhd")
           files.add_dependency_on(other_file)
        """
        for my_source_file in self:
            my_source_file.add_dependency_on(source_file)


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

    def add_dependency_on(self, source_file):
        """
        Add manual dependency of this file other file(s)

        :param source_file: The file(s) which this file depends on

        :example:

        .. code-block:: python

           other_files = lib.get_source_files("*.vhd")
           my_file.add_dependency_on(other_files)
        """
        if isinstance(source_file, SourceFile):
            private_source_file = source_file._source_file  # pylint: disable=protected-access
            self._project.add_manual_dependency(self._source_file,
                                                depends_on=private_source_file)
        elif hasattr(source_file, "__iter__"):
            for element in source_file:
                self.add_dependency_on(element)
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


def check_not_empty(lst, allow_empty, error_msg):
    """
    Raise ValueError if the list is empty unless allow_empty is True
    Returns the list
    """
    if (not allow_empty) and (not lst):
        raise ValueError(error_msg +
                         ". Use allow_empty=True to avoid exception.")
    return lst
