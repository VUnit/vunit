# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Functions to add builtin VHDL code to a project for compilation
"""

from pathlib import Path
from glob import glob
import logging
import importlib
import importlib.resources
import importlib.util
import re
import operator
from dataclasses import dataclass
from typing import TypeVar, Any, Tuple

try:
    # Python 3.11+
    import tomllib  # type: ignore
except ModuleNotFoundError:
    import tomli as tomllib  # type: ignore

from vunit.vhdl_standard import VHDL, VHDLStandard
from vunit.ui.common import get_checked_file_names_from_globs
from vunit.about import version, VUnitVersion


LOGGER = logging.getLogger(__name__)

VHDL_PATH = (Path(__file__).parent / "vhdl").resolve()
VERILOG_PATH = (Path(__file__).parent / "verilog").resolve()


@dataclass(frozen=True)
class ValidationError:
    path: str
    message: str


VersionT = TypeVar("VersionT", VHDLStandard, VUnitVersion)


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

        add("array_util")  # Removed in v5.0.0
        add("com")
        add("verification_components", ["com", "osvvm"])
        add("osvvm")
        add("random", ["osvvm"])

    def add(self, name, args=None):
        self._builtins_adder.add(name, args)

    _VERSION_REQUIREMENT_RE = re.compile(r"(?P<operator>===|~=|<=|!=|==|>=|>|<)\s*(?P<version>.*)", re.VERBOSE)
    _OPERATORS = {
        "==": operator.eq,
        "!=": operator.ne,
        ">=": operator.ge,
        "<=": operator.le,
        ">": operator.gt,
        "<": operator.lt,
    }

    def _meets_required_version(
        self,
        version_class: type[VersionT],
        current_version_str: str,
        required_version_specifier: str,
    ) -> bool:
        """Check if the current VUnit version meets the required version."""

        current_version = version_class(current_version_str)
        requirement_list = required_version_specifier.split(",")
        for requirement in requirement_list:
            requirement = requirement.strip()
            # Skip empty requirements since trailing commas are allowed
            if requirement == "":
                continue

            match = self._VERSION_REQUIREMENT_RE.fullmatch(requirement)
            if not match:
                raise RuntimeError(
                    f"Invalid version requirement format: {requirement}. Use <OPERATOR><VERSION> "
                    "where OPERATOR is one of <=, <, !=, ==, >=, and >."
                )

            version_operator = match.group("operator")
            operator_function = self._OPERATORS.get(version_operator, None)
            if not operator_function:
                raise RuntimeError(f"Unsupported version specifier operator: {version_operator}.")

            required_version_str = requirement[match.end("operator") :].strip()
            required_version = version_class(required_version_str)

            if not operator_function(current_version, required_version):
                return False

        return True

    @staticmethod
    def _to_toml_type(python_type: type) -> Tuple[str, str]:
        """Translate Python type to TOML type terminology."""
        mapping = {
            dict: ("table", "a"),
            list: ("array", "an"),
            str: ("string", "a"),
            int: ("integer", "an"),
            float: ("float", "a"),
        }
        return mapping.get(python_type, (python_type.__name__, "a"))

    def _check_valid_keys(
        self, data: dict[str, Any], valid: dict[str, type], path: str = "TOML"
    ) -> list[ValidationError]:
        """Check that TOML keys are valid, both name and type."""
        errors = []
        for key, value in data.items():
            if key not in valid:
                toml_type, _ = self._to_toml_type(type(value))
                errors.append(ValidationError(path=f"{path}.{key}", message=f"Unexpected {toml_type} '{key}'."))
            elif not isinstance(value, valid[key]):
                toml_type, article = self._to_toml_type(valid[key])
                errors.append(ValidationError(path=f"{path}.{key}", message=f"'{key}' must be {article} {toml_type}."))

        return errors

    def _check_mandatory_keys(
        self, data: dict[str, Any], mandatory: dict[str, type], path: str = "TOML"
    ) -> list[ValidationError]:
        """Check that mandatory TOML keys are present."""
        missing_keys = [key for key in mandatory.keys() if key not in data]
        errors = []

        for key in missing_keys:
            toml_type, _ = self._to_toml_type(mandatory[key])
            errors.append(ValidationError(path=f"{path}", message=f"Missing mandatory {toml_type} '{key}'."))

        return errors

    @staticmethod
    def _log_validation_errors(errors: list[ValidationError]) -> None:
        """Log validation error path and message."""
        if errors:
            for error in errors:
                LOGGER.error("%s: %s", error.path, error.message)

            raise RuntimeError(f"Invalid vunit_pkg.toml: {len(errors)} error(s) found.")

    def _validate_toml(self, data: dict) -> None:
        """Validate that the TOML specification has the correct format."""
        errors = []

        errors.extend(self._check_mandatory_keys(data, mandatory={"package": dict}, path="TOML"))
        errors.extend(self._check_valid_keys(data, valid={"package": dict}, path="TOML"))

        self._log_validation_errors(errors)

        package = data["package"]
        errors.extend(
            self._check_valid_keys(
                package,
                valid={"requires-vunit": str, "requires-vhdl": str, "library": str, "sources": list},
                path="package",
            )
        )

        if "sources" in package:
            errors.extend(self._check_mandatory_keys(package, mandatory={"library": str}, path="package"))

            for idx, source in enumerate(package["sources"]):
                errors.extend(
                    self._check_mandatory_keys(source, mandatory={"include": list}, path=f"package.sources[{idx}]")
                )
                if "include" in source:
                    for list_idx, path in enumerate(source["include"]):
                        if not isinstance(path, str):
                            errors.append(
                                ValidationError(
                                    path=f"package.sources[{idx}].include[{list_idx}]",
                                    message="Path must be a string.",
                                )
                            )

        self._log_validation_errors(errors)

    @staticmethod
    def _read_toml(root: Path, package_name: str) -> dict:
        """Read TOML file."""
        toml = root / "vunit_pkg.toml"

        if not toml.is_file():
            raise RuntimeError(f"Could not find vunit_pkg.toml for package {package_name} in {root}.")

        try:
            with toml.open("rb") as fptr:
                return tomllib.load(fptr)
        except tomllib.TOMLDecodeError as exc:
            raise RuntimeError(f"vunit_pkg.toml for package {package_name} is not a valid TOML file") from exc

    @staticmethod
    def _find_package(package_name: str) -> Path:
        """Find package path."""

        # find_spec is safe since it does not execute the package __init__.py file
        spec = importlib.util.find_spec(package_name)
        if spec is None:
            raise RuntimeError(f"Could not find package {package_name}.")

        if spec.submodule_search_locations is not None and spec.origin is None:
            raise RuntimeError(f"Package {package_name} is a namespace package, which is currently not supported.")

        if spec.submodule_search_locations is not None and spec.origin:
            return Path(spec.origin).parent

        raise RuntimeError(f"Failed to find location of package {package_name}.")

    def add_package(self, package_name: str) -> None:
        """Add VUnit package."""
        # The following future improvements are planned:
        # - Support for user specified library name
        # - Support for shared libraries across multiple packages
        # - Support for adding subsets of packages

        # Just like PyPi, all package names are normalized such that dashes, dots and
        # underscores are equivalent.
        package_name = package_name.replace("-", "_").replace(".", "_")

        package_root = self._find_package(package_name)
        data = self._read_toml(package_root, package_name)
        self._validate_toml(data)

        package = data["package"]
        vunit_version = version()
        if not self._meets_required_version(VUnitVersion, vunit_version, package.get("requires-vunit", "")):
            raise RuntimeError(
                f"Package {package_name} requires VUnit version "
                f"{package['requires-vunit']} but current version is {vunit_version}."
            )

        package_vhdl_standard = package.get("requires-vhdl", "")
        if not self._meets_required_version(VHDLStandard, str(self._vhdl_standard), package_vhdl_standard):
            use_vhdl_standard = None
            for vhdl_standard in VHDL.STANDARDS:
                if self._meets_required_version(VHDLStandard, str(vhdl_standard), package_vhdl_standard):
                    use_vhdl_standard = str(vhdl_standard)
                    break

            if not use_vhdl_standard:
                raise RuntimeError(
                    f"Package {package_name} requires VHDL standard "
                    f"{package['requires-vhdl']}. Failed to find a compatible standard."
                )

            LOGGER.warning(
                "Package %s requires VHDL standard %s but current standard is %s. "
                "Proceeding with mixed-language compilation using VHDL standard %s for the package.",
                package_name,
                package["requires-vhdl"],
                self._vhdl_standard,
                use_vhdl_standard,
            )

        else:
            use_vhdl_standard = None

        sources = package.get("sources", [])
        if sources:
            library_name = package.get("library")
            library = self._add_library_if_not_exist(
                library_name,
                f"Library {library_name} previously defined. Skipping addition of {package_name}.",
            )

            if library is None:
                return

            for source in sources:
                for include in source["include"]:
                    library.add_source_files(package_root / include, vhdl_standard=use_vhdl_standard)

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
                pattern=(
                    str(VHDL_PATH / "data_types" / "src" / "api" / f"external_{key!s}_pkg.vhd")
                    if external is None or key not in external or not external[key] or external[key] is True
                    else external[key]
                ),
                allow_empty=False,
            )

    @staticmethod
    def _add_array_util():
        """
        Array utility was removed in v5.0.0. Raise a runtime error.
        """
        raise RuntimeError("Array util was removed in v5.0.0; use 'integer_array_t' instead")

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

    def _add_library_if_not_exist(self, library_name, message):
        """
        Check if a library name exists in the project. If not, add it and return a handle.
        """
        if library_name.lower() in [
            library.lower() for library in self._vunit_obj._project._libraries  # pylint: disable=protected-access
        ]:
            LOGGER.warning(message)
            return None
        return self._vunit_obj.add_library(library_name)

    def _add_osvvm(self):
        """
        Add osvvm library
        """
        library = self._add_library_if_not_exist(
            "osvvm", "Library 'OSVVM' previously defined. Skipping addition of builtin OSVVM (2023.04)."
        )
        if library is None:
            return

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
                    "MemoryPkg.vhd",
                    "MemoryGenericPkg.vhd",
                ]
            ):
                continue

            if supports_vhdl_package_generics and (
                bname
                in [
                    "ScoreboardPkg_int_c.vhd",
                    "ScoreboardPkg_slv_c.vhd",
                    "MemoryPkg_c.vhd",
                    "MemoryPkg_orig_c.vhd",
                ]
            ):
                continue

            library.add_source_files(file_name, preprocessors=[])

    def _add_vhdl_logging(self):
        """
        Add logging functionality
        """

        use_call_paths = self._simulator_class.supports_vhdl_call_paths() and (
            self._vhdl_standard in VHDL.STD_2019.and_later
        )
        if use_call_paths:
            self._vunit_lib.add_source_file(VHDL_PATH / "logging" / "src" / "location_pkg-body-2019p.vhd")
        else:
            self._vunit_lib.add_source_file(VHDL_PATH / "logging" / "src" / "location_pkg-body-2008m.vhd")

        for file_name in get_checked_file_names_from_globs(VHDL_PATH / "logging" / "src" / "*.vhd", allow_empty=False):
            base_file_name = Path(file_name).name

            if base_file_name.startswith("location_pkg-body"):
                continue

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

            self._vunit_lib.add_source_file(file_name)

    def add_verilog_builtins(self):
        """
        Add Verilog builtins
        """
        self._vunit_lib.add_source_files(VERILOG_PATH / "vunit_pkg.sv")

    def add_vhdl_builtins(self, external=None, use_external_log=None):
        """
        Add vunit VHDL builtin libraries

        :param external: struct to provide bridges for the external VHDL API.

        :example:

        .. code-block:: python

            Builtins.add_vhdl_builtins(external={
                'string': ['path/to/custom/file'],
                'integer': ['path/to/custom/file']
            })
        """
        self._add_data_types(external=external)
        self._add_vhdl_logging()
        self._add_files(VHDL_PATH / "*.vhd")
        for path in (
            "core",
            "string_ops",
            "check",
            "dictionary",
            "run",
            "path",
        ):
            self._add_files(VHDL_PATH / path / "src" / "*.vhd")

        logging_files = glob(str(VHDL_PATH / "logging" / "src" / "*.vhd"))
        for logging_file in logging_files:
            if logging_file.endswith("common_log_pkg-body.vhd") and use_external_log:
                self._add_files(Path(use_external_log))
                continue

            self._add_files(Path(logging_file))


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
