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
use vunit_lib.avalon_stream_pkg.all;
use vunit_lib.stream_slave_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.vc_pkg.all;

entity tb_avalon_sink_compliance is
  generic(
    runner_cfg : string);
end entity;

architecture tb of tb_avalon_sink_compliance is

  constant sink : avalon_sink_t := new_avalon_sink(
    data_length => 8
  );

  signal clk : std_logic;
  signal ready : std_logic;
  signal valid : std_logic;
  signal sop : std_logic;
  signal eop : std_logic;
  signal data : std_logic_vector(data_length(sink)-1 downto 0);

begin
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    test_runner_cleanup(runner);
  end process test_runner;

  vc_inst: entity vunit_lib.avalon_sink
    generic map(sink)
    port map(
      clk => clk,
      ready => ready,
      valid => valid,
      sop => sop,
      eop => eop,
      data => data
    );

end architecture;
