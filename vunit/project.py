# Classes to model a HDL design hierarchy
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

"""
Functionality to represent and operate on a HDL code project
"""


import logging
LOGGER = logging.getLogger(__name__)

from vunit.hashing import hash_string
from os.path import join, basename, dirname

from vunit.dependency_graph import DependencyGraph
from vunit.vhdl_parser import VHDLParser
import vunit.ostools as ostools
import traceback


class Project(object):
    """
    The representation of a HDL code project.
    Compute lists of source files to recompile based on file contents,
    timestamps and depenencies derived from the design hierarchy.
    """
    def __init__(self, depend_on_components=False, vhdl_parser=VHDLParser()):
        self._vhdl_parser = vhdl_parser
        self._libraries = {}
        self._source_files = {}
        self._source_files_in_order = []
        self._depend_on_components = depend_on_components

    @staticmethod
    def _validate_library_name(library_name):
        """
        Check that the library_name is valid or raise RuntimeError
        """
        if library_name == "work":
            LOGGER.error("Cannot add library named work. work is a reference to the current library. "
                         "http://www.sigasi.com/content/work-not-vhdl-library")
            raise RuntimeError("Illegal library name 'work'")

    def add_library(self, logical_name, directory, allow_replacement=False, is_external=False):
        """
        Add library to project with logical_name located or to be located in directory
        allow_replacement -- Allow replacing an existing library
        is_external -- Library is assumed to a black-box
        """
        self._validate_library_name(logical_name)
        if logical_name not in self._libraries:
            library = Library(logical_name, directory, is_external=is_external)
            self._libraries[logical_name] = library
            LOGGER.info('Adding library %s with path %s', logical_name, directory)
        else:
            assert allow_replacement
            library = Library(logical_name, directory, is_external=is_external)
            self._libraries[logical_name] = library
            LOGGER.info('Replacing library %s with path %s', logical_name, directory)

    def add_source_file(self, file_name, library_name, file_type='vhdl'):
        """
        Add a file_name as a source file in library_name with file_type
        """
        LOGGER.info('Adding source file %s to library %s', file_name, library_name)
        self._validate_library_name(library_name)
        library = self._libraries[library_name]
        source_file = SourceFile(file_name, library, file_type, vhdl_parser=self._vhdl_parser)
        library.add_design_units(source_file.design_units)
        self._source_files[file_name] = source_file
        self._source_files_in_order.append(file_name)

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
                LOGGER.warning("failed to find a primary design unit '%s' in library '%s'",
                               unit.primary_design_unit, library.name)
            else:
                yield primary_unit.source_file

    def _find_other_design_unit_dependencies(self, source_file):
        """
        Iterate over the dependencies on other design unit of the source_file
        """
        for library_name, unit_name in source_file.dependencies:
            try:
                library = self._libraries[library_name]
            except KeyError:
                if library_name not in ("ieee", "std"):
                    LOGGER.warning("failed to find library '%s'", library_name)
                continue

            try:
                primary_unit = library.primary_design_units[unit_name]
            except KeyError:
                if not library.is_external:
                    LOGGER.warning("failed to find a primary design unit '%s' in library '%s'",
                                   unit_name, library.name)
            else:
                yield primary_unit.source_file

    def _find_component_design_unit_dependencies(self, source_file):
        """
        Iterate over the dependencies on other design units of the source_file
        that are the result of component instantiations
        """
        for unit_name in source_file.depending_components:
            found_component_entity = False

            for library in self.get_libraries():
                try:
                    primary_unit = library.primary_design_units[unit_name]
                except KeyError:
                    continue
                else:
                    found_component_entity = True
                    yield primary_unit.source_file

            if not found_component_entity:
                LOGGER.debug("failed to find a matching entity for component '%s' ", unit_name)

    def _create_dependency_graph(self):
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
                LOGGER.info('Adding dependency: %s depends on %s', end.name, start.name)

        def add_dependencies(dependency_function):
            """
            Utility to add all dependencies returned by a dependency_function
            returning an iterator of dependencies
            """
            for source_file in self.get_source_files_in_order():
                for dependency in dependency_function(source_file):
                    add_dependency(dependency, source_file)

        dependency_graph = DependencyGraph()
        for source_file in self.get_source_files_in_order():
            dependency_graph.add_node(source_file)

        add_dependencies(self._find_other_design_unit_dependencies)
        add_dependencies(self._find_primary_secondary_design_unit_dependencies)

        if self._depend_on_components:
            add_dependencies(self._find_component_design_unit_dependencies)

        return dependency_graph

    def get_files_in_compile_order(self, incremental=True):
        """
        Get a list of all files in compile order
        incremental -- Only return files that need recompile if True
        """
        dependency_graph = self._create_dependency_graph()

        files = []
        for source_file in self.get_source_files_in_order():
            if (not incremental) or self._needs_recompile(dependency_graph, source_file):
                files.append(source_file)

        # Get files that are affected by recompiling the modified files
        affected_files = dependency_graph.get_dependent(files)
        compile_order = dependency_graph.toposort()

        def comparison_key(source_file):
            return compile_order.index(source_file)

        return sorted(affected_files, key=comparison_key)

    def get_source_files_in_order(self):
        """
        Get a list of source files in the order they were added to the project
        """
        return [self._source_files[file_name] for file_name in self._source_files_in_order]

    def get_source_file(self, file_name):
        """
        Get source file object by file name
        """
        return self._source_files[file_name]

    def get_libraries(self):
        return self._libraries.values()

    def get_library(self, library_name):
        return self._libraries[library_name]

    def has_library(self, library_name):
        return library_name in self._libraries

    def _needs_recompile(self, dependency_graph, source_file):
        """
        Returns True if the source_file needs to be recompiled
        given the dependency_graph, the file contents and the last modification time
        """
        content_hash = source_file.content_hash
        content_hash_file_name = self._hash_file_name_of(source_file)

        if not ostools.file_exists(content_hash_file_name):
            LOGGER.debug("%s has no vunit_hash file at %s and must be recompiled",
                         source_file.name, content_hash_file_name)
            return True

        old_content_hash = ostools.read_file(content_hash_file_name)
        if old_content_hash != content_hash:
            LOGGER.debug("%s has different hash than last time and must be recompiled",
                         source_file.name)
            return True

        for other_file in dependency_graph.get_dependencies(source_file):
            other_content_hash_file_name = self._hash_file_name_of(other_file)

            if not ostools.file_exists(other_content_hash_file_name):
                continue

            if more_recent(other_content_hash_file_name, content_hash_file_name):
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


class Library(object):
    """
    Represents a VHDL library
    """
    def __init__(self, name, directory, is_external=False):
        self.name = name
        self.directory = directory
        self.primary_design_units = {}

        # Entity objects
        self._entities = {}

        # Entity name to architecture names mapping
        self._architecture_names = {}
        self._is_external = is_external

    @property
    def is_external(self):
        """
        External black box library, typically compiled outside of VUnit
        """
        return self._is_external

    def add_design_units(self, design_units):
        """
        Add a design unit to the library
        """
        for design_unit in design_units:
            if design_unit.is_primary:
                self.primary_design_units[design_unit.name] = design_unit

            if design_unit.unit_type == 'entity':
                if design_unit.name not in self._architecture_names:
                    self._architecture_names[design_unit.name] = {}
                self._entities[design_unit.name] = design_unit

            if design_unit.unit_type == 'architecture':
                if design_unit.primary_design_unit not in self._architecture_names:
                    self._architecture_names[design_unit.primary_design_unit] = {}

                file_name = design_unit.source_file.name
                self._architecture_names[design_unit.primary_design_unit][design_unit.name] = file_name

    def get_entities(self):
        """
        Return a list of all entites in the design with their generic names and architecture names
        """
        entities = []
        for entity in self._entities.values():
            entity.architecture_names = self._architecture_names[entity.name]
            entities.append(entity)
        return entities

    def has_entity(self, name):
        """
        Return true if entity with 'name' is in library
        """
        return name in self._entities

    def __eq__(self, other):
        if isinstance(other, type(self)):
            return self.name == other.name
        else:
            return False

    def __hash__(self):
        return hash(self.name)


class SourceFile(object):
    """
    Represents a HDL source file
    """
    def __init__(self, name, library, file_type, vhdl_parser):
        self.name = name
        self.library = library
        self.file_type = file_type
        code = ostools.read_file(self.name)
        self._content_hash = hash_string(code)

        self.design_units = []
        self.dependencies = []
        self.depending_components = []

        if self.file_type == 'vhdl':
            try:
                design_file = vhdl_parser.parse(code, name)
                self.design_units = self._find_design_units(design_file)
                self.dependencies = self._find_dependencies(design_file)
                self.depending_components = design_file.component_instantiations
            except KeyboardInterrupt:
                raise
            except:  # pylint: disable=bare-except
                traceback.print_exc()
                LOGGER.error("Failed to parse %s", name)

        for design_unit in self.design_units:
            if design_unit.is_primary:
                LOGGER.debug('Adding primary design unit (%s) %s', design_unit.unit_type, design_unit.name)
            elif design_unit.unit_type == 'package body':
                LOGGER.debug('Adding secondary design unit (package body) for package %s',
                             design_unit.primary_design_unit)
            else:
                LOGGER.debug('Adding secondary design unit (%s) %s', design_unit.unit_type, design_unit.name)

        if len(self.depending_components) != 0:
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
        for library_name, uses in design_file.libraries.items():
            if library_name == "work":
                # Work means same library as current file
                library_name = self.library.name
            for use in uses:
                result.append((library_name, use[0]))

        for library_name, entity in design_file.instantiations:
            if library_name == "work":
                # Work means same library as current file
                library_name = self.library.name
            result.append((library_name, entity))

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
            result.append(DesignUnit(context.identifier, self, 'context'))

        for package in design_file.packages:
            result.append(DesignUnit(package.identifier, self, 'package'))

        for architecture in design_file.architectures:
            result.append(DesignUnit(architecture.identifier, self, 'architecture', False, architecture.entity))

        for body in design_file.package_bodies:
            result.append(DesignUnit('package body for ' + body.identifier,
                                     self, 'package body', False, body.identifier))

        return result

    def __eq__(self, other):
        if isinstance(other, type(self)):
            return self.name == other.name
        else:
            return False

    def __hash__(self):
        return hash(self.name)

    @property
    def content_hash(self):
        return self._content_hash


class Entity(object):
    """
    Represents a VHDL Entity
    """
    def __init__(self, name, source_file, generic_names=None):
        self.name = name
        self.source_file = source_file
        self.generic_names = [] if generic_names is None else generic_names
        self.architecture_names = {}

        self.unit_type = 'entity'
        self.is_primary = True

    @property
    def file_name(self):
        return self.source_file.name

    @property
    def library_name(self):
        return self.source_file.library.name


class DesignUnit(object):
    """
    Represents a VHDL design unit
    """
    def __init__(self,  # pylint: disable=too-many-arguments
                 name, source_file, unit_type, is_primary=True, primary_design_unit=None):
        self.source_file = source_file
        self.name = name.lower()
        self.unit_type = unit_type
        self.is_primary = is_primary

        # Related primary design unit if this is a secondary design unit.
        self.primary_design_unit = None if is_primary else primary_design_unit.lower()


def more_recent(file_name, than_file_name):
    """
    Returns True if the modification time of file_name is more recent
    than_file_name
    """
    mtime = ostools.get_modification_time(file_name)
    than_mtime = ostools.get_modification_time(than_file_name)
    return mtime > than_mtime
