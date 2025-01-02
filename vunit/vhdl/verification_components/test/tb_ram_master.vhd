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
context work.com_context;

use work.queue_pkg.all;
use work.bus_master_pkg.all;

entity tb_ram_master is
  generic (runner_cfg : string);
end entity;

architecture a of tb_ram_master is
  constant latency : integer := 2;
  constant num_back_to_back_reads : integer := 64;

  signal clk   : std_logic := '0';
  signal en    : std_logic;
  signal we    : std_logic_vector(3 downto 0);
  signal addr  : std_logic_vector(7 downto 0);
  signal wdata : std_logic_vector(31 downto 0);
  signal rdata : std_logic_vector(31 downto 0) := (others => '0');

  constant bus_handle : bus_master_t := new_bus(data_length => wdata'length, address_length => addr'length);

  signal start, done : boolean := false;
begin

  main : process
    variable reference : bus_reference_t;
    variable reference_queue : queue_t := new_queue;
    variable tmp : std_logic_vector(rdata'range);
  begin
    test_runner_setup(runner, runner_cfg);
    start <= true;
    wait for 0 ns;

    if run("Test single write") then
      write_bus(net, bus_handle, x"77", x"11223344");

    elsif run("Test single write with byte enable") then
      write_bus(net, bus_handle, x"77", x"11223344", byte_enable => "0101");

    elsif run("Test single read") then
      read_bus(net, bus_handle, x"33", tmp);
      check_equal(tmp, std_logic_vector'(x"55667788"), "read data");

    elsif run("Test read back to back") then
      for i in 1 to num_back_to_back_reads loop
        read_bus(net, bus_handle, std_logic_vector(to_unsigned(i, addr'length)), reference);
        push(reference_queue, reference);
      end loop;

      for i in 1 to num_back_to_back_reads loop
        reference := pop(reference_queue);
        await_read_bus_reply(net, reference, tmp);
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
      wait until en = '1' and rising_edge(clk);
      check_equal(en, '1', "en");
      check_equal(we, std_logic_vector'("1111"), "we");
      check_equal(addr, std_logic_vector'(x"77"), "addr");
      check_equal(wdata, std_logic_vector'(x"11223344"), "wdata");
      done <= true;
      wait until en = '1' and rising_edge(clk);
      assert false report "Should never happen";

    elsif enabled("Test single write with byte enable") then
      wait until en = '1' and rising_edge(clk);
      check_equal(en, '1', "en");
      check_equal(we, std_logic_vector'("0101"), "we");
      check_equal(addr, std_logic_vector'(x"77"), "addr");
      check_equal(wdata, std_logic_vector'(x"11223344"), "wdata");
      done <= true;
      wait until en = '1' and rising_edge(clk);
      assert false report "Should never happen";

    elsif enabled("Test single read") then
      rdata <= x"11223344";
      wait until en = '1' and rising_edge(clk);
      check_equal(we, std_logic_vector'("0000"), "we");
      check_equal(addr, std_logic_vector'(x"33"), "addr");
      for i in 2 to latency loop
        wait until rising_edge(clk);
        check_equal(en, '0', "en");
      end loop;

      rdata <= x"55667788";
      wait until rising_edge(clk);
      check_equal(en, '0', "en");
      rdata <= x"99aabbcc";
      done <= true;

    elsif enabled("Test read back to back") then
      wait until en = '1' and rising_edge(clk);

      for i in 1 to num_back_to_back_reads + (latency-1) loop
        if i <= num_back_to_back_reads then
          check_equal(en, '1', "en");
          check_equal(we, std_logic_vector'("0000"), "we");
          check_equal(addr, i, "addr");
        else
          check_equal(en, '0', "en");
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
      en    => en,
      we    => we,
      addr  => addr,
      wdata => wdata,
      rdata => rdata);

  clk <= not clk after 5 ns;

end architecture;
