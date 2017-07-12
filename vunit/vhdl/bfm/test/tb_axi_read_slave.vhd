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
context work.com_context;

use work.axi_pkg.all;
use work.memory_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.logger_pkg.all;
use work.random_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_axi_read_slave is
  generic (runner_cfg : string);
end entity;

architecture a of tb_axi_read_slave is
  signal clk    : std_logic := '0';

  constant log_data_size : integer := 4;
  constant data_size : integer := 2**log_data_size;

  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal arid    : std_logic_vector(3 downto 0);
  signal araddr  : std_logic_vector(31 downto 0);
  signal arlen   : axi4_len_t;
  signal arsize  : axi4_size_t;
  signal arburst : axi_burst_type_t;

  signal rvalid : std_logic;
  signal rready : std_logic := '0';
  signal rid : std_logic_vector(arid'range);
  signal rdata : std_logic_vector(8*data_size-1 downto 0);
  signal rresp : axi_resp_t;
  signal rlast : std_logic;

  constant axi_slave : axi_slave_t := new_axi_slave;
  constant memory : memory_t := new_memory;

begin
  main : process
    variable alloc : alloc_t;
    variable rnd : RandomPType;

    procedure write_addr(id : std_logic_vector;
                         addr : natural;
                         len : natural;
                         log_size : natural;
                         burst : axi_burst_type_t) is
    begin
        arvalid <= '1';
        arid <= id;
        araddr <= std_logic_vector(to_unsigned(addr, araddr'length));
        arlen <= std_logic_vector(to_unsigned(len-1, arlen'length));
        arsize <= std_logic_vector(to_unsigned(log_size, arsize'length));
        arburst <= burst;

        wait until (arvalid and arready) = '1' and rising_edge(clk);
        arvalid <= '0';
    end procedure;

    procedure read_data(id : std_logic_vector; address : natural; size : natural; resp : axi_resp_t; last : boolean) is
      variable idx : integer;
    begin
      rready <= '1';
      wait until (rvalid and rready) = '1' and rising_edge(clk);
      rready <= '0';
      for i in 0 to size-1 loop
        idx := (address + i) mod data_size; -- Align data bus
        check_equal(rdata(8*idx+7 downto 8*idx), read_byte(memory, address+i));
      end loop;
      check_equal(rid, id, "rid");
      check_equal(rresp, resp, "rresp");
      check_equal(rlast, last, "rlast");
    end procedure;

    variable data : integer_vector_ptr_t;
    variable size, log_size : natural;
    variable id : std_logic_vector(arid'range);
    variable len : natural;
    variable burst : axi_burst_type_t;
    variable start_time, diff_time : time;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("Test random read") then
      for test_idx in 0 to 32-1 loop

        id := rnd.RandSlv(arid'length);
        case rnd.RandInt(1) is
          when 0 =>
            burst := axi_burst_type_fixed;
            len := 1;
          when 1 =>
            burst := axi_burst_type_incr;
            len := rnd.RandInt(1, 2**arlen'length);
          when others =>
            assert false;
        end case;

        log_size := rnd.RandInt(0, 3);
        size := 2**log_size;
        random_integer_vector_ptr(rnd, data, size * len, 0, 255);

        alloc := allocate(memory, 8 * len, alignment => 4096);
        for i in 0 to length(data)-1 loop
          write_byte(memory, base_address(alloc)+i, get(data, i));
        end loop;

        write_addr(id, base_address(alloc), len, log_size, burst);

        for i in 0 to len-1 loop
          read_data(id, base_address(alloc)+size*i, size, axi_resp_okay, i=len-1);
        end loop;
      end loop;

    elsif run("Test error on unsupported wrap burst") then
      mock(axi_slave_logger);

      alloc := allocate(memory, 8);
      write_addr(x"2", base_address(alloc), 2, 0, axi_burst_type_wrap);
      wait until get_mock_log_count(axi_slave_logger, failure) > 0 and rising_edge(clk);
      check_only_log(axi_slave_logger, "Wrapping burst type not supported", failure);
      unmock(axi_slave_logger);

    elsif run("Test error 4KB boundary crossing") then
      alloc := allocate(memory, 4096+32, alignment => 4096);
      mock(axi_slave_logger);
      write_addr(x"2", base_address(alloc)+4000, 256, 0, axi_burst_type_incr);
      wait until get_mock_log_count(axi_slave_logger, failure) > 0 and rising_edge(clk);
      check_only_log(axi_slave_logger, "Crossing 4KB boundary", failure);
      unmock(axi_slave_logger);

    elsif run("Test default address channel fifo depth is 1") then
      alloc := allocate(memory, 1024);
      write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_incr); -- Taken data process
      write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_incr); -- In the queue
      for i in 0 to 127 loop
        wait until rising_edge(clk);
        assert arready = '0' report "Can only have one address in the queue";
      end loop;

    elsif run("Test set address channel fifo depth") then
      alloc := allocate(memory, 1024);
      set_address_channel_fifo_depth(event, axi_slave, 16);

      write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_incr); -- Taken data process
      for i in 1 to 16 loop
        write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_incr); -- In the queue
      end loop;

      for i in 0 to 127 loop
        wait until rising_edge(clk);
        assert arready = '0' report "Address queue should be full";
      end loop;

    elsif run("Test changing address channel depth to smaller than content gives error") then
      alloc := allocate(memory, 1024);
      set_address_channel_fifo_depth(event, axi_slave, 16);

      write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_incr); -- Taken data process
      for i in 1 to 16 loop
        write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_incr); -- In the queue
      end loop;

      set_address_channel_fifo_depth(event, axi_slave, 17);
      set_address_channel_fifo_depth(event, axi_slave, 16);

      mock(axi_slave_logger);
      set_address_channel_fifo_depth(event, axi_slave, 1);
      check_only_log(axi_slave_logger, "New address channel fifo depth 1 is smaller than current content size 16", failure);
      unmock(axi_slave_logger);

    elsif run("Test address channel stall probability") then
      alloc := allocate(memory, 1024);
      set_address_channel_fifo_depth(event, axi_slave, 128);

      start_time := now;
      for i in 1 to 16 loop
        write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_incr);
      end loop;
      diff_time := now - start_time;

      set_address_channel_stall_probability(event, axi_slave, 0.9);
      start_time := now;
      for i in 1 to 16 loop
        write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_incr);
      end loop;
      assert (now - start_time) > 5.0 * diff_time report "Should take about longer with stall probability";

    elsif run("Test well behaved check does not fail for well behaved bursts") then
      alloc := allocate(memory, 128);
      enable_well_behaved_check(event, axi_slave);
      set_address_channel_fifo_depth(event, axi_slave, 3);
      set_write_response_fifo_depth(event, axi_slave, 3);

      wait until rising_edge(clk);
      rready <= '1';
      assert rvalid = '0';
      -- Only allow non max size for single beat bursts
      write_addr(x"0", base_address(alloc), len => 1, log_size => log_data_size, burst => axi_burst_type_incr);
      rready <= '1';
      assert rvalid = '0';
      write_addr(x"0", base_address(alloc), len => 2, log_size => log_data_size, burst => axi_burst_type_incr);
      rready <= '1';
      assert rvalid = '1';
      write_addr(x"0", base_address(alloc), len => 1, log_size => 0, burst => axi_burst_type_incr);
      rready <= '1';
      assert rvalid = '1';
      wait until rising_edge(clk);
      rready <= '1';
      assert rvalid = '1';
      wait until rising_edge(clk);
      rready <= '0';
      assert rvalid = '1';
      wait until rising_edge(clk);
      rready <= '0';
      assert rvalid = '0';
      wait until rising_edge(clk);
      assert rvalid = '0';
      wait until rising_edge(clk);
      assert rvalid = '0';
      wait until rising_edge(clk);
      assert rvalid = '0';

    elsif run("Test well behaved check does not fail after well behaved burst finished") then
      alloc := allocate(memory, 128);
      enable_well_behaved_check(event, axi_slave);

      wait until rising_edge(clk);
      rready <= '1';
      assert rvalid = '0';
      -- Only allow non max size for single beat bursts
      write_addr(x"0", base_address(alloc), len => 3, log_size => log_data_size, burst => axi_burst_type_incr);
      rready <= '1';
      assert rvalid = '0';
      wait until rising_edge(clk);
      rready <= '1';
      assert rvalid = '1';
      wait until rising_edge(clk);
      rready <= '1';
      assert rvalid = '1';
      wait until rising_edge(clk);
      rready <= '0';
      assert rvalid = '1';
      wait until rising_edge(clk);
      rready <= '0';
      assert rvalid = '0';
      wait until rising_edge(clk);
      rready <= '0';
      wait until rising_edge(clk);
      rready <= '0';
      assert rvalid = '0';

    elsif run("Test well behaved check fails for ill behaved awsize") then
      alloc := allocate(memory, 8);
      enable_well_behaved_check(event, axi_slave);
      mock(axi_slave_logger);
      rready <= '1';
      wait until rising_edge(clk);
      write_addr(x"0", base_address(alloc), len => 2, log_size => 0, burst => axi_burst_type_incr);
      check_only_log(axi_slave_logger, "Burst not well behaved, axi size = 1 but bus data width allows " & to_string(data_size), failure);
      unmock(axi_slave_logger);

    elsif run("Test well behaved check fails when rready not high during active burst") then
      alloc := allocate(memory, 128);
      enable_well_behaved_check(event, axi_slave);
      mock(axi_slave_logger);
      wait until rising_edge(clk);
      write_addr(x"0", base_address(alloc), len => 2, log_size => log_data_size, burst => axi_burst_type_incr);
      check_only_log(axi_slave_logger, "Burst not well behaved, rready was not high during active burst", failure);
      unmock(axi_slave_logger);

    elsif run("Test well behaved check fails when wvalid not high during active burst and arready is low") then
      alloc := allocate(memory, 8);
      enable_well_behaved_check(event, axi_slave);
      mock(axi_slave_logger);
      set_address_channel_stall_probability(event, axi_slave, 1.0);

      wait until rising_edge(clk);
      wait until rising_edge(clk);
      assert arready = '0';

      arvalid <= '1';
      arid <= x"0";
      araddr <= std_logic_vector(to_unsigned(base_address(alloc), araddr'length));
      arlen <= std_logic_vector(to_unsigned(0, arlen'length));
      arsize <= std_logic_vector(to_unsigned(log_size, arsize'length));
      arburst <= axi_burst_type_incr;

      wait until rising_edge(clk);
      assert arready = '0';
      wait until get_mock_log_count(axi_slave_logger, failure) > 0 for 0 ns;

      check_only_log(axi_slave_logger, "Burst not well behaved, rready was not high during active burst", failure);
      unmock(axi_slave_logger);


    end if;

    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 1 ms);

  dut : entity work.axi_read_slave
    generic map (
      axi_slave => axi_slave,
      memory => memory)
    port map (
      aclk    => clk,

      arvalid => arvalid,
      arready => arready,
      arid    => arid,
      araddr  => araddr,
      arlen   => arlen,
      arsize  => arsize,
      arburst => arburst,

      rvalid  => rvalid,
      rready  => rready,
      rid     => rid,
      rdata   => rdata,
      rresp   => rresp,
      rlast   => rlast);

  clk <= not clk after 5 ns;
end architecture;
