# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
The context given to the setup function of a VUnit package
"""

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

from vunit.sim_if.hooks import register_hooks
from vunit.vhdl_standard import VHDLStandard


@dataclass(frozen=True)
class PackageContext:
    """
    The context in which a VUnit package is added.

    An instance of this class is passed to the setup function of a package, that is the
    function pointed out by the ``setup`` key of the package ``vunit_pkg.toml`` file. The
    setup function is called after the sources listed in ``vunit_pkg.toml`` have been added
    and the context provides what a package needs to complete its own addition, for example
    building a native library or adding generated sources.
    """

    #: The directory containing the ``vunit_pkg.toml`` file of the package.
    package_root: Path
    #: The :class:`.Library` created for the package or None if the package has no sources.
    library: Any
    #: The VHDL standard used to compile the sources of the package.
    vhdl_standard: VHDLStandard
    #: The VUnit output path. Files created by the package are to be placed under this path.
    output_path: Path
    #: The path of the run script creating the VUnit object.
    run_script_path: Path
    #: The class of the selected simulator interface or None if no simulator was found.
    simulator_class: Any
    _vunit_obj: Any

    #: Register hooks extending what a simulator does for a test, see :ref:`packages`.
    register_simulator_hooks = staticmethod(register_hooks)

    @property
    def simulator_name(self) -> Optional[str]:
        """
        The name of the selected simulator or None if no simulator was found.
        """
        return self.simulator_class.name if self.simulator_class else None

    @property
    def simulator_prefix(self) -> Optional[str]:
        """
        The path the executables of the selected simulator were found in, None if no simulator
        was found. The setup function of a package gets what it builds against from here, before
        any simulator interface exists to ask.
        """
        return self.simulator_class.find_prefix() if self.simulator_class else None

    @property
    def simulator_backend(self) -> Optional[str]:
        """
        How the selected simulator installation was built, None for a simulator with no such
        notion. What it says is simulator specific.

        GHDL is the simulator having one: its code generator, ``"mcode"``, ``"llvm"``,
        ``"llvm-jit"`` or ``"gcc"``, which decides how a native library is bound to the design.
        It follows from the prefix, so it cannot be had from the simulator class alone.
        """
        determine_backend = getattr(self.simulator_class, "determine_backend", None)
        prefix = self.simulator_prefix

        if determine_backend is None or prefix is None:
            return None

        return determine_backend(prefix)

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
            vhdl_standard=str(self.vhdl_standard) if vhdl_standard is None else vhdl_standard,
        )
