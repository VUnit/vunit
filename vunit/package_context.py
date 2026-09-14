# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
The context given to the setup function of a VUnit package
"""

from pathlib import Path
from typing import Optional

from vunit.vhdl_standard import VHDLStandard


class PackageContext(object):
    """
    The context in which a VUnit package is added.

    An instance of this class is passed to the setup function of a package, that is the
    function pointed out by the ``setup`` key of the package ``vunit_pkg.toml`` file. The
    setup function is called after the sources listed in ``vunit_pkg.toml`` have been added
    and the context provides what a package needs to complete its own addition, for example
    building a native library or adding generated sources.
    """

    def __init__(  # pylint: disable=too-many-arguments,too-many-positional-arguments
        self,
        vunit_obj,
        package_root: Path,
        library,
        vhdl_standard: VHDLStandard,
        simulator_class,
    ):
        self._vunit_obj = vunit_obj
        self._package_root = package_root
        self._library = library
        self._vhdl_standard = vhdl_standard
        self._simulator_class = simulator_class

    @property
    def package_root(self) -> Path:
        """
        The directory containing the ``vunit_pkg.toml`` file of the package.
        """
        return self._package_root

    @property
    def library(self):
        """
        The :class:`.Library` created for the package or None if the package has no sources.
        """
        return self._library

    @property
    def vhdl_standard(self) -> VHDLStandard:
        """
        The VHDL standard used to compile the sources of the package.
        """
        return self._vhdl_standard

    @property
    def output_path(self) -> Path:
        """
        The VUnit output path. Files created by the package are to be placed under this path.
        """
        return Path(self._vunit_obj._output_path)  # pylint: disable=protected-access

    @property
    def run_script_path(self) -> Path:
        """
        The path of the run script creating the VUnit object.
        """
        return self._vunit_obj._run_script_path  # pylint: disable=protected-access

    @property
    def simulator_name(self) -> Optional[str]:
        """
        The name of the selected simulator or None if no simulator was found.
        """
        return self._simulator_class.name if self._simulator_class else None

    @property
    def simulator_class(self):
        """
        The class of the selected simulator interface.
        """
        return self._simulator_class

    def add_library(self, library_name: str):
        """
        Add a library managed by VUnit, see :meth:`.VUnit.add_library`.

        :param library_name: The name of the library
        :returns: The created :class:`.Library` object
        """
        return self._vunit_obj.add_library(library_name)

    def add_source_files(self, library_name: str, pattern, vhdl_standard: Optional[str] = None):
        """
        Add source files matching wildcard pattern to library, see :meth:`.VUnit.add_source_files`.

        :param library_name: The name of the library to add files into
        :param pattern: A wildcard pattern matching the files to add or a list of files
        :param vhdl_standard: The VHDL standard used to compile files,
                              if None the standard of the package is used
        :returns: A list of files (:class:`.SourceFileList`) that were added
        """
        return self._vunit_obj.add_source_files(
            pattern,
            library_name,
            vhdl_standard=str(self._vhdl_standard) if vhdl_standard is None else vhdl_standard,
        )
