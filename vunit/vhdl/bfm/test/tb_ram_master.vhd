-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.message_pkg.all;
use work.queue_pkg.all;
use work.bus_pkg.all;

entity tb_ram_master is
  generic (runner_cfg : string);
end entity;

architecture a of tb_ram_master is
  constant latency : integer := 2;
  constant num_back_to_back_reads : integer := 64;

  signal clk   : std_logic := '0';
  signal wr    : std_logic;
  signal rd    : std_logic;
  signal addr  : std_logic_vector(7 downto 0);
  signal wdata : std_logic_vector(31 downto 0);
  signal rdata : std_logic_vector(31 downto 0) := (others => '0');

  constant bus_handle : bus_t := new_bus(data_length => wdata'length, address_length => addr'length);

  signal start, done : boolean := false;
begin

  main : process
    variable reply : reply_t;
    variable reply_queue : queue_t := allocate;
    variable tmp : std_logic_vector(rdata'range);
  begin
    test_runner_setup(runner, runner_cfg);
    start <= true;
    wait for 0 ns;

    if run("Test single write") then
      write_bus(event, bus_handle, x"77", x"11223344");

    elsif run("Test single read") then
      read_bus(event, bus_handle, x"33", tmp);
      check_equal(tmp, std_logic_vector'(x"55667788"), "read data");

    elsif run("Test read back to back") then
      for i in 1 to num_back_to_back_reads loop
        read_bus(event, bus_handle, std_logic_vector(to_unsigned(i, addr'length)), reply);
        push(reply_queue, reply);
      end loop;

      for i in 1 to num_back_to_back_reads loop
        reply := pop(reply_queue);
        await_read_bus_reply(event, reply, tmp);
        check_equal(tmp, std_logic_vector(to_unsigned(111*i, tmp'length)), "read data");
      end loop;
    end if;

    wait for 100 ns;

    if not done then
      wait until done;
    end if;

    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 100 us);


  support : process
  begin
    wait until start;

    if enabled("Test single write") then
      wait until wr = '1' and rising_edge(clk);
      check_equal(rd, '0', "rd");
      check_equal(addr, std_logic_vector'(x"77"), "addr");
      check_equal(wdata, std_logic_vector'(x"11223344"), "wdata");
      done <= true;
      wait until wr = '1' and rising_edge(clk);
      assert false report "Should never happen";

    elsif enabled("Test single read") then
      rdata <= x"11223344";
      wait until rd = '1' and rising_edge(clk);
      check_equal(addr, std_logic_vector'(x"33"), "addr");
      for i in 2 to latency loop
        wait until rising_edge(clk);
        check_equal(rd, '0', "rd");
      end loop;

      rdata <= x"55667788";
      wait until rising_edge(clk);
      check_equal(rd, '0', "rd");
      rdata <= x"99aabbcc";
      done <= true;

    elsif enabled("Test read back to back") then
      wait until rd = '1' and rising_edge(clk);

      for i in 1 to num_back_to_back_reads + (latency-1) loop
        if i <= num_back_to_back_reads then
          check_equal(rd, '1', "rd");
          check_equal(addr, i, "addr");
        else
          check_equal(rd, '0', "rd");
        end if;

        if i > (latency-1) then
          rdata <= std_logic_vector(to_unsigned(111*(i - (latency-1)), rdata'length));
        end if;

        wait until rising_edge(clk);
      end loop;

      done <= true;
    end if;
  end process;

  dut : entity work.ram_master
    generic map (
      bus_handle => bus_handle,
      latency => latency)
    port map (
      clk   => clk,
      wr    => wr,
      rd    => rd,
      addr  => addr,
      wdata => wdata,
      rdata => rdata);

  clk <= not clk after 5 ns;

end architecture;
