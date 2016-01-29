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
use vunit_lib.textio.all;
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

library uart_lib;

library tb_uart_lib;
use tb_uart_lib.uart_model_pkg.all;

entity tb_uart_rx is
  generic (
    runner_cfg : runner_cfg_t := runner_cfg_default);
end entity;

architecture tb of tb_uart_rx is
  constant baud_rate : integer := 115200; -- bits / s
  constant clk_period : integer := 20; -- ns
  constant cycles_per_bit : integer := 50 * 10**6 / baud_rate;

  signal clk : std_logic := '0';
  signal rx : std_logic := '1';
  signal overflow : std_logic;
  signal tready : std_logic := '0';
  signal tvalid : std_Logic;
  signal tdata : std_logic_vector(7 downto 0);

  signal num_overflows : integer := 0;
begin

  main : process
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

    while test_suite loop
      reset_checker_stat;
      if run("test_tvalid_low_at_start") then
        wait until tvalid = '1' for 1 ms;
        check_equal(tvalid, '0');
      elsif run("test_receives_one_byte") then
        uart_send(77, rx, baud_rate);
        tready <= '1';
        wait until tready = '1' and tvalid = '1' and rising_edge(clk);
        check_equal(unsigned(tdata), 77);
        tready <= '0';
        check_false(clk, check_enabled, tvalid);
        check_equal(num_overflows, 0);
      elsif run("test_two_bytes_casues_overflow") then
        uart_send(77, rx, baud_rate);
        wait until tvalid = '1' and rising_edge(clk);
        check_equal(num_overflows, 0);
        wait for 1 ms;
        uart_send(77, rx, baud_rate);
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

end architecture;
