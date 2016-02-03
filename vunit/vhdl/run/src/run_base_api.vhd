-- This file provides the API for run_base_pkg.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;
use work.log_special_types_pkg.all;
use work.run_types_pkg.all;
use work.run_special_types_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

package run_base_pkg is
  signal runner : runner_sync_t := (phase => test_runner_entry,
                                    locks => ((false, false),
                                              (false, false),
                                              (false, false),
                                              (false, false),
                                              (false, false),
                                              (false, false),
                                              (false, false)),
                                    exit_without_errors => false,
                                    exit_simulation => false);

  shared variable runner_trace_logger : logger_t;

  procedure runner_init(active_python_runner : boolean);

  impure function has_active_python_runner return boolean;

  procedure set_phase (
      constant new_phase  : in runner_phase_t);

  impure function get_phase
      return runner_phase_t;

  procedure set_test_case_name (
    constant index : in positive;
    constant new_name  : in string);

  impure function get_test_case_name (
    constant index : positive)
    return string;

  procedure set_num_of_test_cases (
    constant new_value : in integer);

  impure function get_num_of_test_cases
    return integer;

  procedure inc_num_of_test_cases;

  impure function get_active_test_case_index
    return integer;

  procedure inc_active_test_case_index;

  procedure set_test_suite_completed;

  impure function get_test_suite_completed
    return boolean;

  impure function get_test_suite_iteration
    return natural;

  procedure inc_test_suite_iteration;

  procedure set_run_test_case (
    constant index : in positive;
    constant new_name  : in string);

  impure function get_run_test_case (
    constant index : positive)
    return string;

  procedure set_running_test_case (
    constant new_name  : in string);

  impure function get_running_test_case
    return string;

  impure function get_num_of_run_test_cases
    return natural;

  procedure inc_num_of_run_test_cases;

  procedure set_has_run_since_last_loop_check;

  procedure clear_has_run_since_last_loop_check;

  impure function get_has_run_since_last_loop_check
    return boolean;

  procedure set_run_all;

  procedure set_run_all (
    constant new_value : in boolean);

  impure function get_run_all
    return boolean;

  impure function get_test_case_iteration
    return natural;

  procedure inc_test_case_iteration;

  procedure init_test_case_iteration;

  procedure set_test_case_exit_after_error;

  procedure clear_test_case_exit_after_error;

  impure function get_test_case_exit_after_error
    return boolean;

  procedure set_test_suite_exit_after_error;

  procedure clear_test_suite_exit_after_error;

  impure function get_test_suite_exit_after_error
    return boolean;

  procedure set_cfg (
    constant new_value : in string);

  impure function get_cfg
    return string;
end package;
