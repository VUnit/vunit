-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use vunit_lib.signal_checker_pkg.all;

use work.axil_pkg.all;
use work.axi_dma_regs_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_axi_dma_regs is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_axi_dma_regs is
  constant axil_bus : bus_master_t := new_bus(data_length => 32, address_length => 32);

  constant clk_period : time := 1 ns;

  signal clk      : std_logic := '1';
  signal axil_m2s : axil_m2s_t := axil_m2s_init;
  signal axil_s2m : axil_s2m_t;

  signal start_transfer : std_logic;
  signal transfer_done  : std_logic  := '0';
  signal src_address    : std_logic_vector(31 downto 0);
  signal dst_address    : std_logic_vector(31 downto 0);
  signal num_bytes      : std_logic_vector(31 downto 0);

  constant src_address_checker : signal_checker_t := new_signal_checker(
    logger => get_logger("src_address_checker"));

  constant dst_address_checker : signal_checker_t := new_signal_checker(
    logger => get_logger("dst_address_checker"));

  constant num_bytes_checker : signal_checker_t := new_signal_checker(
    logger => get_logger("num_bytes_checker"));

  constant start_transfer_checker : signal_checker_t := new_signal_checker(
    logger => get_logger("start_transfer_checker"));

begin

  main : process
    variable rnd : RandomPType;
    variable nbytes, src_addr, dst_addr, rdata : std_logic_vector(axil_s2m.r.data'range);
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("Test source address") then
      src_addr := rnd.RandSlv(src_addr'length);
      expect(net, src_address_checker, src_addr, now + 3 * clk_period);
      write_bus(net, axil_bus, src_address_reg_addr, src_addr);
      wait_until_idle(net, axil_bus);
      wait_until_idle(net, src_address_checker);

    elsif run("Test destination address") then
      dst_addr := rnd.RandSlv(dst_addr'length);
      expect(net, dst_address_checker, dst_addr, now + 3 * clk_period);
      write_bus(net, axil_bus, dst_address_reg_addr, dst_addr);
      wait_until_idle(net, axil_bus);
      wait_until_idle(net, dst_address_checker);

    elsif run("Test num bytes") then
      nbytes := rnd.RandSlv(nbytes'length);
      expect(net, num_bytes_checker, nbytes, now + 3 * clk_period);
      write_bus(net, axil_bus, num_bytes_reg_addr, nbytes);
      wait_until_idle(net, axil_bus);
      wait_until_idle(net, num_bytes_checker);

    elsif run("Test start transfer command") then
      expect(net, start_transfer_checker, "1", now + 3 * clk_period);
      expect(net, start_transfer_checker, "0", now + 4 * clk_period);
      write_bus(net, axil_bus, command_reg_addr, start_transfer_command);
      wait_until_idle(net, axil_bus);
      wait_until_idle(net, start_transfer_checker);

    elsif run("Test status register") then
      check_bus(net, axil_bus, status_reg_addr, (transfer_done_status'range => '0'),
                msg => "Transfer done low initially");
      transfer_done <= '1';
      wait for 0 ns;
      check_bus(net, axil_bus, status_reg_addr, transfer_done_status,
                msg => "Transfer done high when set");
      transfer_done <= '0';
      wait for 0 ns;
      check_bus(net, axil_bus, status_reg_addr, (transfer_done_status'range => '0'),
                msg => "Transfer done low when cleared");
    end if;

    -- Avoid unexpected change of data after test
    wait for 100 * clk_period;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 1 ms);

  dut: entity work.axi_dma_regs
    port map (
      clk            => clk,
      axils_m2s      => axil_m2s,
      axils_s2m      => axil_s2m,
      start_transfer => start_transfer,
      transfer_done  => transfer_done,
      src_address    => src_address,
      dst_address    => dst_address,
      num_bytes      => num_bytes);

  clk <= not clk after clk_period / 2;

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

  src_address_checker_inst: entity vunit_lib.std_logic_checker
    generic map (
      signal_checker => src_address_checker)
    port map (
      value => src_address);

  dst_address_checker_inst: entity vunit_lib.std_logic_checker
    generic map (
      signal_checker => dst_address_checker)
    port map (
      value => dst_address);

  num_bytes_checker_inst: entity vunit_lib.std_logic_checker
    generic map (
      signal_checker => num_bytes_checker)
    port map (
      value => num_bytes);

  start_transfer_checker_inst: entity vunit_lib.std_logic_checker
    generic map (
      signal_checker => start_transfer_checker)
    port map (
      value(0) => start_transfer);

end architecture;
