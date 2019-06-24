-- Run API package provides the common user API for all
-- implementations of the runner functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

use work.logger_pkg.all;
use work.runner_pkg.all;
use work.run_types_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

package run_pkg is
  signal runner : runner_sync_t := (runner_event_idx => idle_runner,
                                    runner_exit_status_idx => runner_exit_with_errors,
                                    runner_timeout_update_idx => idle_runner,
                                    runner_timeout_idx => idle_runner);

  signal vunit_true_boolean_signal : boolean := true;
  signal vunit_false_boolean_signal : boolean := false;

  constant runner_state : runner_t := new_runner;

  procedure test_runner_setup(
    signal runner : inout runner_sync_t;
    constant runner_cfg : in string := runner_cfg_default);

  impure function num_of_enabled_test_cases
  return integer;

  impure function enabled(
    constant name : string)
  return boolean;

  impure function test_suite
  return boolean;

  impure function run(
    constant name : string)
  return boolean;

  impure function active_test_case
  return string;

  impure function running_test_case
  return string;

  procedure test_runner_cleanup(
    signal runner : inout runner_sync_t;
    external_failure : boolean := false;
    allow_disabled_errors : boolean := false;
    allow_disabled_failures : boolean := false;
    fail_on_warning : boolean := false);

  impure function test_suite_error(
    constant err : boolean)
  return boolean;

  impure function test_case_error(
    constant err : boolean)
  return boolean;

  impure function test_suite_exit
  return boolean;

  impure function test_case_exit
  return boolean;

  impure function test_exit
  return boolean;

  impure function test_case
  return boolean;

  alias in_test_case is test_case[return boolean];

  -- Set watchdog timeout dynamically relative to current time
  -- Overrides time argument to test_runner_watchdog procedure
  procedure set_timeout(signal runner : inout runner_sync_t;
                        constant timeout : in time);

  procedure test_runner_watchdog(
    signal runner : inout runner_sync_t;
    constant timeout : in time;
    constant do_runner_cleanup : boolean := true);

  function timeout_notification(
    signal runner : runner_sync_t
  ) return boolean;

  procedure wait_on(
    signal source : in boolean;
    signal condition : in boolean;
    constant timeout : in delay_length := max_timeout;
    constant logger : in logger_t := default_logger);

  procedure wait_on(
    signal source : in boolean;
    constant timeout : in delay_length := max_timeout;
    constant logger : in logger_t := default_logger);

  procedure wait_for(
    constant timeout : in delay_length := max_timeout;
    constant logger : in logger_t := default_logger);

  procedure wait_until(
    signal condition : in boolean;
    constant timeout : in delay_length := max_timeout;
    constant logger : in logger_t := default_logger);

  procedure lock_entry(
    signal runner : inout runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := runner_trace_logger;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  procedure unlock_entry(
    signal runner : inout runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := runner_trace_logger;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  procedure lock_exit(
    signal runner : inout runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := runner_trace_logger;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  procedure unlock_exit(
    signal runner : inout runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := runner_trace_logger;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  procedure wait_until(
    signal runner : in runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := runner_trace_logger;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  procedure entry_gate(
    signal runner : inout runner_sync_t);

  procedure exit_gate(
    signal runner : in runner_sync_t);

  impure function active_python_runner(
    constant runner_cfg : string)
  return boolean;

  impure function output_path(
    constant runner_cfg : string)
  return string;

  impure function enabled_test_cases(
    constant runner_cfg : string)
  return test_cases_t;

  impure function tb_path(
    constant runner_cfg : string)
  return string;

  alias test_runner_setup_entry_gate is entry_gate[runner_sync_t];
  alias test_runner_setup_exit_gate is exit_gate[runner_sync_t];
  alias test_suite_setup_entry_gate is entry_gate[runner_sync_t];
  alias test_suite_setup_exit_gate is exit_gate[runner_sync_t];
  alias test_case_setup_entry_gate is entry_gate[runner_sync_t];
  alias test_case_setup_exit_gate is exit_gate[runner_sync_t];
  alias test_case_entry_gate is entry_gate[runner_sync_t];
  alias test_case_exit_gate is exit_gate[runner_sync_t];
  alias test_case_cleanup_entry_gate is entry_gate[runner_sync_t];
  alias test_case_cleanup_exit_gate is exit_gate[runner_sync_t];
  alias test_suite_cleanup_entry_gate is entry_gate[runner_sync_t];
  alias test_suite_cleanup_exit_gate is exit_gate[runner_sync_t];
  alias test_runner_cleanup_entry_gate is entry_gate[runner_sync_t];
  alias test_runner_cleanup_exit_gate is exit_gate[runner_sync_t];

  -- Private
  procedure notify(signal runner : inout runner_sync_t;
                   idx : natural := runner_event_idx);

end package;
