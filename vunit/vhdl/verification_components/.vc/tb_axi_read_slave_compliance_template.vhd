-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
library vunit_lib;
context vunit_lib.com_context;
context vunit_lib.vc_context;
context vunit_lib.vunit_context;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use vunit_lib.axi_pkg.all;
use vunit_lib.axi_slave_pkg.all;
use vunit_lib.axi_slave_private_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_axi_read_slave_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_axi_read_slave_compliance is

  constant memory : memory_t := new_memory;
  constant axi_slave : axi_slave_t := new_axi_slave(
    memory => memory
  );

  constant log_data_size : integer := 4;
  constant data_size : integer := 2**log_data_size;

  signal aclk : std_logic;
  signal arvalid : std_logic;
  signal arready : std_logic;
  signal arid : std_logic_vector(3 downto 0);
  signal araddr : std_logic_vector(31 downto 0);
  signal arlen : axi4_len_t;
  signal arsize : axi4_size_t;
  signal arburst : axi_burst_type_t;
  signal rvalid : std_logic;
  signal rready : std_logic;
  signal rid : std_logic_vector(arid'range);
  signal rdata : std_logic_vector(8*data_size-1 downto 0);
  signal rresp : axi_resp_t;
  signal rlast : std_logic;

begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  vc_inst: entity vunit_lib.axi_read_slave
    generic map(axi_slave)

    port map(
      aclk => aclk,
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
      rlast => rlast
      );

end architecture;
