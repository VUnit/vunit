# Classes to model a HDL design hierarchy
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Functionality to represent and operate on a HDL code project
"""
from typing import Optional, Union
from pathlib import Path
import logging
from collections import OrderedDict
from vunit.hashing import hash_string
from vunit.dependency_graph import DependencyGraph, CircularDependencyException
from vunit.vhdl_parser import VHDLParser
from vunit.parsing.verilog.parser import VerilogParser
from vunit.exceptions import CompileError
from vunit import ostools
from vunit.source_file import (
    VERILOG_FILE_TYPES,
    SourceFile,
    VerilogSourceFile,
    VHDLSourceFile,
)
from vunit.vhdl_standard import VHDL, VHDLStandard
from vunit.library import Library

LOGGER = logging.getLogger(__name__)


class Project(object):  # pylint: disable=too-many-instance-attributes
    """
    The representation of a HDL code project.
    Compute lists of source files to recompile based on file contents,
    timestamps and depenencies derived from the design hierarchy.
    """

    def __init__(self, depend_on_package_body=False, database=None):
        """
        depend_on_package_body - Package users depend also on package body
        """
        self._database = database
        self._vhdl_parser = VHDLParser(database=self._database)
        self._verilog_parser = VerilogParser(database=self._database)
        self._libraries = OrderedDict()
        # Mapping between library lower case name and real library name
        self._lower_library_names_dict = {}
        self._source_files_in_order = []
        self._manual_dependencies = []
        self._depend_on_package_body = depend_on_package_body
        self._builtin_libraries = set(["ieee", "std"])

    def _validate_new_library_name(self, library_name):
        """
        Check that the library_name is valid or raise RuntimeError
        """
        if library_name == "work":
            LOGGER.error(
                "Cannot add library named work. work is a reference to the current library. "
                "http://www.sigasi.com/content/work-not-vhdl-library"
            )
            raise RuntimeError("Illegal library name 'work'")

        if library_name in self._libraries:
            raise ValueError(f"Library {library_name!s} already exists")

        lower_name = library_name.lower()
        if lower_name in self._lower_library_names_dict:
            raise RuntimeError(
                f"Library name {library_name!r} not case-insensitive unique. "
                f"Library name {self._lower_library_names_dict[lower_name]!r} previously defined"
            )

    def add_builtin_library(self, logical_name):
        """
        Add a builtin library name that does not give missing dependency warnings
        """
        self._builtin_libraries.add(logical_name)

    def add_library(
        self,
        logical_name,
        directory: Union[str, Path],
        vhdl_standard: VHDLStandard = VHDL.STD_2008,
        is_external=False,
    ):
        """
        Add library to project with logical_name located or to be located in directory
        is_external -- Library is assumed to a black-box
        """
        self._validate_new_library_name(logical_name)

        dpath = Path(directory)
        dstr = str(directory)

        if is_external:
            if not dpath.exists():
                raise ValueError(f"External library {dstr!r} does not exist")

            if not dpath.is_dir():
                raise ValueError(f"External library must be a directory. Got {dstr!r}")

        library = Library(logical_name, dstr, vhdl_standard, is_external=is_external)
        LOGGER.debug("Adding library %s with path %s", logical_name, dstr)

        self._libraries[logical_name] = library
        self._lower_library_names_dict[logical_name.lower()] = library.name

    def add_source_file(  # pylint: disable=too-many-arguments
        self,
        file_name,
        library_name,
        *,
        file_type="vhdl",
        include_dirs=None,
        defines=None,
        vhdl_standard: Optional[VHDLStandard] = None,
        no_parse=False,
    ):
        """
        Add a file_name as a source file in library_name with file_type

        :param no_parse: Do not parse file contents
        """
        fname = file_name if isinstance(file_name, Path) else Path(file_name)
        if not fname.exists():
            raise ValueError(f"File {str(fname)!r} does not exist")

        LOGGER.debug("Adding source file %s to library %s", str(fname), library_name)
        library = self._libraries[library_name]

        if file_type == "vhdl":
            assert include_dirs is None
            source_file: SourceFile = VHDLSourceFile(
                fname,
                library,
                vhdl_parser=self._vhdl_parser,
                database=self._database,
                vhdl_standard=library.vhdl_standard if vhdl_standard is None else vhdl_standard,
                no_parse=no_parse,
            )
        elif file_type in VERILOG_FILE_TYPES:
            source_file = VerilogSourceFile(
                file_type,
                fname,
                library,
                verilog_parser=self._verilog_parser,
                database=self._database,
                include_dirs=include_dirs,
                defines=defines,
                no_parse=no_parse,
            )
        else:
            raise ValueError(file_type)

        old_source_file = library.add_source_file(source_file)
        if id(source_file) == id(old_source_file):
            self._source_files_in_order.append(source_file)

        return old_source_file

    def add_manual_dependency(self, source_file, depends_on):
        """
        Add manual dependency where 'source_file' depends_on 'depends_on'
        """
        self._manual_dependencies.append((source_file, depends_on))

    @staticmethod
    def _failed_to_find_primary_design_unit_in_library(source_file_name, primary_design_unit, library_name):
        """
        Show a warning about a primary unit not found in a library.

        Guess whether the error is produced because of missing builtins.
        """
        LOGGER.warning(
            "%s: failed to find a primary design unit '%s' in library '%s'",
            source_file_name,
            primary_design_unit,
            library_name,
        )
        # From there on, we try to guess whether the error is produced because of missing builtins.
        if library_name != "vunit_lib":
            # If the library is not VUnit's, we assume it's unrelated.
            return

        # We get the main script (the one executed by the user), and we read all the content.
        import __main__  # pylint: disable=import-outside-toplevel

        rscript = Path(__main__.__file__)
        with rscript.open("r", encoding="utf-8") as fptr:
            content = list(fptr)

        for line in content:
            if "add_vhdl_builtins" in line:
                # If the user is already aware of the feature, but it is commented/hidden, we assume it's known.
                return

        # Find the line where 'from_args' or 'from_argv' are used.
        for num, line in enumerate(content, 1):
            if ".from_arg" in line:
                # Print a block message telling the user which file and line to modify.
                solution = f"""
Solution - Add a call to 'add_vhdl_builtins()' after the following location:

  File: {rscript!s}
  Line: {num}

As shown below:

{num - 1}|  {content[num - 2].rstrip()}
{num}|  {line.rstrip()}
{num + 1}|+ {line.split('=')[0].rstrip()}.add_vhdl_builtins()  # Add this line!
{num + 2}|  {content[num].rstrip()}
{num + 3}|  {content[num + 1].rstrip()}
"""
                hline = "=" * 75
                print(hline)
                LOGGER.critical(
                    """As of VUnit v5, HDL builtins are not compiled by default.
To preserve the functionality, the run script is now required to explicitly use
methods 'add_vhdl_builtins()' or 'add_verilog_builtins()'.
%s
See https://github.com/VUnit/vunit/issues/777 and http://vunit.github.io/hdl_libraries.html.""",
                    solution,
                )
                print(hline)
                break

    def _find_primary_secondary_design_unit_dependencies(self, source_file):
        """
        Iterate over dependencies between the primary design units of the source_file
        and their secondary design units
        """
        library = source_file.library

        for unit in source_file.design_units:
            if unit.is_primary:
                continue

            try:
                primary_unit = library.primary_design_units[unit.primary_design_unit]
            except KeyError:
                self._failed_to_find_primary_design_unit_in_library(
                    source_file.name,
                    unit.primary_design_unit,
                    library.name,
                )
            else:
                yield primary_unit.source_file

    def _find_vhdl_library_reference(self, library_name):
        """
        Find a VHDL library reference that is case insensitive or raise KeyError
        """
        real_library_name = self._lower_library_names_dict[library_name.lower()]
        return self._libraries[real_library_name]

    @staticmethod
    def _handle_ambiguous_architecture(source_file, ref, primary_unit):
        """
        Pretty print architecture ambiguity
        """
        LOGGER.error(
            "Ambiguous direct entity instantiation of %s.%s in %s.\n  "
            "Remove all but one architecture or specify one of:\n  %s",
            ref.library,
            ref.design_unit,
            source_file.name,
            "\n  ".join(
                f"{idx}. {name} ({location})"
                for idx, (name, location) in enumerate(primary_unit.architecture_names.items(), 1)
            ),
        )

    def _find_other_vhdl_design_unit_dependencies(  # pylint: disable=too-many-branches
        self, source_file, depend_on_package_body, implementation_dependencies
    ):
        """
        Iterate over the dependencies on other design unit of the source_file
        """
        for ref in source_file.dependencies:
            try:
                library = self._find_vhdl_library_reference(ref.library)
            except KeyError:
                if ref.library not in self._builtin_libraries:
                    LOGGER.warning("%s: failed to find library '%s'", source_file.name, ref.library)
                continue

            if ref.is_entity_reference() and ref.design_unit in library.modules:
                # Is a verilog module instantiation
                yield library.modules[ref.design_unit].source_file
                continue

            try:
                primary_unit = library.primary_design_units[ref.design_unit]
            except KeyError:
                if not library.is_external:
                    self._failed_to_find_primary_design_unit_in_library(
                        source_file.name,
                        ref.design_unit,
                        library.name,
                    )
                continue
            else:
                yield primary_unit.source_file

            if ref.is_entity_reference():
                if ref.reference_all_names_within():
                    # Reference all architectures,
                    # We make configuration declarations implicitly reference all architectures
                    names = primary_unit.architecture_names.keys()
                elif ref.name_within is None and implementation_dependencies:
                    # For implementation dependencies we add a dependency to all architectures
                    names = primary_unit.architecture_names.keys()
                else:
                    names = [ref.name_within]

                for name in names:
                    if name is None:
                        # Was not a reference to a specific architecture
                        if len(primary_unit.architecture_names) > 1:
                            self._handle_ambiguous_architecture(source_file, ref, primary_unit)
                            raise RuntimeError(f"Ambiguous use of {ref.library}.{ref.design_unit}")
                        continue

                    if name in primary_unit.architecture_names:
                        file_name = primary_unit.architecture_names[name]
                        yield library.get_source_file(file_name)
                    else:
                        LOGGER.warning(
                            "%s: failed to find architecture '%s' of entity '%s.%s'",
                            source_file.name,
                            name,
                            library.name,
                            primary_unit.name,
                        )

            elif ref.is_package_reference() and depend_on_package_body:
                try:
                    yield library.get_package_body(primary_unit.name).source_file
                except KeyError:
                    # There was no package body, which is legal in VHDL
                    pass

    def _find_verilog_package_dependencies(self, source_file):
        """
        Find dependencies from import of verilog packages
        """
        for package_name in source_file.package_dependencies:
            for library in self._libraries.values():
                try:
                    design_unit = library.verilog_packages[package_name]
                    yield design_unit.source_file
                except KeyError:
                    pass

    def _find_verilog_module_dependencies(self, source_file):
        """
        Find dependencies from instantiation of verilog modules
        """
        for module_name in source_file.module_dependencies:
            if module_name in source_file.library.modules:
                design_unit = source_file.library.modules[module_name]
                yield design_unit.source_file
            else:
                for library in self._libraries.values():
                    try:
                        design_unit = library.modules[module_name]
                        yield design_unit.source_file
                    except KeyError:
                        pass

    @staticmethod
    def _find_component_design_unit_dependencies(source_file):
        """
        Iterate over the dependencies on other design units of the source_file
        that are the result of component instantiations
        """
        for unit_name in source_file.depending_components:
            found_component_match = False

            try:
                primary_unit = source_file.library.primary_design_units[unit_name]
                yield primary_unit.source_file

                for file_name in primary_unit.architecture_names.values():
                    yield source_file.library.get_source_file(file_name)
            except KeyError:
                pass
            else:
                found_component_match = True

            try:
                module = source_file.library.modules[unit_name]
            except KeyError:
                pass
            else:
                found_component_match = True
                yield module.source_file

            if not found_component_match:
                LOGGER.debug(
                    "failed to find a matching entity/module for component '%s' ",
                    unit_name,
                )

    def create_dependency_graph(self, implementation_dependencies=False):
        """
        Create a DependencyGraph object of the HDL code project
        """

        def add_dependency(start, end):
            """
            Utility to add dependency
            """
            if start.name == end.name:
                return

            is_new = dependency_graph.add_dependency(start, end)

            if is_new:
                LOGGER.debug("Adding dependency: %s depends on %s", end.name, start.name)

        def add_dependencies(dependency_function, files):
            """
            Utility to add all dependencies returned by a dependency_function
            returning an iterator of dependencies
            """
            for source_file in files:
                for dependency in dependency_function(source_file):
                    add_dependency(dependency, source_file)

        dependency_graph = DependencyGraph()
        for source_file in self._source_files_in_order:
            dependency_graph.add_node(source_file)

        vhdl_files = [source_file for source_file in self._source_files_in_order if source_file.file_type == "vhdl"]

        depend_on_package_bodies = self._depend_on_package_body or implementation_dependencies
        add_dependencies(
            lambda source_file: self._find_other_vhdl_design_unit_dependencies(
                source_file, depend_on_package_bodies, implementation_dependencies
            ),
            vhdl_files,
        )
        add_dependencies(self._find_primary_secondary_design_unit_dependencies, vhdl_files)

        verilog_files = [
            source_file for source_file in self._source_files_in_order if source_file.file_type in VERILOG_FILE_TYPES
        ]

        add_dependencies(self._find_verilog_package_dependencies, verilog_files)
        add_dependencies(self._find_verilog_module_dependencies, verilog_files)

        if implementation_dependencies:
            add_dependencies(self._find_component_design_unit_dependencies, vhdl_files)

        for source_file, depends_on in self._manual_dependencies:
            add_dependency(depends_on, source_file)

        return dependency_graph

    @staticmethod
    def _handle_circular_dependency(exception):
        """
        Pretty print circular dependency to error log
        """
        LOGGER.error(
            "Found circular dependency:\n%s",
            " ->\n".join(source_file.name for source_file in exception.path),
        )

    def _get_compile_timestamps(self, files):
        """
        Return a dictionary of mapping file to the timestamp when it
        was compiled or None if it was not compiled
        """
        # Cache timestamps to avoid duplicate file operations
        timestamps = {}
        for source_file in files:
            hash_file_name = self._hash_file_name_of(source_file)
            if not ostools.file_exists(hash_file_name):
                timestamps[source_file] = None
            else:
                timestamps[source_file] = ostools.get_modification_time(hash_file_name)
        return timestamps

    def get_files_in_compile_order(self, incremental=True, dependency_graph=None, files=None):
        """
        Get a list of all files in compile order
        param: incremental: Only return files that need recompile if True
        param: files: provide a list of files that shall be sorted, if None all files are used
        """
        if dependency_graph is None:
            dependency_graph = self.create_dependency_graph()

        files_to_recompile = self._get_files_to_recompile(
            files or self.get_source_files_in_order(), dependency_graph, incremental
        )
        return self.get_affected_files_in_compile_order(files_to_recompile, dependency_graph.get_dependent)

    def _get_files_to_recompile(self, files, dependency_graph, incremental):
        """
        Analyse a given set of SourceFile according to the compile timestamps
        and return the set that has to be recompiled.
        param: files: a list of type SourceFile
        param: dependency_graph: The DependencyGraph object to be used
        """
        timestamps = self._get_compile_timestamps(files)
        result_list = []
        for source_file in files:
            if (not incremental) or self._needs_recompile(dependency_graph, source_file, timestamps):
                result_list.append(source_file)
        return result_list

    def get_dependencies_in_compile_order(self, target_files=None, implementation_dependencies=False):
        """
        Get a list of dependencies of target files including the
        target files.
        :param target_files: A list of SourceFiles
        """

        if target_files is None:
            target_files = self._source_files_in_order

        dependency_graph = self.create_dependency_graph(implementation_dependencies)
        return self.get_affected_files_in_compile_order(set(target_files), dependency_graph.get_dependencies)

    def get_affected_files_in_compile_order(self, target_files, get_depend_func):
        """
        Returns the affected files in compile order given a list of target files and a dependencie function
        :param target_files: The files to compile
        :param get_depend_func: one of DependencyGraph [get_dependencies, get_dependent, get_direct_dependencies]
        """
        affected_files = self.get_affected_files(target_files, get_depend_func)
        return self._get_compile_order(affected_files, get_depend_func.__self__)

    def get_minimal_file_set_in_compile_order(self, target_files=None):
        """
        Get the minimal set of files to be compiled for a list of target files of type SourceFile
        param: target_files: List of type SourceFile, if the paramater is None all files are used
        """
        ###
        # First get all files that are required to fullfill the dependencies for the target files
        dependency_graph = self.create_dependency_graph(True)
        dependency_files = self.get_affected_files(
            target_files or self.get_source_files_in_order(),
            dependency_graph.get_dependencies,
        )

        ###
        # Now the file set is known, but it has to be evaluated which files
        # realy have to be compiled according to their timestamp.
        max_file_set_to_be_compiled = self.get_files_in_compile_order(incremental=True, files=dependency_files)

        # get_files_in_compile_order returns more files than actually are in the
        # list of dependent files. So the list is filtered for only the files
        # that are required
        min_file_set_to_be_compiled = [f for f in max_file_set_to_be_compiled if f in dependency_files]
        return min_file_set_to_be_compiled

    def get_affected_files(self, target_files, get_depend_func):
        """
        Get affected files given a  list of type SourceFile, if the list is None
        all files are taken into account
        :param target_files: An initial list of type SourceFile
        :param get_depend_func: One of either [get_dependent, get_dependencies, get_direct_dependencies]
        of an object dependency_graph of type DependencyGraph
        """
        try:
            return get_depend_func(target_files)
        except CircularDependencyException as exc:
            self._handle_circular_dependency(exc)
            raise CompileError from exc

    def _get_compile_order(self, files, dependency_graph):
        """
        Returns a sorted list of type SourceFile using the given dependency graph
        param: dependency_graph: The DependencyGraph object
        """
        try:
            compile_order = dependency_graph.toposort()
        except CircularDependencyException as exc:
            self._handle_circular_dependency(exc)
            raise CompileError from exc

        def comparison_key(source_file):
            return compile_order.index(source_file)

        return sorted(files, key=comparison_key)

    def get_source_files_in_order(self):
        """
        Get a list of source files in the order they were added to the project
        """
        return list(self._source_files_in_order)

    def get_libraries(self):
        return self._libraries.values()

    def get_library(self, library_name):
        return self._libraries[library_name]

    def has_library(self, library_name):
        return library_name in self._libraries

    def _needs_recompile(self, dependency_graph, source_file, timestamps):
        """
        Returns True if the source_file needs to be recompiled
        given the dependency_graph, the file contents and the last modification time
        """
        timestamp = timestamps[source_file]

        content_hash_file_name = self._hash_file_name_of(source_file)
        if timestamp is None:
            LOGGER.debug(
                "%s has no vunit_hash file at %s and must be recompiled",
                source_file.name,
                content_hash_file_name,
            )
            return True

        old_content_hash = ostools.read_file(content_hash_file_name)
        if old_content_hash != source_file.content_hash:
            LOGGER.debug(
                "%s has different hash than last time and must be recompiled",
                source_file.name,
            )
            return True

        for other_file in dependency_graph.get_direct_dependencies(source_file):
            other_timestamp = timestamps[other_file]

            if other_timestamp is None:
                # Other file has not been compiled and will trigger recompile of this file
                continue

            if other_timestamp > timestamp:
                LOGGER.debug(
                    "%s has dependency compiled earlier and must be recompiled",
                    source_file.name,
                )
                return True

        LOGGER.debug("%s has same hash file and must not be recompiled", source_file.name)

        return False

    def _hash_file_name_of(self, source_file):
        """
        Returns the name of the hash file associated with the source_file
        """
        library = self.get_library(source_file.library.name)
        prefix = hash_string(str(Path(source_file.name).parent))
        return str(Path(library.directory) / prefix / Path(source_file.name).name / ".vunit_hash")

    def update(self, source_file):
        """
        Mark that source_file has been recompiled, triggers a re-write of the hash file
        to update the timestamp
        """
        new_content_hash = source_file.content_hash
        ostools.write_file(self._hash_file_name_of(source_file), new_content_hash)
        LOGGER.debug("Wrote %s content_hash=%s", source_file.name, new_content_hash)
