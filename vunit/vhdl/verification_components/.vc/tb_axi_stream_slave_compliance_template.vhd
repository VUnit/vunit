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
use vunit_lib.axi_stream_pkg.all;
use vunit_lib.stream_slave_pkg.all;
use vunit_lib.string_ptr_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_axi_stream_slave_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_axi_stream_slave_compliance is

  constant slave : axi_stream_slave_t := new_axi_stream_slave(
    data_length => 8
  );

  signal aclk : std_logic;
  signal tvalid : std_logic;
  signal tready : std_logic;
  signal tdata : std_logic_vector(data_length(slave)-1 downto 0);

begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  vc_inst: entity vunit_lib.axi_stream_slave
    generic map(slave)
    port map(
      aclk => aclk,
      areset_n => open,
      tvalid => tvalid,
      tready => tready,
      tdata => tdata,
      tlast => open,
      tkeep => open,
      tstrb => open,
      tid => open,
      tdest => open,
      tuser => open
    );

end architecture;
