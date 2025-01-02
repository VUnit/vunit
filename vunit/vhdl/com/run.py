# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit

ROOT = Path(__file__).parent

UI = VUnit.from_argv()
UI.add_vhdl_builtins()
UI.add_com()

TB_COM_LIB = UI.add_library("tb_com_lib")
TB_COM_LIB.add_source_files(ROOT / "test" / "*.vhd")
TB_COM_LIB.package("custom_types_pkg").generate_codecs(
    codec_package_name="custom_codec_pkg",
    used_packages=[
        "ieee.std_logic_1164",
        "constants_pkg",
        "tb_com_lib.more_constants_pkg",
    ],
)

UI.main()
