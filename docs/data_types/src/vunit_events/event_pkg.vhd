-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use vunit_lib.runner_pkg.all;
use vunit_lib.id_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

library osvvm;
use osvvm.RandomPkg.all;

use work.incrementer_pkg.all;

package event_pkg is
  -- start_snippet event_creation
  signal new_data_set : event_t := new_event("new_data_set");
  -- The above is equivalent to
  -- signal new_data_set : event_t := new_event(get_id("new_data_set"));
  -- end_snippet event_creation

  -- start_snippet dut_checker_logger
  constant dut_checker_logger : logger_t := get_logger("dut_checker");
  -- end_snippet dut_checker_logger
  signal dut_checker_done : event_t := new_event("dut_checker:done");

  constant clk_period : time := 4 ns;
  constant max_latency : time := 20 * clk_period;
  constant queue : queue_t := new_queue;
  shared variable rnd : RandomPType;
  constant n_data_sets : positive := 3;

  constant ctrl_bus : bus_master_t := new_bus(data_length => 32,
                                              address_length => 8,
                                              actor => new_actor("AXI Lite Master"));

  function calculate_expected_output(input_data : integer) return std_logic_vector;
end;

package body event_pkg is
  function calculate_expected_output(input_data : integer) return std_logic_vector is
  begin
    return to_slv(input_data + 1, 16);
  end;
end;
