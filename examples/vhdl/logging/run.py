# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

ui = VUnit.from_argv()
lib = ui.add_library("lib")
lib.add_source_files(join(dirname(__file__), "*.vhd"))

def print_log(output_path):
    log_file_path = join(output_path, "log.csv")
    with open(log_file_path) as fptr:
        log = fptr.read()

    print("")
    msg = "= Contents of log file: %s" % log_file_path
    length = len(msg) + 1
    print("=" * length)
    print(msg)
    print("=" * length)
    print(log)
    print("=" * length)

    return True

lib.test_bench("tb_logging_example").set_post_check(print_log)

ui.main()
