# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
UI classes Library and LibraryList
"""

from pathlib import Path
from fnmatch import fnmatch
from typing import Optional
from ..vhdl_standard import VHDL, VHDLStandard
from ..project import Project
from ..source_file import file_type_of, FILE_TYPES, VERILOG_FILE_TYPES
from ..builtins import add_verilog_include_dir
from .common import check_not_empty, get_checked_file_names_from_globs
from .source import SourceFile, SourceFileList
from .testbench import TestBench
from .packagefacade import PackageFacade


class LibraryList(list):
    """
    A list of :class:`.Library`
    """

    def __init__(self, libraries):
        list.__init__(self, libraries)

    def get_test_benches(self, pattern="*", allow_empty=False):
        """
        Get a list of test benches

        :param pattern: A wildcard pattern matching the test_bench name
        :param allow_empty: To disable an error when no test benches were found
        :returns: A list of :class:`.TestBench` objects
        """
        results = []
        for library in self:
            results += library.get_test_benches(pattern, allow_empty=True)

        return check_not_empty(
            results,
            allow_empty,
            "No testbenches found within libraries",
        )

    def set_generic(self, name, value, allow_empty=False):
        """
        Set a value of generic within all |configurations| of test benches and tests in these libraries

        :param name: The name of the generic
        :param value: The value of the generic
        :param allow_empty: To disable an error when no test benches were found

        :example:

        .. code-block:: python

           libs.set_generic("data_width", 16)

        .. note::
           Only affects test benches added *before* the generic is set.
        """
        check_not_empty(
            self.get_test_benches(allow_empty=True),
            allow_empty,
            "No testbenches in libraries",
        )

        for library in self:
            library.set_generic(name, value, allow_empty=True)

    def set_parameter(self, name, value, allow_empty=False):
        """
        Set a value of parameter within all |configurations| of test benches and tests in these libraries

        :param name: The name of the parameter
        :param value: The value of the parameter
        :param allow_empty: To disable an error when no test benches were found

        :example:

        .. code-block:: python

           libs.set_parameter("data_width", 16)

        .. note::
           Only affects test benches added *before* the parameter is set.
        """
        check_not_empty(
            self.get_test_benches(allow_empty=True),
            allow_empty,
            "No testbenches in libraries",
        )

        for library in self:
            library.set_parameter(name, value, allow_empty=True)

    def set_sim_option(self, name, value, allow_empty=False, overwrite=True):
        """
        Set simulation option within all |configurations| of test benches and tests in these libraries.

        :param name: |simulation_options|
        :param value: The value of the simulation option
        :param allow_empty: To disable an error when no test benches were found
        :param overwrite: To overwrite the option or append to the existing value

        :example:

        .. code-block:: python

           libs.set_sim_option("ghdl.a_flags", ["--no-vital-checks"])

        .. note::
           Only affects test benches added *before* the option is set.
        """
        check_not_empty(
            self.get_test_benches(allow_empty=True),
            allow_empty,
            "No testbenches in libraries",
        )

        for library in self:
            library.set_sim_option(name, value, allow_empty=True, overwrite=overwrite)

    def get_source_files(self, pattern="*", allow_empty=False):
        """
        Get a list of source files within these libraries

        :param pattern: A wildcard pattern matching either an absolute or relative path
        :param allow_empty: To disable an error if no files matched the pattern
        :returns: A :class:`.SourceFileList` object
        """

        results = [
            source_file for library in self for source_file in library.get_source_files(pattern, allow_empty=True)
        ]

        check_not_empty(
            results,
            allow_empty,
            f"Pattern {pattern} did not match any file",
        )

        return SourceFileList(results)

    def set_compile_option(self, name, value, allow_empty=False):
        """
        Set compile option for all files within these libraries

        :param name: |compile_option|
        :param value: The value of the compile option
        :param allow_empty: To disable an error when no source files were found

        :example:

        .. code-block:: python

           libs.set_compile_option("ghdl.a_flags", ["--no-vital-checks"])


        .. note::
           Only affects files added *before* the option is set.
        """
        check_not_empty(
            self.get_source_files(allow_empty=True),
            allow_empty,
            "No source files in libraries",
        )

        for library in self:
            library.set_compile_option(name, value, allow_empty=True)

    def add_compile_option(self, name, value, allow_empty=False):
        """
        Add compile option to all files within these libraries

        :param name: |compile_option|
        :param value: The value of the compile option
        :param allow_empty: To disable an error when no source files were found

        .. note::
           Only affects files added *before* the option is set.
        """
        check_not_empty(
            self.get_source_files(allow_empty=True),
            allow_empty,
            "No source files in libraries",
        )

        for library in self:
            library.add_compile_option(name, value, allow_empty=True)


class Library(object):
    """
    User interface of a library
    """

    def __init__(self, library_name, parent, project: Project, test_bench_list):
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

    def set_sim_option(self, name, value, allow_empty=False, overwrite=True):
        """
        Set simulation option within all |configurations| of test benches and tests this library

        :param name: |simulation_options|
        :param value: The value of the simulation option
        :param allow_empty: To disable an error when no test benches were found
        :param overwrite: To overwrite the option or append to the existing value

        :example:

        .. code-block:: python

           lib.set_sim_option("ghdl.a_flags", ["--no-vital-checks"])

        .. note::
           Only affects test benches added *before* the option is set.
        """
        for test_bench in self.get_test_benches(allow_empty=allow_empty):
            test_bench.set_sim_option(name, value, overwrite)

    def set_compile_option(self, name, value, allow_empty=False):
        """
        Set compile option for all files within the library

        :param name: |compile_option|
        :param value: The value of the compile option
        :param allow_empty: To disable an error when no source files were found

        :example:

        .. code-block:: python

           lib.set_compile_option("ghdl.a_flags", ["--no-vital-checks"])


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

    def add_source_files(  # pylint: disable=too-many-arguments, too-many-positional-arguments
        self,
        pattern,
        preprocessors=None,
        include_dirs=None,
        defines=None,
        allow_empty=False,
        vhdl_standard: Optional[str] = None,
        no_parse=False,
        file_type=None,
    ):
        """
        Add source files matching wildcard pattern to library

        :param pattern: A wildcard pattern match the files to add
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param allow_empty: To disable an error if no files matched the pattern
        :param vhdl_standard: The VHDL standard used to compile files, if None library default is used
        :param no_parse: Do not parse file(s) for dependency or test scanning purposes
        :param file_type: The type of the file; ``"vhdl"``, ``"verilog"``  or ``"systemverilog"``.
                          Auto-detected by default when set to ``None``.
        :returns: A list of files (:class:`.SourceFileList`) which were added

        :example:

        .. code-block:: python

           library.add_source_files("*.vhd")

        """
        return SourceFileList(
            source_files=[
                self.add_source_file(
                    file_name,
                    preprocessors,
                    include_dirs,
                    defines,
                    vhdl_standard,
                    no_parse=no_parse,
                    file_type=file_type,
                )
                for file_name in get_checked_file_names_from_globs(pattern, allow_empty)
            ]
        )

    def add_source_file(  # pylint: disable=too-many-arguments,too-many-positional-arguments
        self,
        file_name,
        preprocessors=None,
        include_dirs=None,
        defines=None,
        vhdl_standard: Optional[str] = None,
        no_parse=False,
        file_type=None,
    ):
        """
        Add source file to library

        :param file_name: The name of the file
        :param include_dirs: A list of include directories
        :param defines: A dictionary containing Verilog defines to be set
        :param vhdl_standard: The VHDL standard used to compile this file, if None library default is used
        :param no_parse: Do not parse file for dependency or test scanning purposes
        :param file_type: The type of the file; ``"vhdl"``, ``"verilog"``  or ``"systemverilog"``.
                          Auto-detected by default when set to ``None``.
        :returns: The :class:`.SourceFile` which was added

        :example:

        .. code-block:: python

           library.add_source_file("file.vhd")

        """
        file_name = Path(file_name).resolve()

        if file_type is None:
            file_type = file_type_of(file_name)
        elif file_type not in FILE_TYPES:
            raise ValueError(f"file_type {file_type!r} not in {FILE_TYPES!r}")

        if file_type in VERILOG_FILE_TYPES:
            include_dirs = include_dirs if include_dirs is not None else []
            include_dirs = add_verilog_include_dir(include_dirs)

        new_file_name = self._parent._preprocess(  # pylint: disable=protected-access
            self._library_name, file_name, preprocessors
        )

        source_file = self._project.add_source_file(
            new_file_name,
            self._library_name,
            file_type=file_type,
            include_dirs=include_dirs,
            defines=defines,
            vhdl_standard=self._which_vhdl_standard(vhdl_standard),
            no_parse=no_parse,
        )
        # To get correct tb_path generic
        source_file.original_name = file_name

        self._test_bench_list.add_from_source_file(source_file)

        return SourceFile(source_file, self._project, self._parent)

    def package(self, name):
        """
        Get a package within the library
        """
        library = self._project.get_library(self._library_name)
        design_unit = library.primary_design_units.get(name)

        if design_unit is None:
            raise KeyError(name)
        if design_unit.unit_type != "package":
            raise KeyError(name)

        return PackageFacade(self._parent, self._library_name, name, design_unit)

    def entity(self, name):
        """
        Get an entity within the library

        :param name: The name of the entity
        :returns: A :class:`.TestBench` object
        :raises: KeyError
        """
        name = name.lower()
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
        name = name.lower()

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
            if not fnmatch(Path(test_bench.name).resolve(), pattern):
                continue

            results.append(TestBench(test_bench, self))

        return check_not_empty(
            results,
            allow_empty,
            f"No test benches found within library {self._library_name!s}",
        )

    def _which_vhdl_standard(self, vhdl_standard: Optional[str]) -> VHDLStandard:
        """
        Return default vhdl_standard if the argument is None
        The argument is a string from the user
        """
        if vhdl_standard is None:
            return self._project.get_library(self._library_name).vhdl_standard

        return VHDL.standard(vhdl_standard)
