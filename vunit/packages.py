# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Adding VUnit packages: the simulator they provide and their sources and setup function
"""

import importlib
from vunit.builtins import Builtins
from vunit.sim_if.factory import SIMULATOR_FACTORY


def add_package(vunit_obj, package_name: str, allow_setup: bool = False) -> None:
    """
    Add a VUnit package: the simulator it provides, if any, and its sources and setup function.
    """
    package_name, package = Builtins.read_package(package_name)
    selected = vunit_obj._simulator_selected  # pylint: disable=protected-access
    _add_package_simulator(package_name, package, allow_setup, selected)
    vunit_obj._builtins.add_package_content(package_name, allow_setup)  # pylint: disable=protected-access


def _add_package_simulator(package_name: str, package: dict, allow_setup: bool, selection_frozen: bool) -> None:
    """
    Register the simulator interface class declared by a package, if any.
    """
    spec = package.get("simulator")
    if spec is None:
        return

    if selection_frozen:
        raise RuntimeError(
            f"Package {package_name} provides a simulator ({spec}) but the simulator has already been selected. "
            "Add simulator packages before any other call that depends on the simulator."
        )
    if not allow_setup:
        raise RuntimeError(
            f"Package {package_name} requires running Python code when it is added ({spec}). "
            "Pass allow_setup=True to add_package to allow it."
        )

    module_name, class_name = spec.split(":")
    try:
        simulator_class = getattr(importlib.import_module(module_name), class_name, None)
    except ImportError as exc:
        raise RuntimeError(
            f"Failed to import module {module_name} of the simulator of package {package_name}."
        ) from exc
    if simulator_class is None:
        raise RuntimeError(
            f"Could not find simulator class {class_name} in module {module_name} for package {package_name}."
        )

    try:
        SIMULATOR_FACTORY.register_simulator(simulator_class)
    except ValueError as exc:
        raise RuntimeError(f"Package {package_name} failed to add its simulator: {exc}") from exc
