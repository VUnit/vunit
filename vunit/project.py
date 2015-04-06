# Classes to model a HDL design hierarchy
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

import logging
logger = logging.getLogger(__name__)

import hashlib
from os.path import join, basename, dirname

from vunit.dependency_graph import DependencyGraph
from vunit.vhdl_parser import VHDLDesignFile
import vunit.ostools as ostools
import traceback


class Library:
    def __init__(self, name, directory, is_external=False):
        self.name = name
        self.directory = directory
        self.primary_design_units = {}

        # Entity objects
        self._entities = {}

        # Entity name to architecture names mapping
        self._architecture_names = {}
        self._is_external = is_external

    def add_design_units(self, design_units):
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

    def __eq__(self, other):
        if type(self) != type(other):
            return False
        else:
            return self.name == other.name

    def __hash__(self):
        return hash(self.name)


class SourceFile:
    def __init__(self, name, library, file_type='vhdl'):
        self.name = name
        self.library = library
        self.file_type = file_type
        code = ostools.read_file(self.name)
        self._md5 = hashlib.md5(code.encode()).hexdigest()

        self.design_units = []
        self.dependencies = []
        self.depending_components = []

        if self.file_type == 'vhdl':
            try:
                design_file = VHDLDesignFile.parse(code)
                self.design_units = self._find_design_units(design_file)
                self.dependencies = self._find_dependencies(design_file)
                self.depending_components = design_file.component_instantiations
            except:  # pylint: disable=bare-except
                traceback.print_exc()
                logger.error("Failed to parse %s", name)

        for design_unit in self.design_units:
            if design_unit.is_primary:
                logger.debug('Adding primary design unit (%s) %s', design_unit.unit_type, design_unit.name)
            elif design_unit.unit_type == 'package body':
                logger.debug('Adding secondary design unit (package body) for package %s',
                             design_unit.primary_design_unit)
            else:
                logger.debug('Adding secondary design unit (%s) %s', design_unit.unit_type, design_unit.name)

        if len(self.depending_components) != 0:
            logger.debug("The file '%s' has the following components:", self.name)
            for component in self.depending_components:
                logger.debug(component)
        else:
            logger.debug("The file '%s' has no components", self.name)

    def _find_dependencies(self, design_file):
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
        if type(self) != type(other):
            return False
        else:
            return self.name == other.name

    def __hash__(self):
        return hash(self.name)

    def md5(self):
        return self._md5


class Entity:
    def __init__(self, name, source_file, generic_names=None):
        self.name = name
        self.file_name = source_file.name
        self.library_name = source_file.library.name
        self.generic_names = [] if generic_names is None else generic_names
        self.architecture_names = {}

        self.source_file = source_file
        self.unit_type = 'entity'
        self.is_primary = True


class DesignUnit:
    def __init__(self, name, source_file, unit_type, is_primary=True, primary_design_unit=None):
        self.source_file = source_file
        self.name = name.lower()
        self.unit_type = unit_type
        self.is_primary = is_primary

        # Related primary design unit if this is a secondary design unit.
        self.primary_design_unit = None if is_primary else primary_design_unit.lower()


class Project:
    def __init__(self, depend_on_components=False):
        self._libraries = {}
        self._source_files = {}
        self._source_files_in_order = []
        self._depend_on_components = depend_on_components

    @staticmethod
    def _validate_library_name(library_name):
        if library_name == "work":
            logger.error("Cannot add library named work. work is a reference to the current library. "
                         "http://www.sigasi.com/content/work-not-vhdl-library")
            raise RuntimeError("Illegal library name 'work'")

    def add_library(self, logical_name, directory, allow_replacement=False, is_external=False):
        self._validate_library_name(logical_name)
        if logical_name not in self._libraries:
            library = Library(logical_name, directory, is_external=is_external)
            self._libraries[logical_name] = library
            logger.info('Adding library %s with path %s', logical_name, directory)
        else:
            assert allow_replacement
            library = Library(logical_name, directory, is_external=is_external)
            self._libraries[logical_name] = library
            logger.info('Replacing library %s with path %s', logical_name, directory)

    def add_source_file(self, file_name, library_name, file_type='vhdl'):
        logger.info('Adding source file %s to library %s', file_name, library_name)
        self._validate_library_name(library_name)
        library = self._libraries[library_name]
        source_file = SourceFile(file_name, library, file_type)
        library.add_design_units(source_file.design_units)
        self._source_files[file_name] = source_file
        self._source_files_in_order.append(file_name)

    @staticmethod
    def _find_primary_secondary_design_unit_dependencies(source_file):
        library = source_file.library

        for unit in source_file.design_units:
            if unit.is_primary:
                continue

            try:
                primary_unit = library.primary_design_units[unit.primary_design_unit]
            except KeyError:
                logger.warning("failed to find a primary design unit '%s' in library '%s'",
                               unit.primary_design_unit, library.name)
            else:
                yield primary_unit.source_file

    def _find_other_design_unit_dependencies(self, source_file):
        for library_name, unit_name in source_file.dependencies:
            try:
                library = self._libraries[library_name]
            except KeyError:
                if library_name not in ("ieee", "std"):
                    logger.warning("failed to find library '%s'", library_name)
                continue

            try:
                primary_unit = library.primary_design_units[unit_name]
            except KeyError:
                if not library._is_external:
                    logger.warning("failed to find a primary design unit '%s' in library '%s'",
                                   unit_name, library.name)
            else:
                yield primary_unit.source_file

    def _find_component_design_unit_dependencies(self, source_file):

        for unit_name in source_file.depending_components:
            found_component_entity = False

            for library in self.get_libraries():
                try:
                    primary_unit = library.primary_design_units[unit_name]
                except:
                    continue
                else:
                    found_component_entity = True
                    yield primary_unit.source_file

            if not found_component_entity:
                logger.debug("failed to find a matching entity for component '%s' ", unit_name)

    def _create_dependency_graph(self):
        def add_dependency(start, end):
            if start.name == end.name:
                return

            is_new = dependency_graph.add_dependency(start, end)

            if is_new:
                logger.info('Adding dependency: %s depends on %s', end.name, start.name)

        def add_dependencies(dependency_function):
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
        dependency_graph = self._create_dependency_graph()

        files = []
        for source_file in self.get_source_files_in_order():
            if (not incremental) or self._needs_recompile(dependency_graph, source_file):
                files.append(source_file)

        # Get files that are affected by recompiling the modified files
        affected_files = dependency_graph.get_affected(files)
        compile_order = dependency_graph.toposort()

        def comparison_key(source_file):
            return compile_order.index(source_file)

        return sorted(affected_files, key=comparison_key)

    def get_source_files_in_order(self):
        return [self._source_files[file_name] for file_name in self._source_files_in_order]

    def get_libraries(self):
        return self._libraries.values()

    def get_library(self, library_name):
        return self._libraries[library_name]

    def has_library(self, library_name):
        return library_name in self._libraries

    def _needs_recompile(self, dependency_graph, source_file):
        md5 = source_file.md5()
        md5_file_name = self._hash_file_name_of(source_file)

        if not ostools.file_exists(md5_file_name):
            logger.debug("%s has no vunit_hash file at %s and must be recompiled",
                         source_file.name, md5_file_name)
            return True

        old_md5 = ostools.read_file(md5_file_name)
        if old_md5 != md5:
            logger.debug("%s has different hash than last time and must be recompiled",
                         source_file.name)
            return True

        for other_file in dependency_graph.get_dependencies(source_file):
            other_md5_file_name = self._hash_file_name_of(other_file)

            if not ostools.file_exists(other_md5_file_name):
                continue

            if ostools.get_modification_time(other_md5_file_name) > ostools.get_modification_time(md5_file_name):
                logger.debug("%s has dependency compiled earlier and must be recompiled",
                             source_file.name)
                return True

        logger.debug("%s has same hash file and must not be recompiled",
                     source_file.name)

        return False

    def _hash_file_name_of(self, source_file):
        library = self.get_library(source_file.library.name)
        md5_prefix = hashlib.md5(dirname(source_file.name).encode()).hexdigest()
        return join(library.directory, md5_prefix, basename(source_file.name) + ".vunit_hash")

    def update(self, source_file):
        new_md5 = source_file.md5()
        ostools.write_file(self._hash_file_name_of(source_file), new_md5)
        logger.debug('Wrote %s md5=%s', source_file.name, new_md5)
