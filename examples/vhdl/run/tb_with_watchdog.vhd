-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_with_watchdog is
  generic(runner_cfg : string := runner_cfg_default);
end entity;

architecture tb of tb_with_watchdog is
  signal done : boolean := false;
  constant a_long_time : time := 2 ns;
begin
  test_runner_watchdog(runner, 1 ns);

  done <= true after a_long_time;

  test_runner : process
    constant logger : logger_t := get_logger(test_runner'path_name);
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that stalls") then
        wait until done;

      elsif run("Test that needs longer timeout") then
        -- It is also possible to set/re-set the timeout
        -- When test cases need separate timeout settings
        set_timeout(runner, 2 ms);
        wait for 1 ms;

      elsif run("Test that stalling processes can inform why they caused a timeout") then
        -- Instead of just waiting for done also act on a timeout notification
        wait until done or timeout_notification(runner);

        -- Inform that you were still waiting for something to happen when the timeout
        -- occured. This will help identifying who to blame for the timeout
        if not done then
          info(logger, "Still waiting for done signal");
          wait;
        end if;

      elsif run("Test timing out with a wait procedure") then
        wait_until(done, logger => logger);

      end if;

    end loop;

    test_runner_cleanup(runner);
  end process;

end architecture;
