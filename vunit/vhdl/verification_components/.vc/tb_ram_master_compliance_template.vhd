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
use vunit_lib.bus_master_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.ram_master_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_ram_master_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_ram_master_compliance is

  constant ram_master : ram_master_t := new_ram_master(
    data_length => 32,
    address_length => 32,
    latency => 2
  );

  signal clk : std_logic;
  signal en : std_logic;
  signal we : std_logic_vector(byte_enable_length(as_bus_master(ram_master))-1 downto 0);
  signal addr : std_logic_vector(address_length(as_bus_master(ram_master)) - 1 downto 0);
  signal wdata : std_logic_vector(data_length(as_bus_master(ram_master)) - 1 downto 0);
  signal rdata : std_logic_vector(data_length(as_bus_master(ram_master)) - 1 downto 0);

begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  vc_inst: entity vunit_lib.ram_master
    generic map(ram_master)
    port map(
      clk => clk,
      en => en,
      we => we,
      addr => addr,
      wdata => wdata,
      rdata => rdata
    );

end architecture;
