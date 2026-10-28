-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_yavs is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_yavs is
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("test_pass") then
        check_true(true);
      elsif run("test with, comma: and colon") then
        check_true(true);
      elsif run("test_fail") then
        check_true(false);
      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;
end architecture;
