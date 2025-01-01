-- Run base package provides fundamental run functionality.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ptr_pkg.all;
use work.string_ptr_pool_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.integer_vector_ptr_pool_pkg.all;
use work.run_types_pkg.all;
use work.logger_pkg.all;
use work.string_ops.all;
use work.codec_pkg.all;

package runner_pkg is
  constant runner_trace_logger : logger_t := get_logger("runner");

  type runner_t is record
    p_data : integer_vector_ptr_t;
  end record;

  type key_t is record
    p_is_entry_key : boolean;
    p_phase : runner_legal_phase_t;
    p_key_id : natural;
  end record;

  constant null_runner : runner_t := (p_data => null_ptr);
  constant unknown_num_of_test_cases : integer := integer'left;

  -- Deprecated
  constant unknown_num_of_test_cases_c : integer := unknown_num_of_test_cases;

  impure function new_runner return runner_t;

  procedure runner_init(runner : runner_t);
  procedure set_active_python_runner(runner : runner_t; value : boolean);
  impure function has_active_python_runner(runner : runner_t) return boolean;

  impure function get_base_seed(runner : runner_t) return string;
  procedure set_base_seed(runner : runner_t; value : string);

  impure function get_entry_key(runner : runner_t; phase : runner_legal_phase_t) return key_t;
  impure function get_exit_key(runner : runner_t; phase : runner_legal_phase_t) return key_t;
  impure function is_locked(runner : runner_t; key : key_t) return boolean;
  procedure lock(runner : runner_t; key : key_t);
  procedure unlock(runner : runner_t; key : key_t);

  impure function entry_is_locked(runner : runner_t; phase : runner_legal_phase_t) return boolean;
  impure function exit_is_locked(runner : runner_t; phase : runner_legal_phase_t) return boolean;

  procedure set_phase(runner : runner_t; new_phase : runner_phase_t);

  impure function get_phase(runner : runner_t) return runner_phase_t;

  procedure set_gate_status(runner : runner_t; is_within_gates : boolean);

  impure function is_within_gates(runner : runner_t; phase : runner_legal_phase_t) return boolean;

  procedure set_test_case_name(runner : runner_t; index : positive; new_name : string);

  impure function get_test_case_name(runner : runner_t; index : positive) return string;

  procedure set_num_of_test_cases(runner : runner_t; new_value : integer);

  procedure inc_num_of_test_cases(runner : runner_t);

  impure function get_num_of_test_cases(runner : runner_t) return integer;

  impure function get_active_test_case_index(runner : runner_t) return integer;

  procedure inc_active_test_case_index(runner : runner_t);

  procedure set_test_suite_completed(runner : runner_t);

  impure function get_test_suite_completed(runner : runner_t) return boolean;

  impure function get_test_suite_iteration(runner : runner_t) return natural;

  procedure inc_test_suite_iteration(runner : runner_t);

  procedure set_run_test_case(runner : runner_t; index : positive; new_name : string);

  impure function get_run_test_case(runner : runner_t; index : positive) return string;

  procedure set_running_test_case(runner : runner_t; new_name : string);

  impure function get_running_test_case(runner : runner_t) return string;

  impure function get_num_of_run_test_cases(runner : runner_t) return natural;

  procedure inc_num_of_run_test_cases(runner : runner_t);

  procedure set_has_run_since_last_loop_check(runner : runner_t);

  procedure clear_has_run_since_last_loop_check(runner : runner_t);

  impure function get_has_run_since_last_loop_check(runner : runner_t) return boolean;

  procedure set_run_all(runner : runner_t);

  procedure set_run_all(runner : runner_t; new_value : boolean);

  impure function get_run_all(runner : runner_t) return boolean;

  impure function get_test_case_iteration(runner : runner_t) return natural;

  procedure inc_test_case_iteration(runner : runner_t);

  procedure init_test_case_iteration(runner : runner_t);

  procedure set_test_case_exit_after_error(runner : runner_t);

  procedure clear_test_case_exit_after_error(runner : runner_t);

  impure function get_test_case_exit_after_error(runner : runner_t) return boolean;

  procedure set_test_suite_exit_after_error(runner : runner_t);

  procedure clear_test_suite_exit_after_error(runner : runner_t);

  impure function get_test_suite_exit_after_error(runner : runner_t) return boolean;

  procedure set_cfg(runner : runner_t; new_value : string);

  impure function get_cfg(runner : runner_t) return string;

  procedure set_timeout(runner : runner_t; timeout : time);
  impure function get_timeout(runner : runner_t) return time;

  -- Private procedures only use for VUnit internal testing
  procedure p_disable_simulation_exit(runner : runner_t);
  impure function p_simulation_exit_is_disabled(runner : runner_t) return boolean;
end package;

package body runner_pkg is

  constant active_python_runner_idx : natural := 0;
  constant runner_phase_idx : natural := 1;
  constant test_case_names_idx : natural := 2;
  constant n_test_cases_idx : natural := 3;
  constant active_test_case_index_idx : natural := 4;
  constant test_suite_completed_idx : natural := 5;
  constant test_suite_iteration_idx : natural := 6;
  constant run_test_cases_idx : natural := 7;
  constant running_test_case_idx : natural := 8;
  constant n_run_test_cases_idx : natural := 9;
  constant has_run_since_last_loop_check_idx : natural := 10;
  constant run_all_idx : natural := 11;
  constant test_case_iteration_idx : natural := 12;
  constant test_case_exit_after_error_idx : natural := 13;
  constant test_suite_exit_after_error_idx : natural := 14;
  constant runner_cfg_idx : natural := 15;
  constant disable_simulation_exit_idx : natural := 16;
  constant entry_locks_idx : natural := 17;
  constant exit_locks_idx : natural := 18;
  constant timeout_idx : natural := 19;
  constant is_within_gates_idx : natural := 20;
  constant base_seed_idx : natural := 21;
  constant runner_length : natural := base_seed_idx + 1;

  constant n_locks : positive := 254;
  constant n_locked_idx : natural := 0;
  constant n_used_locks_idx : natural := 1;
  constant lock_idx : natural := 2;
  constant lock_is_unlocked : natural := 0;
  constant lock_is_locked : natural := 1;

  function to_integer(value : boolean) return natural is
  begin
    if value then
      return 1;
    else
      return 0;
    end if;
  end;

  constant str_pool : string_ptr_pool_t := new_string_ptr_pool;
  constant int_pool : integer_vector_ptr_pool_t := new_integer_vector_ptr_pool;

  impure function new_runner return runner_t is
    variable runner : runner_t := (p_data => new_integer_vector_ptr(int_pool, runner_length));
  begin
    runner_init(runner);
    return runner;
  end;

  procedure runner_init(runner : runner_t) is
    constant n_legal_phases : positive :=
      runner_legal_phase_t'pos(runner_legal_phase_t'high) -
      runner_legal_phase_t'pos(runner_legal_phase_t'low) + 1;
  begin
    assert runner.p_data /= null_ptr;
    reallocate(runner.p_data, runner_length);

    set_phase(runner, runner_phase_t'low);
    set_active_python_runner(runner, false);

    set(runner.p_data, test_case_names_idx, to_integer(integer_vector_ptr_t'(new_integer_vector_ptr)));

    set(runner.p_data, n_test_cases_idx, unknown_num_of_test_cases);
    set(runner.p_data, active_test_case_index_idx, 1);
    set(runner.p_data, test_suite_completed_idx, to_integer(false));
    set(runner.p_data, test_suite_iteration_idx, 0);

    set(runner.p_data, run_test_cases_idx, to_integer(integer_vector_ptr_t'(new_integer_vector_ptr)));
    set(runner.p_data, running_test_case_idx, to_integer(null_string_ptr));

    set(runner.p_data, n_run_test_cases_idx, 0);
    set(runner.p_data, has_run_since_last_loop_check_idx, to_integer(true));
    set(runner.p_data, run_all_idx, to_integer(true));
    set(runner.p_data, test_case_iteration_idx, 0);
    set(runner.p_data, test_case_exit_after_error_idx, to_integer(false));
    set(runner.p_data, test_suite_exit_after_error_idx, to_integer(false));
    set(runner.p_data, runner_cfg_idx, to_integer(new_string_ptr(str_pool, runner_cfg_default)));

    set(runner.p_data, disable_simulation_exit_idx, to_integer(false));

    set(runner.p_data, entry_locks_idx, to_integer(integer_vector_ptr_t'(new_integer_vector_ptr(n_legal_phases))));
    for idx in 0 to n_legal_phases - 1 loop
      set(to_integer_vector_ptr(get(runner.p_data, entry_locks_idx)), idx, to_integer(integer_vector_ptr_t'(new_integer_vector_ptr(lock_idx + n_locks))));
    end loop;

    set(runner.p_data, exit_locks_idx, to_integer(integer_vector_ptr_t'(new_integer_vector_ptr(n_legal_phases))));
    for idx in 0 to n_legal_phases - 1 loop
      set(to_integer_vector_ptr(get(runner.p_data, exit_locks_idx)), idx, to_integer(integer_vector_ptr_t'(new_integer_vector_ptr(lock_idx + n_locks))));
    end loop;

    set(runner.p_data, timeout_idx, to_integer(new_string_ptr(str_pool, encode(0 ns))));
    set(runner.p_data, is_within_gates_idx, 0);
    set(runner.p_data, base_seed_idx, to_integer(new_string_ptr(str_pool, "4dcb138c52fce0e7")));
  end;

  procedure set_active_python_runner(runner : runner_t; value : boolean) is
  begin
    set(runner.p_data, active_python_runner_idx, to_integer(value));
  end;

  impure function has_active_python_runner(runner : runner_t) return boolean is
  begin
    return get(runner.p_data, active_python_runner_idx) = 1;
  end function;

  impure function get_base_seed(runner : runner_t) return string is
  begin
    return to_string(to_string_ptr(get(runner.p_data, base_seed_idx)));
  end function;

  procedure set_base_seed(runner : runner_t; value : string) is
  begin
    set(runner.p_data, base_seed_idx, to_integer(new_string_ptr(str_pool, value)));
  end;

  impure function get_entry_key(runner : runner_t; phase : runner_legal_phase_t) return key_t is
    variable key : key_t;
    constant entry_locks : integer_vector_ptr_t := to_integer_vector_ptr(get(runner.p_data, entry_locks_idx));
    constant idx : natural := runner_legal_phase_t'pos(phase) - runner_legal_phase_t'pos(runner_legal_phase_t'low);
    constant lock_data : integer_vector_ptr_t := to_integer_vector_ptr(get(entry_locks, idx));
    constant n_used_locks : natural := get(lock_data, n_used_locks_idx);
  begin
    key.p_is_entry_key := true;
    key.p_key_id := n_used_locks;
    key.p_phase := phase;

    set(lock_data, n_used_locks_idx, n_used_locks + 1);

    return key;
  end;

  impure function get_exit_key(runner : runner_t; phase : runner_legal_phase_t) return key_t is
    variable key : key_t;
    constant exit_locks : integer_vector_ptr_t := to_integer_vector_ptr(get(runner.p_data, exit_locks_idx));
    constant idx : natural := runner_legal_phase_t'pos(phase) - runner_legal_phase_t'pos(runner_legal_phase_t'low);
    constant lock_data : integer_vector_ptr_t := to_integer_vector_ptr(get(exit_locks, idx));
    constant n_used_locks : natural := get(lock_data, n_used_locks_idx);
  begin
    key.p_is_entry_key := false;
    key.p_key_id := n_used_locks;
    key.p_phase := phase;

    set(lock_data, n_used_locks_idx, n_used_locks + 1);

    return key;
  end;

  impure function is_locked(runner : runner_t; key : key_t) return boolean is
    constant idx : natural := runner_legal_phase_t'pos(key.p_phase) - runner_legal_phase_t'pos(runner_legal_phase_t'low);
    variable lock_data : integer_vector_ptr_t;
  begin
    if key.p_is_entry_key then
      lock_data := to_integer_vector_ptr(get(to_integer_vector_ptr(get(runner.p_data, entry_locks_idx)), idx));
    else
      lock_data := to_integer_vector_ptr(get(to_integer_vector_ptr(get(runner.p_data, exit_locks_idx)), idx));
    end if;

    return get(lock_data, lock_idx + key.p_key_id) = lock_is_locked;
  end;

  procedure lock(runner : runner_t; key : key_t) is
    constant idx : natural := runner_legal_phase_t'pos(key.p_phase) - runner_legal_phase_t'pos(runner_legal_phase_t'low);
    variable lock_data : integer_vector_ptr_t;
  begin
    if key.p_is_entry_key then
      lock_data := to_integer_vector_ptr(get(to_integer_vector_ptr(get(runner.p_data, entry_locks_idx)), idx));
    else
      lock_data := to_integer_vector_ptr(get(to_integer_vector_ptr(get(runner.p_data, exit_locks_idx)), idx));
    end if;

    if get(lock_data, lock_idx + key.p_key_id) = lock_is_unlocked then
      set(lock_data, lock_idx + key.p_key_id, lock_is_locked);
      set(lock_data, n_locked_idx, get(lock_data, n_locked_idx) + 1);
    end if;
  end;

  procedure unlock(runner : runner_t; key : key_t) is
    constant idx : natural := runner_legal_phase_t'pos(key.p_phase) - runner_legal_phase_t'pos(runner_legal_phase_t'low);
    variable lock_data : integer_vector_ptr_t;
  begin
    if key.p_is_entry_key then
      lock_data := to_integer_vector_ptr(get(to_integer_vector_ptr(get(runner.p_data, entry_locks_idx)), idx));
    else
      lock_data := to_integer_vector_ptr(get(to_integer_vector_ptr(get(runner.p_data, exit_locks_idx)), idx));
    end if;

    if get(lock_data, lock_idx + key.p_key_id) = lock_is_locked then
      set(lock_data, lock_idx + key.p_key_id, lock_is_unlocked);
      set(lock_data, n_locked_idx, get(lock_data, n_locked_idx) - 1);
    end if;
  end;

  impure function entry_is_locked(runner : runner_t; phase : runner_legal_phase_t) return boolean is
    constant entry_locks : integer_vector_ptr_t := to_integer_vector_ptr(get(runner.p_data, entry_locks_idx));
    constant idx : natural := runner_legal_phase_t'pos(phase) - runner_legal_phase_t'pos(runner_legal_phase_t'low);
    constant lock_data : integer_vector_ptr_t := to_integer_vector_ptr(get(entry_locks, idx));
    constant n_locked : natural := get(lock_data, n_locked_idx);
  begin
    return n_locked > 0;
  end;

  impure function exit_is_locked(runner : runner_t; phase : runner_legal_phase_t) return boolean is
    constant exit_locks : integer_vector_ptr_t := to_integer_vector_ptr(get(runner.p_data, exit_locks_idx));
    constant idx : natural := runner_legal_phase_t'pos(phase) - runner_legal_phase_t'pos(runner_legal_phase_t'low);
    constant lock_data : integer_vector_ptr_t := to_integer_vector_ptr(get(exit_locks, idx));
    constant n_locked : natural := get(lock_data, n_locked_idx);
  begin
    return n_locked > 0;
  end;

  procedure set_phase(runner : runner_t; new_phase : runner_phase_t) is
  begin
    set(runner.p_data, runner_phase_idx, runner_phase_t'pos(new_phase));
  end;

  impure function get_phase(runner : runner_t) return runner_phase_t is
  begin
    return runner_phase_t'val(get(runner.p_data, runner_phase_idx));
  end;

  procedure set_gate_status(runner : runner_t; is_within_gates : boolean) is
  begin
    if is_within_gates then
      set(runner.p_data, is_within_gates_idx, 1);
    else
      set(runner.p_data, is_within_gates_idx, 0);
    end if;
  end;

  impure function is_within_gates(runner : runner_t; phase : runner_legal_phase_t) return boolean is
  begin
    if get_phase(runner) /= phase then
      return false;
    end if;

    return get(runner.p_data, is_within_gates_idx) = 1;
  end;

  procedure set_test_case_name(runner : runner_t; index : positive; new_name : string) is
    constant test_case_names : integer_vector_ptr_t := to_integer_vector_ptr(get(runner.p_data, test_case_names_idx));
    variable test_case_name : string_ptr_t;
  begin
    if index-1 >= length(test_case_names) then
      resize(test_case_names, index, value => to_integer(null_string_ptr));
    end if;

    test_case_name := to_string_ptr(get(test_case_names, index-1));

    if test_case_name = null_string_ptr then
      test_case_name := new_string_ptr(str_pool, new_name);
    else
      reallocate(test_case_name, new_name);
    end if;

    set(test_case_names, index-1, to_integer(test_case_name));
  end;

  impure function get_test_case_name(runner : runner_t; index : positive) return string  is
    constant test_case_names : integer_vector_ptr_t := to_integer_vector_ptr(get(runner.p_data, test_case_names_idx));
    variable test_case_name : string_ptr_t;
  begin
    -- @TODO fail instead?
    if index-1 >= length(test_case_names) then
      return "";
    end if;

    test_case_name := to_string_ptr(get(test_case_names, index-1));

    if test_case_name = null_string_ptr then
      return "";
    end if;

    return to_string(test_case_name);
  end;

  procedure set_num_of_test_cases(runner : runner_t; new_value : integer) is
  begin
    set(runner.p_data, n_test_cases_idx, new_value);
  end;

  procedure inc_num_of_test_cases(runner : runner_t) is
  begin
    set(runner.p_data, n_test_cases_idx, get_num_of_test_cases(runner) + 1);
  end;

  impure function get_num_of_test_cases(runner : runner_t) return integer is
  begin
    return get(runner.p_data, n_test_cases_idx);
  end;

  impure function get_active_test_case_index(runner : runner_t) return integer is
  begin
    return get(runner.p_data, active_test_case_index_idx);
  end;

  procedure inc_active_test_case_index(runner : runner_t) is
  begin
    set(runner.p_data, active_test_case_index_idx, get_active_test_case_index(runner) + 1);
  end;

  procedure set_test_suite_completed(runner : runner_t) is
  begin
    set(runner.p_data, test_suite_completed_idx, to_integer(true));
  end;

  impure function get_test_suite_completed(runner : runner_t) return boolean is
  begin
    return get(runner.p_data, test_suite_completed_idx) = 1;
  end;

  impure function get_test_suite_iteration(runner : runner_t) return natural is
  begin
    return get(runner.p_data, test_suite_iteration_idx);
  end;

  procedure inc_test_suite_iteration(runner : runner_t) is
  begin
    set(runner.p_data, test_suite_iteration_idx, get_test_suite_iteration(runner) + 1);
  end;

  procedure set_run_test_case(runner : runner_t; index : positive; new_name : string) is
    constant run_test_cases : integer_vector_ptr_t := to_integer_vector_ptr(get(runner.p_data, run_test_cases_idx));
    variable run_test_case : string_ptr_t;
  begin
    if index-1 >= length(run_test_cases) then
      resize(run_test_cases, index, value => to_integer(null_string_ptr));
    end if;

    run_test_case := to_string_ptr(get(run_test_cases, index-1));

    if run_test_case = null_string_ptr then
      run_test_case := new_string_ptr(str_pool, new_name);
    else
      reallocate(run_test_case, new_name);
    end if;

    set(run_test_cases, index-1, to_integer(run_test_case));
  end;

  impure function get_run_test_case(runner : runner_t; index : positive) return string  is
    constant run_test_cases : integer_vector_ptr_t := to_integer_vector_ptr(get(runner.p_data, run_test_cases_idx));
    variable run_test_case : string_ptr_t;
  begin
    -- @TODO fail instead?
    if index-1 >= length(run_test_cases) then
      return "";
    end if;

    run_test_case := to_string_ptr(get(run_test_cases, index-1));

    if run_test_case = null_string_ptr then
      return "";
    end if;

    return to_string(run_test_case);
  end;

  procedure set_running_test_case(runner : runner_t; new_name : string) is
    variable running_test_case : string_ptr_t := to_string_ptr(get(runner.p_data, running_test_case_idx));
  begin
    if running_test_case = null_string_ptr then
      running_test_case := new_string_ptr(str_pool, new_name);
    else
      reallocate(running_test_case, new_name);
    end if;
    set(runner.p_data, running_test_case_idx, to_integer(running_test_case));
  end;

  impure function get_running_test_case(runner : runner_t) return string is
    constant running_test_case : string_ptr_t := to_string_ptr(get(runner.p_data, running_test_case_idx));
  begin
    if running_test_case = null_string_ptr then
      return "";
    end if;
    return to_string(running_test_case);
  end;

  impure function get_num_of_run_test_cases(runner : runner_t) return natural is
  begin
    return get(runner.p_data, n_run_test_cases_idx);
  end;

  procedure inc_num_of_run_test_cases(runner : runner_t) is
  begin
    set(runner.p_data, n_run_test_cases_idx, get_num_of_run_test_cases(runner) + 1);
  end;

  procedure set_has_run_since_last_loop_check(runner : runner_t) is
  begin
    set(runner.p_data, has_run_since_last_loop_check_idx, to_integer(true));
  end;

  procedure clear_has_run_since_last_loop_check(runner : runner_t) is
  begin
    set(runner.p_data, has_run_since_last_loop_check_idx, to_integer(false));
  end;

  impure function get_has_run_since_last_loop_check(runner : runner_t) return boolean is
  begin
    return get(runner.p_data, has_run_since_last_loop_check_idx) = 1;
  end;

  procedure set_run_all(runner : runner_t) is
  begin
    set_run_all(runner, true);
  end;

  procedure set_run_all(runner : runner_t; new_value : boolean) is
  begin
    set(runner.p_data, run_all_idx, to_integer(new_value));
  end;

  impure function get_run_all(runner : runner_t) return boolean is
  begin
    return get(runner.p_data, run_all_idx) = 1;
  end;

  impure function get_test_case_iteration(runner : runner_t) return natural is
  begin
    return get(runner.p_data, test_case_iteration_idx);
  end;

  procedure inc_test_case_iteration(runner : runner_t) is
  begin
    set(runner.p_data, test_case_iteration_idx, get_test_case_iteration(runner) + 1);
  end;

  procedure init_test_case_iteration(runner : runner_t) is
  begin
    set(runner.p_data, test_case_iteration_idx, 0);
  end;

  procedure set_test_case_exit_after_error(runner : runner_t) is
  begin
    set(runner.p_data, test_case_exit_after_error_idx, to_integer(true));
  end;

  procedure clear_test_case_exit_after_error(runner : runner_t) is
  begin
    set(runner.p_data, test_case_exit_after_error_idx, to_integer(false));
  end;

  impure function get_test_case_exit_after_error(runner : runner_t) return boolean is
  begin
    return get(runner.p_data, test_case_exit_after_error_idx) = 1;
  end;

  procedure set_test_suite_exit_after_error(runner : runner_t) is
  begin
    set(runner.p_data, test_suite_exit_after_error_idx, to_integer(true));
  end;

  procedure clear_test_suite_exit_after_error(runner : runner_t) is
  begin
    set(runner.p_data, test_suite_exit_after_error_idx, to_integer(false));
  end;

  impure function get_test_suite_exit_after_error(runner : runner_t) return boolean is
  begin
    return get(runner.p_data, test_suite_exit_after_error_idx) = 1;
  end;

  procedure set_cfg(runner : runner_t; new_value : string) is
    variable runner_cfg : string_ptr_t := to_string_ptr(get(runner.p_data, runner_cfg_idx));
  begin
    if runner_cfg = null_string_ptr then
      runner_cfg := new_string_ptr(str_pool, new_value);
    else
      reallocate(runner_cfg, new_value);
    end if;
    set(runner.p_data, runner_cfg_idx, to_integer(runner_cfg));
  end;

  impure function get_cfg(runner : runner_t) return string is
    constant runner_cfg : string_ptr_t := to_string_ptr(get(runner.p_data, runner_cfg_idx));
  begin
    return to_string(runner_cfg);
  end;

  procedure p_disable_simulation_exit(runner : runner_t) is
  begin
    set(runner.p_data, disable_simulation_exit_idx, to_integer(true));
  end;

  impure function p_simulation_exit_is_disabled(runner : runner_t) return boolean is
  begin
    return get(runner.p_data, disable_simulation_exit_idx) = to_integer(true);
  end;

  procedure set_timeout(runner : runner_t; timeout : time) is
    constant new_value : string := encode(timeout);
    variable timeout_ptr : string_ptr_t := to_string_ptr(get(runner.p_data, timeout_idx));
  begin
    if timeout_ptr = null_string_ptr then
      timeout_ptr := new_string_ptr(str_pool, new_value);
    else
      reallocate(timeout_ptr, new_value);
    end if;
    set(runner.p_data, timeout_idx, to_integer(timeout_ptr));
  end;

  impure function get_timeout(runner : runner_t) return time is
    constant timeout_ptr : string_ptr_t := to_string_ptr(get(runner.p_data, timeout_idx));
  begin
    return decode(to_string(timeout_ptr));
  end;

end package body;
