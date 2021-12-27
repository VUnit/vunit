-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

use std.textio.all;

entity tb_reading_runner_cfg_from_file is
  generic(runner_cfg : string);
end entity;

architecture tb of tb_reading_runner_cfg_from_file is
begin
  test_runner : process
  begin
    test_runner_setup(runner, null_runner_cfg);

    check_true(active_python_runner(null_runner_cfg));
    check(output_path(null_runner_cfg) /= "");
    check(enabled_test_cases(null_runner_cfg) /= "__all__");
    check(tb_path(null_runner_cfg) /= "");

    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
