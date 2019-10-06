-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity top_tb is
  generic (
    RUNNER_CFG	: string);
end entity;

architecture arch of top_tb is
  signal clk : std_logic := '0';

  constant BITS : natural := 8;
  signal in_a, in_b, add_out : unsigned(BITS - 1 downto 0);

begin
  clk <= not clk after 1 ns;


  main: process
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("test") then
        in_a <= to_unsigned(10, in_a);
        in_b <= to_unsigned(15, in_b);
        wait for 3 ns;
        check(add_out = in_a + in_b, "Addition failed");
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;

  top_module: entity work.top
  generic map(
    BITS => BITS
  )
  port map(
    clk => clk,
    op_a => in_a,
    op_b => in_b,
    sum => add_out
  );
  
end architecture;
