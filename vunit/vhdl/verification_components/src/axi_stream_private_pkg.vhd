-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.axi_stream_pkg.all;

package axi_stream_private_pkg is
  procedure probability_stall_axi_stream(
      signal aclk : in std_logic;
      axi_stream  : in axi_stream_slave_t;
      rnd         : inout RandomPType
    );

  procedure probability_stall_axi_stream(
      signal aclk : in std_logic;
      axi_stream  : in axi_stream_master_t;
      rnd         : inout RandomPType
    );

  procedure probability_stall_axi_stream(
      signal aclk  : in std_logic;
      stall_config : in stall_config_t;
      rnd          : inout RandomPType
    );

end package;

package body axi_stream_private_pkg is

  procedure probability_stall_axi_stream(
    signal aclk : in std_logic;
    axi_stream  : in axi_stream_master_t;
    rnd         : inout RandomPType) is
  begin
    probability_stall_axi_stream(aclk, axi_stream.p_stall_config, rnd);
  end procedure;

  procedure probability_stall_axi_stream(
    signal aclk : in std_logic;
    axi_stream  : in axi_stream_slave_t;
    rnd         : inout RandomPType) is
  begin
    probability_stall_axi_stream(aclk, axi_stream.p_stall_config, rnd);
  end procedure;

  procedure probability_stall_axi_stream(
    signal aclk  : in std_logic;
    stall_config : in stall_config_t;
    rnd          : inout RandomPType) is
    variable num_stall_cycles : natural := 0;
  begin
    if rnd.Uniform(0.0, 1.0) < stall_config.stall_probability then
      num_stall_cycles := rnd.FavorSmall(stall_config.min_stall_cycles, stall_config.max_stall_cycles);
    end if;
    for stall in 0 to num_stall_cycles-1 loop
       wait until rising_edge(aclk);
    end loop;
  end procedure;

end package body;
