-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
--
-- Description: This is an example of a testbench using a generic instead
-- of VHDL configurations to select the DUT to run. Without VHDL configurations
-- the width generic to the dff entity can be exposed and modified at the top-level

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;

-- start_snippet selecting_dut_with_generics
entity tb_selecting_dut_with_generics is
  generic(
    runner_cfg : string;
    width : positive;
    dff_arch : string
  );
end entity;

architecture tb of tb_selecting_dut_with_generics is
  -- start_folding ...
  constant clk_period : time := 10 ns;

  signal reset : std_logic;
  signal clk : std_logic := '0';
  signal d : std_logic_vector(width - 1 downto 0);
  signal q : std_logic_vector(width - 1 downto 0);
  -- end_folding ...
begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test reset") then
        -- start_folding ...
        d <= (others => '1');
        reset <= '1';
        wait until rising_edge(clk);
        wait for 0 ns;
        check_equal(q, 0);
        -- end_folding ...
      elsif run("Test state change") then
        -- start_folding ...
        reset <= '0';

        d <= (others => '1');
        wait until rising_edge(clk);
        wait for 0 ns;
        check_equal(q, std_logic_vector'(q'range => '1'));

        d <= (others => '0');
        wait until rising_edge(clk);
        wait for 0 ns;
        check_equal(q, 0);
        -- end_folding ...
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 10 * clk_period);

  test_fixture : block is
  begin
    clk <= not clk after clk_period / 2;

    dut_selection : if dff_arch = "rtl" generate
      dut : entity work.dff(rtl)
        generic map(
          width => width
        )
        port map(
          clk => clk,
          reset => reset,
          d => d,
          q => q
        );

    elsif dff_arch = "behavioral" generate
      dut : entity work.dff(behavioral)
        generic map(
          width => width
        )
        port map(
          clk => clk,
          reset => reset,
          d => d,
          q => q
        );

    else generate
      error("Unknown DFF architecture");
    end generate;
  end block;
end architecture;
-- end_snippet selecting_dut_with_generics
