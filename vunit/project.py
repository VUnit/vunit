# Classes to model a HDL design hierarchy
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

"""
Functionality to represent and operate on a HDL code project
"""


from os.path import join, basename, dirname, splitext, isdir, exists
from copy import copy
import traceback
import logging
from collections import OrderedDict
from vunit.hashing import hash_string
from vunit.dependency_graph import (DependencyGraph,
                                    CircularDependencyException)
from vunit.vhdl_parser import VHDLParser, VHDLReference
from vunit.cached import file_content_hash
from vunit.parsing.verilog.parser import VerilogParser
from vunit.parsing.encodings import HDL_FILE_ENCODING
from vunit.exceptions import CompileError
from vunit.simulator_factory import SIMULATOR_FACTORY
from vunit.design_unit import DesignUnit, VHDLDesignUnit, Entity, Module
from vunit import ostools
LOGGER = logging.getLogger(__name__)


class Project(object):  # pylint: disable=too-many-instance-attributes
    """
    The representation of a HDL code project.
    Compute lists of source files to recompile based on file contents,
    timestamps and depenencies derived from the design hierarchy.
    """
    def __init__(self,
                 depend_on_package_body=False,
                 database=None):
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
            LOGGER.error("Cannot add library named work. work is a reference to the current library. "
                         "http://www.sigasi.com/content/work-not-vhdl-library")
            raise RuntimeError("Illegal library name 'work'")

        if library_name in self._libraries:
            raise ValueError("Library %s already exists" % library_name)

        lower_name = library_name.lower()
        if lower_name in self._lower_library_names_dict:
            raise RuntimeError(
                "Library name %r not case-insensitive unique. Library name %r previously defined"
                % (library_name, self._lower_library_names_dict[lower_name]))

    def add_builtin_library(self, logical_name):
        """
        Add a builtin library name that does not give missing dependency warnings
        """
        self._builtin_libraries.add(logical_name)

    def add_library(self, logical_name, directory, vhdl_standard='2008', is_external=False):
        """
        Add library to project with logical_name located or to be located in directory
        is_external -- Library is assumed to a black-box
        """
        self._validate_new_library_name(logical_name)

        if is_external:
            if not exists(directory):
                raise ValueError("External library %r does not exist" % directory)

            if not isdir(directory):
                raise ValueError("External library must be a directory. Got %r" % directory)

        library = Library(logical_name, directory, vhdl_standard, is_external=is_external)
        LOGGER.debug('Adding library %s with path %s', logical_name, directory)

        self._libraries[logical_name] = library
        self._lower_library_names_dict[logical_name.lower()] = library.name

    def add_source_file(self,    # pylint: disable=too-many-arguments
                        file_name, library_name, file_type='vhdl', include_dirs=None, defines=None,
                        vhdl_standard=None,
                        no_parse=False):
        """
        Add a file_name as a source file in library_name with file_type

        :param no_parse: Do not parse file contents
        """
        if not ostools.file_exists(file_name):
            raise ValueError("File %r does not exist" % file_name)

        LOGGER.debug('Adding source file %s to library %s', file_name, library_name)
        library = self._libraries[library_name]

        if file_type == "vhdl":
            assert include_dirs is None
            source_file = VHDLSourceFile(
                file_name,
                library,
                vhdl_parser=self._vhdl_parser,
                database=self._database,
                vhdl_standard=library.vhdl_standard if vhdl_standard is None else vhdl_standard,
                no_parse=no_parse)
        elif file_type in VERILOG_FILE_TYPES:
            source_file = VerilogSourceFile(file_type,
                                            file_name,
                                            library,
                                            verilog_parser=self._verilog_parser,
                                            database=self._database,
                                            include_dirs=include_dirs,
                                            defines=defines,
                                            no_parse=no_parse)
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
    def _find_primary_secondary_design_unit_dependencies(source_file):
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
                LOGGER.warning("%s: failed to find a primary design unit '%s' in library '%s'",
                               source_file.name, unit.primary_design_unit, library.name)
            else:
                yield primary_unit.source_file

    def _find_vhdl_library_reference(self, library_name):
        """
        Find a VHDL library reference that is case insensitive or raise KeyError
        """
        real_library_name = self._lower_library_names_dict[library_name]
        return self._libraries[real_library_name]

    def _find_other_vhdl_design_unit_dependencies(self,  # pylint: disable=too-many-branches
                                                  source_file,
                                                  depend_on_package_body,
                                                  implementation_dependencies):
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
                    LOGGER.warning("%s: failed to find a primary design unit '%s' in library '%s'",
                                   source_file.name, ref.design_unit, library.name)
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
                        continue

                    if name in primary_unit.architecture_names:
                        file_name = primary_unit.architecture_names[name]
                        yield library.get_source_file(file_name)
                    else:
                        LOGGER.warning("%s: failed to find architecture '%s' of entity '%s.%s'",
                                       source_file.name, name, library.name, primary_unit.name)

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
                LOGGER.debug("failed to find a matching entity/module for component '%s' ", unit_name)

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
                LOGGER.debug('Adding dependency: %s depends on %s', end.name, start.name)

        def add_dependencies(dependency_function, files):
            """
            Utility to add all dependencies returned by a dependency_function
            returning an iterator of dependencies
            """
            for source_file in files:
                for dependency in dependency_function(source_file):
                    add_dependency(dependency, source_file)

        dependency_graph = DependencyGraph()
        for source_file in self.get_source_files_in_order():
            dependency_graph.add_node(source_file)

        vhdl_files = [source_file
                      for source_file in self.get_source_files_in_order()
                      if source_file.file_type == 'vhdl']

        depend_on_package_bodies = self._depend_on_package_body or implementation_dependencies
        add_dependencies(
            lambda source_file: self._find_other_vhdl_design_unit_dependencies(source_file,
                                                                               depend_on_package_bodies,
                                                                               implementation_dependencies),
            vhdl_files)
        add_dependencies(self._find_primary_secondary_design_unit_dependencies, vhdl_files)

        verilog_files = [source_file
                         for source_file in self.get_source_files_in_order()
                         if source_file.file_type in VERILOG_FILE_TYPES]

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
        LOGGER.error("Found circular dependency:\n%s",
                     " ->\n".join(source_file.name for source_file in exception.path))

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

    def get_files_in_compile_order(self, incremental=True, dependency_graph=None):
        """
        Get a list of all files in compile order
        incremental -- Only return files that need recompile if True
        """
        if dependency_graph is None:
            dependency_graph = self.create_dependency_graph()

        all_files = self.get_source_files_in_order()
        timestamps = self._get_compile_timestamps(all_files)
        files = []
        for source_file in all_files:
            if (not incremental) or self._needs_recompile(dependency_graph, source_file, timestamps):
                files.append(source_file)

        # Get files that are affected by recompiling the modified files
        try:
            affected_files = dependency_graph.get_dependent(files)
            compile_order = dependency_graph.toposort()
        except CircularDependencyException as exc:
            self._handle_circular_dependency(exc)
            raise CompileError

        def comparison_key(source_file):
            return compile_order.index(source_file)

        retval = sorted(affected_files, key=comparison_key)
        return retval

    def get_dependencies_in_compile_order(self, target_files=None, implementation_dependencies=False):
        """
        Get a list of dependencies of target files including the
        target files.
        :param target_files: A list of SourceFiles
        """

        if target_files is None:
            target_files = self.get_source_files_in_order()

        dependency_graph = self.create_dependency_graph(implementation_dependencies)

        try:
            affected_files = dependency_graph.get_dependencies(set(target_files))
            compile_order = dependency_graph.toposort()
        except CircularDependencyException as exc:
            self._handle_circular_dependency(exc)
            raise CompileError

        def comparison_key(source_file):
            return compile_order.index(source_file)

        sorted_files = sorted(affected_files, key=comparison_key)
        return sorted_files

    def get_source_files_in_order(self):
        """
        Get a list of source files in the order they were added to the project
        """
        return [source_file for source_file in self._source_files_in_order]

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
            LOGGER.debug("%s has no vunit_hash file at %s and must be recompiled",
                         source_file.name, content_hash_file_name)
            return True

        old_content_hash = ostools.read_file(content_hash_file_name)
        if old_content_hash != source_file.content_hash:
            LOGGER.debug("%s has different hash than last time and must be recompiled",
                         source_file.name)
            return True

        for other_file in dependency_graph.get_direct_dependencies(source_file):
            other_timestamp = timestamps[other_file]

            if other_timestamp is None:
                # Other file has not been compiled and will trigger recompile of this file
                continue

            if other_timestamp > timestamp:
                LOGGER.debug("%s has dependency compiled earlier and must be recompiled",
                             source_file.name)
                return True

        LOGGER.debug("%s has same hash file and must not be recompiled",
                     source_file.name)

        return False

    def _hash_file_name_of(self, source_file):
        """
        Returns the name of the hash file associated with the source_file
        """
        library = self.get_library(source_file.library.name)
        prefix = hash_string(dirname(source_file.name))
        return join(library.directory, prefix, basename(source_file.name) + ".vunit_hash")

    def update(self, source_file):
        """
        Mark that source_file has been recompiled, triggers a re-write of the hash file
        to update the timestamp
        """
        new_content_hash = source_file.content_hash
        ostools.write_file(self._hash_file_name_of(source_file), new_content_hash)
        LOGGER.debug('Wrote %s content_hash=%s', source_file.name, new_content_hash)


class Library(object):  # pylint: disable=too-many-instance-attributes
    """
    Represents a VHDL library
    """
    def __init__(self, name, directory, vhdl_standard, is_external=False):
        self.name = name
        self.directory = directory

        # Default VHDL standard for files added unless explicitly set per file
        self.vhdl_standard = vhdl_standard

        self._source_files = {}

        # Entity objects
        self._entities = {}
        self._package_bodies = {}

        self.primary_design_units = {}

        # Entity name to architecture design unit mapping
        self._architectures = {}

        # Verilog specific
        # Module objects
        self.modules = {}
        self.verilog_packages = {}

        self._is_external = is_external

    def add_source_file(self, source_file):
        """
        Add source file to library unless it exists

        returns The source file that has added or the old source file
        """
        if source_file.name in self._source_files:
            old_source_file = self._source_files[source_file.name]
            if old_source_file.content_hash != source_file.content_hash:
                raise RuntimeError("%s already added to library %s" % (
                    source_file.name, self.name))
            else:
                LOGGER.info("Ignoring duplicate file %s added to library %s due to identical contents",
                            source_file.name, self.name)

            return old_source_file
            # Ignore source files already added with identical content hash
        else:
            self._source_files[source_file.name] = source_file
            source_file.add_to_library(self)

            return source_file

    def get_source_file(self, file_name):
        """
        Get source file with file name or raise KeyError
        """
        return self._source_files[file_name]

    @property
    def is_external(self):
        """
        External black box library, typically compiled outside of VUnit
        """
        return self._is_external

    @staticmethod
    def _warning_on_duplication(design_unit, old_file_name):
        """
        Utility function to give warning for design unit duplication
        """
        LOGGER.warning("%s: %s '%s' previously defined in %s",
                       design_unit.source_file.name,
                       design_unit.unit_type,
                       design_unit.name,
                       old_file_name)

    def _check_duplication(self, dictionary, design_unit):
        """
        Utility function to check if design_unit already in dictionary
        and give warning
        """
        if design_unit.name in dictionary:
            self._warning_on_duplication(design_unit, dictionary[design_unit.name].source_file.name)

    def add_vhdl_design_units(self, design_units):
        """
        Add VHDL design units to the library
        """
        for design_unit in design_units:
            if design_unit.is_primary:
                self._check_duplication(self.primary_design_units,
                                        design_unit)
                self.primary_design_units[design_unit.name] = design_unit

                if design_unit.unit_type == 'entity':
                    if design_unit.name not in self._architectures:
                        self._architectures[design_unit.name] = {}
                    self._entities[design_unit.name] = design_unit

                    for architecture in self._architectures[design_unit.name].values():
                        design_unit.add_architecture(architecture)

            else:
                if design_unit.unit_type == 'architecture':
                    if design_unit.primary_design_unit not in self._architectures:
                        self._architectures[design_unit.primary_design_unit] = {}

                    if design_unit.name in self._architectures[design_unit.primary_design_unit]:
                        self._warning_on_duplication(
                            design_unit,
                            self._architectures[design_unit.primary_design_unit][design_unit.name].source_file.name)

                    self._architectures[design_unit.primary_design_unit][design_unit.name] = design_unit

                    if design_unit.primary_design_unit in self._entities:
                        self._entities[design_unit.primary_design_unit].add_architecture(design_unit)

                if design_unit.unit_type == 'package body':
                    if design_unit.primary_design_unit in self._package_bodies:
                        self._warning_on_duplication(
                            design_unit,
                            self._package_bodies[design_unit.primary_design_unit].source_file.name)
                    self._package_bodies[design_unit.primary_design_unit] = design_unit

    def add_verilog_design_units(self, design_units):
        """
        Add Verilog design units to the library
        """
        for design_unit in design_units:
            if design_unit.unit_type == 'module':
                if design_unit.name in self.modules:
                    self._warning_on_duplication(design_unit, self.modules[design_unit.name].source_file.name)
                self.modules[design_unit.name] = design_unit
            elif design_unit.unit_type == 'package':
                if design_unit.name in self.verilog_packages:
                    self._warning_on_duplication(design_unit, self.verilog_packages[design_unit.name].source_file.name)
                self.verilog_packages[design_unit.name] = design_unit

    def get_entities(self):
        """
        Return a list of all entites in the design with their generic names and architecture names
        """
        entities = []
        for entity in self._entities.values():
            entities.append(entity)
        return entities

    def get_modules(self):
        """
        Return a list of all modules in the design
        """
        return list(self.modules.values())

    def get_package_body(self, name):
        return self._package_bodies[name]

    def has_entity(self, name):
        """
        Return true if entity with 'name' is in library
        """
        return name in self._entities

    def __eq__(self, other):
        if isinstance(other, type(self)):
            return self.name == other.name

        return False

    def __lt__(self, other):
        return self.name < other.name

    def __hash__(self):
        return hash(self.name)


class SourceFile(object):
    """
    Represents a generic source file
    """

    def __init__(self, name, library, file_type):
        self.name = name
        self.library = library
        self.file_type = file_type
        self.design_units = []
        self._content_hash = None
        self._compile_options = {}

        # The file name before preprocessing
        self.original_name = name

    @property
    def is_vhdl(self):
        return self.file_type == "vhdl"

    @property
    def is_system_verilog(self):
        return self.file_type == "systemverilog"

    @property
    def is_any_verilog(self):
        return self.file_type in VERILOG_FILE_TYPES

    def __eq__(self, other):
        if isinstance(other, type(self)):
            return self.to_tuple() == other.to_tuple()

        return False

    def to_tuple(self):
        return (self.name, self.library, self.file_type)

    def __lt__(self, other):
        return self.to_tuple() < other.to_tuple()

    def __hash__(self):
        return hash(self.to_tuple())

    def __repr__(self):
        return "SourceFile(%s, %s)" % (self.name, self.library.name)

    def set_compile_option(self, name, value):
        """
        Set compile option
        """
        SIMULATOR_FACTORY.check_compile_option(name, value)
        self._compile_options[name] = copy(value)

    def add_compile_option(self, name, value):
        """
        Add compile option
        """
        SIMULATOR_FACTORY.check_compile_option(name, value)

        if name not in self._compile_options:
            self._compile_options[name] = copy(value)
        else:
            self._compile_options[name] += value

    @property
    def compile_options(self):
        return self._compile_options

    def get_compile_option(self, name):
        """
        Return a copy of the compile option list
        """
        SIMULATOR_FACTORY.check_compile_option_name(name)

        if name not in self._compile_options:
            self._compile_options[name] = []

        return copy(self._compile_options[name])

    def _compile_options_hash(self):
        """
        Compute hash of compile options

        Needs to be updated if there are nested dictionaries
        """
        return hash_string(repr(sorted(self._compile_options.items())))

    @property
    def content_hash(self):
        """
        Compute hash of contents and compile options
        """
        return hash_string(self._content_hash + self._compile_options_hash())


class VerilogSourceFile(SourceFile):
    """
    Represents a Verilog source file
    """
    def __init__(self,  # pylint: disable=too-many-arguments
                 file_type, name, library, verilog_parser, database, include_dirs=None, defines=None, no_parse=False):
        SourceFile.__init__(self, name, library, file_type)
        self.package_dependencies = []
        self.module_dependencies = []
        self.include_dirs = include_dirs if include_dirs is not None else []
        self.defines = defines.copy() if defines is not None else {}
        self._content_hash = file_content_hash(self.name, encoding=HDL_FILE_ENCODING,
                                               database=database)

        for path in self.include_dirs:
            self._content_hash = hash_string(self._content_hash + hash_string(path))

        for key, value in sorted(self.defines.items()):
            self._content_hash = hash_string(self._content_hash + hash_string(key))
            self._content_hash = hash_string(self._content_hash + hash_string(value))

        if not no_parse:
            self.parse(verilog_parser, database, include_dirs)

    def parse(self, parser, database, include_dirs):
        """
        Parse Verilog code and adding dependencies and design units
        """
        try:
            design_file = parser.parse(self.name, include_dirs, self.defines)
            for included_file_name in design_file.included_files:
                self._content_hash = hash_string(self._content_hash
                                                 + file_content_hash(included_file_name,
                                                                     encoding=HDL_FILE_ENCODING,
                                                                     database=database))

            for module in design_file.modules:
                self.design_units.append(Module(module.name, self, module.parameters))

            for package in design_file.packages:
                self.design_units.append(DesignUnit(package.name, self, "package"))

            for package_name in design_file.imports:
                self.package_dependencies.append(package_name)

            for package_name in design_file.package_references:
                self.package_dependencies.append(package_name)

            for instance_name in design_file.instances:
                self.module_dependencies.append(instance_name)

        except KeyboardInterrupt:
            raise KeyboardInterrupt
        except:  # pylint: disable=bare-except
            traceback.print_exc()
            LOGGER.error("Failed to parse %s", self.name)

    def add_to_library(self, library):
        """
        Add design units to the library
        """
        assert self.library == library
        library.add_verilog_design_units(self.design_units)


class VHDLSourceFile(SourceFile):
    """
    Represents a VHDL source file
    """
    def __init__(self,  # pylint: disable=too-many-arguments
                 name, library, vhdl_parser, database, vhdl_standard, no_parse=False):
        SourceFile.__init__(self, name, library, 'vhdl')
        self.dependencies = []
        self.depending_components = []
        self._vhdl_standard = vhdl_standard
        check_vhdl_standard(vhdl_standard)

        if not no_parse:

            try:
                design_file = vhdl_parser.parse(self.name)
            except KeyboardInterrupt:
                raise KeyboardInterrupt
            except:  # pylint: disable=bare-except
                traceback.print_exc()
                LOGGER.error("Failed to parse %s", self.name)
            else:
                self._add_design_file(design_file)

        self._content_hash = file_content_hash(self.name,
                                               encoding=HDL_FILE_ENCODING,
                                               database=database)

    def get_vhdl_standard(self):
        """
        Return the VHDL standard used to create this file
        """
        return self._vhdl_standard

    def _add_design_file(self, design_file):
        """
        Parse VHDL code and adding dependencies and design units
        """
        self.design_units = self._find_design_units(design_file)
        self.dependencies = self._find_dependencies(design_file)
        self.depending_components = design_file.component_instantiations

        for design_unit in self.design_units:
            if design_unit.is_primary:
                LOGGER.debug('Adding primary design unit (%s) %s', design_unit.unit_type, design_unit.name)
            elif design_unit.unit_type == 'package body':
                LOGGER.debug('Adding secondary design unit (package body) for package %s',
                             design_unit.primary_design_unit)
            else:
                LOGGER.debug('Adding secondary design unit (%s) %s', design_unit.unit_type, design_unit.name)

        if self.depending_components:
            LOGGER.debug("The file '%s' has the following components:", self.name)
            for component in self.depending_components:
                LOGGER.debug(component)
        else:
            LOGGER.debug("The file '%s' has no components", self.name)

    def _find_dependencies(self, design_file):
        """
        Return a list of dependencies of this source_file based on the
        use clause and entity instantiations
        """
        # Find dependencies introduced by the use clause
        result = []
        for ref in design_file.references:
            ref = ref.copy()

            if ref.library == "work":
                # Work means same library as current file
                ref.library = self.library.name

            result.append(ref)

        for configuration in design_file.configurations:
            result.append(VHDLReference('entity', self.library.name, configuration.entity, 'all'))

        return result

    def _find_design_units(self, design_file):
        """
        Return all design units found in the design_file
        """
        result = []
        for entity in design_file.entities:
            generic_names = [generic.identifier for generic in entity.generics]
            result.append(Entity(entity.identifier, self, generic_names))

        for context in design_file.contexts:
            result.append(VHDLDesignUnit(context.identifier, self, 'context'))

        for package in design_file.packages:
            result.append(VHDLDesignUnit(package.identifier, self, 'package'))

        for architecture in design_file.architectures:
            result.append(VHDLDesignUnit(architecture.identifier, self, 'architecture', False, architecture.entity))

        for configuration in design_file.configurations:
            result.append(VHDLDesignUnit(configuration.identifier, self, 'configuration'))

        for body in design_file.package_bodies:
            result.append(VHDLDesignUnit(body.identifier,
                                         self, 'package body', False, body.identifier))

        return result

    @property
    def content_hash(self):
        """
        Compute hash of contents and compile options
        """
        return hash_string(self._content_hash + self._compile_options_hash() + hash_string(self._vhdl_standard))

    def add_to_library(self, library):
        """
        Add design units to the library
        """
        assert self.library == library
        library.add_vhdl_design_units(self.design_units)


# lower case representation of supported extensions
VHDL_EXTENSIONS = (".vhd", ".vhdl", ".vho")
VERILOG_EXTENSIONS = (".v", ".vp", ".vams", ".vo")
SYSTEM_VERILOG_EXTENSIONS = (".sv",)
VERILOG_FILE_TYPES = ("verilog", "systemverilog")
FILE_TYPES = ("vhdl", ) + VERILOG_FILE_TYPES


def file_type_of(file_name):
    """
    Return the file type of file_name based on the file ending
    """
    _, ext = splitext(file_name)
    if ext.lower() in VHDL_EXTENSIONS:
        return "vhdl"

    if ext.lower() in VERILOG_EXTENSIONS:
        return "verilog"

    if ext.lower() in SYSTEM_VERILOG_EXTENSIONS:
        return "systemverilog"

    raise RuntimeError("Unknown file ending '%s' of %s" % (ext, file_name))


def check_vhdl_standard(vhdl_standard, from_str=None):
    """
    Check the VHDL standard selected is recognized
    """
    if from_str is None:
        from_str = ""
    else:
        from_str += " "

    valid_standards = ('93', '2002', '2008')
    if vhdl_standard not in valid_standards:
        raise ValueError("Unknown VHDL standard '%s' %snot one of %r" % (vhdl_standard, from_str, valid_standards))
