# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from vunit import VUnit

root = Path(__file__).parent

ui = VUnit.from_argv()

lib = ui.add_library("tb_run_lib")
lib.add_source_files(root / "test" / "tb_run.vhd")
lib.add_source_files(root / "test" / "run_tests.vhd")
lib.add_source_files(root / "test" / "tb_watchdog.vhd")
ui.enable_location_preprocessing()
lib.add_source_files(root / "test" / "tb_wait_pkg.vhd")

tb_wait_pkg = lib.test_bench("tb_wait_pkg")
for use_boolean_test_signal in [False, True]:
    for test in tb_wait_pkg.get_tests():
        if test.name not in ["Test wait_for", "Test wait_until"] and "wait_" in test.name:
            test.add_config(
                name="with boolean signal" if use_boolean_test_signal else "with other signal",
                generics=dict(use_boolean_test_signal=use_boolean_test_signal),
            )

ui.main()
