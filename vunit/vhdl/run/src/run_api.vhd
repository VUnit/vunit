-- Run API package provides the common user API for all
-- implementations of the runner functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.logger_pkg.all;
use work.runner_pkg.all;
use work.run_types_pkg.all;
use work.event_private_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package run_pkg is
  signal runner : runner_sync_t := new_basic_event(runner_phase_event) & new_basic_event(runner_timeout_update_event) &
  new_basic_event(runner_timeout_event) & new_basic_event(vunit_error_event) & runner_exit_with_errors;
  alias runner_phase is runner(runner_phase_idx to runner_phase_idx + basic_event_length - 1);
  alias runner_timeout_update is runner(runner_timeout_update_idx to runner_timeout_update_idx + basic_event_length - 1);
  alias runner_timeout is runner(runner_timeout_idx to runner_timeout_idx + basic_event_length - 1);
  alias vunit_error is runner(vunit_error_idx to vunit_error_idx + basic_event_length - 1);

  constant runner_state : runner_t := new_runner;

  procedure test_runner_setup (
    signal runner : inout runner_sync_t;
    constant runner_cfg : in string := runner_cfg_default);

  impure function num_of_enabled_test_cases
    return integer;

  impure function get_seed(runner_cfg : string; salt : string := "") return string;
  alias get_string_seed is get_seed[string, string return string];
  impure function get_seed(runner_cfg : string; salt : string := "") return unsigned;
  alias get_unsigned_seed is get_seed[string, string return unsigned];
  impure function get_seed(runner_cfg : string; salt : string := "") return signed;
  alias get_signed_seed is get_seed[string, string return signed];
  impure function get_seed(runner_cfg : string; salt : string := "") return integer;
  alias get_integer_seed is get_seed[string, string return integer];

  procedure get_seed(seed : out string; salt : string := "");
  procedure get_seed(seed : out unsigned; salt : string := "");
  procedure get_seed(seed : out signed; salt : string := "");
  procedure get_seed(seed : out integer; salt : string := "");

  procedure get_uniform_seed(seed1, seed2 : out positive; salt : string := "");

  impure function enabled (
    constant name : string)
    return boolean;

  impure function test_suite
    return boolean;

  impure function run (
    constant name : string)
    return boolean;

  impure function active_test_case
    return string;

  impure function running_test_case
    return string;

  procedure test_runner_cleanup (
    signal runner: inout runner_sync_t;
    external_failure : boolean := false;
    allow_disabled_errors : boolean := false;
    allow_disabled_failures : boolean := false;
    fail_on_warning : boolean := false);

  impure function test_suite_error (
    constant err : boolean)
    return boolean;

  impure function test_case_error (
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

  procedure test_runner_watchdog (
    signal runner                    : inout runner_sync_t;
    constant timeout                 : in    time;
    constant do_runner_cleanup : boolean := true;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "");

  -- Deprecated function. Use is_active(test_runner_timeout) instead.
  function timeout_notification (
    signal runner : runner_sync_t
  ) return boolean;

  -- Get unique key for entry gate of phase.
  impure function get_entry_key(phase : runner_legal_phase_t) return key_t;

  -- Get unique key for exit gate of phase.
  impure function get_exit_key(phase : runner_legal_phase_t) return key_t;

  -- Return true if gate lock associated with key is locked.
  impure function is_locked(key : key_t) return boolean;

  -- Lock gate lock associated with key. An already locked lock will remain
  -- locked. If a logger is provided, a trace message is issued with the lock event.
  procedure lock(
    signal runner : inout runner_sync_t;
    constant key : in key_t;
    constant logger : in logger_t := null_logger;
    constant path_offset : in natural := 0;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  -- Unlock gate lock associated with key and notify runner_phase event. An already unlocked
  -- lock will remain unlocked. If a logger is provided, a trace message is issued with the unlock event.
  procedure unlock(
    signal runner : inout runner_sync_t;
    constant key : in key_t;
    constant logger : in logger_t := null_logger;
    constant path_offset : in natural := 0;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  -- Wait until testbench enters phase. If a logger is provided, a trace message is
  -- issued when starting and stopping the wait.
  procedure wait_until (
    signal runner : in runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := null_logger;
    constant path_offset : in natural := 0;
    constant line_num  : in natural := 0;
    constant file_name : in string := "");

  -- Get current phase.
  impure function get_phase return runner_phase_t;

  -- Return true when testbench has passed the entry gate of phase but has yet to
  -- pass the exit gate of that phase.
  impure function is_within_gates_of(phase : runner_legal_phase_t) return boolean;

  procedure entry_gate (
    signal runner : inout runner_sync_t);

  procedure exit_gate (
    signal runner : inout runner_sync_t);

  impure function active_python_runner (
    constant runner_cfg : string)
    return boolean;

  impure function output_path (
    constant runner_cfg : string)
    return string;

  impure function enabled_test_cases (
    constant runner_cfg : string)
    return test_cases_t;

  impure function tb_path (
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

end package;
