# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

"""
Build the prebuilt Windows DLL of the VHDL Python bridge for the running Python.

Must be run on Windows, with the Python version the DLL is built for, from a
shell where the MSVC compiler (cl.exe) is available (e.g. a "Developer
Command Prompt" or the ilammy/msvc-dev-cmd GitHub action). This is used by CI
to produce the DLLs shipped in vunit/python_bridge/bin. End users never need it.

The Python DLL is delay-loaded; the bridge loads it by absolute path at run
time. That way the simulator does not need the Python installation on PATH.
"""

import argparse
import importlib.util
import subprocess
import sys
import sysconfig
from pathlib import Path


def _load_native_library():
    """
    Load vunit/python_bridge/native_library.py by path, without importing vunit and its dependencies.
    """
    path = Path(__file__).parent.parent / "vunit" / "python_bridge" / "native_library.py"
    spec = importlib.util.spec_from_file_location("_vunit_python_bridge_native_library", path)
    module = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
    spec.loader.exec_module(module)  # type: ignore[union-attr]
    return module


NATIVE_LIBRARY = _load_native_library()


def main():
    """
    Build the DLL.
    """
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=NATIVE_LIBRARY.BINARY_PATH,
        help="Directory to write the DLL to (default: %(default)s)",
    )
    args = parser.parse_args()

    if sys.platform != "win32" or sysconfig.get_platform() != "win-amd64":
        raise SystemExit("The bridge DLL must be built on 64-bit Windows with a python.org style CPython")
    if sysconfig.get_config_var("Py_GIL_DISABLED"):
        raise SystemExit("Free-threaded CPython builds are not supported")

    python_lib = f"python{sys.version_info[0]}{sys.version_info[1]}"
    include_dir = sysconfig.get_paths()["include"]
    libs_dir = Path(sys.base_prefix) / "libs"
    if not (libs_dir / f"{python_lib}.lib").is_file():
        raise SystemExit(f"Missing import library {libs_dir / (python_lib + '.lib')}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / NATIVE_LIBRARY.windows_dll_name()
    build_dir = args.output_dir / "build"
    build_dir.mkdir(exist_ok=True)

    cmd = [
        "cl",
        "/nologo",
        "/LD",
        "/O2",
        "/W3",
        "/MD",
        "/Brepro",
        f"/I{include_dir}",
        f"/Fo{build_dir}\\",
        *[str(path) for path in NATIVE_LIBRARY.bridge_sources()],
        f"/Fe{output}",
        "/link",
        "/Brepro",
        f"/LIBPATH:{libs_dir}",
        f"{python_lib}.lib",
        "delayimp.lib",
        f"/DELAYLOAD:{python_lib}.dll",
    ]
    print(" ".join(cmd))
    subprocess.run(cmd, check=True)

    for suffix in (".lib", ".exp"):
        output.with_suffix(suffix).unlink(missing_ok=True)
    for path in build_dir.iterdir():
        path.unlink()
    build_dir.rmdir()
    print(f"Built {output}")


if __name__ == "__main__":
    main()
