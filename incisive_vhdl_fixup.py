# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

"""
Perform necessary modifications to VUnit VHDL code to support
Cadence Incisive
"""

from __future__ import print_function

import sys
import os
import re

def fix_file(file_name):
    replace_context_with_use_clauses(file_name)
    tee_to_double_writeline(file_name)

def tee_to_double_writeline(file_name):
    with open(file_name, "r") as fptr:
        text = fptr.read()

    text = re.sub(r"^(\s *)TEE\((.*?),(.*?)\)\s *;",
           """\
-- \\g<0> -- Not supported by Cadence Incisive
\\1WriteLine(OUTPUT, \\3);
\\1WriteLine(\\2, \\3);""", text, flags=re.MULTILINE)

    with open(file_name, "w") as fptr:
        fptr.write(text)

def replace_context_with_use_clauses(file_name):
    with open(file_name, "r") as fptr:
        text = fptr.read()

    text = text.replace("context vunit_lib.vunit_context;",
"""\
-- context vunit_lib.vunit_context; -- Not supported by Cadence Incisive
use vunit_lib.lang.all;
use vunit_lib.string_ops.all;
use vunit_lib.dictionary.all;
use vunit_lib.path.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;"""
)

    text = text.replace("context vunit_lib.com_context;",
"""\
-- context vunit_lib.com_context; -- Not supported by Cadence Incisive
use vunit_lib.com_pkg.all;
use vunit_lib.com_types_pkg.all;
use vunit_lib.com_codec_pkg.all;
use vunit_lib.com_string_pkg.all;
use vunit_lib.com_debug_codec_builder_pkg.all;
use vunit_lib.com_std_codec_builder_pkg.all;
""")

    with open(file_name, "w") as fptr:
        fptr.write(text)

root = os.path.abspath(os.path.dirname(__file__))
for base, _, files in os.walk(root):
    for file_name in files:
        if file_name.endswith(".vhd"):
            fix_file(os.path.join(base, file_name))
