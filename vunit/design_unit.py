# Classes to model a HDL design hierarchy
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Classes representing Entites, Architectures, Packades, Modules etc
"""


class DesignUnit(object):
    """
    Represents a generic design unit
    """

    def __init__(self, name, source_file, unit_type):
        self.name = name
        self.source_file = source_file
        self.unit_type = unit_type

    @property
    def file_name(self):
        return self.source_file.name

    @property
    def original_file_name(self):
        return self.source_file.original_name

    @property
    def library_name(self):
        return self.source_file.library.name

    @property
    def is_entity(self):
        return False

    @property
    def is_module(self):
        return False


class VHDLDesignUnit(DesignUnit):
    """
    Represents a VHDL design unit
    """

    def __init__(
        self,  # pylint: disable=too-many-arguments
        name,
        source_file,
        unit_type,
        *,
        is_primary=True,
        primary_design_unit=None,
    ):
        DesignUnit.__init__(self, name, source_file, unit_type)
        self.is_primary = is_primary
        self.primary_design_unit = primary_design_unit


class Entity(VHDLDesignUnit):
    """
    Represents a VHDL Entity
    """

    def __init__(self, name, source_file, generic_names=None):
        VHDLDesignUnit.__init__(self, name, source_file, "entity", is_primary=True)
        self.generic_names = [] if generic_names is None else generic_names
        self._add_architecture_callback = None
        self._architecture_names = {}

    def add_architecture(self, design_unit):
        """
        Add architecture of this entity
        """
        self._architecture_names[design_unit.name] = design_unit.source_file.name

        if self._add_architecture_callback is not None:
            self._add_architecture_callback()

    def set_add_architecture_callback(self, callback):
        """
        Set callback to be called when an architecture is added
        """
        assert self._add_architecture_callback is None
        self._add_architecture_callback = callback

    @property
    def architecture_names(self):
        return self._architecture_names

    @property
    def is_entity(self):
        return True


class Module(DesignUnit):
    """
    Represents a Verilog Module
    """

    def __init__(self, name, source_file, generic_names=None):
        DesignUnit.__init__(self, name, source_file, "module")
        self.generic_names = [] if generic_names is None else generic_names

    @property
    def is_module(self):
        return True
