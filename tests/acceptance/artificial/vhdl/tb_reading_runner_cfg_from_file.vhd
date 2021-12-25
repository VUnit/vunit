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
    file runner_cfg_fptr : text;
    variable runner_cfg_line : line;
  begin
    file_open(runner_cfg_fptr, "runner.cfg", write_mode);
    write(
      runner_cfg_line,
      string'("active python runner : true,enabled_test_cases : ,output path : " &
      replace(output_path(runner_cfg), ":", "::") & ",tb path : " &
      replace(tb_path(runner_cfg), ":", "::") & ",use_color : true")
    );
    writeline(runner_cfg_fptr, runner_cfg_line);
    file_close(runner_cfg_fptr);

    test_runner_setup(runner, null_runner_cfg);
    check_true(active_python_runner(null_runner_cfg));
    check(output_path(null_runner_cfg) /= "");
    check(enabled_test_cases(null_runner_cfg) /= "__all__");
    check(tb_path(null_runner_cfg) /= "");

    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
