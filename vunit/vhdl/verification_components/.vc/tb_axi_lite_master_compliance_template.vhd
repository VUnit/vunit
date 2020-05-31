-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
library vunit_lib;
context vunit_lib.com_context;
context vunit_lib.vunit_context;
use ieee.std_logic_1164.all;
use vunit_lib.axi_lite_master_pkg.all;
use vunit_lib.axi_pkg.all;
use vunit_lib.axi_slave_pkg.all;
use vunit_lib.axi_slave_private_pkg.all;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_axi_lite_master_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_axi_lite_master_compliance is

  constant bus_handle : bus_master_t := new_bus(
    data_length => 32,
    address_length => 32
  );

  signal aclk : std_logic;
  signal arready : std_logic;
  signal arvalid : std_logic;
  signal araddr : std_logic_vector(address_length(bus_handle) - 1 downto 0);
  signal rready : std_logic;
  signal rvalid : std_logic;
  signal rdata : std_logic_vector(data_length(bus_handle) - 1 downto 0);
  signal rresp : axi_resp_t;
  signal awready : std_logic;
  signal awvalid : std_logic;
  signal awaddr : std_logic_vector(address_length(bus_handle) - 1 downto 0);
  signal wready : std_logic;
  signal wvalid : std_logic;
  signal wdata : std_logic_vector(data_length(bus_handle) - 1 downto 0);
  signal wstrb : std_logic_vector(byte_enable_length(bus_handle) - 1 downto 0);
  signal bvalid : std_logic;
  signal bready : std_logic;

begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  vc_inst: entity vunit_lib.axi_lite_master
    generic map(bus_handle)
    port map(
      aclk => aclk,
      arready => arready,
      arvalid => arvalid,
      araddr => araddr,
      rready => rready,
      rvalid => rvalid,
      rdata => rdata,
      rresp => rresp,
      awready => awready,
      awvalid => awvalid,
      awaddr => awaddr,
      wready => wready,
      wvalid => wvalid,
      wdata => wdata,
      wstrb => wstrb,
      bvalid => bvalid,
      bready => bready,
      bresp => open
    );

end architecture;
