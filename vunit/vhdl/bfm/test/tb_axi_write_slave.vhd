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
use work.random_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_axi_write_slave is
  generic (runner_cfg : string);
end entity;

architecture a of tb_axi_write_slave is
  signal clk    : std_logic := '0';

  constant log_data_size : integer := 4;
  constant data_size     : integer := 2**log_data_size;

  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal awid    : std_logic_vector(3 downto 0);
  signal awaddr  : std_logic_vector(31 downto 0);
  signal awlen   : axi4_len_t;
  signal awsize  : axi4_size_t;
  signal awburst : axi_burst_type_t;

  signal wvalid  : std_logic;
  signal wready  : std_logic := '0';
  signal wid     : std_logic_vector(awid'range);
  signal wdata   : std_logic_vector(8*data_size-1 downto 0);
  signal wstrb   : std_logic_vector(data_size downto 0);
  signal wlast   : std_logic;

  signal bvalid  : std_logic := '0';
  signal bready  : std_logic;
  signal bid     : std_logic_vector(awid'range);
  signal bresp   : axi_resp_t;

  constant axi_slave : axi_slave_t := new_axi_slave;
  constant memory : memory_t := new_memory;

begin
  main : process
    variable alloc : alloc_t;
    variable rnd : RandomPType;

    procedure read_response(id : std_logic_vector;
                            resp : axi_resp_t := axi_resp_okay) is
    begin
      bready <= '1';
      wait until (bvalid and bready) = '1' and rising_edge(clk);
      check_equal(bresp, resp, "bresp");
      check_equal(bid, id, "bid");
      bready <= '0';
    end procedure;


    procedure write_addr(id : std_logic_vector;
                         addr : natural;
                         len : natural;
                         log_size : natural;
                         burst : axi_burst_type_t) is
    begin
      awvalid <= '1';
      awid <= id;
      awaddr <= std_logic_vector(to_unsigned(addr, awaddr'length));
      awlen <= std_logic_vector(to_unsigned(len-1, awlen'length));
      awsize <= std_logic_vector(to_unsigned(log_size, awsize'length));
      awburst <= burst;

      wait until (awvalid and awready) = '1' and rising_edge(clk);
      awvalid <= '0';
    end procedure;

    variable data : integer_vector_ptr_t;
    variable strb : integer_vector_ptr_t;
    variable size, log_size : natural;
    variable id : std_logic_vector(awid'range);
    variable len : natural;
    variable burst : axi_burst_type_t;
    variable idx : integer;
    variable num_ops : integer;
    variable start_time, diff_time : time;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("Test random writes") then
      num_ops := 0;
      for test_idx in 0 to 32-1 loop

        id := rnd.RandSlv(awid'length);
        case rnd.RandInt(1) is
          when 0 =>
            burst := axi_burst_type_fixed;
            len := 1;
          when 1 =>
            burst := axi_burst_type_incr;
            len := rnd.RandInt(1, 2**awlen'length);
          when others =>
            assert false;
        end case;

        log_size := rnd.RandInt(0, 3);
        size := 2**log_size;
        random_integer_vector_ptr(rnd, data, size * len, 0, 255);
        random_integer_vector_ptr(rnd, strb, length(data), 0, 1);

        alloc := allocate(memory, 8 * len, alignment => 4096);
        for i in 0 to length(data)-1 loop
          if get(strb, i) = 1 then
            set_expected_byte(memory, base_address(alloc)+i, get(data, i));
            num_ops := num_ops + 1;
          else
            set_permissions(memory, base_address(alloc)+i, no_access);
          end if;
        end loop;

        write_addr(id, base_address(alloc), len, log_size, burst);

        wid <= id;

        for j in 0 to len-1 loop
          for i in 0 to size-1 loop
            idx := (base_address(alloc) + j*size + i) mod data_size;
            wdata(8*idx+7 downto 8*idx) <= std_logic_vector(to_unsigned(get(data, j*size + i), 8));
            wstrb(idx downto idx) <= std_logic_vector(to_unsigned(get(strb, j*size + i), 1));
          end loop;

          if j = len-1 then
            wlast <= '1';
          else
            wlast <= '0';
          end if;

          wvalid <= '1';
          wait until (wvalid and wready) = '1' and rising_edge(clk);
          wvalid <= '0';
          wstrb <= (others => '0');
          wdata <= (others => '0');
        end loop;

        read_response(id, axi_resp_okay);

        check_all_was_written(alloc);
      end loop;

      assert num_ops > 5000;

    elsif run("Test error on missing tlast fixed") then
      mock(axi_slave_logger);

      alloc := allocate(memory, 8);
      write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_fixed);
      wvalid <= '1';
      wait until (wvalid and wready) = '1' and rising_edge(clk);
      wvalid <= '0';

      wait until get_mock_log_count(axi_slave_logger, failure) > 0 and rising_edge(clk);
      check_only_log(axi_slave_logger, "Expected wlast='1' on last beat of burst with length 1 starting at address 0", failure);
      unmock(axi_slave_logger);
      read_response(x"2", axi_resp_okay);

    elsif run("Test error on missing tlast incr") then
      alloc := allocate(memory, 8);
      write_addr(x"2", base_address(alloc), 2, 0, axi_burst_type_incr);

      wvalid <= '1';
      wait until (wvalid and wready) = '1' and rising_edge(clk);
      wvalid <= '0';
      wait until wvalid = '0' and rising_edge(clk);

      mock(axi_slave_logger);

      wvalid <= '1';
      wait until (wvalid and wready) = '1' and rising_edge(clk);
      wvalid <= '0';
      wait until get_mock_log_count(axi_slave_logger, failure) > 0 and rising_edge(clk);

      check_only_log(axi_slave_logger, "Expected wlast='1' on last beat of burst with length 2 starting at address 0", failure);
      unmock(axi_slave_logger);
      read_response(x"2", axi_resp_okay);

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

    elsif run("Test default address channel depth is 1") then
      write_addr(x"2", 0, 1, 0, axi_burst_type_incr); -- Taken data process
      write_addr(x"2", 0, 1, 0, axi_burst_type_incr); -- In the queue
      for i in 0 to 127 loop
        wait until rising_edge(clk);
        assert awready = '0' report "Can only have one address in the queue";
      end loop;

    elsif run("Test set address channel fifo depth") then
      set_address_channel_fifo_depth(event, axi_slave, 16);

      write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_incr); -- Taken data process
      for i in 1 to 16 loop
        write_addr(x"2", base_address(alloc), 1, 0, axi_burst_type_incr); -- In the queue
      end loop;

      for i in 0 to 127 loop
        wait until rising_edge(clk);
        assert awready = '0' report "Address queue should be full";
      end loop;

    elsif run("Test changing address channel depth to smaller than content gives error") then
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
      alloc := allocate(memory, 8);
      enable_well_behaved_check(event, axi_slave);
      set_address_channel_fifo_depth(event, axi_slave, 3);
      set_write_response_fifo_depth(event, axi_slave, 3);

      bready <= '1';

      wait until rising_edge(clk);
      wvalid <= '1';
      wlast  <= '1';
      assert wready = '0';
      -- Only allow non max size for single beat bursts
      write_addr(x"0", base_address(alloc), len => 1, log_size => log_data_size, burst => axi_burst_type_incr);
      wvalid <= '1';
      wlast  <= '1';
      assert wready = '0';
      write_addr(x"0", base_address(alloc), len => 2, log_size => log_data_size, burst => axi_burst_type_incr);
      wvalid <= '1';
      wlast  <= '0';
      assert wready = '1';
      write_addr(x"0", base_address(alloc), len => 1, log_size => 0, burst => axi_burst_type_incr);
      wvalid <= '1';
      wlast  <= '1';
      assert wready = '1';
      wait until rising_edge(clk);
      wvalid <= '1';
      wlast  <= '1';
      assert wready = '1';
      wait until rising_edge(clk);
      wvalid <= '0';
      wlast  <= '0';
      assert wready = '1';
      wait until rising_edge(clk);
      wvalid <= '0';
      wlast  <= '0';
      assert wready = '0';
      wait until rising_edge(clk);
      assert wready = '0';
      wait until rising_edge(clk);
      assert wready = '0';
      wait until rising_edge(clk);
      assert wready = '0';

    elsif run("Test well behaved check does not fail after well behaved burst finished") then
      alloc := allocate(memory, 8);
      enable_well_behaved_check(event, axi_slave);
      bready <= '1';

      wait until rising_edge(clk);
      wvalid <= '1';
      wlast  <= '0';
      assert wready = '0';
      -- Only allow non max size for single beat bursts
      write_addr(x"0", base_address(alloc), len => 3, log_size => log_data_size, burst => axi_burst_type_incr);
      wvalid <= '1';
      wlast  <= '0';
      assert wready = '0';
      wait until rising_edge(clk);
      wvalid <= '1';
      wlast  <= '0';
      assert wready = '1';
      wait until rising_edge(clk);
      wvalid <= '1';
      wlast  <= '1';
      assert wready = '1';
      wait until rising_edge(clk);
      wvalid <= '0';
      wlast  <= '0';
      assert wready = '1';
      wait until rising_edge(clk);
      wvalid <= '0';
      wlast  <= '0';
      assert wready = '0';
      wait until rising_edge(clk);
      wvalid <= '0';
      wlast  <= '0';
      wait until rising_edge(clk);
      wvalid <= '0';
      wlast  <= '0';
      assert wready = '0';

    elsif run("Test well behaved check fails for ill behaved awsize") then
      alloc := allocate(memory, 8);
      enable_well_behaved_check(event, axi_slave);
      mock(axi_slave_logger);
      bready <= '1';

      wait until rising_edge(clk);
      wvalid <= '1';
      wlast  <= '0';
      write_addr(x"0", base_address(alloc), len => 2, log_size => 0, burst => axi_burst_type_incr);
      check_only_log(axi_slave_logger, "Burst not well behaved, axi size = 1 but bus data width allows " & to_string(data_size), failure);
      unmock(axi_slave_logger);

    elsif run("Test well behaved check fails when wvalid not high during active burst") then
      alloc := allocate(memory, 8);
      enable_well_behaved_check(event, axi_slave);
      mock(axi_slave_logger);
      bready <= '1';
      wait until rising_edge(clk);
      write_addr(x"0", base_address(alloc), len => 2, log_size => log_data_size, burst => axi_burst_type_incr);
      check_only_log(axi_slave_logger, "Burst not well behaved, vwalid was not high during active burst", failure);
      unmock(axi_slave_logger);

    elsif run("Test well behaved check fails when bready not high during active burst") then
      alloc := allocate(memory, 8);
      enable_well_behaved_check(event, axi_slave);
      mock(axi_slave_logger);
      wvalid <= '1';
      wait until rising_edge(clk);
      write_addr(x"0", base_address(alloc), len => 2, log_size => log_data_size, burst => axi_burst_type_incr);
      check_only_log(axi_slave_logger, "Burst not well behaved, bready was not high during active burst", failure);
      unmock(axi_slave_logger);

    elsif run("Test well behaved check fails when wvalid not high during active burst and awready is low") then
      alloc := allocate(memory, 8);
      enable_well_behaved_check(event, axi_slave);
      mock(axi_slave_logger);
      set_address_channel_stall_probability(event, axi_slave, 1.0);
      bready <= '1';

      wait until rising_edge(clk);
      wait until rising_edge(clk);
      assert awready = '0';

      awvalid <= '1';
      awid <= x"0";
      awaddr <= std_logic_vector(to_unsigned(base_address(alloc), awaddr'length));
      awlen <= std_logic_vector(to_unsigned(0, awlen'length));
      awsize <= std_logic_vector(to_unsigned(log_size, awsize'length));
      awburst <= axi_burst_type_incr;

      wait until rising_edge(clk);
      assert awready = '0';
      wait until get_mock_log_count(axi_slave_logger, failure) > 0 for 0 ns;

      check_only_log(axi_slave_logger, "Burst not well behaved, vwalid was not high during active burst", failure);
      unmock(axi_slave_logger);

    end if;

    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 1 ms);

  dut : entity work.axi_write_slave
    generic map (
      axi_slave => axi_slave,
      memory => memory)
    port map (
      aclk    => clk,
      awvalid => awvalid,
      awready => awready,
      awid    => awid,
      awaddr  => awaddr,
      awlen   => awlen,
      awsize  => awsize,
      awburst => awburst,
      wvalid  => wvalid,
      wready  => wready,
      wid     => wid,
      wdata   => wdata,
      wstrb   => wstrb,
      wlast   => wlast,
      bvalid  => bvalid,
      bready  => bready,
      bid     => bid,
      bresp   => bresp);

  clk <= not clk after 5 ns;
end architecture;
