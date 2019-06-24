# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)
ui = VUnit.from_argv()

lib = ui.add_library("tb_run_lib")
lib.add_source_files(join(root, 'test', '*.vhd'))

tb_watchdog = lib.test_bench("tb_watchdog")
for use_boolean_test_signal in [False, True]:
    for test in tb_watchdog.get_tests():
        if test.name not in ["Test wait_for", "Test wait_until"] and "wait_" in test.name:
            test.add_config(name="with boolean signal" if use_boolean_test_signal else "with other signal",
                            generics=dict(use_boolean_test_signal=use_boolean_test_signal))

ui.set_compile_option("rivierapro.vcom_flags", ["-dbg"])
ui.main()
