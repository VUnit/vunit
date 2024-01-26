# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

"""
Temporary helper module to compile C-code used by python_pkg.
"""
from pathlib import Path
from glob import glob
import subprocess
import sys


def compile_vhpi_application(run_script_root, vu):
    """
    Compile VHPI application used by Aldec's simulators.
    """
    path_to_shared_lib = (run_script_root / "vunit_out" / vu.get_simulator_name() / "libraries").resolve()
    if not path_to_shared_lib.exists():
        path_to_shared_lib.mkdir(parents=True, exist_ok=True)
    shared_lib = path_to_shared_lib / "python.dll"
    path_to_python_include = Path(sys.executable).parent.resolve() / "include"
    path_to_python_libs = Path(sys.executable).parent.resolve() / "libs"
    python_shared_lib = f"python{sys.version_info[0]}{sys.version_info[1]}"
    path_to_python_pkg = Path(__file__).parent.resolve() / "vhdl" / "python" / "src"
    c_file_paths = [path_to_python_pkg / "python_pkg_vhpi.c", path_to_python_pkg / "python_pkg.c"]
    path_to_simulator = Path(vu._simulator_class.find_prefix()).resolve()  # pylint: disable=protected-access
    ccomp_executable = path_to_simulator / "ccomp.exe"

    proc = subprocess.run(
        [
            str(ccomp_executable),
            "-vhpi",
            "-dbg",
            "-verbose",
            "-o",
            '"' + str(shared_lib) + '"',
            "-l",
            python_shared_lib,
            "-l",
            "python3",
            "-l",
            "_tkinter",
            "-I",
            '"' + str(path_to_python_include) + '"',
            "-I",
            '"' + str(path_to_python_pkg) + '"',
            "-L",
            '"' + str(path_to_python_libs) + '"',
            " ".join(['"' + str(path) + '"' for path in c_file_paths]),
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    if proc.returncode != 0:
        print(proc.stdout)
        print(proc.stderr)
        raise RuntimeError("Failed to compile VHPI application")


def compile_fli_application(run_script_root, vu):  # pylint: disable=too-many-locals
    """
    Compile FLI application used by Questa.
    """
    path_to_simulator = Path(vu._simulator_class.find_prefix()).resolve()  # pylint: disable=protected-access
    path_to_simulator_include = (path_to_simulator / ".." / "include").resolve()

    # 32 or 64 bit installation?
    vsim_executable = path_to_simulator / "vsim.exe"
    proc = subprocess.run(
        [vsim_executable, "-version"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        print(proc.stderr)
        raise RuntimeError("Failed to get vsim version")

    is_64_bit = "64 vsim" in proc.stdout

    # Find GCC executable
    matches = glob(str((path_to_simulator / ".." / f"gcc*mingw{'64' if is_64_bit else '32'}*").resolve()))
    if len(matches) != 1:
        raise RuntimeError("Failed to find GCC executable")
    gcc_executable = (Path(matches[0]) / "bin" / "gcc.exe").resolve()

    path_to_python_include = Path(sys.executable).parent.resolve() / "include"
    path_to_python_pkg = Path(__file__).parent.resolve() / "vhdl" / "python" / "src"
    c_file_paths = [path_to_python_pkg / "python_pkg_fli.c", path_to_python_pkg / "python_pkg.c"]

    for c_file_path in c_file_paths:
        args = [
            str(gcc_executable),
            "-g",
            "-c",
            "-m64" if is_64_bit else "-m32",
            "-Wall",
            "-D__USE_MINGW_ANSI_STDIO=1",
        ]

        if not is_64_bit:
            args += ["-ansi", "-pedantic"]

        args += [
            "-I" + str(path_to_simulator_include),
            "-I" + str(path_to_python_include),
            "-freg-struct-return",
            str(c_file_path),
        ]

        proc = subprocess.run(
            args,
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode != 0:
            print(proc.stdout)
            print(proc.stderr)
            raise RuntimeError("Failed to compile FLI application")

    path_to_python_libs = Path(sys.executable).parent.resolve() / "libs"

    path_to_shared_lib = run_script_root / "vunit_out" / vu.get_simulator_name() / "libraries" / "python"
    if not path_to_shared_lib.exists():
        path_to_shared_lib.mkdir(parents=True, exist_ok=True)
    python_shared_lib = f"python{sys.version_info[0]}{sys.version_info[1]}"

    args = [
        str(gcc_executable),
        "-shared",
        "-lm",
        "-m64" if is_64_bit else "-m32",
        "-Wl,-Bsymbolic",
        "-Wl,-export-all-symbols",
        "-o",
        str(path_to_shared_lib / "python_fli.so"),
        "python_pkg.o",
        "python_pkg_fli.o",
        "-l" + python_shared_lib,
        "-l_tkinter",
        "-L" + str(path_to_simulator),
        "-L" + str(path_to_python_libs),
        "-lmtipli",
    ]

    proc = subprocess.run(
        args,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        print(proc.stdout)
        print(proc.stderr)
        raise RuntimeError("Failed to link FLI application")
