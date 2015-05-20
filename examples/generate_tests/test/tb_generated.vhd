-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_generated is
  generic (
    runner_cfg : runner_cfg_t := runner_cfg_default;
    output_path : string;
    data_width : natural;
    sign : boolean;
    message : string);
end entity;

architecture a of tb_generated is
begin
  main : process
   file fwrite : text;
   variable l : line;
  begin
    test_runner_setup(runner, runner_cfg);
    file_open(fwrite, output_path & "/" & "generics.txt", write_mode);
    write(l, message & ", " & to_string(data_width) & ", " & to_string(sign));
    writeline(fwrite, l);
    file_close(fwrite);
    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 10 ms);
end architecture;
