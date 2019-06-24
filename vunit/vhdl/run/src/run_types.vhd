-- Run types package provides common types used by all VHDL implementations.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;
use work.dictionary.all;

library ieee;
use ieee.std_logic_1164.all;

package run_types_pkg is
  constant max_locked_time : time := 1 ms;
  constant max_n_test_cases : natural := 1024;

  -- Default value for timeout parameters. ModelSim can't handle time'high
  constant max_timeout : time := 1 hr;

  -- Deprecated
  constant max_locked_time_c : time := max_locked_time;
  constant max_n_test_cases_c : natural := max_n_test_cases;

  subtype runner_cfg_t is string; -- Subtype deprecated, use string instead
  constant runner_cfg_default : string := "enabled_test_cases : __all__, output path : , active python runner : false";
  subtype test_cases_t is string;

  type runner_phase_t is (test_runner_entry, test_runner_setup, test_suite_setup, test_case_setup,
                          test_case, test_case_cleanup, test_suite_cleanup, test_runner_cleanup,
                          test_runner_exit);
  subtype runner_legal_phase_t is runner_phase_t range test_runner_setup to test_runner_cleanup;

  type phase_locks_t is record
    entry_is_locked : boolean;
    exit_is_locked : boolean;
  end record;

  type boolean_array_t is array (integer range <>) of boolean;

  constant runner_event_idx : natural := 0;
  constant runner_exit_status_idx : natural := 1;
  constant runner_timeout_update_idx : natural := 2;
  constant runner_timeout_idx : natural := 3;

  constant runner_event : std_logic := '1';
  constant idle_runner : std_logic := 'Z';

  constant runner_exit_with_errors : std_logic := 'Z';
  constant runner_exit_without_errors : std_logic := '1';

  subtype runner_sync_t is std_logic_vector(runner_event_idx to runner_timeout_idx);
end package;

package body run_types_pkg is
end package body run_types_pkg;
