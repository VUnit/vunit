# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

"""
The main public Python interface of VUnit.
"""


from __future__ import print_function

import sys
import os
import traceback

from os.path import exists, relpath, abspath, join, basename, splitext
from glob import glob
from fnmatch import fnmatch
from vunit.database import PickledDataBase, DataBase

import vunit.ostools as ostools
from vunit.vunit_cli import VUnitCLI
from vunit.simulator_factory import SimulatorFactory
from vunit.color_printer import (COLOR_PRINTER,
                                 NO_COLOR_PRINTER)
from vunit.project import Project, file_type_of
from vunit.test_runner import TestRunner
from vunit.test_report import TestReport
from vunit.test_scanner import TestScanner, TestScannerError, tb_filter
from vunit.test_configuration import TestConfiguration, create_scope
from vunit.exceptions import CompileError
from vunit.location_preprocessor import LocationPreprocessor
from vunit.check_preprocessor import CheckPreprocessor
from vunit.vhdl_parser import CachedVHDLParser
from vunit.builtins import (add_vhdl_builtins,
                            add_verilog_include_dir,
                            add_array_util,
                            add_osvvm,
                            add_com)
from vunit.com import codec_generator

import logging
LOGGER = logging.getLogger(__name__)


class VUnit(object):  # pylint: disable=too-many-instance-attributes, too-many-public-methods
    """
    The public interface of VUnit
    """

    @classmethod
    def from_argv(cls, argv=None, compile_builtins=True):
        """
        Create VUnit instance from command line arguments
        Can take arguments from 'argv' if not None  instead of sys.argv
        """
        args = VUnitCLI().parse_args(argv=argv)
        return cls.from_args(args, compile_builtins=compile_builtins)

    @classmethod
    def from_args(cls, args, compile_builtins=True):
        """
        Create VUnit instance from args namespace
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
                   compile_only=args.compile,
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
                 compile_only=False,
                 elaborate_only=False,
                 vhdl_standard='2008',
                 compile_builtins=True,
                 num_threads=1,
                 exit_0=False):

        self._configure_logging(log_level)

        self._output_path = output_path

        if no_color:
            self._printer = NO_COLOR_PRINTER
        else:
            self._printer = COLOR_PRINTER

        self._verbose = verbose
        self._xunit_xml = xunit_xml

        self._test_filter = test_filter if test_filter is not None else lambda name: True
        self._list_only = list_only
        self._compile_only = compile_only
        self._vhdl_standard = vhdl_standard

        self._tb_filter = tb_filter
        self._configuration = TestConfiguration(elaborate_only=elaborate_only)
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

        if compile_builtins:
            self.add_builtins(library_name="vunit_lib")

    def _create_project(self):
        """
        Create Project instance
        """
        database = self._create_database()
        self._project = Project(
            vhdl_parser=CachedVHDLParser(database=database),
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
        version = str((5, sys.version)).encode()
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
        Add external black box library
        """
        self._project.add_library(library_name, abspath(path), is_external=True)
        return self._create_library_facade(library_name)

    def add_library(self, library_name):
        """
        Add vunit managed white box library
        """
        path = join(self._simulator_factory.simulator_output_path, "libraries", library_name)
        self._project.add_library(library_name, abspath(path))
        return self._create_library_facade(library_name)

    def library(self, library_name):
        """
        Get reference to library
        """
        if not self._project.has_library(library_name):
            raise KeyError(library_name)
        return self._create_library_facade(library_name)

    def _create_library_facade(self, library_name):
        """
        Create a Library object to be exposed to users
        """
        return LibraryFacade(library_name, self, self._project, self._configuration)

    def set_generic(self, name, value):
        """
        Globally set generic
        """
        self._configuration.set_generic(name.lower(), value, scope=create_scope())

    def set_parameter(self, name, value):
        """
        Globally set parameter
        """
        self.set_generic(name, value)

    def set_sim_option(self, name, value):
        """
        Globally set simulation option
        """
        self._configuration.set_sim_option(name, value, scope=create_scope())

    def set_compile_option(self, name, value):
        """
        Globally set compile option
        """
        for source_file in self._project.get_source_files_in_order():
            source_file.set_compile_option(name, value)

    def set_pli(self, value):
        """
        Globally set pli
        """
        self._configuration.set_pli(value, scope=create_scope())

    def disable_ieee_warnings(self):
        """
        Globally disable ieee warnings
        """
        self._configuration.disable_ieee_warnings(scope=create_scope())

    def get_source_file(self, file_name, library_name=None):
        """
        Get specific source file in specfic or any library.
        Error if multiple matches.
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
        Get source files matching wildcard pattern in either a specific
        library or all libraries
        """
        results = []
        for source_file in self._project.get_source_files_in_order():
            if library_name is not None:
                if source_file.library.name != library_name:
                    continue

            if not (fnmatch(abspath(source_file.name), pattern) or
                    fnmatch(relpath(source_file.name), pattern)):
                continue

            results.append(FileFacade(source_file, self._project))

        if (not allow_empty) and len(results) == 0:
            raise ValueError(("Pattern %r did not match any file. "
                              "Use allow_empty=True to avoid exception,") % pattern)

        return FileSetFacade(results)

    def add_source_files(self,   # pylint: disable=too-many-arguments
                         pattern, library_name, preprocessors=None, include_dirs=None, allow_empty=False):
        """
        Add source files matching wildcard pattern to library
        """
        file_names = glob(pattern)

        if (not allow_empty) and len(file_names) == 0:
            raise ValueError(("Pattern %r did not match any file. "
                              "Use allow_empty=True to avoid exception,") % pattern)

        return FileSetFacade(source_files=[
            self.add_source_file(file_name, library_name, preprocessors, include_dirs)
            for file_name in file_names])

    def add_source_file(self, file_name, library_name, preprocessors=None, include_dirs=None):
        """
        Add source file to library
        """
        file_type = file_type_of(file_name)

        if file_type == "verilog":
            include_dirs = include_dirs if include_dirs is not None else []
            add_verilog_include_dir(include_dirs)

        file_name = self._preprocess(library_name, abspath(file_name), preprocessors)
        return FileFacade(self._project.add_source_file(file_name,
                                                        library_name,
                                                        file_type=file_type,
                                                        include_dirs=include_dirs),
                          self._project)

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
        Run vunit main function and exit with code
        """
        try:
            all_ok = self._main()
        except KeyboardInterrupt:
            exit(1)
        except CompileError:
            exit(1)
        except TestScannerError:
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
                              self._configuration)
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
        simulator_if.compile_project(self._project, self._vhdl_standard)

    def _run_test(self, test_cases, report):
        """
        Run the test suites and return the report
        """
        runner = TestRunner(report,
                            join(self._output_path, "tests"),
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

    def get_project_compile_order(self, target=None):
        """
        Get all project files in compile order.  An optional target
        file may be specified causing only its direct and indirect
        dependencies to be included.
        """
        if target is not None:
            target = abspath(target)
        return self._project.get_dependencies_in_compile_order(target=target)


class LibraryFacade(object):
    """
    User interface of a library
    """
    def __init__(self, library_name, parent, project, configuration):
        self._library_name = library_name
        self._parent = parent
        self._project = project
        self._configuration = configuration
        self._scope = create_scope(self._library_name)

    def set_generic(self, name, value):
        """ Set generic within library """
        self._configuration.set_generic(name.lower(), value, scope=self._scope)

    def set_parameter(self, name, value):
        """ Set generic within library  """
        self.set_generic(name, value)

    def set_sim_option(self, name, value):
        """
        Set simulation option within library
        """
        self._configuration.set_sim_option(name, value, scope=self._scope)

    def set_compile_option(self, name, value):
        """
        Set compile option within library
        """
        for source_file in self._project.get_source_files_in_order():
            if source_file.library.name == self._library_name:
                source_file.set_compile_option(name, value)

    def set_pli(self, value):
        """ Set pli within library """
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

    def add_source_files(self, pattern, preprocessors=None, allow_empty=False):
        return self._parent.add_source_files(pattern, self._library_name, preprocessors,
                                             allow_empty=allow_empty)

    def add_source_file(self, pattern, preprocessors=None):
        return self._parent.add_source_file(pattern, self._library_name, preprocessors)

    def package(self, package_name):
        """
        Return the package with package_name or raise KeyError if does not exist
        """
        library = self._project.get_library(self._library_name)
        design_unit = library.primary_design_units.get(package_name)

        if design_unit is None:
            raise KeyError(package_name)
        if design_unit.unit_type is not 'package':
            raise KeyError(package_name)

        return PackageFacade(self._parent, self._library_name, package_name, design_unit)

    def entity(self, entity_name):
        """
        Return the entity with entity_name or raise KeyError if does not exist
        """
        library = self._project.get_library(self._library_name)
        if not library.has_entity(entity_name):
            raise KeyError(entity_name)

        return EntityFacade(self._library_name, entity_name,
                            self._configuration)

    def module(self, name):
        """
        Return the module with name or raise KeyError if does not exist
        """
        library = self._project.get_library(self._library_name)
        if name not in library.modules:
            raise KeyError(name)

        return EntityFacade(self._library_name, name,
                            self._configuration)


class EntityFacade(object):
    """
    User interface of an entity
    """
    def __init__(self, library_name, entity_name, config):
        self._library_name = library_name
        self._entity_name = entity_name
        self._config = config
        self._scope = create_scope(library_name, entity_name)

    def set_generic(self, name, value):
        """ Set generic within entity """
        self._config.set_generic(name.lower(), value, scope=self._scope)

    def set_parameter(self, name, value):
        """ Set generic within module """
        self.set_generic(name, value)

    def set_sim_option(self, name, value):
        """
        Set simulation option within entity
        """
        self._config.set_sim_option(name, value, scope=self._scope)

    def set_pli(self, value):
        """ Set pli within entity """
        self._config.set_pli(value, scope=self._scope)

    def add_config(self,  # pylint: disable=too-many-arguments
                   name="", generics=None, parameters=None, pre_config=None, post_check=None):
        """
        Add a run-configuration of all tests within entity
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
        Disable ieee warnings within entity
        """
        self._config.disable_ieee_warnings(scope=self._scope)

    def test(self, test_name):
        """
        Return the test case with test_name

        @TODO we cannot check that test exists at this point since tests are scanned in main
        @TODO assumes there is only one architecture for test benchs
        @TODO makes sense to have multiple architectures of a test bench?
        """

        return TestFacade(self._library_name, self._entity_name, test_name, self._config)


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


class TestFacade(object):
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
        Add a run-configuration this test case
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
        Set generic for test case
        """
        self._config.set_generic(name.lower(), value, scope=self._scope)

    def set_parameter(self, name, value):
        """
        Set generic within test case
        """
        self.set_generic(name, value)

    def set_sim_option(self, name, value):
        """
        Set simulation option within entity
        """
        self._config.set_sim_option(name, value, scope=self._scope)

    def disable_ieee_warnings(self):
        """
        Disable ieee warnings for test case
        """
        self._config.disable_ieee_warnings(scope=self._scope)


class FileSetFacade(list):
    """
    A set of several files
    """

    def __init__(self, source_files):
        list.__init__(self, source_files)

    def set_compile_option(self, name, value):
        """
        Set compile option
        """
        for source_file in self:
            source_file.set_compile_option(name, value)

    def depends_on(self, source_file):
        """
        Add manual dependency of these files on another
        """
        for my_source_file in self:
            my_source_file.depends_on(source_file)


class FileFacade(object):
    """
    A single file
    """
    def __init__(self, source_file, project):
        self._source_file = source_file
        self._project = project

    def set_compile_option(self, name, value):
        """
        Set compile option
        """
        self._source_file.set_compile_option(name, value)

    def depends_on(self, source_file):
        """
        Add manual dependency of this file on another
        """
        if isinstance(source_file, FileFacade):
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
    assert vhdl_standard in ('93', '2002', '2008')
    return vhdl_standard


def lower_generics(generics):
    """
    Convert all generics names to lower case to match internal representation.
    @TODO Maybe warn in case of conflict. VHDL forbids this though so the user will notice anyway.
    """
    return dict((name.lower(), value) for name, value in generics.items())
