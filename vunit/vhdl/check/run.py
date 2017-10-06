# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname, basename
from vunit import VUnit
from vunit.check_preprocessor import CheckPreprocessor
from glob import glob

import sys
sys.path.append(join(dirname(__file__), "tools"))

import generate_check_equal
import generate_check_match

generate_check_equal.main()
generate_check_match.main()


vhdl_path = join(dirname(__file__), "test")
ui = VUnit.from_argv()

lib = ui.add_library('lib')
lib.add_source_files(join(vhdl_path, "test_support.vhd"))

for file_name in glob(join(vhdl_path, "tb_*.vhd")):
    if ui.vhdl_standard != '2008' and file_name.endswith("2008.vhd"):
        continue

    if basename(file_name).startswith("tb_check_relation"):
        lib.add_source_files(file_name, preprocessors=[CheckPreprocessor()])
    else:
        lib.add_source_files(file_name)

tb_check = lib.entity("tb_check")
tb_check.add_config(generics=dict(use_check_not_check_true=True), name="using check")
tb_check.add_config(generics=dict(use_check_not_check_true=False), name="using check_true")

ui.main()
