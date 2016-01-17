-- Run types package provides common types used by all VHDL implementations.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;
use work.dictionary.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package run_types_pkg is
  constant max_locked_time_c : time := 1 ms;
  constant max_n_test_cases_c : natural := 1024;
  constant unknown_num_of_test_cases_c : integer := integer'left;

  subtype runner_cfg_t is string; -- Subtype deprecated, use string instead
  constant runner_cfg_default : string := "enabled_test_cases : __all__, output path : , active python runner : false";
  subtype test_cases_t is string;

  subtype runner_phase_t is std_logic_vector(3 downto 0);
  constant test_runner_entry_phase : runner_phase_t := "ZZZZ";
  constant test_runner_setup_phase : runner_phase_t := X"2";
  constant test_suite_setup_phase : runner_phase_t := X"3";
  constant test_case_setup_phase : runner_phase_t := X"4";
  constant test_case_phase : runner_phase_t := X"5";
  constant test_case_cleanup_phase : runner_phase_t := X"6";
  constant test_suite_cleanup_phase : runner_phase_t := X"7";
  constant test_runner_cleanup_phase : runner_phase_t := X"8";
  constant test_runner_exit_phase : runner_phase_t := "UUUU";

  function "<" (
    constant l, r : runner_phase_t)
    return boolean;

  function ">" (
    constant l, r : runner_phase_t)
    return boolean;

  function index_of (
    constant phase : runner_phase_t)
    return natural;

  function to_string (
    constant phase : runner_phase_t)
    return string;

  constant resolved_true_c : std_logic := '1';
  constant resolved_false_c : std_logic := 'Z';
  type phase_locks_t is record
    entry_is_locked : std_logic;
    exit_is_locked : std_logic;
  end record phase_locks_t;
  type phase_locks_array_t is array (natural range <>) of phase_locks_t;

  type runner_sync_t is record
    phase : runner_phase_t;
    locks : phase_locks_array_t(to_integer(unsigned(test_runner_setup_phase)) to
                                to_integer(unsigned(test_runner_cleanup_phase)));
    exit_without_errors : std_logic;
    exit_simulation : std_logic;
  end record runner_sync_t;

  type test_case_names_t is array (positive range <>) of line;

  type runner_state_t is record
    active_python_runner : boolean;
    runner_phase : runner_phase_t;
    test_case_names : test_case_names_t(1 to max_n_test_cases_c);
    n_test_cases : integer;
    active_test_case_index : positive;
    test_suite_completed : boolean;
    test_suite_iteration : natural;
    run_test_cases : test_case_names_t(1 to max_n_test_cases_c);
    running_test_case_v : line;
    n_run_test_cases : natural;
    has_run_since_last_loop_check : boolean;
    run_all : boolean;
    test_case_iteration : natural;
    test_case_exit_after_error : boolean;
    test_suite_exit_after_error : boolean;
    runner_cfg : line;
  end record runner_state_t;

end package;

package body run_types_pkg is
  function index_of (
    constant phase : runner_phase_t)
    return natural is
  begin
    if phase = test_runner_entry_phase then
      return 1;
    elsif phase = test_runner_exit_phase then
      return 9;
    elsif is_x(phase) then
      return 0;
    else
      return to_integer(unsigned(phase));
    end if;
  end function index_of;

  function "<" (
    constant l, r : runner_phase_t)
    return boolean is
  begin
    return index_of(l) < index_of(r);
  end function;

  function ">" (
    constant l, r : runner_phase_t)
    return boolean is
  begin
    return index_of(l) > index_of(r);
  end function;

  function to_string (
    constant phase : runner_phase_t)
    return string is
  begin
    case phase is
      when test_runner_entry_phase =>
        return "test runner entry phase";
      when test_runner_setup_phase =>
        return "test runner setup phase";
      when test_suite_setup_phase =>
        return "test suite setup phase";
      when test_case_setup_phase =>
        return "test case setup phase";
      when test_case_phase =>
        return "test case phase";
      when test_case_cleanup_phase =>
        return "test case cleanup phase";
      when test_suite_cleanup_phase =>
        return "test suite cleanup phase";
      when test_runner_cleanup_phase =>
        return "test runner cleanup phase";
      when test_runner_exit_phase =>
        return "test runner exit phase";
      when others =>
        return "unknown";
    end case;
  end function to_string;

end package body run_types_pkg;
