-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_with_watchdog is
  generic(runner_cfg : string);
end entity;

-- start_snippet tb_with_watchdog
architecture tb of tb_with_watchdog is
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that stalls") then
        wait;
      elsif run("Test to_string for boolean") then
        check_equal(to_string(true), "true");
      elsif run("Test that needs longer timeout") then
        -- It is also possible to set/re-set the timeout
        -- When test cases need separate timeout settings
        set_timeout(runner, 2 ms);
        wait for 1 ms;
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 10 ms);
end architecture;
-- end_snippet tb_with_watchdog
