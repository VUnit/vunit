# Classes to model a HDL design hierarchy
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Functionality to represent and operate on a HDL code library
"""

import logging
from vunit.vhdl_standard import VHDLStandard

LOGGER = logging.getLogger(__name__)


class Library(object):  # pylint: disable=too-many-instance-attributes
    """
    Represents a VHDL library
    """

    def __init__(self, name: str, directory: str, vhdl_standard: VHDLStandard, is_external=False):
        self.name = name
        self.directory = directory

        # Default VHDL standard for files added unless explicitly set per file
        self.vhdl_standard = vhdl_standard

        self._source_files = {}  # type: ignore

        # Entity objects
        self._entities = {}  # type: ignore
        self._package_bodies = {}  # type: ignore

        self.primary_design_units = {}  # type: ignore

        # Entity name to architecture design unit mapping
        self._architectures = {}  # type: ignore

        # Verilog specific
        # Module objects
        self.modules = {}  # type: ignore
        self.verilog_packages = {}  # type: ignore

        self._is_external = is_external

    def add_source_file(self, source_file):
        """
        Add source file to library unless it exists

        returns The source file that has added or the old source file
        """
        if source_file.name in self._source_files:
            old_source_file = self._source_files[source_file.name]
            if old_source_file.content_hash != source_file.content_hash:
                raise RuntimeError(f"{source_file.name!s} already added to library {self.name!s}")

            LOGGER.info(
                "Ignoring duplicate file %s added to library %s due to identical contents",
                source_file.name,
                self.name,
            )

            return old_source_file

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
        LOGGER.warning(
            "%s: %s '%s' previously defined in %s",
            design_unit.source_file.name,
            design_unit.unit_type,
            design_unit.name,
            old_file_name,
        )

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
                self._check_duplication(self.primary_design_units, design_unit)
                self.primary_design_units[design_unit.name] = design_unit

                if design_unit.unit_type == "entity":
                    if design_unit.name not in self._architectures:
                        self._architectures[design_unit.name] = {}
                    self._entities[design_unit.name] = design_unit

                    for architecture in self._architectures[design_unit.name].values():
                        design_unit.add_architecture(architecture)

            else:
                if design_unit.unit_type == "architecture":
                    if design_unit.primary_design_unit not in self._architectures:
                        self._architectures[design_unit.primary_design_unit] = {}

                    if design_unit.name in self._architectures[design_unit.primary_design_unit]:
                        self._warning_on_duplication(
                            design_unit,
                            self._architectures[design_unit.primary_design_unit][design_unit.name].source_file.name,
                        )

                    self._architectures[design_unit.primary_design_unit][design_unit.name] = design_unit

                    if design_unit.primary_design_unit in self._entities:
                        self._entities[design_unit.primary_design_unit].add_architecture(design_unit)

                if design_unit.unit_type == "package body":
                    if design_unit.primary_design_unit in self._package_bodies:
                        self._warning_on_duplication(
                            design_unit,
                            self._package_bodies[design_unit.primary_design_unit].source_file.name,
                        )
                    self._package_bodies[design_unit.primary_design_unit] = design_unit

    def add_verilog_design_units(self, design_units):
        """
        Add Verilog design units to the library
        """
        for design_unit in design_units:
            if design_unit.unit_type == "module":
                if design_unit.name in self.modules:
                    self._warning_on_duplication(design_unit, self.modules[design_unit.name].source_file.name)
                self.modules[design_unit.name] = design_unit
            elif design_unit.unit_type == "package":
                if design_unit.name in self.verilog_packages:
                    self._warning_on_duplication(
                        design_unit,
                        self.verilog_packages[design_unit.name].source_file.name,
                    )
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
