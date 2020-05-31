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
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_axi_stream_monitor_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_axi_stream_monitor_compliance is

  constant monitor : axi_stream_monitor_t := new_axi_stream_monitor(
    data_length => 8
  );

  signal aclk : std_logic;
  signal tvalid : std_logic;
  signal tdata : std_logic_vector(data_length(monitor) - 1 downto 0);

begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  vc_inst: entity vunit_lib.axi_stream_monitor
    generic map(monitor)
    port map(
      aclk => aclk,
      tvalid => tvalid,
      tready => open,
      tdata => tdata,
      tlast => open,
      tkeep => open,
      tstrb => open,
      tid => open,
      tdest => open,
      tuser => open
    );

end architecture;
