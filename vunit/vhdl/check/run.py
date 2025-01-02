# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from glob import glob
from vunit import VUnit, ROOT
from vunit.check_preprocessor import CheckPreprocessor

import vunit.vhdl.check.tools.generate_check_equal as generate_check_equal
import vunit.vhdl.check.tools.generate_check_match as generate_check_match
import vunit.vhdl.check.tools.generate_check_equal_2008p as generate_check_equal_2008p

generate_check_equal.main()
generate_check_match.main()
generate_check_equal_2008p.main()

VU = VUnit.from_argv()
VU.add_vhdl_builtins()

LIB = VU.add_library("lib")
LIB.add_source_files(Path(ROOT) / "vunit" / "vhdl" / "check" / "test" / "test_support.vhd")
VU.add_library("logging_tb_lib").add_source_files(
    Path(ROOT) / "vunit" / "vhdl" / "logging" / "test" / "test_support_pkg.vhd"
)

for file_name in glob(str(Path(ROOT) / "vunit" / "vhdl" / "check" / "test" / "tb_*.vhd")):
    if VU.vhdl_standard not in ["2008", "2019"] and file_name.endswith("2008p.vhd"):
        continue

    if Path(file_name).name.startswith("tb_check_relation"):
        LIB.add_source_files(file_name, preprocessors=[CheckPreprocessor()])
    else:
        LIB.add_source_files(file_name)

TB_CHECK = LIB.entity("tb_check")
TB_CHECK.add_config(generics=dict(use_check_not_check_true=True), name="using check")
TB_CHECK.add_config(generics=dict(use_check_not_check_true=False), name="using check_true")

VU.main()
