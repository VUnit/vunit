# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Building the foreign language application implementing ``python_pkg``/``python_context``
(see :ref:`python_bridge`) for the simulators the VUnit Python bridge does not serve.

``setup_vhpi_application`` is called by :meth:`add_python() <vunit.ui.VUnit.add_python>` for
Riviera-PRO/Active-HDL (VHPI). The application is built under the output path on first use and
rebuilt when its sources, the Python running VUnit or the simulator change.
"""

from pathlib import Path
import sys
import hashlib

from .native_library import compile_library

SRC_PATH = Path(__file__).parent.resolve() / "native" / "vhpi"


def setup_vhpi_application(output_path, simulator_class):
    """
    Build the VHPI application for Riviera-PRO/Active-HDL under the output path, unless the one
    already there was built from the same sources for the same Python and simulator.
    """
    target = Path(output_path) / simulator_class.name / "libraries" / "python.dll"
    sources = [SRC_PATH / "python_pkg_vhpi.c", SRC_PATH / "python_pkg.c"]
    simulator_prefix = Path(simulator_class.find_prefix()).resolve()
    fingerprint = _fingerprint(sources, simulator_prefix)
    fingerprint_file = target.with_suffix(target.suffix + ".fingerprint")
    if target.exists() and fingerprint_file.exists() and fingerprint_file.read_text(encoding="utf-8") == fingerprint:
        return

    target.parent.mkdir(parents=True, exist_ok=True)
    fingerprint_file.unlink(missing_ok=True)
    _build_vhpi(target, sources, simulator_prefix)
    fingerprint_file.write_text(fingerprint, encoding="utf-8")


def _fingerprint(sources, simulator_prefix):
    """
    Everything the built application depends on: the C sources and headers, the Python that is
    embedded and the simulator whose headers and libraries are used.
    """
    digest = hashlib.sha256()
    for path in sorted(sources) + sorted(SRC_PATH.glob("*.h")):
        digest.update(path.name.encode("utf-8") + b"\0" + path.read_bytes() + b"\0")
    for item in [sys.executable, sys.prefix, sys.version, sys.platform, str(simulator_prefix)]:
        digest.update(item.encode("utf-8") + b"\0")
    return digest.hexdigest()


def _build_vhpi(target, sources, simulator_prefix):
    """
    Compile the VHPI application with the ccomp compiler driver of Riviera-PRO/Active-HDL.
    """
    python_include = Path(sys.executable).parent.resolve() / "include"
    python_libs = Path(sys.executable).parent.resolve() / "libs"
    ccomp = simulator_prefix / ("ccomp.exe" if sys.platform == "win32" else "ccomp")
    args = [str(ccomp), "-vhpi", "-dbg", "-verbose", "-o", f'"{target}"']
    args += ["-l", f"python{sys.version_info[0]}{sys.version_info[1]}", "-l", "python3", "-l", "_tkinter"]
    args += ["-I", f'"{python_include}"', "-I", f'"{SRC_PATH}"', "-L", f'"{python_libs}"']
    args += [" ".join(f'"{path}"' for path in sources)]
    compile_library(args, target, target)
