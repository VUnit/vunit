# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit
from vunit.python_fli_compile import compile_vhpi_application, compile_fli_application

def remote_test():
  return 2


def main():
  root = Path(__file__).parent

  vu = VUnit.from_argv()
  vu.add_vhdl_builtins()
  vu.add_python()
  simulator_name = vu.get_simulator_name()
     
  if simulator_name in ["rivierapro", "activehdl"]:
      # TODO: Include VHPI application compilation in VUnit
      # NOTE: A clean build will delete the output after it was created so another no clean build has to be performed.
      compile_vhpi_application(root, simulator_name)
  elif simulator_name == "modelsim":
      compile_fli_application(root, vu)

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
