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

  procedure set_inactive_axi_stream_policy(
    master : axi_stream_master_t;
    inactive_policy : inactive_bus_policy_t;
    axi_stream_signal : axi_stream_signal_t
  );

  impure function get_inactive_axi_stream_policy(master : axi_stream_master_t) return inactive_axi_stream_policy_t;

  impure function get_stall_config(master : axi_stream_master_t) return stall_config_t;
  impure function get_stall_config(slave : axi_stream_slave_t) return stall_config_t;
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

  procedure set_inactive_axi_stream_policy(
    master : axi_stream_master_t;
    inactive_policy : inactive_bus_policy_t;
    axi_stream_signal : axi_stream_signal_t
  ) is
    variable start, stop : axi_stream_signal_t := axi_stream_signal;
  begin
    if axi_stream_signal = all_signals then
      start := tdata;
      stop := tuser;
    end if;

    for sig in start to stop loop
      set(
        to_integer_vector_ptr(get(master.p_config, p_interactive_policy_idx)),
        axi_stream_signal_t'pos(sig),
        inactive_bus_policy_t'pos(inactive_policy)
      );
    end loop;
  end;

  impure function to_inactive_axi_stream_policy(vec : integer_vector_ptr_t) return inactive_axi_stream_policy_t is
    variable inactive_policy : inactive_axi_stream_policy_t;
  begin
    for sig in inactive_policy'range loop
      inactive_policy(sig) := inactive_bus_policy_t'val(get(vec, axi_stream_signal_t'pos(sig)));
    end loop;

    return inactive_policy;
  end;

  impure function get_inactive_axi_stream_policy(master : axi_stream_master_t) return inactive_axi_stream_policy_t is
  begin
    return to_inactive_axi_stream_policy(to_integer_vector_ptr(get(master.p_config, p_interactive_policy_idx)));
  end;

  impure function to_stall_config(vec : integer_vector_ptr_t) return stall_config_t is
    variable stall_config : stall_config_t;
  begin
    stall_config.stall_probability := real(get(vec, 0)) * (2.0 ** (-23));
    stall_config.min_stall_cycles := get(vec, 1);
    stall_config.max_stall_cycles := get(vec, 2);

    return stall_config;
  end;

  impure function get_stall_config(master : axi_stream_master_t) return stall_config_t is
  begin
    return to_stall_config(to_integer_vector_ptr(get(master.p_config, p_stall_config_idx)));
  end;

  impure function get_stall_config(slave : axi_stream_slave_t) return stall_config_t is
  begin
    return to_stall_config(to_integer_vector_ptr(get(slave.p_config, p_stall_config_idx)));
  end;
end package body;
