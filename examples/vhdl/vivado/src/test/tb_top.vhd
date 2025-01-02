-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lib;

entity tb_top is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_top is
  signal clk       : std_logic := '0';
  signal rstn      : std_logic := '0';
  signal in_valid  : std_logic := '0';
  signal in_ready  : std_logic;
  signal in_data   : std_logic_vector(7 downto 0) := (others => '0');
  signal out_valid : std_logic;
  signal out_ready : std_logic := '0';
  signal out_data  : std_logic_vector(7 downto 0);

  constant num_data : integer := 128;
  signal start, done : boolean := false;
begin
  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rstn <= '1';
    wait until rising_edge(clk);

    start <= true;
    wait until done;
    test_runner_cleanup(runner);
  end process;

  stimuli : process
  begin
    wait until start and rising_edge(clk);
    for i in 1 to num_data loop
      info("input " & integer'image(i) & " of " & integer'image(num_data));
      in_valid <= '1';
      in_data <= std_logic_vector(to_unsigned(i, in_data'length));
      wait until (in_ready and in_valid) = '1' and rising_edge(clk);
      in_valid <= '0';
    end loop;
    wait;
  end process;

  data_check : process
  begin
    wait until start and rising_edge(clk);
    for i in 1 to num_data loop
      info("output " & integer'image(i) & " of " & integer'image(num_data));
      out_ready <= '1';
      wait until (out_valid and out_ready) = '1' and rising_edge(clk);
      out_ready <= '0';
      check_equal(unsigned(out_data), i);
    end loop;
    done <= true;
    wait;
  end process;

  clk <= not clk after 1 ns;
  dut : entity lib.top
    port map (
      clk       => clk,
      rstn      => rstn,
      in_valid  => in_valid,
      in_ready  => in_ready,
      in_data   => in_data,
      out_valid => out_valid,
      out_ready => out_ready,
      out_data  => out_data);

  test_runner_watchdog(runner, 1 ms);
end architecture;
