# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

"""
Perform necessary modifications to VUnit VHDL code to support
Cadence Incisive
"""

import os
import re
from pathlib import Path


def fix_file(file_name):
    replace_context_with_use_clauses(file_name)
    tee_to_double_writeline(file_name)


def tee_to_double_writeline(file_name):
    """
    Convert TEE calls to double writeline calls
    """

    with Path(file_name).open("r", encoding="iso-8859-1") as fptr:
        text = fptr.read()

    text = re.sub(
        r"^(\s *)TEE\((.*?),(.*?)\)\s *;",
        """\
-- \\g<0> -- Not supported by Cadence Incisive
\\1WriteLine(OUTPUT, \\3);
\\1WriteLine(\\2, \\3);""",
        text,
        flags=re.MULTILINE,
    )

    with Path(file_name).open("w", encoding="iso-8859-1") as fptr:
        fptr.write(text)


def replace_context_with_use_clauses(file_name):
    """
    Replace VUnit contexts with use clauses
    """

    with Path(file_name).open("r", encoding="iso-8859-1") as fptr:
        text = fptr.read()

    text = text.replace(
        "context vunit_lib.vunit_context;",
        """\
-- context vunit_lib.vunit_context; -- Not supported by Cadence Incisive

use vunit_lib.integer_vector_ptr_pkg.all;
use vunit_lib.integer_vector_ptr_pool_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.string_ptr_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.queue_pool_pkg.all;
use vunit_lib.string_ptr_pkg.all;
use vunit_lib.string_ptr_pool_pkg.all;
use vunit_lib.dict_pkg.all;

use vunit_lib.string_ops.all;
use vunit_lib.dictionary.all;
use vunit_lib.path.all;
use vunit_lib.print_pkg.all;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.log_handler_pkg.all;
use vunit_lib.log_deprecated_pkg.all;
use vunit_lib.ansi_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.check_deprecated_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.run_deprecated_pkg.all;""",
    )

    text = text.replace(
        "context vunit_lib.com_context;",
        """\
-- context vunit_lib.com_context; -- Not supported by Cadence Incisive
use vunit_lib.com_pkg.all;
use vunit_lib.com_types_pkg.all;
use vunit_lib.codec_pkg.all;
use vunit_lib.codec_2008_pkg.all;
use vunit_lib.com_string_pkg.all;
use vunit_lib.codec_builder_pkg.all;
use vunit_lib.codec_builder_2008_pkg.all;
use vunit_lib.com_debug_codec_builder_pkg.all;
use vunit_lib.com_deprecated_pkg.all;
use vunit_lib.com_common_pkg.all;
""",
    )

    with Path(file_name).open("w", encoding="iso-8859-1") as fptr:
        fptr.write(text)


def main():
    """
    Remove incisive incompatabilities from source code
    """
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    for base, _, files in os.walk(root):
        for file_name in files:
            if file_name.endswith(".vhd"):
                fix_file(os.path.join(base, file_name))


if __name__ == "__main__":
    main()
