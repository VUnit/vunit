# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

# pylint: disable=too-many-lines

"""
Public VUnit User Interface (UI)
"""

import csv
import sys
import traceback
import logging
import json
import os
from typing import Optional, Set, Union
from pathlib import Path
from fnmatch import fnmatch
from ..database import PickledDataBase, DataBase
from .. import ostools
from ..vunit_cli import VUnitCLI
from ..sim_if.factory import SIMULATOR_FACTORY
from ..sim_if import SimulatorInterface
from ..color_printer import COLOR_PRINTER, NO_COLOR_PRINTER

from ..project import Project
from ..exceptions import CompileError
from ..location_preprocessor import LocationPreprocessor
from ..check_preprocessor import CheckPreprocessor
from ..parsing.encodings import HDL_FILE_ENCODING
from ..builtins import Builtins
from ..vhdl_standard import VHDL, VHDLStandard
from ..test.bench_list import TestBenchList
from ..test.report import TestReport
from ..test.runner import TestRunner

from .common import LOGGER, TEST_OUTPUT_PATH, select_vhdl_standard, check_not_empty
from .source import SourceFile, SourceFileList
from .library import Library
from .results import Results


class VUnit(  # pylint: disable=too-many-instance-attributes, too-many-public-methods
    object
):
    """
    The public interface of VUnit

    :example:

    .. code-block:: python

       from vunit import VUnit
    """

    @classmethod
    def from_argv(
        cls,
        argv=None,
        compile_builtins: Optional[bool] = True,
        vhdl_standard: Optional[str] = None,
    ):
        """
        Create VUnit instance from command line arguments.

        :param argv: Use explicit argv instead of actual command line argument
        :param compile_builtins: Do not compile builtins. Used for VUnit internal testing.
        :param vhdl_standard: The VHDL standard used to compile files,
                              if None the VUNIT_VHDL_STANDARD environment variable is used
        :returns: A :class:`.VUnit` object instance

        :example:

        .. code-block:: python

           from vunit import VUnit
           prj = VUnit.from_argv()

        """
        args = VUnitCLI().parse_args(argv=argv)
        return cls.from_args(
            args, compile_builtins=compile_builtins, vhdl_standard=vhdl_standard
        )

    @classmethod
    def from_args(
        cls,
        args,
        compile_builtins: Optional[bool] = True,
        vhdl_standard: Optional[str] = None,
    ):
        """
        Create VUnit instance from args namespace.
        Intended for users who adds custom command line options.
        See :class:`vunit.vunit_cli.VUnitCLI` class to learn about
        adding custom command line options.

        :param args: The parsed argument namespace object
        :param compile_builtins: Do not compile builtins. Used for VUnit internal testing.
        :param vhdl_standard: The VHDL standard used to compile files,
                              if None the VUNIT_VHDL_STANDARD environment variable is used
        :returns: A :class:`.VUnit` object instance

        """
        return cls(args, compile_builtins=compile_builtins, vhdl_standard=vhdl_standard)

    def __init__(
        self,
        args,
        compile_builtins: Optional[bool] = True,
        vhdl_standard: Optional[str] = None,
    ):
        self._args = args
        self._configure_logging(args.log_level)
        self._output_path = str(Path(args.output_path).resolve())

        if args.no_color:
            self._printer = NO_COLOR_PRINTER
        else:
            self._printer = COLOR_PRINTER

        def test_filter(name, attribute_names):
            keep = any(fnmatch(name, pattern) for pattern in args.test_patterns)

            if args.with_attributes is not None:
                keep = keep and set(args.with_attributes).issubset(attribute_names)

            if args.without_attributes is not None:
                keep = keep and set(args.without_attributes).isdisjoint(attribute_names)
            return keep

        self._test_filter = test_filter
        self._vhdl_standard: VHDLStandard = select_vhdl_standard(vhdl_standard)

        self._external_preprocessors = []  # type: ignore
        self._location_preprocessor = None
        self._check_preprocessor = None

        self._simulator_class = SIMULATOR_FACTORY.select_simulator()

        # Use default simulator options if no simulator was present
        if self._simulator_class is None:
            simulator_class = SimulatorInterface
            self._simulator_output_path = str(Path(self._output_path) / "none")
        else:
            simulator_class = self._simulator_class
            self._simulator_output_path = str(
                Path(self._output_path) / simulator_class.name
            )

        self._create_output_path(args.clean)

        database = self._create_database()
        self._project = Project(
            database=database,
            depend_on_package_body=simulator_class.package_users_depend_on_bodies,
        )

        self._test_bench_list = TestBenchList(database=database)

        self._builtins = Builtins(self, self._vhdl_standard, simulator_class)
        if compile_builtins:
            self.add_builtins()

    def _create_database(self):
        """
        Create a persistent database to store expensive parse results

        Check for Python version used to create the database is the
        same as the running python instance or re-create
        """
        project_database_file_name = str(Path(self._output_path) / "project_database")
        create_new = False
        key = b"version"
        version = str((9, sys.version)).encode()
        database = None
        try:
            database = DataBase(project_database_file_name)
            create_new = (key not in database) or (database[key] != version)
        except KeyboardInterrupt as exk:
            raise KeyboardInterrupt from exk
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
        logging.basicConfig(
            filename=None, format="%(levelname)7s - %(message)s", level=level
        )

    def _which_vhdl_standard(self, vhdl_standard: Optional[str]) -> VHDLStandard:
        """
        Return default vhdl_standard if the argument is None
        The argument is a string from the user
        """
        if vhdl_standard is None:
            return self._vhdl_standard

        return VHDL.standard(vhdl_standard)

    def add_external_library(
        self, library_name, path: Union[str, Path], vhdl_standard: Optional[str] = None
    ):
        """
        Add an externally compiled library as a black-box

        :param library_name: The name of the external library
        :param path: The path to the external library directory
        :param vhdl_standard: The VHDL standard used to compile files,
                              if None the VUNIT_VHDL_STANDARD environment variable is used
        :returns: The created :class:`.Library` object

        :example:

        .. code-block:: python

           prj.add_external_library("unisim", "path/to/unisim/")

        """

        self._project.add_library(
            library_name,
            Path(path).resolve(),
            self._which_vhdl_standard(vhdl_standard),
            is_external=True,
        )
        return self.library(library_name)

    def add_source_files_from_csv(
        self, project_csv_path: Union[str, Path], vhdl_standard: Optional[str] = None
    ):
        """
        Add a project configuration, mapping all the libraries and files

        :param project_csv_path: path to csv project specification, each line contains the name
                                 of the library and the path to one file 'lib_name,filename'
                                 note that all filenames are relative to the parent folder of the
                                 csv file
        :param vhdl_standard: The VHDL standard used to compile files,
                              if None, the VUNIT_VHDL_STANDARD environment variable is used
        :returns: A list of files (:class `.SourceFileList`) that were added

        """
        libs: Set[str] = set()
        files = SourceFileList(list())

        ppath = Path(project_csv_path)

        with ppath.open() as csv_path_file:
            for row in csv.reader(csv_path_file):
                if len(row) == 2:
                    lib_name = row[0].strip()
                    no_normalized_file = row[1].strip()
                    file_name_ = str((ppath.parent / no_normalized_file).resolve())
                    lib = (
                        self.library(lib_name)
                        if lib_name in libs
                        else self.add_library(lib_name)
                    )
                    libs.add(lib_name)
                    file_ = lib.add_source_file(file_name_, vhdl_standard=vhdl_standard)
                    files.append(file_)
                elif len(row) > 2:
                    LOGGER.error(
                        "More than one library and one file in csv description"
                    )
        return files

    def add_library(
        self,
        library_name: str,
        vhdl_standard: Optional[str] = None,
        allow_duplicate: Optional[bool] = False,
    ):
        """
        Add a library managed by VUnit.

        :param library_name: The name of the library
        :param vhdl_standard: The VHDL standard used to compile files,
                              if None the VUNIT_VHDL_STANDARD environment variable is used
        :param allow_duplicate: Set to True to allow the same library
                                to be added multiple times. Subsequent additions will just
                                return the previously created library.
        :returns: The created :class:`.Library` object

        :example:

        .. code-block:: python

           library = prj.add_library("lib")

        """
        standard = self._which_vhdl_standard(vhdl_standard)
        path = Path(self._simulator_output_path) / "libraries" / library_name
        if not self._project.has_library(library_name):
            self._project.add_library(library_name, str(path.resolve()), standard)
        elif not allow_duplicate:
            raise ValueError(
                "Library %s already added. Use allow_duplicate to ignore this error."
                % library_name
            )
        return self.library(library_name)

    def library(self, library_name: str):
        """
        Get a library

        :param library_name: The name of the library
        :returns: A :class:`.Library` object
        """
        if not self._project.has_library(library_name):
            raise KeyError(library_name)
        return Library(library_name, self, self._project, self._test_bench_list)

    def set_attribute(self, name: str, value: str, allow_empty: Optional[bool] = False):
        """
        Set a value of attribute in all |configurations|

        :param name: The name of the attribute
        :param value: The value of the attribute
        :param allow_empty: To disable an error when no test benches were found

        :example:

        .. code-block:: python

           prj.set_attribute(".foo", "bar")

        .. note::
           Only affects test benches added *before* the attribute is set.
        """
        test_benches = self._test_bench_list.get_test_benches()
        for test_bench in check_not_empty(
            test_benches, allow_empty, "No test benches found"
        ):
            test_bench.set_attribute(name, value)

    def set_generic(self, name: str, value: str, allow_empty: Optional[bool] = False):
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
        for test_bench in check_not_empty(
            test_benches, allow_empty, "No test benches found"
        ):
            test_bench.set_generic(name.lower(), value)

    def set_parameter(self, name: str, value: str, allow_empty: Optional[bool] = False):
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
        for test_bench in check_not_empty(
            test_benches, allow_empty, "No test benches found"
        ):
            test_bench.set_generic(name, value)

    def set_sim_option(
        self,
        name: str,
        value: str,
        allow_empty: Optional[bool] = False,
        overwrite: Optional[bool] = True,
    ):
        """
        Set simulation option in all |configurations|

        :param name: |simulation_options|
        :param value: The value of the simulation option
        :param allow_empty: To disable an error when no test benches were found
        :param overwrite: To overwrite the option or append to the existing value

        :example:

        .. code-block:: python

           prj.set_sim_option("ghdl.a_flags", ["--no-vital-checks"])

        .. note::
           Only affects test benches added *before* the option is set.
        """
        test_benches = self._test_bench_list.get_test_benches()
        for test_bench in check_not_empty(
            test_benches, allow_empty, "No test benches found"
        ):
            test_bench.set_sim_option(name, value, overwrite)

    def set_compile_option(
        self, name: str, value: str, allow_empty: Optional[bool] = False
    ):
        """
        Set compile option of all files

        :param name: |compile_option|
        :param value: The value of the compile option
        :param allow_empty: To disable an error when no source files were found

        :example:

        .. code-block:: python

           prj.set_compile_option("ghdl.a_flags", ["--no-vital-checks"])


        .. note::
           Only affects files added *before* the option is set.
        """
        source_files = self._project.get_source_files_in_order()
        for source_file in check_not_empty(
            source_files, allow_empty, "No source files found"
        ):
            source_file.set_compile_option(name, value)

    def add_compile_option(
        self, name: str, value: str, allow_empty: Optional[bool] = False
    ):
        """
        Add compile option to all files

        :param name: |compile_option|
        :param value: The value of the compile option
        :param allow_empty: To disable an error when no source files were found

        .. note::
           Only affects files added *before* the option is set.
        """
        source_files = self._project.get_source_files_in_order()
        for source_file in check_not_empty(
            source_files, allow_empty, "No source files found"
        ):
            source_file.add_compile_option(name, value)

    def get_source_file(
        self, file_name: Union[str, Path], library_name: Optional[str] = None
    ):
        """
        Get a source file

        :param file_name: The name of the file as a relative or absolute path
        :param library_name: The name of a specific library to search if not all libraries
        :returns: A :class:`.SourceFile` object
        """

        fstr = str(file_name)

        files = self.get_source_files(fstr, library_name, allow_empty=True)
        if len(files) > 1:
            raise ValueError(
                "Found file named '%s' in multiple-libraries, "
                "add explicit library_name." % fstr
            )
        if not files:
            if library_name is None:
                raise ValueError("Found no file named '%s'" % fstr)

            raise ValueError(
                "Found no file named '%s' in library '%s'" % (fstr, library_name)
            )
        return files[0]

    def get_source_files(
        self,
        pattern="*",
        library_name: Optional[str] = None,
        allow_empty: Optional[bool] = False,
    ):
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

            if not (
                fnmatch(str(Path(source_file.name).resolve()), pattern)
                or fnmatch(ostools.simplify_path(source_file.name), pattern)
            ):
                continue

            results.append(SourceFile(source_file, self._project, self))

        check_not_empty(
            results,
            allow_empty,
            ("Pattern %r did not match any file" % pattern)
            + (
                ("within library %s" % library_name) if library_name is not None else ""
            ),
        )

        return SourceFileList(results)

    def add_source_files(  # pylint: disable=too-many-arguments
        self,
        pattern,
        library_name: str,
        preprocessors=None,
        include_dirs=None,
        defines=None,
        allow_empty: Optional[bool] = False,
        vhdl_standard: Optional[str] = None,
        no_parse: Optional[bool] = False,
        file_type=None,
    ):
        """
        Add source files matching wildcard pattern to library

        :param pattern: A wildcard pattern matching the files to add or a list of files
        :param library_name: The name of the library to add files into
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param allow_empty: To disable an error if no files matched the pattern
        :param vhdl_standard: The VHDL standard used to compile files,
                              if None VUNIT_VHDL_STANDARD environment variable is used
        :param no_parse: Do not parse file(s) for dependency or test scanning purposes
        :param file_type: The type of the file; ``"vhdl"``, ``"verilog"``  or ``"systemverilog"``.
                          Auto-detected by default when set to ``None``.
        :returns: A list of files (:class:`.SourceFileList`) which were added

        :example:

        .. code-block:: python

           prj.add_source_files("*.vhd", "lib")

        """
        return self.library(library_name).add_source_files(
            pattern=pattern,
            preprocessors=preprocessors,
            include_dirs=include_dirs,
            defines=defines,
            allow_empty=allow_empty,
            vhdl_standard=vhdl_standard,
            no_parse=no_parse,
            file_type=file_type,
        )

    def add_source_file(  # pylint: disable=too-many-arguments
        self,
        file_name: Union[str, Path],
        library_name: str,
        preprocessors=None,
        include_dirs=None,
        defines=None,
        vhdl_standard: Optional[str] = None,
        no_parse: Optional[bool] = False,
        file_type=None,
    ):
        """
        Add source file to library

        :param file_name: The name of the file
        :param library_name: The name of the library to add the file into
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param vhdl_standard: The VHDL standard used to compile this file,
                              if None VUNIT_VHDL_STANDARD environment variable is used
        :param no_parse: Do not parse file for dependency or test scanning purposes
        :param file_type: The type of the file; ``"vhdl"``, ``"verilog"``  or ``"systemverilog"``.
                          Auto-detected by default when set to ``None``.
        :returns: The :class:`.SourceFile` which was added

        :example:

        .. code-block:: python

           prj.add_source_file("file.vhd", "lib")

        """
        return self.library(library_name).add_source_file(
            file_name=str(file_name),
            preprocessors=preprocessors,
            include_dirs=include_dirs,
            defines=defines,
            vhdl_standard=vhdl_standard,
            no_parse=no_parse,
            file_type=file_type,
        )

    def _preprocess(
        self, library_name: str, file_name: Union[str, Path], preprocessors
    ):
        """
        Preprocess file_name within library_name using explicit preprocessors
        if preprocessors is None then use implicit globally defined processors
        """
        # @TODO dependency checking etc...

        if preprocessors is None:
            preprocessors = [self._location_preprocessor, self._check_preprocessor]
            preprocessors = [p for p in preprocessors if p is not None]
            preprocessors = self._external_preprocessors + preprocessors

        fstr = str(file_name)

        if not preprocessors:
            return fstr

        fname = str(Path(file_name).name)

        try:
            code = ostools.read_file(file_name, encoding=HDL_FILE_ENCODING)
            for preprocessor in preprocessors:
                code = preprocessor.run(code, fname)
        except KeyboardInterrupt as exk:
            raise KeyboardInterrupt from exk
        except:  # pylint: disable=bare-except
            traceback.print_exc()
            LOGGER.error("Failed to preprocess %s", fstr)
            return fstr
        else:
            pp_file_name = str(Path(self._preprocessed_path) / library_name / fname)

            idx = 1
            while ostools.file_exists(pp_file_name):
                LOGGER.debug(
                    "Preprocessed file exists '%s', adding prefix", pp_file_name
                )
                pp_file_name = str(
                    Path(self._preprocessed_path)
                    / library_name
                    / ("%i_%s" % (idx, fname)),
                )
                idx += 1

            ostools.write_file(pp_file_name, code, encoding=HDL_FILE_ENCODING)
            return pp_file_name

    def add_preprocessor(self, preprocessor):
        """
        Add a custom preprocessor to be used on all files, must be called before adding any files
        """
        self._external_preprocessors.append(preprocessor)

    def enable_location_preprocessing(
        self, additional_subprograms=None, exclude_subprograms=None
    ):
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

    def main(self, post_run=None):
        """
        Run vunit main function and exit

        :param post_run: A callback function which is called after
          running tests. The function must accept a single `results`
          argument which is an instance of :class:`.Results`
        """
        try:
            all_ok = self._main(post_run)
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

    def _create_tests(self, simulator_if: Union[None, SimulatorInterface]):
        """
        Create the test cases
        """
        self._test_bench_list.warn_when_empty()
        test_list = self._test_bench_list.create_tests(
            simulator_if, self._args.elaborate
        )
        test_list.keep_matches(self._test_filter)
        return test_list

    def _main(self, post_run):
        """
        Base vunit main function without performing exit
        """

        if self._args.export_json is not None:
            return self._main_export_json(self._args.export_json)

        if self._args.list:
            return self._main_list_only()

        if self._args.files:
            return self._main_list_files_only()

        if self._args.compile:
            return self._main_compile_only()

        all_ok = self._main_run(post_run)
        return all_ok

    def _create_simulator_if(self):
        """
        Create new simulator instance
        """

        if self._simulator_class is None:
            LOGGER.error(
                "No available simulator detected.\n"
                "Simulator binary folder must be available in PATH environment variable.\n"
                "Simulator binary folder can also be set the in VUNIT_<SIMULATOR_NAME>_PATH environment variable.\n"
            )
            sys.exit(1)

        if not Path(self._simulator_output_path).exists():
            os.makedirs(self._simulator_output_path)

        return self._simulator_class.from_args(
            args=self._args, output_path=self._simulator_output_path
        )

    def _main_run(self, post_run):
        """
        Main with running tests
        """
        simulator_if = self._create_simulator_if()
        test_list = self._create_tests(simulator_if)
        self._compile(simulator_if)
        print()

        start_time = ostools.get_time()
        report = TestReport(printer=self._printer)

        try:
            self._run_test(test_list, report)
        except KeyboardInterrupt:
            print()
            LOGGER.debug("_main: Caught Ctrl-C shutting down")
        finally:
            del test_list

        report.set_real_total_time(ostools.get_time() - start_time)
        report.print_str()

        if post_run is not None:
            post_run(results=Results(self._output_path, simulator_if, report))

        del simulator_if

        if self._args.xunit_xml is not None:
            xml = report.to_junit_xml_str(self._args.xunit_xml_format)
            ostools.write_file(self._args.xunit_xml, xml)

        return report.all_ok()

    def _main_list_only(self):
        """
        Main function when only listing test cases
        """
        test_list = self._create_tests(simulator_if=None)
        for test_name in test_list.test_names:
            print(test_name)
        print("Listed %i tests" % test_list.num_tests)
        return True

    def _main_export_json(
        self, json_file_name: Union[str, Path]
    ):  # pylint: disable=too-many-locals
        """
        Main function when exporting to JSON
        """

        file_objects = self.get_compile_order()
        files = []
        for source_file in file_objects:
            files.append(
                dict(
                    file_name=str(Path(source_file.name).resolve()),
                    library_name=source_file.library.name,
                )
            )

        tests = []
        for test_suite in self._create_tests(simulator_if=None):
            test_information = test_suite.test_information
            test_configuration = test_suite.test_configuration
            for name in test_suite.test_names:
                info = test_information[name]
                config = test_configuration[name]

                attributes = {}
                for attr in info.attributes:
                    attributes[attr.name] = attr.value

                attributes.update(config.attributes)

                tests.append(
                    dict(
                        name=name,
                        location=dict(
                            file_name=str(info.location.file_name),
                            offset=info.location.offset,
                            length=info.location.length,
                        ),
                        attributes=attributes,
                    )
                )

        json_data = dict(
            # The semantic version (https://semver.org/) of the JSON export data format
            export_format_version=dict(major=1, minor=0, patch=0),
            # The set of files added to the project
            files=files,
            # The list of all tests
            tests=tests,
        )

        with Path(json_file_name).open("w") as fptr:
            json.dump(json_data, fptr, sort_keys=True, indent=4, separators=(",", ": "))

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

    def _create_output_path(self, clean: bool):
        """
        Create or re-create the output path if necessary
        """
        if clean:
            ostools.renew_path(self._output_path)
        elif not Path(self._output_path).exists():
            os.makedirs(self._output_path)

        ostools.renew_path(self._preprocessed_path)

    @property
    def vhdl_standard(self) -> str:
        return str(self._vhdl_standard)

    @property
    def _preprocessed_path(self):
        return str(Path(self._output_path) / "preprocessed")

    @property
    def codecs_path(self):
        return str(Path(self._output_path) / "codecs")

    def _compile(self, simulator_if: SimulatorInterface):
        """
        Compile entire project
        """
        # get test benches
        if self._args.minimal:
            target_files = self._get_testbench_files(simulator_if)
        else:
            target_files = None

        simulator_if.compile_project(
            self._project,
            continue_on_error=self._args.keep_compiling,
            printer=self._printer,
            target_files=target_files,
        )

    def _get_testbench_files(self, simulator_if: Union[None, SimulatorInterface]):
        """
        Return the list of all test bench files for the currently selected tests to run
        """
        test_list = self._create_tests(simulator_if)
        tb_file_names = {test_suite.file_name for test_suite in test_list}
        return [
            self.get_source_file(  # pylint: disable=protected-access
                file_name
            )._source_file
            for file_name in tb_file_names
        ]

    def _run_test(self, test_cases, report):
        """
        Run the test suites and return the report
        """

        if self._args.verbose:
            verbosity = TestRunner.VERBOSITY_VERBOSE
        elif self._args.quiet:
            verbosity = TestRunner.VERBOSITY_QUIET
        else:
            verbosity = TestRunner.VERBOSITY_NORMAL

        runner = TestRunner(
            report,
            str(Path(self._output_path) / TEST_OUTPUT_PATH),
            verbosity=verbosity,
            num_threads=self._args.num_threads,
            fail_fast=self._args.fail_fast,
            dont_catch_exceptions=self._args.dont_catch_exceptions,
            no_color=self._args.no_color,
        )
        runner.run(test_cases)

    def add_builtins(self, external=None):
        """
        Add vunit VHDL builtin libraries

        :param external: struct to provide bridges for the external VHDL API.
                         {
                             'string': ['path/to/custom/file'],
                             'integer': ['path/to/custom/file']
                         }.
        """
        self._builtins.add_vhdl_builtins(external=external)

    def add_com(self):
        """
        Add communication package
        """
        self._builtins.add("com")

    def add_array_util(self):
        """
        Add array util
        """
        self._builtins.add("array_util")

    def add_random(self):
        """
        Add random
        """
        self._builtins.add("random")

    def add_verification_components(self):
        """
        Add verification component library
        """
        self._builtins.add("verification_components")

    def add_osvvm(self):
        """
        Add osvvm library
        """
        self._builtins.add("osvvm")

    def add_json4vhdl(self):
        """
        Add JSON-for-VHDL library
        """
        self._builtins.add("json4vhdl")

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
            source_files = self.get_source_files(allow_empty=True)

        target_files = [
            source_file._source_file  # pylint: disable=protected-access
            for source_file in source_files
        ]
        source_files = self._project.get_dependencies_in_compile_order(target_files)
        return SourceFileList(
            [
                SourceFile(source_file, self._project, self)
                for source_file in source_files
            ]
        )

    def get_implementation_subset(self, source_files):
        """
        Get the subset of files which are required to successfully
        elaborate the list of input files without any missing
        dependencies.

        :param source_files: A list of :class:`.SourceFile` objects
        :returns: A list of :class:`.SourceFile` objects which is the implementation subset.
        """
        target_files = [
            source_file._source_file  # pylint: disable=protected-access
            for source_file in source_files
        ]
        source_files = self._project.get_dependencies_in_compile_order(
            target_files, implementation_dependencies=True
        )
        return SourceFileList(
            [
                SourceFile(source_file, self._project, self)
                for source_file in source_files
            ]
        )

    def get_simulator_name(self):
        """
        Get the name of the simulator used.

        Will return None if no simulator was found.
        """
        if self._simulator_class is None:
            return None
        return self._simulator_class.name

    def simulator_supports_coverage(self):
        """
        Returns True when the simulator supports coverage

        Will return None if no simulator was found.
        """
        if self._simulator_class is None:
            return None
        return self._simulator_class.supports_coverage()
