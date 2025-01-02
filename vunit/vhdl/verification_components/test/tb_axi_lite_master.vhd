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
use work.bus_master_pkg.all;
use work.axi_lite_master_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_axi_lite_master is
  generic (runner_cfg : string);
end entity;

architecture a of tb_axi_lite_master is
  constant num_random_tests : integer := 128;

  signal clk    : std_logic := '0';
  signal arready : std_logic := '0';
  signal arvalid : std_logic;
  signal araddr  : std_logic_vector(31 downto 0);

  signal rready  : std_logic := '0';
  signal rvalid  : std_logic;
  signal rdata   : std_logic_vector(15 downto 0);
  signal rresp   : std_logic_vector(1 downto 0);

  signal awready : std_logic := '0';
  signal awvalid : std_logic;
  signal awaddr  : std_logic_vector(31 downto 0);

  signal wready  : std_logic := '0';
  signal wvalid  : std_logic;
  signal wdata   : std_logic_vector(15 downto 0);
  signal wstrb   : std_logic_vector(1 downto 0);

  signal bvalid  : std_logic := '0';
  signal bready  : std_logic;
  signal bresp   : std_logic_vector(1 downto 0);

  constant bus_handle : bus_master_t := new_bus(data_length => wdata'length,
                                                address_length => awaddr'length);

  signal start, done : boolean := false;
begin

  main : process
    variable tmp : std_logic_vector(rdata'range);
    variable rnd : RandomPType;
    variable timestamp : time;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed("common_seed");
    start <= true;
    wait for 0 ns;

    if run("Test single write") then
      mock(get_logger(bus_handle), debug);
      write_bus(net, bus_handle, x"01234567", x"1122");
      wait_until_idle(net, bus_handle);
      check_only_log(get_logger(bus_handle), "Wrote 0x1122 to address 0x01234567", debug);
      unmock(get_logger(bus_handle));

    elsif run("Test single write with byte enable") then
      write_bus(net, bus_handle, x"01234567", x"1122", byte_enable => "10");

    elsif run("Test write not okay") then
      write_bus(net, bus_handle, x"01234567", x"1122");

    elsif run("Test write with axi resp") then
      write_axi_lite(net, bus_handle, x"01234567", x"1122", axi_resp_slverr);

    elsif run("Test write with wrong axi resp") then
      write_axi_lite(net, bus_handle, x"01234567", x"1122", axi_resp_decerr);

    elsif run("Test single read") then
      mock(get_logger(bus_handle), debug);
      read_bus(net, bus_handle, x"01234567", tmp);
      check_equal(tmp, std_logic_vector'(x"5566"), "read data");
      check_only_log(get_logger(bus_handle), "Read 0x5566 from address 0x01234567", debug);
      unmock(get_logger(bus_handle));

    elsif run("Test read not okay") then
      read_bus(net, bus_handle, x"01234567", tmp);

    elsif run("Test read with axi resp") then
      read_axi_lite(net, bus_handle, x"01234567", axi_resp_slverr, tmp);

    elsif run("Test read with wrong axi resp") then
      read_axi_lite(net, bus_handle, x"01234567", axi_resp_exokay, tmp);

    elsif run("Test random") then
      for i in 0 to num_random_tests-1 loop
        if rnd.RandInt(0, 1) = 0 then
          read_bus(net, bus_handle, rnd.RandSlv(araddr'length), tmp);
          check_equal(tmp, rnd.RandSlv(rdata'length), "read data");
        else
          write_bus(net, bus_handle, rnd.RandSlv(awaddr'length), rnd.RandSlv(wdata'length));
        end if;
      end loop;

    elsif run("Test random axi resp") then
      for i in 0 to num_random_tests-1 loop
        if rnd.RandInt(0, 1) = 0 then
          read_axi_lite(net, bus_handle, rnd.RandSlv(araddr'length), rnd.RandSlv(axi_resp_t'length), tmp);
          check_equal(tmp, rnd.RandSlv(rdata'length), "read data");
        else
          write_axi_lite(net, bus_handle, rnd.RandSlv(awaddr'length), rnd.RandSlv(wdata'length),
                         rnd.RandSlv(axi_resp_t'length));
        end if;
      end loop;

    elsif run("Test idle when idle") then
      wait until rising_edge(clk);
      write_bus(net, bus_handle, x"01234567", x"1122");
      wait for 0 ps;
      timestamp := now;
      wait_until_idle(net, bus_handle);
      check(now > timestamp, "Write: First wait did not have to wait");
      timestamp := now;
      wait_until_idle(net, bus_handle);
      check_equal(timestamp, now, "Write: Second wait had to wait");

      wait until rising_edge(clk);
      read_bus(net, bus_handle, x"01234567", tmp);
      timestamp := now;
      wait_until_idle(net, bus_handle);
      check_equal(timestamp, now, "Read: Second wait had to wait");

    end if;

    wait for 100 ns;

    if not done then
      wait until done;
    end if;

    test_runner_cleanup(runner);
  end process;
  test_runner_watchdog(runner, 100 us);


  support : process
    variable rnd : RandomPType;
  begin
    rnd.InitSeed("common_seed");

    wait until start;

    if enabled("Test single write") then
      awready <= '1';
      wait until (awready and awvalid) = '1' and rising_edge(clk);
      awready <= '0';
      check_equal(awaddr, std_logic_vector'(x"01234567"), "awaddr");

      wready <= '1';
      wait until (wready and wvalid) = '1' and rising_edge(clk);
      wready <= '0';
      check_equal(wdata, std_logic_vector'(x"1122"), "wdata");
      check_equal(wstrb, std_logic_vector'("11"), "wstrb");

      bvalid <= '1';
      bresp <= axi_resp_okay;
      wait until (bready and bvalid) = '1' and rising_edge(clk);
      bvalid <= '0';

      done <= true;

    elsif enabled("Test single write with byte enable") then
      awready <= '1';
      wait until (awready and awvalid) = '1' and rising_edge(clk);
      awready <= '0';
      check_equal(awaddr, std_logic_vector'(x"01234567"), "awaddr");

      wready <= '1';
      wait until (wready and wvalid) = '1' and rising_edge(clk);
      wready <= '0';
      check_equal(wdata, std_logic_vector'(x"1122"), "wdata");
      check_equal(wstrb, std_logic_vector'("10"), "wstrb");

      bvalid <= '1';
      bresp <= axi_resp_okay;
      wait until (bready and bvalid) = '1' and rising_edge(clk);
      bvalid <= '0';

      done <= true;

    elsif enabled("Test write not okay") then
      awready <= '1';
      wait until (awready and awvalid) = '1' and rising_edge(clk);
      awready <= '0';

      wready <= '1';
      wait until (wready and wvalid) = '1' and rising_edge(clk);
      wready <= '0';

      bvalid <= '1';
      bresp <= axi_resp_slverr;
      mock(bus_logger, failure);
      wait until (bready and bvalid) = '1' and rising_edge(clk);
      bvalid <= '0';
      wait until mock_queue_length > 0 for 0 ns;
      check_only_log(bus_logger, "bresp - Got AXI response SLVERR(10) expected OKAY(00)", failure);
      unmock(bus_logger);

      done <= true;

    elsif enabled("Test write with axi resp") then
      awready <= '1';
      wait until (awready and awvalid) = '1' and rising_edge(clk);
      awready <= '0';
      check_equal(awaddr, std_logic_vector'(x"01234567"), "awaddr");

      wready <= '1';
      wait until (wready and wvalid) = '1' and rising_edge(clk);
      wready <= '0';
      check_equal(wdata, std_logic_vector'(x"1122"), "wdata");
      check_equal(wstrb, std_logic_vector'("11"), "wstrb");

      bvalid <= '1';
      bresp <= axi_resp_slverr;
      wait until (bready and bvalid) = '1' and rising_edge(clk);
      bvalid <= '0';

      done <= true;

    elsif enabled("Test write with wrong axi resp") then
      awready <= '1';
      wait until (awready and awvalid) = '1' and rising_edge(clk);
      awready <= '0';
      check_equal(awaddr, std_logic_vector'(x"01234567"), "awaddr");

      wready <= '1';
      wait until (wready and wvalid) = '1' and rising_edge(clk);
      wready <= '0';
      check_equal(wdata, std_logic_vector'(x"1122"), "wdata");
      check_equal(wstrb, std_logic_vector'("11"), "wstrb");

      bvalid <= '1';
      bresp <= axi_resp_exokay;
      mock(bus_logger, failure);
      wait until (bready and bvalid) = '1' and rising_edge(clk);
      bvalid <= '0';
      wait until mock_queue_length > 0 for 0 ns;
      check_only_log(bus_logger, "bresp - Got AXI response EXOKAY(01) expected DECERR(11)", failure);
      unmock(bus_logger);

      done <= true;

    elsif enabled("Test single read") then
      arready <= '1';
      wait until (arready and arvalid) = '1' and rising_edge(clk);
      arready <= '0';
      check_equal(araddr, std_logic_vector'(x"01234567"), "araddr");

      rvalid <= '1';
      rresp <= axi_resp_okay;
      rdata <= x"5566";
      wait until (rready and rvalid) = '1' and rising_edge(clk);
      rvalid <= '0';

      done <= true;

    elsif enabled("Test read not okay") then
      arready <= '1';
      wait until (arready and arvalid) = '1' and rising_edge(clk);
      arready <= '0';

      rvalid <= '1';
      rresp <= axi_resp_decerr;
      rdata <= x"5566";
      mock(bus_logger, failure);
      wait until (rready and rvalid) = '1' and rising_edge(clk);
      rvalid <= '0';
      wait until mock_queue_length > 0 for 0 ns;
      check_only_log(bus_logger, "rresp - Got AXI response DECERR(11) expected OKAY(00)", failure);
      unmock(bus_logger);

      done <= true;

    elsif enabled("Test read with axi resp") then
      arready <= '1';
      wait until (arready and arvalid) = '1' and rising_edge(clk);
      arready <= '0';
      check_equal(araddr, std_logic_vector'(x"01234567"), "araddr");

      rvalid <= '1';
      rresp <= axi_resp_slverr;
      rdata <= x"0000";
      wait until (rready and rvalid) = '1' and rising_edge(clk);
      rvalid <= '0';

      done <= true;

    elsif enabled("Test read with wrong axi resp") then
      arready <= '1';
      wait until (arready and arvalid) = '1' and rising_edge(clk);
      arready <= '0';
      check_equal(araddr, std_logic_vector'(x"01234567"), "araddr");

      rvalid <= '1';
      rresp <= axi_resp_decerr;
      rdata <= x"0000";
      mock(bus_logger, failure);
      wait until (rready and rvalid) = '1' and rising_edge(clk);
      rvalid <= '0';
      wait until mock_queue_length > 0 for 0 ns;
      check_only_log(bus_logger, "rresp - Got AXI response DECERR(11) expected EXOKAY(01)", failure);
      unmock(bus_logger);

      done <= true;

    elsif enabled("Test random") then
      for i in 0 to num_random_tests-1 loop
        if rnd.RandInt(0, 1) = 0 then
          arready <= '1';
          wait until (arready and arvalid) = '1' and rising_edge(clk);
          arready <= '0';
          check_equal(araddr, rnd.RandSlv(araddr'length), "araddr");

          rvalid <= '1';
          rresp <= axi_resp_okay;
          rdata <= rnd.RandSlv(rdata'length);
          wait until (rready and rvalid) = '1' and rising_edge(clk);
          rvalid <= '0';
        else
          awready <= '1';
          wait until (awready and awvalid) = '1' and rising_edge(clk);
          awready <= '0';
          check_equal(awaddr, rnd.RandSlv(awaddr'length), "awaddr");

          wready <= '1';
          wait until (wready and wvalid) = '1' and rising_edge(clk);
          wready <= '0';
          check_equal(wdata, rnd.RandSlv(wdata'length), "wdata");
          check_equal(wstrb, std_logic_vector'("11"), "wstrb");

          bvalid <= '1';
          bresp <= axi_resp_okay;
          wait until (bready and bvalid) = '1' and rising_edge(clk);
          bvalid <= '0';
        end if;
      end loop;
      done <= true;

    elsif enabled("Test random axi resp") then
      for i in 0 to num_random_tests-1 loop
        if rnd.RandInt(0, 1) = 0 then
          arready <= '1';
          wait until (arready and arvalid) = '1' and rising_edge(clk);
          arready <= '0';
          check_equal(araddr, rnd.RandSlv(araddr'length), "araddr");

          rvalid <= '1';
          rresp <= rnd.RandSlv(axi_resp_t'length);
          rdata <= rnd.RandSlv(rdata'length);
          wait until (rready and rvalid) = '1' and rising_edge(clk);
          rvalid <= '0';
        else
          awready <= '1';
          wait until (awready and awvalid) = '1' and rising_edge(clk);
          awready <= '0';
          check_equal(awaddr, rnd.RandSlv(awaddr'length), "awaddr");

          wready <= '1';
          wait until (wready and wvalid) = '1' and rising_edge(clk);
          wready <= '0';
          check_equal(wdata, rnd.RandSlv(wdata'length), "wdata");
          check_equal(wstrb, std_logic_vector'("11"), "wstrb");

          bvalid <= '1';
          bresp <= rnd.RandSlv(axi_resp_t'length);
          wait until (bready and bvalid) = '1' and rising_edge(clk);
          bvalid <= '0';
        end if;
      end loop;
      done <= true;

    elsif enabled("Test idle when idle") then
      wait until rising_edge(clk);
      awready <= '1';
      wait until (awready and awvalid) = '1' and rising_edge(clk);
      awready <= '0';
      check_equal(awaddr, std_logic_vector'(x"01234567"), "awaddr");

      wait until rising_edge(clk);
      wready <= '1';
      wait until (wready and wvalid) = '1' and rising_edge(clk);
      wready <= '0';
      check_equal(wdata, std_logic_vector'(x"1122"), "wdata");
      check_equal(wstrb, std_logic_vector'("11"), "wstrb");

      wait until rising_edge(clk);
      bvalid <= '1';
      bresp <= axi_resp_okay;
      wait until (bready and bvalid) = '1' and rising_edge(clk);
      bvalid <= '0';

      wait until rising_edge(clk);
      arready <= '1';
      wait until (arready and arvalid) = '1' and rising_edge(clk);
      arready <= '0';
      check_equal(araddr, std_logic_vector'(x"01234567"), "araddr");

      wait until rising_edge(clk);
      rvalid <= '1';
      rresp <= axi_resp_okay;
      rdata <= x"5566";
      wait until (rready and rvalid) = '1' and rising_edge(clk);
      rvalid <= '0';

      done <= true;

    end if;
  end process;

  check_not_valid : process
    constant a_addr_invalid_value : std_logic_vector(araddr'range) := (others => 'X');
    constant wdata_invalid_value : std_logic_vector(wdata'range) := (others => 'X');
    constant wstrb_invalid_value : std_logic_vector(wstrb'range) := (others => 'X');
  begin
    wait until rising_edge(clk);

    -- All signals should be driven with 'X' when the channel is not valid
    -- (R and B channels have no outputs from the VC, except for handshake).

    if not arvalid then
      check_equal(araddr, a_addr_invalid_value, "ARADDR not X when ARVALID low");
    end if;

    if not awvalid then
      check_equal(awaddr, a_addr_invalid_value, "AWADDR not X when AWVALID low");
    end if;

    if not wvalid then
      check_equal(wdata, wdata_invalid_value, "WDATA not X when WVALID low");
      check_equal(wstrb, wstrb_invalid_value, "WSTRB not X when WVALID low");
    end if;
  end process;

  dut : entity work.axi_lite_master
    generic map (
      bus_handle => bus_handle)
    port map (
      aclk    => clk,
      arready => arready,
      arvalid => arvalid,
      araddr  => araddr,
      rready  => rready,
      rvalid  => rvalid,
      rdata   => rdata,
      rresp   => rresp,
      awready => awready,
      awvalid => awvalid,
      awaddr  => awaddr,
      wready  => wready,
      wvalid  => wvalid,
      wdata   => wdata,
      wstrb   => wstrb,
      bvalid  => bvalid,
      bready  => bready,
      bresp   => bresp);

  clk <= not clk after 5 ns;

end architecture;
