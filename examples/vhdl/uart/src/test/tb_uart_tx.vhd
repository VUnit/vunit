-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.lang.all;
use vunit_lib.string_ops.all;
use vunit_lib.dictionary.all;
use vunit_lib.path.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

library uart_lib;

library tb_uart_lib;
use tb_uart_lib.uart_model_pkg.all;

entity tb_uart_tx is
  generic (
    runner_cfg : runner_cfg_t := runner_cfg_default);
end entity;

architecture tb of tb_uart_tx is
  constant baud_rate : integer := 115200; -- bits / s
  constant clk_period : integer := 20; -- ns
  constant cycles_per_bit : integer := 50 * 10**6 / baud_rate;

  signal clk : std_logic := '0';
  signal tx : std_logic;
  signal tready : std_logic;
  signal tvalid : std_Logic := '0';
  signal tdata : std_logic_vector(7 downto 0) := (others => '0');

  signal num_sent, num_recv : integer := 0;
  shared variable rnd_stimuli, rnd_expected : RandomPType;
begin

  main : process
    variable index : integer := 0;

    procedure send is
    begin
      tvalid <= '1';
      tdata <= std_logic_vector(to_unsigned(rnd_stimuli.RandInt(0, 2**tdata'length-1), tdata'length));
      wait until tvalid = '1' and tready = '1' and rising_edge(clk);
      num_sent <= num_sent + 1;
      tvalid <= '0';
      tdata <= (others => '0');
    end procedure;

    procedure check_all_was_received is
    begin
      wait until num_recv = num_sent for 1 ms;
      check_equal(num_recv, num_sent);
    end procedure;

    variable stat : checker_stat_t;
    variable filter : log_filter_t;
  begin
    checker_init(display_format => verbose,
                 file_name => join(output_path(runner_cfg), "error.csv"),
                 file_format => verbose_csv);
    logger_init(display_format => verbose,
                 file_name => join(output_path(runner_cfg), "log.csv"),
                file_format => verbose_csv);
    stop_level((debug, verbose), display_handler, filter);
    test_runner_setup(runner, runner_cfg);

    -- Initialize to same seed to get same sequence
    rnd_stimuli.InitSeed(rnd_stimuli'instance_name);
    rnd_expected.InitSeed(rnd_stimuli'instance_name);

    while test_suite loop
      if run("test_send_one_byte") then
        send;
        check_all_was_received;
      elsif run("test_send_two_bytes") then
        send;
        check_all_was_received;
        send;
        check_all_was_received;
      elsif run("test_send_many_bytes") then
        for i in 0 to 7 loop
          send;
        end loop;
        check_all_was_received;
      end if;
    end loop;

    if not active_python_runner(runner_cfg) then
      get_checker_stat(stat);
      info(LF & "Result:" & LF & to_string(stat));
    end if;

    test_runner_cleanup(runner);
    wait;
  end process;
  test_runner_watchdog(runner, 10 ms);

  uart_rx_behav : process
    variable data : integer;
  begin
    uart_recv(data, tx, baud_rate);
    num_recv <= num_recv + 1;
    report "Received " & to_string(data);
    check_equal(data, rnd_expected.RandInt(0, 2**tdata'length-1));
  end process;

  clk <= not clk after (clk_period/2) * 1 ns;

  dut : entity uart_lib.uart_tx
    generic map (
      cycles_per_bit => cycles_per_bit)
    port map (
      clk => clk,
      tx => tx,
      tready => tready,
      tvalid => tvalid,
      tdata => tdata);

end architecture;
