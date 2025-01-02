# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Functionality to represent and operate on VHDL and Verilog source files
"""
from pathlib import Path
from typing import Union
import logging
from copy import copy
import traceback
from vunit.sim_if.factory import SIMULATOR_FACTORY
from vunit.hashing import hash_string
from vunit.vhdl_parser import VHDLReference
from vunit.cached import file_content_hash
from vunit.parsing.encodings import HDL_FILE_ENCODING
from vunit.design_unit import DesignUnit, VHDLDesignUnit, Entity, Module
from vunit.vhdl_standard import VHDLStandard
from vunit.library import Library

LOGGER = logging.getLogger(__name__)


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
        return f"SourceFile({self.name!s}, {self.library.name!s})"

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

    def __init__(  # pylint: disable=too-many-arguments
        self,
        file_type,
        name,
        library,
        *,
        verilog_parser,
        database,
        include_dirs=None,
        defines=None,
        no_parse=False,
    ):
        SourceFile.__init__(self, str(name), library, file_type)
        self.package_dependencies = []
        self.module_dependencies = []
        self.include_dirs = include_dirs if include_dirs is not None else []
        self.defines = defines.copy() if defines is not None else {}
        self._content_hash = file_content_hash(self.name, encoding=HDL_FILE_ENCODING, database=database)

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
                self._content_hash = hash_string(
                    self._content_hash
                    + file_content_hash(
                        included_file_name,
                        encoding=HDL_FILE_ENCODING,
                        database=database,
                    )
                )

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

        except KeyboardInterrupt as exk:
            raise KeyboardInterrupt from exk
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

    def __init__(  # pylint: disable=too-many-arguments
        self,
        name: Union[str, Path],
        library: Library,
        *,
        vhdl_parser,
        database,
        vhdl_standard: VHDLStandard,
        no_parse=False,
    ):
        SourceFile.__init__(self, str(name), library, "vhdl")
        self.dependencies = []  # type: ignore
        self.depending_components = []  # type: ignore
        self._vhdl_standard = vhdl_standard

        if not no_parse:
            try:
                design_file = vhdl_parser.parse(self.name)
            except KeyboardInterrupt as exk:
                raise KeyboardInterrupt from exk
            except:  # pylint: disable=bare-except
                traceback.print_exc()
                LOGGER.error("Failed to parse %s", self.name)
            else:
                self._add_design_file(design_file)

        self._content_hash = file_content_hash(self.name, encoding=HDL_FILE_ENCODING, database=database)

    def get_vhdl_standard(self) -> VHDLStandard:
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
                LOGGER.debug(
                    "Adding primary design unit (%s) %s",
                    design_unit.unit_type,
                    design_unit.name,
                )
            elif design_unit.unit_type == "package body":
                LOGGER.debug(
                    "Adding secondary design unit (package body) for package %s",
                    design_unit.primary_design_unit,
                )
            else:
                LOGGER.debug(
                    "Adding secondary design unit (%s) %s",
                    design_unit.unit_type,
                    design_unit.name,
                )

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
            result.append(VHDLReference("entity", self.library.name, configuration.entity, "all"))

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
            result.append(VHDLDesignUnit(context.identifier, self, "context"))

        for package in design_file.packages:
            result.append(VHDLDesignUnit(package.identifier, self, "package"))

        for architecture in design_file.architectures:
            result.append(
                VHDLDesignUnit(
                    architecture.identifier,
                    self,
                    "architecture",
                    is_primary=False,
                    primary_design_unit=architecture.entity,
                )
            )

        for configuration in design_file.configurations:
            result.append(VHDLDesignUnit(configuration.identifier, self, "configuration"))

        for body in design_file.package_bodies:
            result.append(
                VHDLDesignUnit(
                    body.identifier, self, "package body", is_primary=False, primary_design_unit=body.identifier
                )
            )

        return result

    @property
    def content_hash(self):
        """
        Compute hash of contents and compile options
        """
        return hash_string(self._content_hash + self._compile_options_hash() + hash_string(str(self._vhdl_standard)))

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
FILE_TYPES = ("vhdl",) + VERILOG_FILE_TYPES


def file_type_of(file_name):
    """
    Return the file type of file_name based on the file ending
    """
    ext = str(Path(file_name).suffix)
    if ext.lower() in VHDL_EXTENSIONS:
        return "vhdl"

    if ext.lower() in VERILOG_EXTENSIONS:
        return "verilog"

    if ext.lower() in SYSTEM_VERILOG_EXTENSIONS:
        return "systemverilog"

    raise RuntimeError(f"Unknown file ending '{ext!s}' of {file_name!s}")
