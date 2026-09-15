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
from typing import List, NamedTuple, Optional
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
# The subprogram declarations of the template, whose bodies are generated
SUBPROGRAM_PATTERN = re.compile(r"^  (impure function|procedure) (\w+)(\([^)]*\))?( return \w+)?;", re.MULTILINE)

_BRIDGES: "WeakKeyDictionary[object, PythonBridge]" = WeakKeyDictionary()


class PythonBridge(NamedTuple):
    """
    A prepared bridge: the native library and the generated VHDL.
    """

    library_file: Path
    vhdl_files: List[Path]


def setup(project, output_path: str, simulator_class, run_script_path: Optional[Path]) -> PythonBridge:
    """
    Prepare the Python bridge for a project. Called by add_python().

    :param run_script_path: The run script or None. The runtime puts its directory, or the current
                            directory without a run script, first on sys.path, like python does.
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
    run_script_dir = str(Path.cwd() if run_script_path is None else Path(run_script_path).resolve().parent)
    _write_if_changed(library_file.parent / CONFIG_FILE_NAME, _config_text(run_script_dir))

    # The foreign attribute string of an entry point: the name of its wrapper in native/fli.c
    # and the library, by absolute path since Questa accepts it, for the FLI; the VHPIDIRECT
    # library token and the entry point itself for NVC and GHDL.
    foreign = (
        f"fli_{{entry_point}} {library_file!s}"
        if is_fli
        else f"VHPIDIRECT {_vhpidirect_token(simulator_name, simulator_class, library_file)} {{entry_point}}"
    )
    bridge_package = root / "vhdl" / "python_bridge_pkg.vhd"
    _write_if_changed(bridge_package, _render_bridge_package(foreign))

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
    if (
        simulator_name == "ghdl"
        and simulator_class.determine_backend(simulator_class.find_prefix()) in GHDL_LINKING_BACKENDS
    ):
        return "-lvunit_python_bridge"
    return library_file.name


def _render_bridge_package(foreign: str) -> str:
    """
    The generated python_bridge_pkg.vhd: the declarations of the template with the foreign
    attribute of every subprogram, and a body reporting a failure for each of them since the
    bodies are replaced by the foreign implementations and never executed.
    """
    template = BRIDGE_PACKAGE_TEMPLATE.read_text(encoding="utf-8")
    declarations = FOREIGN_PATTERN.sub(lambda match: foreign.format(entry_point=match.group(1)), template)
    stubs = []
    for kind, name, parameters, result in SUBPROGRAM_PATTERN.findall(declarations):
        stubs.append(f"  {kind} {name}{parameters}{result} is\n  begin")
        stubs.append(f'    report "VUnit Python bridge: foreign subprogram {name} is not bound" severity failure;')
        if result:
            stubs.append(f"    return {'0.0' if result.endswith('real') else '1'};")
        stubs.append("  end;\n")
    return declarations + "\npackage body python_bridge_pkg is\n" + "\n".join(stubs) + "end package body;\n"


def get_bridge(project) -> Optional[PythonBridge]:
    """
    The bridge of a project, None unless Python support is enabled.
    """
    return _BRIDGES.get(project)


def _config_text(run_script_dir: str) -> str:
    """
    Content of the configuration file read by the bridge library at run time.
    """
    lines = {
        "executable": sys.executable,
        "prefix": sys.prefix,
        "runtime": str(RUNTIME_SOURCE),
        "run_script_dir": run_script_dir,
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
