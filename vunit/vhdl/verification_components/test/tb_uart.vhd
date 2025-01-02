-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
context work.data_types_context;
use work.uart_pkg.all;
use work.sync_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;

entity tb_uart is
  generic (runner_cfg : string);
end entity;

architecture a of tb_uart is
  constant master_uart : uart_master_t := new_uart_master;
  constant master_stream : stream_master_t := as_stream(master_uart);

  constant slave_uart : uart_slave_t := new_uart_slave(data_length => 8);
  constant slave_stream : stream_slave_t := as_stream(slave_uart);

  signal chan : std_logic;
begin

  main : process
    variable data : std_logic_vector(7 downto 0);
    variable reference_queue : queue_t := new_queue;
    variable reference : stream_reference_t;

    procedure test_baud_rate(baud_rate : natural) is
      variable start : time;
      variable got, expected : time;
    begin
      set_baud_rate(net, master_uart, baud_rate);
      set_baud_rate(net, slave_uart, baud_rate);

      start := now;
      push_stream(net, master_stream, x"77");
      check_stream(net, slave_stream, x"77");

      wait_until_idle(net, as_sync(master_uart));

      got := now - start;
      expected := (10 * (1 sec)) / (baud_rate);

      check(abs (got - expected) <= 10 ns,
            "Unexpected baud rate got " & to_string(got) & " expected " & to_string(expected));
    end;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test single push and pop") then
      push_stream(net, master_stream, x"77");
      pop_stream(net, slave_stream, data);
      check_equal(data, std_logic_vector'(x"77"), "pop stream data");

    elsif run("test pop before push") then
      for i in 0 to 7 loop
        pop_stream(net, slave_stream, reference);
        push(reference_queue, reference);
      end loop;

      for i in 0 to 7 loop
        push_stream(net, master_stream,
                    std_logic_vector(to_unsigned(i+1, data'length)));
      end loop;

      for i in 0 to 7 loop
        reference := pop(reference_queue);
        await_pop_stream_reply(net, reference, data);
        check_equal(data, to_unsigned(i+1, data'length));
      end loop;

    elsif run("test baud rate") then
      test_baud_rate(2000);
      test_baud_rate(7000);
      test_baud_rate(200000);
    end if;

    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 20 ms);

  uart_master_inst: entity work.uart_master
    generic map (
      uart => master_uart)
    port map (
      tx => chan);

  uart_slave_inst: entity work.uart_slave
    generic map (
      uart => slave_uart)
    port map (
      rx => chan);

end architecture;
