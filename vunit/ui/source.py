# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
UI classes SourceFile and SourceFileList
"""

from .. import ostools


class SourceFileList(list):
    """
    A list of :class:`.SourceFile`
    """

    def __init__(self, source_files):
        list.__init__(self, source_files)

    def set_compile_option(self, name, value):
        """
        Set compile option for all files in the list

        :param name: |compile_option|
        :param value: The value of the compile option

        :example:

        .. code-block:: python

           files.set_compile_option("ghdl.a_flags", ["--no-vital-checks"])
        """
        for source_file in self:
            source_file.set_compile_option(name, value)

    def add_compile_option(self, name, value):
        """
        Add compile option to all files in the list

        :param name: |compile_option|
        :param value: The value of the compile option
        """
        for source_file in self:
            source_file.add_compile_option(name, value)

    def add_dependency_on(self, source_file):
        """
        Add manual dependency of these files on other file(s)

        :param source_file: The file(s) which this file depends on

        :example:

        .. code-block:: python

           other_file = lib.get_source_file("other_file.vhd")
           files.add_dependency_on(other_file)
        """
        for my_source_file in self:
            my_source_file.add_dependency_on(source_file)


class SourceFile(object):
    """
    A single file
    """

    def __init__(self, source_file, project, ui):
        self._source_file = source_file
        self._project = project
        self._ui = ui

    @property
    def name(self):
        """
        The name of the SourceFile
        """
        return ostools.simplify_path(self._source_file.name)

    @property
    def vhdl_standard(self):
        """
        The VHDL standard applicable to the file,
        None if not a VHDL file
        """
        if self._source_file.file_type == "vhdl":
            return str(self._source_file.get_vhdl_standard())

        return None

    @property
    def library(self):
        """
        The library of the source file
        """
        return self._ui.library(self._source_file.library.name)

    def set_compile_option(self, name, value):
        """
        Set compile option for this file

        :param name: |compile_option|
        :param value: The value of the compile option

        :example:

        .. code-block:: python

           my_file.set_compile_option("ghdl.a_flags", ["--no-vital-checks"])
        """
        self._source_file.set_compile_option(name, value)

    def add_compile_option(self, name, value):
        """
        Add compile option to this file

        :param name: |compile_option|
        :param value: The value of the compile option
        """
        self._source_file.add_compile_option(name, value)

    def get_compile_option(self, name):
        """
        Return compile option of this file

        :param name: |compile_option|
        """
        return self._source_file.get_compile_option(name)

    def add_dependency_on(self, source_file):
        """
        Add manual dependency of this file other file(s)

        :param source_file: The file(s) which this file depends on

        :example:

        .. code-block:: python

           other_files = lib.get_source_files("*.vhd")
           my_file.add_dependency_on(other_files)
        """
        if isinstance(source_file, SourceFile):
            private_source_file = source_file._source_file  # pylint: disable=protected-access
            self._project.add_manual_dependency(self._source_file, depends_on=private_source_file)
        elif hasattr(source_file, "__iter__"):
            for element in source_file:
                self.add_dependency_on(element)
        else:
            raise ValueError(source_file)
