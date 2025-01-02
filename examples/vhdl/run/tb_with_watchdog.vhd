-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_with_watchdog is
  generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_with_watchdog is
  signal foo : boolean_vector(1 to 12);
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

      elsif run("Test that stalling processes can inform why they caused a timeout") then
        wait until (and foo);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 1 ns);

  generate_processes : for i in foo'range generate
    some_process : process
      constant logger : logger_t := get_logger(some_process'path_name);
    begin
      -- Instead of just waiting for foo also act on a timeout notification
      wait until foo(i) or timeout_notification(runner);

      -- Inform that you were still waiting for something to happen when the timeout
      -- occured. This will help identifying who to blame for the timeout
      if timeout_notification(runner) then
        warning(logger, "Still waiting for foo(" & to_string(i) & ")");
        wait;
      end if;

      info(logger, "Got foo(" & to_string(i) & "). Doing something useful...");
      wait;
    end process;
  end generate;

  foo_controller : process
  begin
    for i in foo'range loop
      wait for 100 ps;
      foo(i) <= true;
    end loop;
    wait;
  end process;
end architecture;
