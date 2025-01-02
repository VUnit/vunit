-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;

architecture test_state_change_architecture of test_runner is
begin
  main : process
  begin
    test_runner_setup(runner, nested_runner_cfg);

    reset <= '0';

    d <= (others => '1');
    wait until rising_edge(clk);
    wait for 0 ns;
    check_equal(q, std_logic_vector'(q'range => '1'));

    d <= (others => '0');
    wait until rising_edge(clk);
    wait for 0 ns;
    check_equal(q, 0);

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 10 * clk_period);
end;

configuration test_state_change_behavioral of tb_selecting_test_runner_with_vhdl_configuration is
  for tb
    for test_runner_inst : test_runner
      use entity work.test_runner(test_state_change_architecture);
    end for;

    for test_fixture
      for dut : dff
        use entity work.dff(behavioral);
      end for;
    end for;
  end for;
end;

configuration test_state_change_rtl of tb_selecting_test_runner_with_vhdl_configuration is
  for tb
    for test_runner_inst : test_runner
      use entity work.test_runner(test_state_change_architecture);
    end for;

    for test_fixture
      for dut : dff
        use entity work.dff(rtl);
      end for;
    end for;
  end for;
end;
