# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

from __future__ import print_function

import argparse
from os.path import dirname, exists, abspath, join, basename, splitext
from os import makedirs, getcwd
from shutil import rmtree
from glob import glob
import traceback
from fnmatch import fnmatch

import vunit.ostools as ostools
from vunit.color_printer import (ColorPrinter,
                                 NoColorPrinter)
from vunit.modelsim_interface import ModelSimInterface
from vunit.project import Project
from vunit.test_runner import TestRunner
from vunit.test_report import TestReport
from vunit.test_scanner import TestScanner, TestScannerError, tb_filter
from vunit.test_configuration import TestConfiguration
from vunit.exceptions import CompileError
from vunit.location_preprocessor import LocationPreprocessor

import logging
logger = logging.getLogger(__name__)

class VUnit:
    """
    The public interface of VUnit
    """
    @classmethod
    def from_argv(cls, argv=None):
        """
        Create VUnit instance from command line arguments
        Can take arguments from 'argv' if not None  instead of sys.argv
        """
        parser = cls._create_argument_parser()
        args = parser.parse_args(args=argv)

        def test_filter(name):
            return any(fnmatch(name, pattern) for pattern in args.test_patterns)

        return cls(output_path=args.output_path,
                   clean=args.clean,
                   no_color=args.no_color,
                   verbose=args.verbose,
                   xunit_xml=args.xunit_xml,
                   log_level=args.log_level,
                   test_filter=test_filter,
                   list_only=args.list,
                   compile_only=args.compile)

    @classmethod
    def _create_argument_parser(cls):
        parser = argparse.ArgumentParser(description='VUnit command line tool.')

        parser.add_argument('test_patterns', metavar='tests', nargs='*',
                            default='*',
                            help='Tests to run')

        parser.add_argument('-l', '--list', action='store_true',
                           default=False,
                           help='Only list all test cases')

        parser.add_argument('--compile', action='store_true',
                           default=False,
                           help='Only compile project')

        parser.add_argument('--clean', action='store_true',
                           default=False,
                           help='Remove output path first')

        parser.add_argument('-o', '--output-path',
                           default=join(abspath(getcwd()), "vunit_out"),
                           help='Output path for compilation and simulation artifacts')

        parser.add_argument('-x', '--xunit-xml',
                           default=None,
                           help='Xunit test report .xml file')

        parser.add_argument('-v', '--verbose', action="store_true",
                           default=False,
                           help='Print test output immediately and not only when failure')

        parser.add_argument('--no-color', action='store_true',
                           default=False,
                           help='Do not color output')

        parser.add_argument('--log-level',
                            default="warning",
                            choices=["info", "error", "warning", "debug"])

        return parser

    def __init__(self,
                 output_path,
                 clean=False,
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
                 persistent_sim=True):

        self._project = Project()

        self._output_path = output_path
        self._clean = clean

        if no_color:
            self._printer = NoColorPrinter
        else:
            self._printer = ColorPrinter

        self._verbose = verbose
        self._xunit_xml = xunit_xml

        level = getattr(logging, log_level.upper())
        logging.basicConfig(filename=None, format='%(levelname)7s - %(message)s', level=level)

        self._test_filter = test_filter if test_filter is not None else lambda name : True
        self._list_only = list_only
        self._compile_only = compile_only
        self._elaborate_only = elaborate_only
        self._vhdl_standard = vhdl_standard

        self._tb_filter = tb_filter
        self._persistent_sim = persistent_sim
        self._configuration = TestConfiguration()
        self._location_preprocessor = None

        self._create_output_path()

        if compile_builtins:
            self.add_builtins(library_name="vunit_lib")

    def add_external_library(self, library_name, path):
        """
        Add external black box library
        """
        self._project.add_library(library_name, abspath(path), is_external=True)
        return LibraryFacade(library_name, self)

    def add_library(self, library_name):
        """
        Add vunit managed white box library
        """
        path = join(self._output_path, "libraries", library_name)
        self._project.add_library(library_name, abspath(path))
        return LibraryFacade(library_name, self)

    def library(self, library_name):
        """
        Get reference to library
        """
        if not library_name in self._project._libraries:
            raise KeyError(library_name)
        return LibraryFacade(library_name, self)

    def set_generic(self, name, value):
        " Globally set generic "
        self._configuration.set_generic(name, value, scope="")

    def set_pli(self, value):
        " Globally set pli "
        self._configuration.set_generic(value, scope="")

    def add_source_files(self, pattern, library_name):
        """
        Add source files matching wildcard pattern to library
        """

        for file_name in glob(pattern):
            file_name = self._preprocess(library_name, abspath(file_name))
            self._project.add_source_file(file_name,
                                          library_name,
                                          file_type=file_type_of(file_name))

    def _preprocess(self, library_name, file_name):
        # @TODO dependency checking etc...

        if self._location_preprocessor is None:
            return file_name

        code = ostools.read_file(file_name)
        code = self._location_preprocessor.run(code, basename(file_name))

        pp_file_name = join(self._preprocessed_path,
                            library_name, basename(file_name))

        idx = 1
        while ostools.file_exists(pp_file_name):
            logger.debug("Preprocessed file exists '%s', adding prefix" % pp_file_name)
            pp_file_name = join(self._preprocessed_path,
                                library_name, "%i_%s" % (idx, basename(file_name)))
            idx += 1

        ostools.write_file(pp_file_name, code)
        return pp_file_name

    def enable_location_preprocessing(self, additional_subprograms=None):
        """
        Enable location preprocessing, must be called before adding any files
        """
        self._location_preprocessor = LocationPreprocessor()
        if not additional_subprograms is None:
            for subprogram in additional_subprograms:
                self._location_preprocessor.add_subprogram(subprogram)

    def main(self):
        """
        Run vunit main function and exit with code
        """
        try:
            all_ok = self._main()
        except KeyboardInterrupt:
            # Ctrl-C
            exit(1)
        except CompileError:
            exit(1)
        except TestScannerError:
            exit(1)
        except:
            traceback.print_exc()
            exit(1)

        if not all_ok:
            exit(1)

        exit(0)

    def _main(self):
        if self._list_only:
            return self._main_list_only()

        if self._compile_only:
            return self._main_compile_only()

        simulator_if = self._create_simulator_if()
        test_cases = self._create_tests(simulator_if)
        self._compile(simulator_if)

        report = self._run_test(test_cases)
        del simulator_if
        self._post_process(report)
        return report.all_ok()

    def _main_list_only(self):
        simulator_if = None
        test_suites = self._create_tests(simulator_if)
        num_tests = 0
        for test_suite in test_suites:
            for name in test_suite.test_cases:
                print(name)
                num_tests += 1
        print("Listed %i tests" % num_tests)
        return True

    def _main_compile_only(self):
        simulator_if = self._create_simulator_if()
        self._compile(simulator_if)
        return True

    def _create_output_path(self):
        if self._clean and exists(self._output_path):
            rmtree(self._output_path)

        if exists(self._preprocessed_path):
            rmtree(self._preprocessed_path)

        if not exists(self._output_path):
            makedirs(self._output_path)

    def _create_simulator_if(self):
        return ModelSimInterface(
            join(self._output_path, "modelsim.ini"),
            persistent=self._persistent_sim)

    @property
    def _preprocessed_path(self):
        return join(self._output_path, "preprocessed")

    def _create_tests(self, simulator_if):
        scanner = TestScanner(simulator_if,
                              self._configuration,
                              elaborate_only=self._elaborate_only)
        test_list = scanner.from_project(self._project, entity_filter=self._tb_filter)
        test_list.keep_matches(self._test_filter)
        return test_list

    def _compile(self, simulator_if):
        simulator_if.compile_project(self._project, self._vhdl_standard)

    def _run_test(self, test_cases):
        report = TestReport(printer=self._printer)
        runner = TestRunner(report,
                            join(self._output_path, "tests"),
                            verbose=self._verbose)
        runner.run(test_cases)
        return report

    def _post_process(self, report):
        report.print_str()

        if not self._xunit_xml is None:
            xml = report.to_junit_xml_str()
            ostools.write_file(self._xunit_xml, xml)

    def add_builtins(self, library_name, mock_lang=False, mock_log=False):
        files = []

        if mock_lang:
            files += [join("vhdl", "src", "lang", "lang_mock.vhd")]
        else:
            files += [join("vhdl", "src", "lang", "lang.vhd")]

        files += [join("vhdl", "src", "lib", "std", "textio.vhd"),
                  join("string_ops", "src", "string_ops.vhd"),
                  join("check", "src", "check.vhd"),
                  join("check", "src", "check_api.vhd"),
                  join("check", "src", "check_base_api.vhd"),
                  join("check", "src", "check_types.vhd"),
                  join("run", "src", "run.vhd"),
                  join("run", "src", "run_api.vhd"),
                  join("run", "src", "run_types.vhd"),
                  join("run", "src", "run_base_api.vhd")]

        files +=  [join("logging", "src", "log_api.vhd"),
                   join("logging", "src", "log_formatting.vhd"),
                   join("logging", "src", "log.vhd"),
                   join("logging", "src", "log_types.vhd")]

        files +=  [join("dictionary", "src", "dictionary.vhd")]

        files +=  [join("path", "src", "path.vhd")]

        if self._vhdl_standard == '93':
            if mock_log:
                files += [join("logging", "src", "log_base93_mock.vhd"),
                          join("logging", "src", "log_special_types93.vhd"),
                          join("logging", "src", "log_base_api_mock.vhd")]
            else:
                files += [join("logging", "src", "log_base93.vhd"),
                          join("logging", "src", "log_special_types93.vhd"),
                          join("logging", "src", "log_base_api.vhd")]

            files += [join("check", "src", "check_base93.vhd"),
                      join("check", "src", "check_special_types93.vhd"),
                      join("run", "src", "run_base93.vhd"),
                      join("run", "src", "run_special_types93.vhd")]

        elif self._vhdl_standard in ('2002', '2008'):
            if mock_log:
                files += [join("logging", "src", "log_base.vhd"),
                          join("logging", "src", "log_special_types200x_mock.vhd"),
                          join("logging", "src", "log_base_api.vhd")]
            else:
                files += [join("logging", "src", "log_base.vhd"),
                          join("logging", "src", "log_special_types200x.vhd"),
                          join("logging", "src", "log_base_api.vhd")]

            files += [join("check", "src", "check_base.vhd"),
                      join("check", "src", "check_special_types200x.vhd"),
                      join("run", "src", "run_base.vhd"),
                      join("run", "src", "run_special_types200x.vhd")]

            if self._vhdl_standard == '2008':
                files += ["vunit_context.vhd"]

        library = self.add_library(library_name)
        for file_name in files:
            library.add_source_files(abspath(join(dirname(__file__), "..", "vhdl", file_name)))

class LibraryFacade:
    """
    User interface of a library
    """
    def __init__(self, library_name, parent):
        self._library_name = library_name
        self._parent = parent

    def set_generic(self, name, value):
        " Set generic within library "
        self._parent._configuration.set_generic(
            name, value, scope=self._library_name)

    def set_pli(self, value):
        " Set pli within library "
        self._parent._configuration.set_pli(value, scope=self._library_name)

    def add_source_files(self, pattern):
        self._parent.add_source_files(pattern, self._library_name)

    def entity(self, entity_name):
        library = self._parent._project._libraries[self._library_name]
        if not entity_name in library._entities:
            raise KeyError(entity_name)

        return EntityFacade("%s.%s" % (self._library_name, entity_name),
                            self._parent._configuration)

class EntityFacade:
    """
    User interface of an entity
    """
    def __init__(self, name, config):
        self._name = name
        self._config = config

    def set_generic(self, name, value):
        " Set generic within entity "
        self._config.set_generic(name, value, scope=self._name)

    def set_pli(self, value):
        " Set pli within entity "
        self._config.set_pli(value, scope=self._name)

    def add_config(self, *args, **kwargs):
        self._config.add_config(*args, tb_name=self._name, **kwargs)

def file_type_of(file_name):
    _, ext = splitext(file_name)
    if ext in (".vhd", ".vhdl"):
        return "vhdl"
    elif ext in (".v", ".sv"):
        return "verilog"
    else:
        raise RuntimeError("Unknown file ending '%s' of %s" % (ext, file_name))
