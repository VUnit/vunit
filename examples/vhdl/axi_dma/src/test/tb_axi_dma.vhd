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

library osvvm;
use osvvm.RandomPkg.all;

use work.axil_pkg.all;
use work.axi_pkg.all;
use work.axi_dma_regs_pkg.all;

entity tb_axi_dma is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_axi_dma is
  constant clk_period : time := 1 ns;

  constant axil_bus : bus_master_t := new_bus(data_length => 32,
                                              address_length => 32,
                                              logger => get_logger("axil_bus"));

  constant memory : memory_t := new_memory;
  constant axi_rd_slave : axi_slave_t := new_axi_slave(memory => memory,
                                                       logger => get_logger("axi_rd_slave"));

  constant axi_wr_slave : axi_slave_t := new_axi_slave(memory => memory,
                                                       logger => get_logger("axi_wr_slave"));

  signal clk      : std_logic := '0';
  signal axil_m2s : axil_m2s_t := axil_m2s_init;
  signal axil_s2m : axil_s2m_t;

  signal axi_rd_m2s : axi_rd_m2s_t;
  signal axi_rd_s2m : axi_rd_s2m_t := axi_rd_s2m_init;

  signal axi_wr_m2s : axi_wr_m2s_t;
  signal axi_wr_s2m : axi_wr_s2m_t := axi_wr_s2m_init;

  constant max_burst_length : natural := 256;
  constant bytes_per_beat : natural := axi_rd_s2m.r.data'length / 8;

  impure function to_reg_data(value : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(value, data_length(axil_bus)));
  end;
begin

  main : process
    variable rnd : RandomPType;

    procedure perform_transfer(rbuffer, wbuffer : buffer_t;
                               reg_sample_period : delay_length := 100 * clk_period) is
      variable rdata : std_logic_vector(axil_s2m.r.data'range);
      variable byte : natural;
    begin
      info("perform_transfer(num_bytes => " & to_string(num_bytes(rbuffer)) & ")");
      assert num_bytes(rbuffer) = num_bytes(wbuffer) report "buffer size must be equal";

      -- Provide random stimuli to read data buffer
      -- Set expected data on write data buffer
      for i in 0 to num_bytes(rbuffer)-1 loop
        byte := rnd.RandInt(0, 255);
        write_byte(memory, base_address(rbuffer) + i, byte);
        set_expected_byte(memory, base_address(wbuffer) + i, byte);
      end loop;

      write_bus(net, axil_bus, src_address_reg_addr, to_reg_data(base_address(rbuffer)));
      write_bus(net, axil_bus, dst_address_reg_addr, to_reg_data(base_address(wbuffer)));
      write_bus(net, axil_bus, num_bytes_reg_addr, to_reg_data(num_bytes(rbuffer)));
      write_bus(net, axil_bus, command_reg_addr, start_transfer_command);

      loop
        read_bus(net, axil_bus, status_reg_addr, rdata);
        exit when rdata(transfer_done_status_bit) = '1';
        wait for reg_sample_period;
      end loop;

      -- This checks that all data has been correctly written to the write
      -- buffer at this point
      check_expected_was_written(wbuffer);
    end;

    procedure perform_transfer(num_bytes : natural;
                               reg_sample_period : delay_length := 100 * clk_period) is
      variable rbuffer, wbuffer : buffer_t;
    begin
      rbuffer := allocate(memory,
                          num_bytes => num_bytes,
                          name => rbuffer'simple_name,
                          permissions => read_only,
                          alignment => 4096);
      wbuffer := allocate(memory,
                          num_bytes => num_bytes,
                          name => wbuffer'simple_name,
                          permissions => write_only,
                          alignment => 4096);
      perform_transfer(rbuffer, wbuffer, reg_sample_period);
    end;

    variable stat : axi_statistics_t;
    variable unnused_buffer, rbuffer, wbuffer : buffer_t;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);
    show(display_handler, debug);

    if run("Perform simple transfers") then
      -- Perform transfer that are a multiple of the max_burst_length and
      -- do not cross 4k boundaries
      perform_transfer(num_bytes => max_burst_length * bytes_per_beat);
      perform_transfer(num_bytes => 10 * max_burst_length * bytes_per_beat);

    elsif run("Perform split transfers") then
      -- Perform transfers where the max_burst_length cannot be used for the
      -- entire transfer
      perform_transfer(num_bytes => bytes_per_beat);
      get_statistics(net, axi_rd_slave, stat, clear => true);
      check_equal(get_num_burst_with_length(stat, 1), 1);
      check_equal(num_bursts(stat), 1);
      get_statistics(net, axi_wr_slave, stat, clear => true);
      check_equal(get_num_burst_with_length(stat, 1), 1);
      check_equal(num_bursts(stat), 1);

      clear(memory);
      perform_transfer(num_bytes => (max_burst_length - 1) * bytes_per_beat);
      get_statistics(net, axi_rd_slave, stat, clear => true);
      check_equal(get_num_burst_with_length(stat, max_burst_length - 1), 1);
      check_equal(num_bursts(stat), 1);
      get_statistics(net, axi_wr_slave, stat, clear => true);
      check_equal(get_num_burst_with_length(stat, max_burst_length - 1), 1);
      check_equal(num_bursts(stat), 1);

      clear(memory);
      perform_transfer(num_bytes => (max_burst_length + 1) * bytes_per_beat);
      get_statistics(net, axi_rd_slave, stat, clear => true);
      check_equal(get_num_burst_with_length(stat, max_burst_length), 1);
      check_equal(get_num_burst_with_length(stat, 1), 1);
      check_equal(num_bursts(stat), 2);
      get_statistics(net, axi_wr_slave, stat, clear => true);
      check_equal(get_num_burst_with_length(stat, max_burst_length), 1);
      check_equal(get_num_burst_with_length(stat, 1), 1);
      check_equal(num_bursts(stat), 2);

      clear(memory);
      perform_transfer(num_bytes => (2*max_burst_length - 1) * bytes_per_beat);
      get_statistics(net, axi_rd_slave, stat, clear => true);
      check_equal(get_num_burst_with_length(stat, max_burst_length), 1);
      check_equal(get_num_burst_with_length(stat, max_burst_length - 1), 1);
      check_equal(num_bursts(stat), 2);
      get_statistics(net, axi_wr_slave, stat, clear => true);
      check_equal(get_num_burst_with_length(stat, max_burst_length), 1);
      check_equal(get_num_burst_with_length(stat, max_burst_length - 1), 1);
      check_equal(num_bursts(stat), 2);

    elsif run("Check transfer done comes after write response") then
      -- Set a very large response latency to ensure that the
      -- dut does not signal transfer_done until the write reponse has been received
      set_response_latency(net, axi_wr_slave, 100 * clk_period);
      perform_transfer(num_bytes => max_burst_length * bytes_per_beat,
                       reg_sample_period => 10 * clk_period);

    elsif run("Check read burst is split on 4KByte boundary") then
      for i in 1 to 5 loop
        clear(memory);
        unnused_buffer := allocate(memory, num_bytes => 4096 - i * bytes_per_beat);
        rbuffer := allocate(memory,
                            num_bytes => 1024,
                            name => rbuffer'simple_name,
                            permissions => read_only);
        info("base_address(rbuffer) = " & to_string(base_address(rbuffer)));
        check_equal(base_address(rbuffer), 4096 - i * bytes_per_beat);
        wbuffer := allocate(memory,
                            num_bytes => 1024,
                            name => wbuffer'simple_name,
                            permissions => write_only,
                            alignment => 4096);
        perform_transfer(rbuffer, wbuffer);
      end loop;

    elsif run("Check write burst is split on 4KByte boundary") then
      for i in 1 to 5 loop
        clear(memory);
        unnused_buffer := allocate(memory, num_bytes => 4096 - i * bytes_per_beat);
        wbuffer := allocate(memory,
                            num_bytes => 1024,
                            name => wbuffer'simple_name,
                            permissions => write_only);
        info("base_address(wbuffer) = " & to_string(base_address(wbuffer)));
        check_equal(base_address(wbuffer), 4096 - i * bytes_per_beat);
        rbuffer := allocate(memory,
                            num_bytes => 1024,
                            name => rbuffer'simple_name,
                            permissions => read_only,
                            alignment => 4096);
        perform_transfer(rbuffer, wbuffer);
      end loop;


    elsif run("Slow data read") then
      set_address_fifo_depth(net, axi_rd_slave, 16);
      set_address_stall_probability(net, axi_rd_slave, 0.99);
      set_data_stall_probability(net, axi_rd_slave, 0.95);
      for i in 0 to 15 loop
        perform_transfer(num_bytes => rnd.RandInt(1, 3 * max_burst_length) * bytes_per_beat);
      end loop;

    elsif run("Slow data write") then
      set_address_fifo_depth(net, axi_wr_slave, 16);
      set_address_stall_probability(net, axi_wr_slave, 0.99);
      set_data_stall_probability(net, axi_wr_slave, 0.95);
      for i in 0 to 15 loop
        perform_transfer(num_bytes => rnd.RandInt(1, 3 * max_burst_length) * bytes_per_beat);
      end loop;

    elsif run("Random AXI configuration") then
      for idx in 0 to 15 loop
        set_address_fifo_depth(net, axi_wr_slave, rnd.RandInt(1, 16));
        set_address_stall_probability(net, axi_wr_slave, rnd.Uniform(0.0, 0.99));
        set_data_stall_probability(net, axi_wr_slave, rnd.Uniform(0.0, 0.95));
        set_write_response_fifo_depth(net, axi_wr_slave, rnd.RandInt(1, 16));
        set_write_response_stall_probability(net, axi_wr_slave, rnd.Uniform(0.0, 0.99));
        set_response_latency(net, axi_wr_slave, rnd.Uniform(1.0, 100.0) * 1 ns);

        set_address_fifo_depth(net, axi_rd_slave, rnd.RandInt(1, 16));
        set_address_stall_probability(net, axi_rd_slave, rnd.Uniform(0.0, 0.99));
        set_data_stall_probability(net, axi_rd_slave, rnd.Uniform(0.0, 0.95));
        set_response_latency(net, axi_rd_slave, rnd.Uniform(1.0, 100.0) * 1 ns);
        for i in 0 to 3 loop
          clear(memory);
          perform_transfer(num_bytes => rnd.RandInt(1, 3 * max_burst_length) * bytes_per_beat);
        end loop;
      end loop;
    end if;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 10 ms);


  dut: entity work.axi_dma
    generic map (
      max_burst_length => max_burst_length
      )
    port map (
      clk       => clk,

      axils_m2s => axil_m2s,
      axils_s2m => axil_s2m,

      axi_rd_m2s => axi_rd_m2s,
      axi_rd_s2m => axi_rd_s2m,

      axi_wr_m2s => axi_wr_m2s,
      axi_wr_s2m => axi_wr_s2m);

  clk <= not clk after clk_period/2;

  axi_lite_master_inst: entity vunit_lib.axi_lite_master
    generic map (
      bus_handle => axil_bus)
    port map (
      aclk    => clk,
      arready => axil_s2m.ar.ready,
      arvalid => axil_m2s.ar.valid,
      araddr  => axil_m2s.ar.addr,
      rready  => axil_m2s.r.ready,
      rvalid  => axil_s2m.r.valid,
      rdata   => axil_s2m.r.data,
      rresp   => axil_s2m.r.resp,
      awready => axil_s2m.aw.ready,
      awvalid => axil_m2s.aw.valid,
      awaddr  => axil_m2s.aw.addr,
      wready  => axil_s2m.w.ready,
      wvalid  => axil_m2s.w.valid,
      wdata   => axil_m2s.w.data,
      wstrb   => axil_m2s.w.strb,
      bvalid  => axil_s2m.b.valid,
      bready  => axil_m2s.b.ready,
      bresp   => axil_s2m.b.resp);

  axi_read_slave_inst: entity vunit_lib.axi_read_slave
    generic map (
      axi_slave => axi_rd_slave)
    port map (
      aclk    => clk,
      arvalid => axi_rd_m2s.ar.valid,
      arready => axi_rd_s2m.ar.ready,
      arid    => axi_rd_m2s.ar.id,
      araddr  => axi_rd_m2s.ar.addr,
      arlen   => axi_rd_m2s.ar.len,
      arsize  => axi_rd_m2s.ar.size,
      arburst => axi_rd_m2s.ar.burst,
      rvalid  => axi_rd_s2m.r.valid,
      rready  => axi_rd_m2s.r.ready,
      rid     => axi_rd_s2m.r.id,
      rdata   => axi_rd_s2m.r.data,
      rresp   => axi_rd_s2m.r.resp,
      rlast   => axi_rd_s2m.r.last);

  axi_write_slave_inst: entity vunit_lib.axi_write_slave
    generic map (
      axi_slave => axi_wr_slave)
    port map (
      aclk    => clk,
      awvalid => axi_wr_m2s.aw.valid,
      awready => axi_wr_s2m.aw.ready,
      awid    => axi_wr_m2s.aw.id,
      awaddr  => axi_wr_m2s.aw.addr,
      awlen   => axi_wr_m2s.aw.len,
      awsize  => axi_wr_m2s.aw.size,
      awburst => axi_wr_m2s.aw.burst,

      wvalid  => axi_wr_m2s.w.valid,
      wready  => axi_wr_s2m.w.ready,
      wdata   => axi_wr_m2s.w.data,
      wstrb   => axi_wr_m2s.w.strb,
      wlast   => axi_wr_m2s.w.last,

      bvalid  => axi_wr_s2m.b.valid,
      bready  => axi_wr_m2s.b.ready,
      bid     => axi_wr_s2m.b.id,
      bresp   => axi_wr_s2m.b.resp);


end architecture;
