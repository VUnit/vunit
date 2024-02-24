# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

from os import getenv
import glob
from pathlib import Path
from vunit import VUnit, location_preprocessor


def main():
    vhdl_2019 = getenv("VUNIT_VHDL_STANDARD") == "2019"
    root = Path(__file__).parent

    ui = VUnit.from_argv()
    ui.add_vhdl_builtins()

    vunit_lib = ui.library("vunit_lib")
    files = glob.glob(str(root / "test" / "*.vhd"))
    files.remove(str(root / "test" / "tb_location.vhd"))
    vunit_lib.add_source_files(files)

    preprocessor = location_preprocessor.LocationPreprocessor()
    preprocessor.add_subprogram("print_pre_vhdl_2019_style")
    preprocessor.remove_subprogram("info")
    vunit_lib.add_source_files(root / "test" / "tb_location.vhd", preprocessors=[preprocessor])

    if vhdl_2019:
        testbenches = vunit_lib.get_source_files("*tb*")
        testbenches.set_compile_option("rivierapro.vcom_flags", ["-dbg"])
        ui.set_sim_option("rivierapro.vsim_flags", ["-filter RUNTIME_0375"])

    vunit_lib.test_bench("tb_location").set_generic("vhdl_2019", vhdl_2019)

    ui.main()


if __name__ == "__main__":
    main()
