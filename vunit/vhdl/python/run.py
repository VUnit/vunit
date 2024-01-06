# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
import subprocess
import sys
from multiprocessing import Manager, Process, get_context, Queue
from vunit import VUnit


def ccomp(simulator_name):
  root = Path(__file__).parent
  path_to_shared_lib = root / "vunit_out" / simulator_name / "libraries" / "python"
  if not path_to_shared_lib.exists():
      path_to_shared_lib.mkdir(parents=True, exist_ok=True)
  path_to_python_include = Path(sys.executable).parent / "include"
  path_to_python_libs = Path(sys.executable).parent / "libs"
  python_shared_lib = f"python{sys.version_info[0]}{sys.version_info[1]}"
  path_to_cpp_file = root / ".." / ".." / ".." / "vunit" / "vhdl" / "python" / "src" / "python.cpp"

  proc = subprocess.run(
    [
      "ccomp",
      "-vhpi",
      "-dbg",
      "-verbose",
      "-o",
      '"' + str(path_to_shared_lib) + '"',
      "-l",
      python_shared_lib,
      "-l",
      "_tkinter",
      "-I",
      '"' + str(path_to_python_include) + '"',
      "-L",
      '"' + str(path_to_python_libs) + '"',
      '"' + str(path_to_cpp_file) + '"',
    ],
    capture_output=True,
    text=True,
    check=False,
  )

  if proc.returncode != 0:
      print(proc.stdout)
      print(proc.stderr)
      raise RuntimeError("Failed to compile VHPI application")


def remote_test():
  return 2


def main():
  root = Path(__file__).parent

  vu = VUnit.from_argv()
  vu.add_vhdl_builtins()
  vu.add_python()

  # TODO: Include VHPI application compilation in VUnit
  # NOTE: A clean build will delete the output after it was created so another no clean build has to be performed.
  ccomp(vu.get_simulator_name())

  lib = vu.add_library("lib")
  lib.add_source_files(root / "test" / "*.vhd")

  vu.set_compile_option("rivierapro.vcom_flags" , ["-dbg"])
  vu.set_sim_option("rivierapro.vsim_flags" , ["-interceptcoutput"])
  # Crashes RPRO for some reason. TODO: Fix when the C code is properly
  # integrated into the project. Must be able to debug the C code.
  # vu.set_sim_option("rivierapro.vsim_flags" , ["-cdebug"])

  vu.main()


if __name__ == "__main__":
  main()
