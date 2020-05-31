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
use vunit_lib.queue_pkg.all;
use vunit_lib.stream_master_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_axi_stream_master_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_axi_stream_master_compliance is

  constant master : axi_stream_master_t := new_axi_stream_master(
    data_length => 8
  );

  signal aclk : std_logic;
  signal tvalid : std_logic;
  signal tdata : std_logic_vector(data_length(master)-1 downto 0);
  signal tlast : std_logic;
  signal tkeep : std_logic_vector(data_length(master)/8-1 downto 0);
  signal tstrb : std_logic_vector(data_length(master)/8-1 downto 0);
  signal tid : std_logic_vector(id_length(master)-1 downto 0);
  signal tdest : std_logic_vector(dest_length(master)-1 downto 0);
  signal tuser : std_logic_vector(user_length(master)-1 downto 0);

begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  vc_inst: entity vunit_lib.axi_stream_master
    generic map(master)
    port map(
      aclk => aclk,
      areset_n => open,
      tvalid => tvalid,
      tready => open,
      tdata => tdata,
      tlast => tlast,
      tkeep => tkeep,
      tstrb => tstrb,
      tid => tid,
      tdest => tdest,
      tuser => tuser
    );

end architecture;
