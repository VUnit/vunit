-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;

architecture test_reset_a of test_runner is
begin
  main : process
  begin
    test_runner_setup(runner, nested_runner_cfg);

    d <= (others => '1');
    reset <= '1';
    wait until rising_edge(clk);
    wait for 0 ns;
    check_equal(q, 0);

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 10 * clk_period);
end;
