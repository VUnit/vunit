-- Run types package provides common types used by all VHDL implementations.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;
use work.dict_pkg.all;
use work.event_private_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package run_types_pkg is
  constant max_n_test_cases : natural := 1024;

  -- Deprecated
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
  subtype string_seed_t is string(1 to 16);
  subtype unsigned_seed_t is unsigned(63 downto 0);
  subtype signed_seed_t is signed(63 downto 0);

  constant runner_exit_with_errors : std_logic := 'Z';
  constant runner_exit_without_errors : std_logic := '1';

  subtype runner_sync_t is std_logic_vector(0 to 4 * basic_event_length - 1 + 1);
  constant runner_phase_idx : natural := 0;
  constant runner_timeout_update_idx : natural := basic_event_length;
  constant runner_timeout_idx : natural := 2 * basic_event_length;
  constant vunit_error_idx : natural := 3 * basic_event_length;
  constant runner_exit_status_idx : natural :=4 * basic_event_length;

  -- Private
  constant run_db : dict_t := new_dict;
end package;

package body run_types_pkg is
end package body run_types_pkg;
