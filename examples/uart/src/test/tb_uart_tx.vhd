-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

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

  signal received_bytes : integer_vector(0 to 127);
begin

  main : process
    variable index : integer := 0;
    procedure send(value : integer) is
    begin
      tvalid <= '1';
      tdata <= std_logic_vector(to_unsigned(value, tdata'length));
      wait until tvalid = '1' and tready = '1' and rising_edge(clk);
      tvalid <= '0';
      tdata <= (others => '0');
    end procedure;

    procedure check_received_bytes(bytes : integer_vector;
                                   line_num : natural := 0;
                                   file_name : string := "") is 
    begin
      for i in 0 to bytes'length-1 loop
        if received_bytes(index) = integer'left then
          wait on received_bytes until received_bytes(index) /= integer'left;
        end if;
        check_equal(received_bytes(index), bytes(i),
              file_name => file_name,
              line_num => line_num);
        index := index + 1;
      end loop;
      wait on received_bytes for 1 ms;
      check_equal(received_bytes(index), integer'left, "Number of sent and received bytes doesn't match",
            file_name => file_name,
            line_num => line_num);
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

    while test_suite loop
      if run("test_send_one_byte") then
        send(77);
        check_received_bytes((0 => 77))   ;
      elsif run("test_send_two_bytes") then
        send(11);
        send(1);
        check_received_bytes((11,1));
      elsif run("test_send_many_bytes") then
        send(16#a5#);
        send(16#5a#);
        send(16#ff#);
        check_received_bytes((16#a5#, 16#5a#, 16#ff#));
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
    variable index : integer := 0;
  begin
    uart_recv(data, tx, baud_rate);
    received_bytes(index) <= data;
    debug("Received " & to_string(data));
    index := index + 1;
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
