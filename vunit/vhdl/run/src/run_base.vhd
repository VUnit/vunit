-- Run base package provides fundamental run functionality.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

package body run_base_pkg is
  shared variable default_runner : runner_t;

  procedure runner_init(active_python_runner : boolean) is
  begin
    default_runner.init(active_python_runner);
  end;

  impure function has_active_python_runner return boolean is
  begin
    return default_runner.has_active_python_runner;
  end function;

  procedure set_phase (
    constant new_phase  : in runner_phase_t) is
  begin
    default_runner.set_phase(new_phase);
  end;

  impure function get_phase
    return runner_phase_t is
  begin
    return default_runner.get_phase;
  end;

  procedure set_test_case_name (
    constant index : in positive;
    constant new_name  : in string) is
  begin
    default_runner.set_test_case_name(index, new_name);
  end;

  impure function get_test_case_name (
    constant index : positive)
    return string  is
  begin
    return default_runner.get_test_case_name(index);
  end;

  procedure set_num_of_test_cases (
    constant new_value : in integer) is
  begin
    default_runner.set_num_of_test_cases(new_value);
  end;

  impure function get_num_of_test_cases
    return integer is
  begin
    return default_runner.get_num_of_test_cases;
  end;

  procedure inc_num_of_test_cases is
  begin
    default_runner.inc_num_of_test_cases;
  end;

  impure function get_active_test_case_index
    return integer is
  begin
    return default_runner.get_active_test_case_index;
  end;

  procedure inc_active_test_case_index is
  begin
    default_runner.inc_active_test_case_index;
  end;

  procedure set_test_suite_completed is
  begin
    default_runner.set_test_suite_completed;
  end;

  impure function get_test_suite_completed
    return boolean is
  begin
    return default_runner.get_test_suite_completed;
  end;

  impure function get_test_suite_iteration
    return natural is
  begin
    return default_runner.get_test_suite_iteration;
  end;

  procedure inc_test_suite_iteration is
  begin
    default_runner.inc_test_suite_iteration;
  end;

  procedure set_run_test_case (
    constant index : in positive;
    constant new_name  : in string) is
  begin
    default_runner.set_run_test_case(index, new_name);
  end;

  impure function get_run_test_case (
    constant index : positive)
    return string is
  begin
    return default_runner.get_run_test_case(index);
  end;

  procedure set_running_test_case (
    constant new_name  : in string) is
  begin
    default_runner.set_running_test_case(new_name);
  end;

  impure function get_running_test_case
    return string is
  begin
    return default_runner.get_running_test_case;
  end;

  impure function get_num_of_run_test_cases
    return natural is
  begin
    return default_runner.get_num_of_run_test_cases;
  end;

  procedure inc_num_of_run_test_cases is
  begin
    default_runner.inc_num_of_run_test_cases;
  end;

  procedure set_has_run_since_last_loop_check is
  begin
    default_runner.set_has_run_since_last_loop_check;
  end;

  procedure clear_has_run_since_last_loop_check is
  begin
    default_runner.clear_has_run_since_last_loop_check;
  end;

  impure function get_has_run_since_last_loop_check
    return boolean is
  begin
    return default_runner.get_has_run_since_last_loop_check;
  end;

  procedure set_run_all is
  begin
    default_runner.set_run_all;
  end;

  procedure set_run_all (
    constant new_value : in boolean) is
  begin
    default_runner.set_run_all(new_value);
  end;

  impure function get_run_all
    return boolean is
  begin
    return default_runner.get_run_all;
  end;

  impure function get_test_case_iteration
    return natural is
  begin
    return default_runner.get_test_case_iteration;
  end;

  procedure inc_test_case_iteration is
  begin
    default_runner.inc_test_case_iteration;
  end;

  procedure init_test_case_iteration is
  begin
    default_runner.init_test_case_iteration;
  end;

  procedure set_test_case_exit_after_error is
  begin
    default_runner.set_test_case_exit_after_error;
  end;

  procedure clear_test_case_exit_after_error is
  begin
    default_runner.clear_test_case_exit_after_error;
  end;

  impure function get_test_case_exit_after_error
    return boolean is
  begin
    return default_runner.get_test_case_exit_after_error;
  end;

  procedure set_test_suite_exit_after_error is
  begin
    default_runner.set_test_suite_exit_after_error;
  end;

  procedure clear_test_suite_exit_after_error is
  begin
    default_runner.clear_test_suite_exit_after_error;
  end;

  impure function get_test_suite_exit_after_error
    return boolean is
  begin
    return default_runner.get_test_suite_exit_after_error;
  end;

  procedure set_cfg (
    constant new_value : in string) is
  begin
    default_runner.set_cfg(new_value);
  end;

  impure function get_cfg
    return string is
  begin
    return default_runner.get_cfg;
  end;

end package body run_base_pkg;
