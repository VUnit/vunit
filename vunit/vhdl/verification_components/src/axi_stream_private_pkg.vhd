-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.axi_stream_pkg.all;
use work.axi_pkg.all;
use work.integer_vector_ptr_pkg.all;

package axi_stream_private_pkg is
  procedure probability_stall_axi_stream(
    signal aclk  : in std_logic;
    stall_config : in stall_config_t;
    rnd          : inout RandomPType
  );

  function resolve_tstrb(
    tkeep : std_logic_vector;
    tstrb : std_logic_vector
  ) return std_logic_vector;
end package;

package body axi_stream_private_pkg is
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

  function resolve_tstrb(
    tkeep : std_logic_vector;
    tstrb : std_logic_vector
  ) return std_logic_vector is
  begin
    if tstrb = (tstrb'range => 'U') then
      return tkeep;
    else
      return tstrb;
    end if;
  end;
end package body;
