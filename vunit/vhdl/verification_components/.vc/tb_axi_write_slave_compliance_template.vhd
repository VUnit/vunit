-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
library vunit_lib;
context vunit_lib.com_context;
context vunit_lib.vunit_context;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use vunit_lib.axi_pkg.all;
use vunit_lib.axi_slave_pkg.all;
use vunit_lib.axi_slave_private_pkg.all;
use vunit_lib.integer_vector_ptr_pkg.all;
use vunit_lib.integer_vector_ptr_pool_pkg.all;
use vunit_lib.memory_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_axi_write_slave_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_axi_write_slave_compliance is
  constant axi_slave : axi_slave_t := new_axi_slave(
    memory => new_memory
  );

  constant log_data_size : integer := 4;
  constant data_size     : integer := 2**log_data_size;

  signal aclk : std_logic;
  signal awvalid : std_logic;
  signal awready : std_logic;
  signal awid : std_logic_vector(3 downto 0);
  signal awaddr : std_logic_vector(31 downto 0);
  signal awlen : std_logic_vector(7 downto 0);
  signal awsize : std_logic_vector(2 downto 0);
  signal awburst : axi_burst_type_t;
  signal wvalid : std_logic;
  signal wready : std_logic;
  signal wdata : std_logic_vector(8*data_size-1 downto 0);
  signal wstrb : std_logic_vector(data_size downto 0);
  signal wlast : std_logic;
  signal bvalid : std_logic;
  signal bready : std_logic;
  signal bid : std_logic_vector(awid'range);
  signal bresp : axi_resp_t;

begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  vc_inst: entity vunit_lib.axi_write_slave
    generic map(axi_slave)
    port map(
      aclk => aclk,
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
      bresp => bresp
    );

end architecture;
