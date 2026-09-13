# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com


"""
Setup of the Python bridge of a project: native library, configuration and generated VHDL.
"""

import os
import re
import sys
from pathlib import Path
from typing import Callable, List, Optional
from weakref import WeakKeyDictionary

from .native_library import (
    PACKAGE_PATH,
    PythonBridgeError,
    check_python_build,
    prepare_library,
    windows_python_dll,
)

RUNTIME_SOURCE = PACKAGE_PATH / "runtime.py"
VHDL_SOURCE_PATH = PACKAGE_PATH.parent / "vhdl" / "python" / "src"
BRIDGE_PACKAGE_TEMPLATE = VHDL_SOURCE_PATH / "python_bridge_pkg.vhd.in"
CONFIG_FILE_NAME = "vunit_python_bridge.cfg"

# Simulators reaching the bridge through VHPIDIRECT and through the FLI
FLI_SIMULATORS = ("modelsim",)
SUPPORTED_SIMULATORS = ("nvc", "ghdl") + FLI_SIMULATORS

# GHDL backends that link the design ahead of time. For these the library
# token in the VHPIDIRECT attribute is passed to the linker instead of being
# dlopen()ed at run time.
GHDL_LINKING_BACKENDS = ("llvm", "gcc")

# {foreign:<entry point>} placeholder of the bridge package template
FOREIGN_PATTERN = re.compile(r"\{foreign:(\w+)\}")

_BRIDGES: "WeakKeyDictionary[object, PythonBridge]" = WeakKeyDictionary()


class PythonBridge:
    """
    A prepared bridge: native library, its configuration and the generated VHDL.
    """

    def __init__(self, library_file: Path, vhdl_files: List[Path]) -> None:
        self.library_file = library_file
        self.vhdl_files = vhdl_files

    @property
    def directory(self) -> Path:
        return self.library_file.parent


def setup(project, output_path: str, simulator_class, run_script_path: Path) -> PythonBridge:
    """
    Prepare the Python bridge for a project. Called by add_python().

    :param run_script_path: The run script. Its directory is the base of
                            relative Python file names, like for import_run_script.
    :returns: The bridge. Its vhdl_files are to be added to vunit_lib.
    """
    simulator_name = None if simulator_class is None else simulator_class.name
    if simulator_name is not None and simulator_name not in SUPPORTED_SIMULATORS:
        raise PythonBridgeError(
            f"VHDL Python support (add_python()) requires NVC, GHDL or Questa/ModelSim, "
            f"it is not supported for {simulator_name}"
        )

    check_python_build()

    is_fli = simulator_name in FLI_SIMULATORS
    root = Path(output_path) / "python_bridge"
    library_file = prepare_library(root, Path(simulator_class.find_prefix()) if is_fli else None)
    base_dir = str(Path(run_script_path).resolve().parent)
    _write_if_changed(library_file.parent / CONFIG_FILE_NAME, _config_text(base_dir))

    bridge_package = root / "vhdl" / "python_bridge_pkg.vhd"
    _write_if_changed(
        bridge_package,
        _render_bridge_package(
            _fli_foreign(library_file)
            if is_fli
            else _vhpidirect_foreign(_vhpidirect_token(simulator_name, simulator_class, library_file))
        ),
    )

    bridge = PythonBridge(
        library_file,
        [
            bridge_package,
            VHDL_SOURCE_PATH / "python_ffi_pkg_bridge.vhd",
        ],
    )
    _BRIDGES[project] = bridge
    return bridge


def _vhpidirect_token(simulator_name, simulator_class, library_file: Path) -> str:
    """
    The library token of the VHPIDIRECT attributes: the file name the simulator dlopen()s,
    or the linker flag of the GHDL backends that link the design ahead of time.
    """
    if simulator_name == "ghdl" and _ghdl_backend(simulator_class) in GHDL_LINKING_BACKENDS:
        return "-lvunit_python_bridge"
    return library_file.name


def _vhpidirect_foreign(library_token: str) -> Callable[[str], str]:
    """
    The VHPIDIRECT attribute string of an entry point, for NVC and GHDL.
    """
    return lambda entry_point: f"VHPIDIRECT {library_token} {entry_point}"


def _fli_foreign(library_file: Path) -> Callable[[str], str]:
    """
    The FLI attribute string of an entry point: the name of its wrapper in native/fli.c and the
    library to load it from. Questa accepts the absolute path, so the library can stay in the
    bridge cache directory instead of being copied next to the simulation.
    """
    return lambda entry_point: f"fli_{entry_point} {library_file!s}"


def _render_bridge_package(foreign: Callable[[str], str]) -> str:
    """
    The generated python_bridge_pkg.vhd: the template with every {foreign:<entry point>}
    placeholder replaced by the attribute string of the selected simulator.
    """
    template = BRIDGE_PACKAGE_TEMPLATE.read_text(encoding="utf-8")
    return FOREIGN_PATTERN.sub(lambda match: foreign(match.group(1)), template)


def get_bridge(project) -> Optional[PythonBridge]:
    """
    The bridge of a project, None unless Python support is enabled.
    """
    return _BRIDGES.get(project)


def _config_text(base_dir: str) -> str:
    """
    Content of the configuration file read by the bridge library at run time.
    """
    lines = {
        "executable": sys.executable,
        "prefix": sys.prefix,
        "runtime": str(RUNTIME_SOURCE),
        "base_dir": base_dir,
    }
    if sys.platform == "win32":
        lines["python_dll"] = windows_python_dll()
    for key, value in lines.items():
        if "\n" in value or "\r" in value:
            raise PythonBridgeError(f"VHDL Python support cannot handle line breaks in the path {value!r}")
    return "".join(f"{key}={value}\n" for key, value in lines.items())


def _write_if_changed(path: Path, text: str) -> None:
    """
    Write a file unless it already has the given content, keeping timestamps stable.
    """
    data = text.encode("utf-8")
    if path.is_file() and path.read_bytes() == data:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + f".{os.getpid()}.tmp")
    tmp.write_bytes(data)
    os.replace(tmp, path)


def _ghdl_backend(simulator_class) -> Optional[str]:
    """
    Backend of the GHDL that will be used, None if not found.
    """
    prefix = simulator_class.find_prefix()
    if prefix is None:
        return None
    return simulator_class.determine_backend(prefix)
