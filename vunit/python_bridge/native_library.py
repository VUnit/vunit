# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com


"""
The native bridge library: compiled and cached on Linux, prebuilt DLLs on Windows.

This module only depends on the standard library so that tools/build_python_bridge.py
can load it without VUnit's dependencies.
"""

import hashlib
import os
import platform
import shlex
import shutil
import subprocess
import sys
import sysconfig
from pathlib import Path
from typing import List, Optional, Tuple

PACKAGE_PATH = Path(__file__).parent.resolve()
# C sources of the bridge library
NATIVE_PATH = PACKAGE_PATH / "native"
# Prebuilt Windows DLLs, included in releases
BINARY_PATH = PACKAGE_PATH / "bin"
# Front end only compiled into the FLI variant of the library
FLI_SOURCE_NAME = "fli.c"


class PythonBridgeError(RuntimeError):
    """
    The Python bridge cannot be set up in this environment, e.g. due to a missing prerequisite.
    """


def check_python_build() -> None:
    """
    Reject Python builds that the bridge is known not to support.
    """
    if sysconfig.get_config_var("Py_GIL_DISABLED"):
        raise PythonBridgeError(
            "VHDL Python support does not work with free-threaded CPython builds "
            f"({sys.executable}). Use a regular (GIL) CPython build."
        )
    if sys.implementation.name != "cpython":
        raise PythonBridgeError(f"VHDL Python support requires CPython, not {sys.implementation.name}")


def library_file_name(fli: bool = False) -> str:
    """
    File name of the bridge library built on POSIX platforms.
    """
    return "libvunit_python_bridge_fli.so" if fli else "libvunit_python_bridge.so"


def prepare_library(root: Path, simulator_prefix: Optional[Path] = None) -> Path:
    """
    Path of the bridge library for the running Python, built or selected under root.

    :param simulator_prefix: Executable directory of a simulator calling the bridge through
                             the FLI (Questa/ModelSim). The FLI variant of the library, which
                             also contains native/fli.c, is then built against its headers.
                             None selects the VHPIDIRECT variant used by NVC and GHDL.
    """
    if sys.platform == "win32":
        if simulator_prefix is not None:
            return _build_windows_fli_library(root, simulator_prefix)
        return _prepare_windows_library(root)
    return _prepare_posix_library(root, simulator_prefix)


def windows_dll_name(version_info: Optional[Tuple[int, ...]] = None) -> str:
    """
    File name of the prebuilt bridge DLL for a Python version.
    """
    major, minor = sys.version_info[:2] if version_info is None else version_info[:2]
    return f"vunit_python_bridge-cp{major}{minor}-win_amd64.dll"


def windows_python_dll() -> str:
    """
    Path of the Python DLL of the running interpreter.
    """
    import ctypes  # pylint: disable=import-outside-toplevel

    dll_handle = getattr(sys, "dllhandle", None)
    if dll_handle is None:
        raise PythonBridgeError(
            f"VHDL Python support requires a CPython build using a Python DLL ({sys.executable} has none)"
        )
    buffer = ctypes.create_unicode_buffer(32768)
    kernel32 = ctypes.windll.kernel32  # type: ignore[attr-defined]
    length = kernel32.GetModuleFileNameW(ctypes.c_void_p(dll_handle), buffer, len(buffer))
    if length == 0:
        raise PythonBridgeError("Failed to determine the path of the Python DLL")
    return buffer.value


def _prepare_windows_library(root: Path) -> Path:
    """
    Select the prebuilt DLL for the running Python. Never compiles.
    """
    if sysconfig.get_platform() != "win-amd64":
        raise PythonBridgeError(
            "VHDL Python support on Windows requires a 64-bit (x86-64) python.org style CPython, "
            f"{sys.executable} is built for {sysconfig.get_platform()}"
        )
    if hasattr(sys, "gettotalrefcount"):
        raise PythonBridgeError("VHDL Python support does not provide bridge DLLs for debug builds of CPython")

    name = windows_dll_name()
    source = BINARY_PATH / name
    if not source.is_file():
        raise PythonBridgeError(
            f"No prebuilt Python bridge DLL for Python {sys.version_info[0]}.{sys.version_info[1]} "
            f"({source!s} is missing). Released VUnit packages include the DLLs for the supported Python "
            "versions. A development checkout can build them with tools/build_python_bridge.py (requires MSVC)."
        )
    data = source.read_bytes()
    directory = root / f"cp{sys.version_info[0]}{sys.version_info[1]}-win_amd64-{hashlib.sha256(data).hexdigest()[:12]}"
    target = directory / "vunit_python_bridge.dll"
    if not (target.is_file() and target.read_bytes() == data):
        directory.mkdir(parents=True, exist_ok=True)
        tmp = target.with_name(target.name + f".{os.getpid()}.tmp")
        tmp.write_bytes(data)
        os.replace(tmp, target)
    return target


def _python_library() -> Path:
    """
    The shared libpython of the running interpreter.

    Regular --enable-shared builds name it in LDLIBRARY (libpython3.X.so, .dylib); macOS
    framework builds name the framework binary instead (Python.framework/Versions/3.X/Python).
    """
    ldlibrary = sysconfig.get_config_var("LDLIBRARY") or ""
    framework = sysconfig.get_config_var("PYTHONFRAMEWORK") or ""
    version = f"{sys.version_info[0]}.{sys.version_info[1]}{getattr(sys, 'abiflags', '')}"
    shared = bool(sysconfig.get_config_var("Py_ENABLE_SHARED")) or bool(framework)
    if not shared or not (framework or ldlibrary.endswith((".so", ".dylib")) or ".so." in ldlibrary):
        raise PythonBridgeError(
            f"VHDL Python support requires a CPython built with a shared Python library (--enable-shared). "
            f"{sys.executable} links Python statically "
            f"(LDLIBRARY={ldlibrary!r}, Py_ENABLE_SHARED={sysconfig.get_config_var('Py_ENABLE_SHARED')!r})."
        )
    prefix = Path(sys.base_prefix)
    candidates = [Path(sysconfig.get_config_var("LIBDIR") or "") / ldlibrary]
    # Relocated installations (e.g. uv/python-build-standalone) may report a
    # build-time LIBDIR, fall back to the installation prefix.
    candidates.append(prefix / "lib" / ldlibrary)
    if sys.platform == "darwin":
        candidates.append(prefix / "lib" / f"libpython{version}.dylib")
        if framework:
            # The framework binary: the prefix of a framework build is Versions/3.X
            candidates.append(prefix / framework)
            framework_prefix = sysconfig.get_config_var("PYTHONFRAMEWORKPREFIX") or ""
            candidates.append(Path(framework_prefix) / f"{framework}.framework" / "Versions" / version / framework)
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    raise PythonBridgeError(
        f"Failed to find the shared Python library {ldlibrary} of {sys.executable} "
        f"(searched {', '.join(str(path) for path in candidates)})"
    )


def _include_dirs() -> List[str]:
    """
    Include directories of the Python development headers.
    """
    result = []
    for name in ("include", "platinclude"):
        path = sysconfig.get_paths().get(name)
        if path and path not in result:
            result.append(path)
    for path in result:
        if (Path(path) / "Python.h").is_file():
            return result
    raise PythonBridgeError(
        f"VHDL Python support needs the Python development headers (Python.h) of {sys.executable} "
        f"to build the Python bridge library, but they were not found in {', '.join(result)}. "
        "Install the development package of your Python (e.g. python3-dev)."
    )


def _compiler() -> List[str]:
    """
    The C compiler command: CC, the compiler Python was built with, or cc/gcc/clang.
    """
    if os.environ.get("CC"):
        return shlex.split(os.environ["CC"])
    configured = shlex.split(sysconfig.get_config_var("CC") or "")
    if configured and shutil.which(configured[0]):
        return configured[:1]
    for name in ("cc", "gcc", "clang"):
        if shutil.which(name):
            return [name]
    raise PythonBridgeError(
        "VHDL Python support needs a C compiler (cc, gcc or clang) to build the Python bridge library. "
        "Install one or set the CC environment variable."
    )


def bridge_sources(native_path: Optional[Path] = None, fli: bool = False) -> List[Path]:
    """
    The C source files of the bridge library. fli adds the FLI front end.
    """
    path = NATIVE_PATH if native_path is None else native_path
    sources = sorted(item for item in path.glob("*.c") if item.name != FLI_SOURCE_NAME)
    if fli:
        sources.append(path / FLI_SOURCE_NAME)
    return sources


def _fli_include_dir(simulator_prefix: Path) -> str:
    """
    Directory of mti.h, next to the executable directory of the simulator.
    """
    include = Path(simulator_prefix).resolve().parent / "include"
    if not (include / "mti.h").is_file():
        raise PythonBridgeError(
            f"VHDL Python support needs the FLI header mti.h of the simulator to build the Python "
            f"bridge library, but it was not found in {include!s}"
        )
    return str(include)


def _source_fingerprint() -> str:
    """
    Hash of all bridge sources and headers.
    """
    digest = hashlib.sha256()
    for path in sorted(NATIVE_PATH.glob("*.[ch]")):
        digest.update(path.name.encode("utf-8") + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()


def _posix_cache_directory(root: Path, python_library: Path, include_dirs: List[str]) -> Path:
    """
    Cache directory of a build: everything it depends on hashed into its name. The
    include directories cover the FLI variant, whose simulator headers are among them.
    """
    key_items = [
        _source_fingerprint(),
        sys.platform,
        platform.machine(),
        " ".join(platform.libc_ver()),
        sys.version,
        str(sysconfig.get_config_var("SOABI")),
        str(sysconfig.get_config_var("Py_GIL_DISABLED")),
        str(python_library),
        " ".join(include_dirs),
    ]
    key = hashlib.sha256("\n".join(key_items).encode("utf-8")).hexdigest()[:16]
    tag = sysconfig.get_config_var("SOABI") or f"cp{sys.version_info[0]}{sys.version_info[1]}"
    return root / f"{tag}-{key}"


def _prepare_posix_library(root: Path, simulator_prefix: Optional[Path] = None) -> Path:
    """
    Compile the bridge for the running Python, reusing a cached build when possible.

    The FLI variant, selected with simulator_prefix, differs only in the added front end,
    the added include directory and the file name, so both variants share this cache: the
    simulator prefix is part of the key through its include directory.
    """
    fli = simulator_prefix is not None
    python_library = _python_library()
    include_dirs = _include_dirs()
    if simulator_prefix is not None:
        include_dirs = include_dirs + [_fli_include_dir(simulator_prefix)]

    name = library_file_name(fli)
    directory = _posix_cache_directory(root, python_library, include_dirs)
    library_file = directory / name
    if library_file.is_file():
        return library_file

    compiler = _compiler()
    directory.mkdir(parents=True, exist_ok=True)
    tmp = directory / f"{name}.{os.getpid()}.tmp"
    cmd = (
        compiler
        + ["-shared", "-fPIC", "-O2", "-fvisibility=hidden"]
        + [f"-I{path}" for path in include_dirs]
        + [str(path) for path in bridge_sources(fli=fli)]
        + ["-o", str(tmp)]
        + [str(python_library), f"-Wl,-rpath,{python_library.parent!s}"]
        + ([f"-Wl,-install_name,@rpath/{name}"] if sys.platform == "darwin" else [f"-Wl,-soname,{name}"])
        + (["-ldl"] if sys.platform.startswith("linux") else [])
    )
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    except OSError as exc:
        raise PythonBridgeError(f"Failed to run the C compiler {compiler[0]!r}: {exc}") from exc
    if proc.returncode != 0:
        tmp.unlink(missing_ok=True)
        raise PythonBridgeError(
            "Failed to build the Python bridge library:\n"
            + " ".join(shlex.quote(item) for item in cmd)
            + "\n"
            + proc.stdout.decode(errors="replace")
        )
    os.replace(tmp, library_file)
    return library_file


def _questa_mingw_gcc(simulator_prefix: Path) -> str:
    """
    The MinGW gcc bundled with Questa/ModelSim, used for FLI applications on Windows.
    """
    matches = sorted(simulator_prefix.parent.glob("gcc*mingw64*"))
    for match in matches:
        gcc = match / "bin" / "gcc.exe"
        if gcc.is_file():
            return str(gcc.resolve())
    raise PythonBridgeError(
        "VHDL Python support on Windows needs the MinGW GCC bundled with Questa/ModelSim to build "
        f"the Python bridge library, but it was not found in {simulator_prefix.parent!s}"
    )


def _build_windows_fli_library(root: Path, simulator_prefix: Path) -> Path:
    """
    Build the FLI variant on Windows with the MinGW gcc bundled with Questa/ModelSim, against the
    headers and the import library of the Python running VUnit. The prebuilt DLLs cannot be used:
    they are MSVC builds without the FLI front end, which has to be linked against the simulator's
    own libmtipli. Reuses a cached build like the POSIX one.

    Untested: this environment has no Windows installation of Questa.
    """
    simulator_prefix = Path(simulator_prefix).resolve()
    include = _fli_include_dir(simulator_prefix)
    gcc = _questa_mingw_gcc(simulator_prefix)
    python_home = Path(sys.executable).parent.resolve()
    python_include = python_home / "include"
    python_libs = python_home / "libs"
    if not (python_include / "Python.h").is_file():
        raise PythonBridgeError(
            f"VHDL Python support needs the Python development headers (Python.h) of {sys.executable} "
            f"to build the Python bridge library, but they were not found in {python_include!s}"
        )

    key_items = [_source_fingerprint(), sys.version, str(python_home), str(simulator_prefix), gcc]
    key = hashlib.sha256("\n".join(key_items).encode("utf-8")).hexdigest()[:16]
    directory = root / f"cp{sys.version_info[0]}{sys.version_info[1]}-win_amd64-fli-{key}"
    library_file = directory / "vunit_python_bridge_fli.dll"
    if library_file.is_file():
        return library_file

    directory.mkdir(parents=True, exist_ok=True)
    tmp = directory / f"vunit_python_bridge_fli.dll.{os.getpid()}.tmp"
    cmd = (
        [gcc, "-shared", "-m64", "-O2", "-D__USE_MINGW_ANSI_STDIO=1", "-freg-struct-return"]
        + [f"-I{include}", f"-I{python_include!s}"]
        + [str(path) for path in bridge_sources(fli=True)]
        + ["-o", str(tmp)]
        + [f"-L{python_libs!s}", f"-lpython{sys.version_info[0]}{sys.version_info[1]}"]
        + [f"-L{simulator_prefix!s}", "-lmtipli"]
    )
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    except OSError as exc:
        raise PythonBridgeError(f"Failed to run the C compiler {gcc!r}: {exc}") from exc
    if proc.returncode != 0:
        tmp.unlink(missing_ok=True)
        raise PythonBridgeError(
            "Failed to build the Python bridge library:\n"
            + " ".join(shlex.quote(item) for item in cmd)
            + "\n"
            + proc.stdout.decode(errors="replace")
        )
    os.replace(tmp, library_file)
    return library_file
