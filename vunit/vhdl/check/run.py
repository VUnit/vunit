# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname, basename
from vunit import VUnit
from vunit.check_preprocessor import CheckPreprocessor
from glob import glob

vhdl_path = join(dirname(__file__), "test")
ui = VUnit.from_argv(compile_builtins=False)
ui.add_builtins('vunit_lib', mock_log=True)
lib = ui.add_library('lib')
lib.add_source_files(join(vhdl_path, "test_support.vhd"))

if ui.vhdl_standard in ('2002', '2008'):
    lib.add_source_files(join(vhdl_path, "test_count.vhd"))
    lib.add_source_files(join(vhdl_path, "test_types.vhd"))
elif ui.vhdl_standard == '93':
    lib.add_source_files(join(vhdl_path, "test_count93.vhd"))

if ui.vhdl_standard == '2008':
    lib.add_source_files(join(vhdl_path, "tb_check_relation.vhd"), [CheckPreprocessor()])
else:
    lib.add_source_files(join(vhdl_path, "tb_check_relation93_2002.vhd"), [CheckPreprocessor()])

for file_name in glob(join(vhdl_path, "tb_*.vhd")):
    if basename(file_name).startswith("tb_check_relation"):
        continue
    lib.add_source_files(file_name)

ui.main()
