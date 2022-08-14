-- Run package provides test runner functionality to VHDL 2002+ testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

use work.logger_pkg.all;
use work.log_levels_pkg.all;
use work.log_handler_pkg.all;
use work.ansi_pkg.enable_colors;
use work.string_ops.all;
use work.dictionary.all;
use work.path.all;
use work.core_pkg;
use std.textio.all;
use work.event_common_pkg.all;
use work.event_private_pkg.all;

package body run_pkg is
  procedure notify(signal runner : inout runner_sync_t;
                   idx : natural) is
  begin
    -- Input to notify must be static, hence the case statement
    case idx is
      when runner_state_idx =>
        notify(runner(runner_state_idx to runner_state_idx + basic_event_length - 1));
      when runner_timeout_update_idx =>
        notify(runner(runner_timeout_update_idx to runner_timeout_update_idx + basic_event_length - 1));
      when runner_timeout_idx =>
        notify(runner(runner_timeout_idx to runner_timeout_idx + basic_event_length - 1));
      when others =>
        failure(runner_trace_logger, "Unknown target event for notification (index = " & integer'image(idx) & ").");
    end case;
  end procedure notify;

  procedure test_runner_setup (
    signal runner : inout runner_sync_t;
    constant runner_cfg : in string := runner_cfg_default) is
    variable test_case_candidates : lines_t;
    variable selected_enabled_test_cases : line;
  begin

    -- fake active python runner key is only used during testing in tb_run.vhd
    -- to avoid creating vunit_results file
    set_active_python_runner(runner_state,
                             (active_python_runner(runner_cfg) and not has_key(runner_cfg, "fake active python runner")));

    if has_active_python_runner(runner_state) then
      core_pkg.setup(output_path(runner_cfg) & "vunit_results");
      hide(runner_trace_logger, display_handler, info);
    end if;

    if has_key(runner_cfg, "use_color") and boolean'value(get(runner_cfg, "use_color")) then
      enable_colors;
    end if;

    if not active_python_runner(runner_cfg) then
      set_stop_level(failure);
    end if;

    set_phase(runner_state, test_runner_setup);
    runner(runner_exit_status_idx) <= runner_exit_with_errors;
    notify(runner, runner_state_idx);

    trace(runner_trace_logger, "Entering test runner setup phase.");
    entry_gate(runner);

    if selected_enabled_test_cases /= null then
      deallocate(selected_enabled_test_cases);
    end if;

    if has_key(runner_cfg, "enabled_test_cases") then
      write(selected_enabled_test_cases, get(runner_cfg, "enabled_test_cases"));
    else
      write(selected_enabled_test_cases, string'("__all__"));
    end if;
    test_case_candidates := split(replace(selected_enabled_test_cases.all, ",,", "__comma__"), ",");

    set_cfg(runner_state, runner_cfg);

    set_run_all(runner_state, strip(test_case_candidates(0).all) = "__all__");
    if get_run_all(runner_state) then
      set_num_of_test_cases(runner_state, unknown_num_of_test_cases);
    else
      set_num_of_test_cases(runner_state, 0);
      for i in 1 to test_case_candidates'length loop
        if strip(test_case_candidates(i - 1).all) /= "" then
          inc_num_of_test_cases(runner_state);

          set_test_case_name(runner_state,
                             get_num_of_test_cases(runner_state),
                             replace(strip(test_case_candidates(i - 1).all), "__comma__", ","));
        end if;
      end loop;
    end if;
    exit_gate(runner);
    set_phase(runner_state, test_suite_setup);
    notify(runner, runner_state_idx);
    trace(runner_trace_logger, "Entering test suite setup phase.");
    entry_gate(runner);
  end test_runner_setup;

  procedure test_runner_cleanup (
    signal runner: inout runner_sync_t;
    external_failure : boolean := false;
    allow_disabled_errors : boolean := false;
    allow_disabled_failures : boolean := false;
    fail_on_warning : boolean := false) is
  begin
    failure_if(runner_trace_logger, external_failure, "External failure.");

    set_phase(runner_state, test_runner_cleanup);
    notify(runner, runner_state_idx);
    trace(runner_trace_logger, "Entering test runner cleanup phase.");
    entry_gate(runner);
    exit_gate(runner);
    set_phase(runner_state, test_runner_exit);
    notify(runner, runner_state_idx);
    trace(runner_trace_logger, "Entering test runner exit phase.");

    if not final_log_check(allow_disabled_errors => allow_disabled_errors,
                           allow_disabled_failures => allow_disabled_failures,
                           fail_on_warning => fail_on_warning) then
      return;
    end if;

    runner(runner_exit_status_idx) <= runner_exit_without_errors;
    notify(runner, runner_state_idx);

    if has_active_python_runner(runner_state) then
      core_pkg.test_suite_done;
    end if;

    if not p_simulation_exit_is_disabled(runner_state) then
      core_pkg.stop(0);
    end if;

  end procedure test_runner_cleanup;

  impure function num_of_enabled_test_cases
    return integer is
  begin
    return get_num_of_test_cases(runner_state);
  end;

  impure function enabled (
    constant name : string)
    return boolean is
    variable i : natural := 1;
  begin
    if get_run_all(runner_state) then
      return true;
    end if;

    for i in 1 to get_num_of_test_cases(runner_state) loop
      if get_test_case_name(runner_state, i) = name then
        return true;
      end if;
    end loop;

    return false;
  end;

  impure function test_suite
    return boolean is
    variable ret_val : boolean;
  begin
    init_test_case_iteration(runner_state);

    if get_test_suite_completed(runner_state) then
      ret_val := false;
    elsif get_run_all(runner_state) then
      ret_val := get_has_run_since_last_loop_check(runner_state);
    else
      if get_test_suite_iteration(runner_state) > 0 then
        inc_active_test_case_index(runner_state);
      end if;

      ret_val := get_active_test_case_index(runner_state) <= get_num_of_test_cases(runner_state);
    end if;

    clear_has_run_since_last_loop_check(runner_state);

    if ret_val then
      inc_test_suite_iteration(runner_state);
      set_phase(runner_state, test_case_setup);
      trace(runner_trace_logger, "Entering test case setup phase.");
    else
      set_test_suite_completed(runner_state);
      set_phase(runner_state, test_suite_cleanup);
      trace(runner_trace_logger, "Entering test suite cleanup phase.");
    end if;

    return ret_val;
  end;

  impure function test_case
    return boolean is
  begin
    if get_test_case_iteration(runner_state) = 0 then
      set_phase(runner_state, test_case);
      trace(runner_trace_logger, "Entering test case phase.");
      inc_test_case_iteration(runner_state);
      clear_test_case_exit_after_error(runner_state);
      clear_test_suite_exit_after_error(runner_state);
      set_running_test_case(runner_state, "");
      return true;
    else
      set_phase(runner_state, test_case_cleanup);
      trace(runner_trace_logger, "Entering test case cleanup phase.");
      return false;
    end if;
  end function test_case;

  impure function run (
    constant name : string)
    return boolean is

    impure function has_run (
      constant name : string)
      return boolean is
    begin
      for i in 1 to get_num_of_run_test_cases(runner_state) loop
        if get_run_test_case(runner_state, i) = name then
          return true;
        end if;
      end loop;
      return false;
    end function has_run;

    procedure register_run (
      constant name : in string) is
    begin
      inc_num_of_run_test_cases(runner_state);
      set_has_run_since_last_loop_check(runner_state);
      set_run_test_case(runner_state, get_num_of_run_test_cases(runner_state), name);
    end procedure register_run;

  begin
    if get_test_suite_completed(runner_state) then
      set_running_test_case(runner_state, "");
      return false;
    elsif get_run_all(runner_state) then
      if not has_run(name) then
        register_run(name);
        info(runner_trace_logger, "Test case: " & name);
        if has_active_python_runner(runner_state) then
          core_pkg.test_start(name);
        end if;
        set_running_test_case(runner_state, name);
        return true;
      end if;
    elsif get_test_case_name(runner_state, get_active_test_case_index(runner_state)) = name then
      info(runner_trace_logger, "Test case: " & name);
      if has_active_python_runner(runner_state) then
        core_pkg.test_start(name);
      end if;
      set_running_test_case(runner_state, name);
      return true;
    end if;

    set_running_test_case(runner_state, "");
    return false;
  end;

  impure function active_test_case
    return string is
  begin
    if get_run_all(runner_state) then
      return "";
    end if;
    return get_test_case_name(runner_state, get_active_test_case_index(runner_state));
  end;

  impure function running_test_case
    return string is
  begin
    return get_running_test_case(runner_state);
  end;

  procedure set_timeout(signal runner : inout runner_sync_t;
                        constant timeout : in time) is
  begin
    set_timeout(runner_state, timeout);
    notify(runner, runner_timeout_update_idx);
  end;

  procedure test_runner_watchdog (
    signal runner                    : inout runner_sync_t;
    constant timeout                 : in    time;
    constant do_runner_cleanup : boolean := true) is

    variable current_timeout : time := timeout;
  begin

    loop
      wait until (runner(runner_exit_status_idx) = runner_exit_without_errors) or
                  is_active(test_runner_timeout_update) for current_timeout;

      if is_active(test_runner_timeout_update) then
        debug(runner_trace_logger, "Update watchdog timeout " & time'image(current_timeout) & ".");
        current_timeout := get_timeout(runner_state);
      else
        exit;
      end if;
    end loop;

    if not (runner(runner_exit_status_idx) = runner_exit_without_errors) then
      notify(runner, runner_timeout_idx);
      wait until not is_active(test_runner_timeout);
      error(runner_trace_logger, "Test runner timeout after " & time'image(current_timeout) & ".");
      if do_runner_cleanup then
        test_runner_cleanup(runner);
      end if;
    end if;
  end;

  function timeout_notification (
    signal runner : runner_sync_t
  ) return boolean is
  begin
    -- Cannot use better logging functions since timeout_notification is pure
    report "timeout_notification(runner) is deprecated and will be removed in future releases. Use is_active(test_runner_timeout) instead.";
    return runner(runner_timeout_idx) = p_triggered_event;
  end;

  impure function test_suite_error (
    constant err : boolean)
    return boolean is
  begin
    if err then
      set_test_suite_completed(runner_state);
      set_phase(runner_state, test_case_cleanup);
      trace(runner_trace_logger, "Entering test case cleanup phase.");
      set_test_suite_exit_after_error(runner_state);
    end if;

    return err;
  end function test_suite_error;

  impure function test_case_error (
    constant err : boolean)
    return boolean is
  begin
    if err then
      set_phase(runner_state, test_case_cleanup);
      trace(runner_trace_logger, "Entering test case cleanup phase.");
      set_test_case_exit_after_error(runner_state);
    end if;

    return err;
  end function test_case_error;

  impure function test_suite_exit
    return boolean is
  begin
    return get_test_suite_exit_after_error(runner_state);
  end function test_suite_exit;

  impure function test_case_exit
    return boolean is
  begin
    return get_test_case_exit_after_error(runner_state);
  end function test_case_exit;

  impure function test_exit
    return boolean is
  begin
    return test_suite_exit or test_case_exit;
  end function test_exit;

  procedure lock_entry (
    signal runner : inout runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := runner_trace_logger;
    constant path_offset : in natural := 0;
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    lock_entry(runner_state, phase);
    log(logger, "Locked " & replace(runner_phase_t'image(phase), "_", " ") & " phase entry gate.", trace, path_offset + 1, line_num, file_name);
    notify(runner, runner_state_idx);
  end;

  procedure unlock_entry (
    signal runner : inout runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := runner_trace_logger;
    constant path_offset : in natural := 0;
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    unlock_entry(runner_state, phase);
    log(logger, "Unlocked " & replace(runner_phase_t'image(phase), "_", " ") & " phase entry gate.", trace, path_offset + 1, line_num, file_name);
    notify(runner, runner_state_idx);
  end;

  procedure lock_exit (
    signal runner : inout runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := runner_trace_logger;
    constant path_offset : in natural := 0;
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    lock_exit(runner_state, phase);
    log(logger, "Locked " & replace(runner_phase_t'image(phase), "_", " ") & " phase exit gate.", trace, path_offset + 1, line_num, file_name);
    notify(runner, runner_state_idx);
  end;

  procedure unlock_exit (
    signal runner : inout runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := runner_trace_logger;
    constant path_offset : in natural := 0;
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    unlock_exit(runner_state, phase);
    log(logger, "Unlocked " & replace(runner_phase_t'image(phase), "_", " ") & " phase exit gate.", trace, path_offset + 1, line_num, file_name);
    notify(runner, runner_state_idx);
  end;

  procedure wait_until (
    signal runner : in runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := runner_trace_logger;
    constant path_offset : in natural := 0;
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    if get_phase(runner_state) /= phase then
      log(logger, "Waiting for phase = " & replace(runner_phase_t'image(phase), "_", " ") & ".", trace, path_offset + 1, line_num, file_name);
      wait on runner until get_phase(runner_state) = phase;
      log(logger, "Waking up. Phase is " & replace(runner_phase_t'image(phase), "_", " ") & ".", trace, path_offset + 1, line_num, file_name);
    end if;
  end;

  procedure entry_gate (
    signal runner : inout runner_sync_t) is
  begin
    if entry_is_locked(runner_state, get_phase(runner_state)) then
      trace(runner_trace_logger, "Halting on " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase entry gate.");
      wait on runner until not entry_is_locked(runner_state, get_phase(runner_state)) for max_locked_time;
    end if;
    notify(runner, runner_state_idx);
    trace(runner_trace_logger, "Passed " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase entry gate.");
  end procedure entry_gate;

  procedure exit_gate (
    signal runner : in runner_sync_t) is
  begin
    if exit_is_locked(runner_state, get_phase(runner_state)) then
      trace(runner_trace_logger, "Halting on " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase exit gate.");
      wait on runner until not exit_is_locked(runner_state, get_phase(runner_state)) for max_locked_time;
    end if;
    trace(runner_trace_logger, "Passed " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase exit gate.");
  end procedure exit_gate;

  impure function active_python_runner (
    constant runner_cfg : string)
    return boolean is
  begin
    if has_key(runner_cfg, "active python runner") then
      return get(runner_cfg, "active python runner") = "true";
    else
      return false;
    end if;
  end;

  impure function output_path (
    constant runner_cfg : string)
    return string is
  begin
    if has_key(runner_cfg, "output path") then
      return get(runner_cfg, "output path");
    else
      return "";
    end if;
  end;

  impure function enabled_test_cases (
    constant runner_cfg : string)
    return test_cases_t is
  begin
    if has_key(runner_cfg, "enabled_test_cases") then
      return get(runner_cfg, "enabled_test_cases");
    else
      return "__all__";
    end if;
  end;

  impure function tb_path (
    constant runner_cfg : string)
    return string is
  begin
    if has_key(runner_cfg, "tb path") then
      return get(runner_cfg, "tb path");
    else
      return "";
    end if;
  end;


end package body run_pkg;
