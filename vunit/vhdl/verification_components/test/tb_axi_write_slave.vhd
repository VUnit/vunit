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
use work.axi_pkg.all;
context work.vc_context;

use work.integer_vector_ptr_pkg.all;
use work.random_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_axi_write_slave is
  generic (runner_cfg : string);
end entity;

architecture a of tb_axi_write_slave is
  signal clk    : std_logic := '1';

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
  signal wdata   : std_logic_vector(8*data_size-1 downto 0);
  signal wstrb   : std_logic_vector(data_size downto 0);
  signal wlast   : std_logic;

  signal bvalid  : std_logic := '0';
  signal bready  : std_logic;
  signal bid     : std_logic_vector(awid'range);
  signal bresp   : axi_resp_t;

  constant memory : memory_t := new_memory;
  constant axi_slave : axi_slave_t := new_axi_slave(memory => memory);

begin
  main : process
    variable buf : buffer_t;
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

    procedure transfer_data(id : std_logic_vector;
                            buf : buffer_t;
                            log_size : natural;
                            data : integer_vector_ptr_t) is
      variable size, len, address, idx : natural;
    begin
      size := 2**log_size;
      len := (length(data) + (base_address(buf) mod size)) / data_size;
      write_addr(id, base_address(buf), len, log_size, axi_burst_type_incr);

      address := base_address(buf);
      for j in 0 to len-1 loop
        wstrb <= (others => '0');
        for i in 0 to size-1-(address mod data_size) loop
          idx := address mod data_size;
          wstrb(idx) <= '1';
          wdata(8*idx+7 downto 8*idx) <=  std_logic_vector(to_unsigned(get(data, address - base_address(buf)), 8));
          set_permissions(memory, address, write_only);
          set_expected_byte(memory, address, get(data, address - base_address(buf)));
          address := address + 1;
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
    end procedure;

    procedure transfer(id : std_logic_vector;
                       buf : buffer_t;
                       log_size : natural;
                       data : integer_vector_ptr_t) is
    begin
      transfer_data(id, buf, log_size, data);
      read_response(id, axi_resp_okay);
      check_expected_was_written(buf);
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

    constant dummy_byte : natural := 13;
    constant large_latency : time := 1 us;
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

        buf := allocate(memory, 8 * len, alignment => 4096);
        for i in 0 to length(data)-1 loop
          if get(strb, i) = 1 then
            set_expected_byte(memory, base_address(buf)+i, get(data, i));
            num_ops := num_ops + 1;
          else
            set_permissions(memory, base_address(buf)+i, no_access);
          end if;
        end loop;

        write_addr(id, base_address(buf), len, log_size, burst);


        for j in 0 to len-1 loop
          for i in 0 to size-1 loop
            idx := (base_address(buf) + j*size + i) mod data_size;
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
        check_expected_was_written(buf);
      end loop;

      assert num_ops > 5000;

    elsif run("Test that permissions are checked") then
      -- Also check that memory errors are made to the axi slave logger
      buf := allocate(memory, data_size, permissions => no_access);
      write_addr(x"0", base_address(buf), 1, log_data_size, axi_burst_type_fixed);

      wvalid <= '1';
      wlast <= '1';
      wstrb <= (0 => '1', others => '0');
      wdata <= (others => '0');
      mock(axi_slave_logger, failure);
      wait until (wvalid and wready) = '1' and rising_edge(clk);
      wait until mock_queue_length > 0 and rising_edge(clk);
      check_only_log(axi_slave_logger,
                     "Writing to address 0 at offset 0 within anonymous buffer at range (0 to 15) without permission (no_access)",
                     failure);
      unmock(axi_slave_logger);
      wvalid <= '0';
      wlast <= '0';
      wstrb <= (others => '0');
      wdata <= (others => '0');

    elsif run("Test data stall probability") then
      for i in 0 to 4 loop
        if i = 2 then
          set_data_stall_probability(net, axi_slave, 0.9);
        else
          set_data_stall_probability(net, axi_slave, 0.0);
        end if;

        log_size := log_data_size;
        size := 2**log_size;
        random_integer_vector_ptr(rnd, data, size * 128, 0, 255);
        buf := allocate(memory, length(data), permissions => no_access);
        start_time := now;
        transfer(x"2", buf, log_size, data);
        info("diff_time := " & to_string(now - start_time));

        if i = 1 or i = 4 then
          -- First two and last two runs should have the same time with 0.0
          -- stall probability
          check_equal(diff_time, now - start_time);
        elsif i = 2 then
          -- Middle run should have larger time
          check(5*diff_time < now - start_time);
        end if;

        diff_time := now - start_time;
      end loop;

    elsif run("Test response latency") then
      for i in 0 to 1 loop
        if i = 1 then
          set_response_latency(net, axi_slave, large_latency);
        end if;

        log_size := log_data_size;
        size := 2**log_size;
        random_integer_vector_ptr(rnd, data, size * 128, 0, 255);
        buf := allocate(memory, length(data), permissions => no_access);

        -- Write known value to memory so that we can check that it has not
        -- been changed to early when response latency is high
        for addr in base_address(buf) to last_address(buf) loop
          write_byte(memory, addr, dummy_byte);
        end loop;

        start_time := now;
        transfer_data(x"2", buf, log_size, data);

        if i = 1 then
          wait for (large_latency - 10 ns);
          -- Check that data was not set yet
          for addr in base_address(buf) to last_address(buf) loop
            check_equal(read_byte(memory, addr), dummy_byte, "Data should not be set yet");
          end loop;
        end if;
        read_response(x"2", axi_resp_okay);
        check_expected_was_written(buf);
        info("diff_time := " & to_string(now - start_time));

        if i = 1 then
          check_equal(diff_time + large_latency, now - start_time);
        end if;

        diff_time := now - start_time;
      end loop;

    elsif run("Test write response stall probability") then
      for i in 0 to 4 loop
        if i = 2 then
          set_write_response_stall_probability(net, axi_slave, 0.95);
        else
          set_write_response_stall_probability(net, axi_slave, 0.0);
        end if;

        log_size := log_data_size;
        size := 2**log_size;
        random_integer_vector_ptr(rnd, data, size, 0, 255);
        buf := allocate(memory, length(data), permissions => no_access);
        start_time := now;
        for j in 0 to 128 loop
          transfer(x"2", buf, log_size, data);
        end loop;

        info("diff_time := " & to_string(now - start_time));

        if i = 1 or i = 4 then
          -- First two and last two runs should have the same time with 0.0
          -- stall probability
          check_equal(diff_time, now - start_time);
        elsif i = 2 then
          -- Middle run should have larger time
          check(5*diff_time < now - start_time);
        end if;

        diff_time := now - start_time;
      end loop;

    elsif run("Test narrow write") then
      -- Half bus width starting at aligned address
      len := 2;
      log_size := log_data_size - 1;
      size := 2**log_size;
      random_integer_vector_ptr(rnd, data, size * 2, 0, 255);
      buf := allocate(memory, length(data), permissions => no_access);
      transfer(x"2", buf, log_size, data);

    elsif run("Test unaligned narrow write") then
      -- Half bus width starting at unaligned address
      log_size := log_data_size - 1;
      size := 2**log_size;
      buf := allocate(memory, 1); -- Unaligned address
      random_integer_vector_ptr(rnd, data, size * 2, 0, 255);
      buf := allocate(memory, length(data), permissions => no_access);
      transfer(x"2", buf, log_size, data);

    elsif run("Test unaligned write") then
      -- Full bus width starting at unaligned address
      len := 2;
      log_size := log_data_size;
      size := 2**log_size;
      buf := allocate(memory, 1); -- Unaligned address
      random_integer_vector_ptr(rnd, data, size * 2, 0, 255);
      buf := allocate(memory, length(data), permissions => no_access);
      transfer(x"2", buf, log_size, data);

    elsif run("Test unaligned write around 4kbyte boundary") then
      -- Do one beat write at unaligned address starting around 4kB boundary
      log_size := log_data_size;
      buf := allocate(memory, 4096 - 2**log_size + 1, permissions => no_access);
      random_integer_vector_ptr(rnd, data, 2**log_size , 0, 255);
      buf := allocate(memory, length(data), permissions => no_access); -- Unaligned address
      transfer(x"2", buf, log_size, data);

    elsif run("Test error on missing tlast fixed") then
      mock(axi_slave_logger, failure);

      buf := allocate(memory, 8);
      write_addr(x"2", base_address(buf), 1, 0, axi_burst_type_fixed);
      wvalid <= '1';
      wait until (wvalid and wready) = '1' and rising_edge(clk);
      wvalid <= '0';

      wait until mock_queue_length > 0 and rising_edge(clk);
      check_only_log(axi_slave_logger,
                     "Expected wlast='1' on last beat of burst #0 for id 2 with length 1 starting at address 0",
                     failure);
      unmock(axi_slave_logger);
      read_response(x"2", axi_resp_okay);

    elsif run("Test error on missing tlast incr") then
      buf := allocate(memory, 8);
      write_addr(x"3", base_address(buf), 2, 0, axi_burst_type_incr);

      wvalid <= '1';
      wait until (wvalid and wready) = '1' and rising_edge(clk);
      wvalid <= '0';
      wait until wvalid = '0' and rising_edge(clk);

      mock(axi_slave_logger, failure);

      wvalid <= '1';
      wait until (wvalid and wready) = '1' and rising_edge(clk);
      wvalid <= '0';
      wait until mock_queue_length > 0 and rising_edge(clk);

      check_only_log(axi_slave_logger,
                     "Expected wlast='1' on last beat of burst #0 for id 3 with length 2 starting at address 0",
                     failure);
      unmock(axi_slave_logger);
      read_response(x"3", axi_resp_okay);

    elsif run("Test error on unsupported wrap burst") then
      mock(axi_slave_logger, failure);
      buf := allocate(memory, 8);
      write_addr(x"2", base_address(buf), 2, 0, axi_burst_type_wrap);
      wait until mock_queue_length > 0 and rising_edge(clk);
      check_only_log(axi_slave_logger, "Wrapping burst type not supported", failure);
      unmock(axi_slave_logger);

    elsif run("Test error 4KByte boundary crossing") then
      buf := allocate(memory, 4096+32, alignment => 4096);
      mock(axi_slave_logger, failure);
      write_addr(x"2", base_address(buf)+4000, 256, 0, axi_burst_type_incr);
      wait until mock_queue_length > 0 and rising_edge(clk);
      check_only_log(axi_slave_logger, "Crossing 4KByte boundary. First page = 0 (4000/4096), last page = 1 (4255/4096)", failure);
      unmock(axi_slave_logger);

    elsif run("Test no error on 4KByte boundary crossing with disabled check") then
      buf := allocate(memory, 4096+32, alignment => 4096);
      disable_4kbyte_boundary_check(net, axi_slave);
      write_addr(x"2", base_address(buf)+4000, 256, 0, axi_burst_type_incr);
      wait until awvalid = '0' and rising_edge(clk);

    elsif run("Test default address depth is 1") then
      write_addr(x"2", 0, 1, 0, axi_burst_type_incr); -- Taken data process
      write_addr(x"2", 0, 1, 0, axi_burst_type_incr); -- In the queue
      for i in 0 to 127 loop
        wait until rising_edge(clk);
        assert awready = '0' report "Can only have one address in the queue";
      end loop;

    elsif run("Test set address fifo depth") then
      set_address_fifo_depth(net, axi_slave, 16);

      write_addr(x"2", base_address(buf), 1, 0, axi_burst_type_incr); -- Taken data process
      for i in 1 to 16 loop
        write_addr(x"2", base_address(buf), 1, 0, axi_burst_type_incr); -- In the queue
      end loop;

      for i in 0 to 127 loop
        wait until rising_edge(clk);
        assert awready = '0' report "Address queue should be full";
      end loop;

    elsif run("Test changing address depth to smaller than content gives error") then
      set_address_fifo_depth(net, axi_slave, 16);

      write_addr(x"2", base_address(buf), 1, 0, axi_burst_type_incr); -- Taken data process
      for i in 1 to 16 loop
        write_addr(x"2", base_address(buf), 1, 0, axi_burst_type_incr); -- In the queue
      end loop;

      set_address_fifo_depth(net, axi_slave, 17);
      set_address_fifo_depth(net, axi_slave, 16);

      mock(axi_slave_logger, failure);

      set_address_fifo_depth(net, axi_slave, 1);
      check_only_log(axi_slave_logger, "New address fifo depth 1 is smaller than current content size 16", failure);
      unmock(axi_slave_logger);

    elsif run("Test address stall probability") then
      set_address_fifo_depth(net, axi_slave, 128);

      start_time := now;
      for i in 1 to 16 loop
        write_addr(x"2", base_address(buf), 1, 0, axi_burst_type_incr);
      end loop;
      diff_time := now - start_time;

      set_address_stall_probability(net, axi_slave, 0.9);
      start_time := now;
      for i in 1 to 16 loop
        write_addr(x"2", base_address(buf), 1, 0, axi_burst_type_incr);
      end loop;
      assert (now - start_time) > 5.0 * diff_time report "Should take about longer with stall probability";

    elsif run("Test well behaved check does not fail for well behaved bursts") then
      buf := allocate(memory, 8);
      enable_well_behaved_check(net, axi_slave);
      set_address_fifo_depth(net, axi_slave, 3);
      set_write_response_fifo_depth(net, axi_slave, 3);

      bready <= '1';

      wait until rising_edge(clk);
      wvalid <= '1';
      wlast  <= '1';
      assert wready = '0';
      -- Only allow non max size for single beat bursts
      write_addr(x"0", base_address(buf), len => 1, log_size => log_data_size, burst => axi_burst_type_incr);
      wvalid <= '1';
      wlast  <= '1';
      assert wready = '0';
      write_addr(x"0", base_address(buf), len => 2, log_size => log_data_size, burst => axi_burst_type_incr);
      wvalid <= '1';
      wlast  <= '0';
      assert wready = '1';
      write_addr(x"0", base_address(buf), len => 1, log_size => 0, burst => axi_burst_type_incr);
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
      buf := allocate(memory, 8);
      enable_well_behaved_check(net, axi_slave);
      bready <= '1';

      wait until rising_edge(clk);
      wvalid <= '1';
      wlast  <= '0';
      assert wready = '0';
      -- Only allow non max size for single beat bursts
      write_addr(x"0", base_address(buf), len => 3, log_size => log_data_size, burst => axi_burst_type_incr);
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
      buf := allocate(memory, 8);
      enable_well_behaved_check(net, axi_slave);
      mock(axi_slave_logger, failure);
      bready <= '1';

      wait until rising_edge(clk);
      wvalid <= '1';
      wlast  <= '0';
      write_addr(x"0", base_address(buf), len => 2, log_size => 0, burst => axi_burst_type_incr);
      check_only_log(axi_slave_logger, "Burst not well behaved, axi size = 1 but bus data width allows " & to_string(data_size), failure);
      unmock(axi_slave_logger);

    elsif run("Test well behaved check fails when wvalid not high during active burst") then
      buf := allocate(memory, 8);
      enable_well_behaved_check(net, axi_slave);
      mock(axi_slave_logger, failure);
      bready <= '1';
      wait until rising_edge(clk);
      write_addr(x"0", base_address(buf), len => 2, log_size => log_data_size, burst => axi_burst_type_incr);
      check_only_log(axi_slave_logger, "Burst not well behaved, wvalid was not high during active burst", failure);
      unmock(axi_slave_logger);

    elsif run("Test well behaved check fails when bready not high during active burst") then
      buf := allocate(memory, 8);
      enable_well_behaved_check(net, axi_slave);
      mock(axi_slave_logger, failure);
      wvalid <= '1';
      wait until rising_edge(clk);
      write_addr(x"0", base_address(buf), len => 2, log_size => log_data_size, burst => axi_burst_type_incr);
      check_only_log(axi_slave_logger, "Burst not well behaved, bready was not high during active burst", failure);
      unmock(axi_slave_logger);

    elsif run("Test well behaved check fails when wvalid not high during active burst and awready is low") then
      buf := allocate(memory, 8);
      enable_well_behaved_check(net, axi_slave);
      mock(axi_slave_logger, failure);
      set_address_stall_probability(net, axi_slave, 1.0);
      bready <= '1';

      wait until rising_edge(clk);
      wait until rising_edge(clk);
      assert awready = '0';

      awvalid <= '1';
      awid <= x"0";
      awaddr <= std_logic_vector(to_unsigned(base_address(buf), awaddr'length));
      awlen <= std_logic_vector(to_unsigned(0, awlen'length));
      awsize <= std_logic_vector(to_unsigned(log_size, awsize'length));
      awburst <= axi_burst_type_incr;

      wait until rising_edge(clk);
      assert awready = '0';
      wait until mock_queue_length > 0 for 0 ns;

      check_only_log(axi_slave_logger, "Burst not well behaved, wvalid was not high during active burst", failure);
      unmock(axi_slave_logger);

    end if;

    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 1 ms);

  check_not_valid : process
    constant bid_invalid_value : std_logic_vector(bid'range) := (others => 'X');
    constant bresp_invalid_value : std_logic_vector(bresp'range) := (others => 'X');
  begin
    wait until rising_edge(clk);

    -- All signals should be driven with 'X' when the channel is not valid
    -- (AW and W have no outputs from the VC, except for handshake, so check is only for B).
    if not bvalid then
      check_equal(bid, bid_invalid_value, "BID not X when BVALID low");
      check_equal(bresp, bresp_invalid_value, "BRESP not X when BVALID low");
    end if;
  end process;

  dut : entity work.axi_write_slave
    generic map (
      axi_slave => axi_slave)
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
      wdata   => wdata,
      wstrb   => wstrb,
      wlast   => wlast,
      bvalid  => bvalid,
      bready  => bready,
      bid     => bid,
      bresp   => bresp);

  clk <= not clk after 5 ns;
end architecture;
