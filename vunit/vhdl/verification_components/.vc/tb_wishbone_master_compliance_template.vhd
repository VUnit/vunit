-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
library osvvm;
library vunit_lib;
context vunit_lib.com_context;
context vunit_lib.vunit_context;
use ieee.std_logic_1164.all;
use osvvm.randompkg.all;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.com_types_pkg.all;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;
use vunit_lib.wishbone_pkg.all;

entity tb_wishbone_master_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_wishbone_master_compliance is

  constant wishbone_master : wishbone_master_t := new_wishbone_master(
    data_length => 32,
    address_length => 32
  );

  signal clk : std_logic;
  signal adr : std_logic_vector(31 downto 0);
  signal dat_i : std_logic_vector(31 downto 0);
  signal dat_o : std_logic_vector(31 downto 0);
  signal sel : std_logic_vector(3 downto 0);
  signal cyc : std_logic;
  signal stb : std_logic;
  signal we : std_logic;
  signal stall : std_logic;
  signal ack : std_logic;

begin
  -- DO NOT modify the test runner process.
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  -- DO NOT modify the VC instantiation.
  vc_inst: entity vunit_lib.wishbone_master
    generic map(wishbone_master)
    port map(
      clk => clk,
      adr => adr,
      dat_i => dat_i,
      dat_o => dat_o,
      sel => sel,
      cyc => cyc,
      stb => stb,
      we => we,
      stall => stall,
      ack => ack
    );

end architecture;
