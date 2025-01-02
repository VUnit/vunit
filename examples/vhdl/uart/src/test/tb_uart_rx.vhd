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
context vunit_lib.vc_context;

library uart_lib;

entity tb_uart_rx is
  generic (
    runner_cfg : string);
end entity;

architecture tb of tb_uart_rx is
  constant baud_rate : integer := 115200; -- bits / s
  constant clk_period : integer := 20; -- ns
  constant cycles_per_bit : integer := 50 * 10**6 / baud_rate;

  signal clk : std_logic := '0';
  signal rx : std_logic := '1';
  signal overflow : std_logic;
  signal tready : std_logic;
  signal tvalid : std_Logic;
  signal tdata : std_logic_vector(7 downto 0);

  signal num_overflows : integer := 0;

  constant uart_bfm : uart_master_t := new_uart_master(initial_baud_rate => baud_rate);
  constant uart_stream : stream_master_t := as_stream(uart_bfm);

  constant axi_stream_bfm : axi_stream_slave_t := new_axi_stream_slave(data_length => tdata'length);
  constant axi_stream : stream_slave_t := as_stream(axi_stream_bfm);
begin

  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      reset_checker_stat;
      if run("test_tvalid_low_at_start") then
        wait until tvalid = '1' for 1 ms;
        check_equal(tvalid, '0');

      elsif run("test_receives_one_byte") then
        push_stream(net, uart_stream, x"77");
        check_stream(net, axi_stream, x"77",true);
        wait until rising_edge(clk);
        check_equal(tvalid, '0');
        check_equal(num_overflows, 0);

      elsif run("test_two_bytes_casues_overflow") then
        push_stream(net, uart_stream, x"77");
        wait until tvalid = '1' and rising_edge(clk);
        check_equal(num_overflows, 0);
        wait for 1 ms;
        push_stream(net, uart_stream, x"77");
        wait for 1 ms;
        wait until num_overflows = 1 and rising_edge(clk);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 10 ms);

  overflow_counter : process (clk)
  begin
    if rising_edge(clk) then
      if overflow = '1' then
        warning("Overflow");
        num_overflows <= num_overflows + 1;
      end if;
    end if;
  end process;

  clk <= not clk after (clk_period/2) * 1 ns;

  dut : entity uart_lib.uart_rx
    generic map (
      cycles_per_bit => cycles_per_bit)
    port map (
      clk => clk,
      rx => rx,
      overflow => overflow,
      tready => tready,
      tvalid => tvalid,
      tdata => tdata);

  uart_master_bfm : entity vunit_lib.uart_master
    generic map (
      uart => uart_bfm)
    port map (
      tx => rx);

  axi_stream_slave_bfm: entity vunit_lib.axi_stream_slave
    generic map (
      slave => axi_stream_bfm)
    port map (
      aclk   => clk,
      tvalid => tvalid,
      tready => tready,
      tdata  => tdata);

end architecture;
