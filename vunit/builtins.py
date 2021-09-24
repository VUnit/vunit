# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

"""
Functions to add builtin VHDL code to a project for compilation
"""

from pathlib import Path
from glob import glob
from warnings import warn
from vunit.vhdl_standard import VHDL, VHDLStandard
from vunit.ui.common import get_checked_file_names_from_globs

VHDL_PATH = (Path(__file__).parent / "vhdl").resolve()
VERILOG_PATH = (Path(__file__).parent / "verilog").resolve()


class Builtins(object):
    """
    Manage VUnit builtins and their dependencies
    """

    def __init__(self, vunit_obj, vhdl_standard: VHDLStandard, simulator_class):
        self._vunit_obj = vunit_obj
        self._vunit_lib = vunit_obj.add_library("vunit_lib")
        self._vhdl_standard = vhdl_standard
        self._simulator_class = simulator_class
        self._builtins_adder = BuiltinsAdder()

        def add(name, deps=tuple()):
            self._builtins_adder.add_type(name, getattr(self, f"_add_{name!s}"), deps)

        add("array_util")
        add("com")
        add("verification_components", ["com", "osvvm"])
        add("osvvm")
        add("random", ["osvvm"])
        add("json4vhdl")

    def add(self, name, args=None):
        self._builtins_adder.add(name, args)

    def _add_files(self, pattern=None, allow_empty=True):
        """
        Add files with naming convention to indicate which standard is supported
        """
        supports_context = self._simulator_class.supports_vhdl_contexts() and self._vhdl_standard.supports_context

        for file_name in get_checked_file_names_from_globs(pattern, allow_empty):
            base_file_name = Path(file_name).name

            standards = set()
            for standard in VHDL.STANDARDS:
                standard_name = str(standard)
                if standard_name + "p" in base_file_name:
                    standards.update(standard.and_later)
                elif standard_name + "m" in base_file_name:
                    standards.update(standard.and_earlier)
                elif standard_name in base_file_name:
                    standards.add(standard)

            if standards and self._vhdl_standard not in standards:
                continue

            if not supports_context and file_name.endswith("_context.vhd"):
                continue

            self._vunit_lib.add_source_file(file_name)

    def _add_data_types(self, external=None):
        """
        Add data types packages (sources corresponding to VHPIDIRECT arrays, or their placeholders)

        :param external: struct to provide bridges for the external VHDL API.
                         {
                             'string': ['path/to/custom/file'],
                             'integer': ['path/to/custom/file']
                         }.
        """
        self._add_files(VHDL_PATH / "data_types" / "src" / "*.vhd")

        for key in ["string", "integer_vector"]:
            self._add_files(
                pattern=str(VHDL_PATH / "data_types" / "src" / "api" / f"external_{key!s}_pkg.vhd")
                if external is None or key not in external or not external[key] or external[key] is True
                else external[key],
                allow_empty=False,
            )

    def _add_array_util(self):
        """
        Add array utility
        """
        if not self._vhdl_standard >= VHDL.STD_2008:
            raise RuntimeError("Array util only supports vhdl 2008 and later")

        arr_deprecation_note = (
            "'array_t' is deprecated and it will removed in future releases; use 'integer_array_t' instead"
        )
        warn(arr_deprecation_note, Warning)

        self._vunit_lib.add_source_files(VHDL_PATH / "array" / "src" / "*.vhd")

    def _add_random(self):
        """
        Add random pkg
        """
        if not self._vhdl_standard >= VHDL.STD_2008:
            raise RuntimeError("Random only supports vhdl 2008 and later")

        self._vunit_lib.add_source_files(VHDL_PATH / "random" / "src" / "*.vhd")

    def _add_com(self):
        """
        Add com library
        """
        if not self._vhdl_standard >= VHDL.STD_2008:
            raise RuntimeError("Communication package only supports vhdl 2008 and later")

        self._add_files(VHDL_PATH / "com" / "src" / "*.vhd")

    def _add_verification_components(self):
        """
        Add verification component library
        """
        if not self._vhdl_standard >= VHDL.STD_2008:
            raise RuntimeError("Verification component library only supports vhdl 2008 and later")
        self._add_files(VHDL_PATH / "verification_components" / "src" / "*.vhd")

    def _add_osvvm(self):
        """
        Add osvvm library
        """
        library_name = "osvvm"

        try:
            library = self._vunit_obj.library(library_name)
        except KeyError:
            library = self._vunit_obj.add_library(library_name)

        simulator_coverage_api = self._simulator_class.get_osvvm_coverage_api()
        supports_vhdl_package_generics = self._simulator_class.supports_vhdl_package_generics()

        if not osvvm_is_installed():
            raise RuntimeError(
                """
Found no OSVVM VHDL files. Did you forget to run

git submodule update --init --recursive

in your VUnit Git repository? You have to do this first if installing using setup.py."""
            )

        for file_name in glob(str(VHDL_PATH / "osvvm" / "*.vhd")):
            bname = Path(file_name).name

            if (bname == "AlertLogPkg_body_BVUL.vhd") or ("2019" in bname):
                continue

            if ((simulator_coverage_api != "rivierapro") and (bname == "VendorCovApiPkg_Aldec.vhd")) or (
                (simulator_coverage_api == "rivierapro") and (bname == "VendorCovApiPkg.vhd")
            ):
                continue

            if not supports_vhdl_package_generics and (
                bname
                in [
                    "ScoreboardGenericPkg.vhd",
                    "ScoreboardPkg_int.vhd",
                    "ScoreboardPkg_slv.vhd",
                ]
            ):
                continue

            library.add_source_files(file_name, preprocessors=[])

    def _add_json4vhdl(self):
        """
        Add JSON-for-VHDL library
        """
        library_name = "JSON"

        try:
            library = self._vunit_obj.library(library_name)
        except KeyError:
            library = self._vunit_obj.add_library(library_name)

        library.add_source_files(VHDL_PATH / "JSON-for-VHDL" / "src" / "*.vhdl")

    def add_verilog_builtins(self):
        """
        Add Verilog builtins
        """
        self._vunit_lib.add_source_files(VERILOG_PATH / "vunit_pkg.sv")

    def add_vhdl_builtins(self, external=None):
        """
        Add vunit VHDL builtin libraries

        :param external: struct to provide bridges for the external VHDL API.
                         {
                             'string': ['path/to/custom/file'],
                             'integer': ['path/to/custom/file']
                         }.
        """
        self._add_data_types(external=external)
        self._add_files(VHDL_PATH / "*.vhd")
        for path in (
            "core",
            "logging",
            "string_ops",
            "check",
            "dictionary",
            "run",
            "path",
        ):
            self._add_files(VHDL_PATH / path / "src" / "*.vhd")


def osvvm_is_installed():
    """
    Checks if OSVVM is installed within the VUnit directory structure
    """
    return len(glob(str(VHDL_PATH / "osvvm" / "*.vhd"))) != 0


def add_verilog_include_dir(include_dirs):
    """
    Add VUnit Verilog include directory
    """
    return [str(VERILOG_PATH / "include")] + include_dirs


class BuiltinsAdder(object):
    """
    Class to manage adding of builtins with dependencies
    """

    def __init__(self):
        self._already_added = {}
        self._types = {}

    def add_type(self, name, function, dependencies=tuple()):
        self._types[name] = (function, dependencies)

    def add(self, name, args=None):
        """
        Add builtin with arguments
        """
        args = {} if args is None else args

        if not self._add_check(name, args):
            function, dependencies = self._types[name]
            for dep_name in dependencies:
                self.add(dep_name)
            function(**args)

    def _add_check(self, name, args=None):
        """
        Check if this package has already been added,
        if it has already been added it must use the same parameters

        @returns False if not yet added
        """
        if name not in self._already_added:
            self._already_added[name] = args
            return False

        old_args = self._already_added[name]
        if args != old_args:
            raise RuntimeError(
                f"Optional builtin {name!r} added with arguments {args!r} "
                f"has already been added with arguments {old_args!r}"
            )
        return True
