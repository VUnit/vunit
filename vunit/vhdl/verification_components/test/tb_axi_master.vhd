-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com
-- Author David Martin david.martin@phios.group 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context work.com_context;

use work.axi_pkg.all;
use work.bus_master_pkg.all;
use work.axi_master_pkg.all;
use work.axi_slave_pkg.all;
use work.memory_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_axi_master is
  generic (runner_cfg : string);
end entity;

architecture a of tb_axi_master is
  constant num_random_tests : integer := 128;

  signal clk    : std_logic := '0';

  signal arvalid : std_logic;
  signal arready : std_logic := '0';
  signal arid    : std_logic_vector(7 downto 0); --TBD
  signal araddr  : std_logic_vector(31 downto 0);
  signal arlen   : std_logic_vector(7 downto 0); --TBD
  signal arsize  : std_logic_vector(2 downto 0);
  signal arburst : axi_burst_type_t;

  signal rvalid  : std_logic;
  signal rready  : std_logic := '0';
  signal rid     : std_logic_vector(7 downto 0); --TBD
  signal rdata   : std_logic_vector(15 downto 0);
  signal rresp   : std_logic_vector(1 downto 0);
  signal rlast   : std_logic;

  signal awvalid : std_logic;
  signal awready : std_logic := '0';
  signal awid    : std_logic_vector(7 downto 0); --TBD
  signal awaddr  : std_logic_vector(31 downto 0);
  signal awlen   : std_logic_vector(7 downto 0); --TBD
  signal awsize  : std_logic_vector(2 downto 0);
  signal awburst : axi_burst_type_t;

  signal wvalid  : std_logic;
  signal wready  : std_logic := '0';
  signal wdata   : std_logic_vector(15 downto 0);
  signal wstrb   : std_logic_vector(1 downto 0);
  signal wlast   : std_logic;

  signal bvalid  : std_logic := '0';
  signal bready  : std_logic;
  signal bid     : std_logic_vector(7 downto 0); --TBD
  signal bresp   : std_logic_vector(1 downto 0);

  constant bus_handle : bus_master_t := new_bus(data_length => wdata'length,
                                                address_length => awaddr'length);

  constant memory : memory_t := new_memory;
  constant axi_rd_slave : axi_slave_t := new_axi_slave(memory => memory,
                                                logger => get_logger("axi_rd_slave"));

  constant axi_wr_slave : axi_slave_t := new_axi_slave(memory => memory,
                                                logger => get_logger("axi_wr_slave"));

  constant tb_logger : logger_t := get_logger("tb");
begin

  main : process

    variable rnd : RandomPType;

    procedure setup_and_set_random_data_read_memory(
      memory : memory_t;
      num_words : positive;
      width : positive;
      data : queue_t
    ) is
        variable rd_buffer : buffer_t;
        variable rand : std_logic_vector(width - 1 downto 0);
    begin
        clear(memory);
        rd_buffer := allocate(memory,
                              num_bytes   => num_words * (width / 8),
                              name        => rd_buffer'simple_name,
                              permissions => read_only);

        for i in 0 to num_words - 1 loop
          rand := rnd.RandSlv(width);
          write_word(memory, base_address(rd_buffer) + (i*(width/8)), rand);
          push(data, rand);
        end loop;
    end;

    procedure setup_and_set_random_data_write_memory(
      memory : memory_t;
      num_words : positive;
      width : positive;
      data : queue_t
    ) is
        variable wt_buffer : buffer_t;
        variable rand : std_logic_vector(width - 1 downto 0);
    begin
        clear(memory);
        wt_buffer := allocate(memory,
                              num_bytes   => num_words * (width / 8),
                              name        => wt_buffer'simple_name,
                              permissions => write_only);

        for i in 0 to num_words - 1 loop
          rand := rnd.RandSlv(width);
          set_expected_word(memory, base_address(wt_buffer) + (i*(width/8)), rand);
          push(data, rand);
        end loop;
    end;

    procedure wait_on_data_write_memory(
      memory : memory_t
    ) is
    begin
        while not expected_was_written(memory) loop
            wait for 1 ns;
        end loop;
    end;

    variable read_data_queue : queue_t := new_queue;
    variable memory_data_queue : queue_t := new_queue;

    variable read_tmp : std_logic_vector(rdata'range);
    variable memory_tmp : std_logic_vector(rdata'range);

    variable burst : natural := 0;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed("common_seed");
    wait for 0 ns;

    if run("Test read with read_bus") then
      for n in 0 to 4 loop
        info(tb_logger, "Setup...");
        burst := 1;
        setup_and_set_random_data_read_memory(memory, burst, rdata'length, memory_data_queue);
        info(tb_logger, "Reading...");
        read_bus(net, bus_handle, 0, read_tmp);
        info(tb_logger, "Compare...");
        memory_tmp := pop(memory_data_queue);
        check_equal(read_tmp, memory_tmp, "read data");
        check_true(is_empty(memory_data_queue), "memory_data_queue not flushed");
      end loop;

    elsif run("Test read with read_axi") then
      for n in 0 to 4 loop
        info(tb_logger, "Setup...");
        burst := 1;
        setup_and_set_random_data_read_memory(memory, burst, rdata'length, memory_data_queue);
        info(tb_logger, "Reading...");
        read_axi(net, bus_handle, x"00000000", "001", x"25", axi_resp_okay, read_tmp);
        info(tb_logger, "Compare...");
        memory_tmp := pop(memory_data_queue);
        check_equal(read_tmp, memory_tmp, "read data");
        check_true(is_empty(memory_data_queue), "memory_data_queue not flushed");
      end loop;

    elsif run("Test random burstcount read with burst_read_bus") then
      for n in 0 to 4 loop
        info(tb_logger, "Setup...");
        burst := rnd.RandInt(1, 255);
        setup_and_set_random_data_read_memory(memory, burst, rdata'length, memory_data_queue);
        info(tb_logger, "Reading...");
        burst_read_bus(net, bus_handle, 0, burst, read_data_queue);
        info(tb_logger, "Compare...");
        for i in 0 to burst - 1 loop
          read_tmp := pop(read_data_queue);
          memory_tmp := pop(memory_data_queue);
          check_equal(read_tmp, memory_tmp, "read data");
        end loop;
        check_true(is_empty(read_data_queue), "read_data_queue not flushed");
        check_true(is_empty(memory_data_queue), "memory_data_queue not flushed");
      end loop;

    elsif run("Test random burstcount read with burst_read_axi") then
      for n in 0 to 4 loop
        info(tb_logger, "Setup...");
        burst := rnd.RandInt(1, 255);
        setup_and_set_random_data_read_memory(memory, burst+1, rdata'length, memory_data_queue);
        info(tb_logger, "Reading...");
        burst_read_axi(net, bus_handle, x"00000000", std_logic_vector(to_unsigned(burst, arlen'length)), "001", axi_burst_type_incr, x"25", axi_resp_okay, read_data_queue);
        info(tb_logger, "Compare...");
        for i in 0 to burst loop
          read_tmp := pop(read_data_queue);
          memory_tmp := pop(memory_data_queue);
          check_equal(read_tmp, memory_tmp, "read data");
        end loop;
        check_true(is_empty(read_data_queue), "read_data_queue not flushed");
        check_true(is_empty(memory_data_queue), "memory_data_queue not flushed");
      end loop;

    elsif run("Test write with write_bus") then
      for n in 0 to 4 loop
        info(tb_logger, "Setup...");
        burst := 1;
        setup_and_set_random_data_write_memory(memory, burst, wdata'length, memory_data_queue);
        info(tb_logger, "Reading...");
        write_bus(net, bus_handle, 0, pop(memory_data_queue));
        info(tb_logger, "Compare...");
        check_true(is_empty(memory_data_queue), "memory_data_queue not flushed");
        wait_on_data_write_memory(memory);
      end loop;

    elsif run("Test write with write_axi") then
      for n in 0 to 4 loop
        info(tb_logger, "Setup...");
        burst := 1;
        setup_and_set_random_data_write_memory(memory, burst, wdata'length, memory_data_queue);
        info(tb_logger, "Reading...");
        write_axi(net, bus_handle, x"00000000", pop(memory_data_queue), "001", x"25", axi_resp_okay);
        info(tb_logger, "Compare...");
        check_true(is_empty(memory_data_queue), "memory_data_queue not flushed");
        wait_on_data_write_memory(memory);
      end loop;

    elsif run("Test random burstcount write with burst_write_bus") then
      for n in 0 to 4 loop
        info(tb_logger, "Setup...");
        burst := rnd.RandInt(1, 255);
        setup_and_set_random_data_write_memory(memory, burst, wdata'length, memory_data_queue);
        info(tb_logger, "Reading...");
        burst_write_bus(net, bus_handle, x"00000000", burst, memory_data_queue);
        info(tb_logger, "Compare...");
        check_true(is_empty(memory_data_queue), "memory_data_queue not flushed");
        wait_on_data_write_memory(memory);
      end loop;
    end if;

    wait for 100 ns;

    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 100 us);

  check_not_valid : process
    constant a_addr_invalid_value : std_logic_vector(araddr'range) := (others => 'X');
    constant a_len_invalid_value : std_logic_vector(arlen'range) := (others => 'X');
    constant a_id_invalid_value : std_logic_vector(arid'range) := (others => 'X');
    constant a_size_invalid_value : std_logic_vector(arsize'range) := (others => 'X');
    constant a_burst_invalid_value : std_logic_vector(arburst'range) := (others => 'X');
    constant wdata_invalid_value : std_logic_vector(wdata'range) := (others => 'X');
    constant wstrb_invalid_value : std_logic_vector(wstrb'range) := (others => 'X');
    constant wlast_invalid_value : std_logic := 'X';
  begin
    wait until rising_edge(clk);

    -- All signals should be driven with 'X' when the channel is not valid
    -- (R and B channels have no outputs from the VC, except for handshake).

    if not arvalid then
      check_equal(araddr, a_addr_invalid_value, "ARADDR not X when ARVALID low");
      check_equal(arlen, a_len_invalid_value, "ARLEN not X when ARVALID low");
      check_equal(arsize, a_size_invalid_value, "ARSIZE not X when ARVALID low");
      check_equal(arburst, a_burst_invalid_value, "ARBURST not X when ARVALID low");
      check_equal(arid, a_id_invalid_value, "ARID not X when ARVALID low");
    end if;

    if not awvalid then
      check_equal(awaddr, a_addr_invalid_value, "AWADDR not X when AWVALID low");
      check_equal(awlen, a_len_invalid_value, "AWLEN not X when ARVALID low");
      check_equal(awsize, a_size_invalid_value, "AWSIZE not X when ARVALID low");
      check_equal(awburst, a_burst_invalid_value, "AWBURST not X when ARVALID low");
      check_equal(awid, a_id_invalid_value, "AWID not X when ARVALID low");
    end if;

    if not wvalid then
      check_equal(wdata, wdata_invalid_value, "WDATA not X when WVALID low");
      check_equal(wstrb, wstrb_invalid_value, "WSTRB not X when WVALID low");
      check_equal(wlast, wlast_invalid_value, "WLAST not X when WVALID low");
    end if;
  end process;

  dut : entity work.axi_master
    generic map (
      bus_handle => bus_handle)
    port map (
      aclk => clk,

      arvalid => arvalid,
      arready => arready,
      arid => arid,
      araddr => araddr,
      arlen => arlen,
      arsize => arsize,
      arburst => arburst,
  
      rvalid => rvalid,
      rready => rready,
      rid => rid,
      rdata => rdata,
      rresp => rresp,
      rlast => rlast,
  
      awvalid => awvalid,
      awready => awready,
      awid => awid,
      awaddr => awaddr,
      awlen => awlen,
      awsize => awsize,
      awburst => awburst,
  
      wvalid => wvalid,
      wready => wready,
      wdata => wdata,
      wstrb => wstrb,
      wlast => wlast,
  
      bvalid => bvalid,
      bready => bready,
      bid => bid,
      bresp => bresp);

  read_slave : entity work.axi_read_slave
    generic map (
      axi_slave => axi_rd_slave)
    port map (
      aclk => clk,
      
      arvalid => arvalid,
      arready => arready,
      arid => arid,
      araddr => araddr,
      arlen => arlen,
      arsize => arsize,
      arburst => arburst,
  
      rvalid => rvalid,
      rready => rready,
      rid => rid,
      rdata => rdata,
      rresp => rresp,
      rlast => rlast);

  write_slave : entity work.axi_write_slave
    generic map (
      axi_slave => axi_wr_slave)
    port map (
      aclk => clk,

      awvalid => awvalid,
      awready => awready,
      awid => awid,
      awaddr => awaddr,
      awlen => awlen,
      awsize => awsize,
      awburst => awburst,
  
      wvalid => wvalid,
      wready => wready,
      wdata => wdata,
      wstrb => wstrb,
      wlast => wlast,
  
      bvalid => bvalid,
      bready => bready,
      bid => bid,
      bresp => bresp);

  clk <= not clk after 5 ns;

end architecture;
