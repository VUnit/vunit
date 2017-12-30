-- Run package provides test runner functionality to VHDL 2002+ testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

use work.logger_pkg.all;
use work.log_levels_pkg.all;
use work.log_handler_pkg.all;
use work.check_pkg.all;
use work.checker_pkg.all;
use work.ansi_pkg.enable_colors;
use work.string_ops.all;
use work.dictionary.all;
use work.path.all;
use work.core_pkg;
use std.textio.all;

package body run_pkg is
  procedure test_runner_setup (
    signal runner : inout runner_sync_t;
    constant runner_cfg : in string := runner_cfg_default) is
    variable test_case_candidates : lines_t;
    variable selected_enabled_test_cases : line;
  begin

    -- fake active python runner key is only used during testing in tb_run.vhd
    -- to avoid creating vunit_results file
    runner_init(runner_state);
    set_active_python_runner(runner_state,
                             (active_python_runner(runner_cfg) and not has_key(runner_cfg, "fake active python runner")));

    if has_active_python_runner(runner_state) then
      core_pkg.setup(output_path(runner_cfg) & "vunit_results");
    end if;

    init_log_handler(file_handler,
                     file_name => join(output_path(runner_cfg), "log.csv"),
                     format => csv);
    set_log_handlers(runner_trace_logger,
                     (new_log_handler(file_name => stdout_file_name, format => verbose, use_color => true),
                      new_log_handler(file_name => join(output_path(runner_cfg), "runner.csv"),
                                      format => csv, use_color => false)));
    update_max_logger_name_length(get_log_handler(runner_trace_logger, 0), get_max_logger_name_length(display_handler));

    if has_active_python_runner(runner_state) then
      set_log_level(runner_trace_logger, get_log_handler(runner_trace_logger, 0), warning);
    else
      set_log_level(runner_trace_logger, get_log_handler(runner_trace_logger, 0), info);
    end if;
    enable_all(runner_trace_logger, get_log_handler(runner_trace_logger, 1));

    if has_key(runner_cfg, "use_color") and boolean'value(get(runner_cfg, "use_color")) then
      enable_colors;
    end if;

    if active_python_runner(runner_cfg) then
      set_stop_level(error);
    else
      set_stop_level(failure);
    end if;

    set_phase(runner_state, test_runner_setup);
    runner.phase <= test_runner_setup;
    runner.exit_without_errors <= false;
    wait for 0 ns;
    verbose(runner_trace_logger, "Entering test runner setup phase.");
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
      set_num_of_test_cases(runner_state, unknown_num_of_test_cases_c);
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
    runner.phase <= test_suite_setup;
    wait for 0 ns;
    verbose(runner_trace_logger, "Entering test suite setup phase.");
    entry_gate(runner);
  end test_runner_setup;

  procedure test_runner_cleanup (
    signal runner: inout runner_sync_t;
    constant external_failure : in boolean := false) is

    impure function check_logger_status(logger : logger_t) return boolean is

      impure function entry_spelling(is_plural : boolean) return string is
      begin
        if is_plural then
          return "entries";
        end if;
        return "entry";
      end;

      variable child : logger_t;
      variable count : natural;
    begin
      for i in 0 to num_children(logger)-1 loop
        child := get_child(logger, i);

        if is_mocked(child) then
          core_pkg.core_failure("Logger """ & get_full_name(child) & """ is still mocked.");
          return false;
        end if;

        for level in error to standard_log_level_t'high loop
          if is_valid(level) then
            count := get_log_count(child, level);
            if count > 0 then
              core_pkg.core_failure("Logger """ & get_full_name(child) &
                                    """ has " & integer'image(count) & " " & get_name(level) &
                                    " " & entry_spelling(count > 1) & ".");
              return false;
            end if;
          end if;
        end loop;

        if not check_logger_status(child) then
          return false;
        end if;

      end loop;

      return true;
    end;

    impure function check_checker_status  return boolean is

      impure function check_spelling(is_plural : boolean) return string is
      begin
        if is_plural then
          return "checks";
        end if;
        return "check";
      end;

      variable stat : checker_stat_t;
      variable checker : checker_t;
    begin
      for i in 0 to num_checkers - 1 loop
        checker := get_checker(i);
        stat := get_checker_stat(checker);
        if stat.n_failed > 0 then
          if get_name(checker) = "" then
            core_pkg.core_failure("Default checker has " & integer'image(stat.n_failed) &
                                  " failed " & check_spelling(stat.n_failed > 1) & ".");
          else
            core_pkg.core_failure("Checker """ & get_name(checker) & """ has " & integer'image(stat.n_failed) &
                                  " failed " & check_spelling(stat.n_failed > 1) & ".");
          end if;

          return false;
        end if;
      end loop;

      return true;
    end;

  begin
    set_phase(runner_state, test_runner_cleanup);
    runner.phase <= test_runner_cleanup;
    wait for 0 ns;
    verbose(runner_trace_logger, "Entering test runner cleanup phase.");
    entry_gate(runner);
    exit_gate(runner);
    set_phase(runner_state, test_runner_exit);
    runner.phase <= test_runner_exit;
    wait for 0 ns;
    verbose(runner_trace_logger, "Entering test runner exit phase.");

    if not check_checker_status then
      return;
    end if;

    if not check_logger_status(root_logger) then
      return;
    end if;

    if external_failure then
      core_pkg.core_failure("External failure.");
      return;
    end if;

    runner.exit_without_errors <= true;
    runner.locks(test_runner_setup to test_runner_cleanup) <= (others => (false, false));
    wait for 0 ns;

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
      verbose(runner_trace_logger, "Entering test case setup phase.");
    else
      set_test_suite_completed(runner_state);
      set_phase(runner_state, test_suite_cleanup);
      verbose(runner_trace_logger, "Entering test suite cleanup phase.");
    end if;

    return ret_val;
  end;

  impure function test_case
    return boolean is
  begin
    if get_test_case_iteration(runner_state) = 0 then
      set_phase(runner_state, test_case);
      verbose(runner_trace_logger, "Entering test case phase.");
      inc_test_case_iteration(runner_state);
      clear_test_case_exit_after_error(runner_state);
      clear_test_suite_exit_after_error(runner_state);
      set_running_test_case(runner_state, "");
      return true;
    else
      set_phase(runner_state, test_case_cleanup);
      verbose(runner_trace_logger, "Entering test case cleanup phase.");
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

  procedure test_runner_watchdog (
    signal runner                    : inout runner_sync_t;
    constant timeout                 : in    time) is
  begin
    wait until runner.exit_without_errors for timeout;
    if not runner.exit_without_errors then
      error(runner_trace_logger, "Test runner timeout after " & time'image(timeout) & ".");
      test_runner_cleanup(runner);
    end if;
  end;

  impure function test_suite_error (
    constant err : boolean)
    return boolean is
  begin
    if err then
      set_test_suite_completed(runner_state);
      set_phase(runner_state, test_case_cleanup);
      verbose(runner_trace_logger, "Entering test case cleanup phase.");
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
      verbose(runner_trace_logger, "Entering test case cleanup phase.");
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
    signal runner : out runner_sync_t;
    constant phase : in runner_phase_t;
    constant me : in string := "";
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    runner.locks(phase).entry_is_locked <= true;
    wait for 0 ns;
    log(runner_trace_logger, "Locked " & replace(runner_phase_t'image(phase), "_", " ") & " phase entry gate.", verbose, line_num, file_name);
  end;

  procedure unlock_entry (
    signal runner : out runner_sync_t;
    constant phase : in runner_phase_t;
    constant me : in string := "";
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    runner.locks(phase).entry_is_locked <= false;
    log(runner_trace_logger, "Unlocked " & replace(runner_phase_t'image(phase), "_", " ") & " phase entry gate.", verbose, line_num, file_name);
    wait for 0 ns;
  end;

  procedure lock_exit (
    signal runner : out runner_sync_t;
    constant phase : in runner_phase_t;
    constant me : in string := "";
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    runner.locks(phase).exit_is_locked <= true;
    wait for 0 ns;
    log(runner_trace_logger, "Locked " & replace(runner_phase_t'image(phase), "_", " ") & " phase exit gate.", verbose, line_num, file_name);
  end;

  procedure unlock_exit (
    signal runner : out runner_sync_t;
    constant phase : in runner_phase_t;
    constant me : in string := "";
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    runner.locks(phase).exit_is_locked <= false;
    log(runner_trace_logger, "Unlocked " & replace(runner_phase_t'image(phase), "_", " ") & " phase exit gate.", verbose, line_num, file_name);
    wait for 0 ns;
  end;

  procedure wait_until (
    signal runner : in runner_sync_t;
    constant phase : in runner_phase_t;
    constant me : in string := "";
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    -- @TODO me
    if runner.phase /= phase then
      log(runner_trace_logger, "Waiting for phase = " & replace(runner_phase_t'image(phase), "_", " ") & ".", verbose, line_num, file_name);
      wait until runner.phase = phase;
      log(runner_trace_logger, "Waking up. Phase is " & replace(runner_phase_t'image(phase), "_", " ") & ".", verbose, line_num, file_name);
    end if;
  end;

  procedure entry_gate (
    signal runner : inout runner_sync_t) is
  begin
    if runner.locks(get_phase(runner_state)).entry_is_locked then
      verbose(runner_trace_logger, "Halting on " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase entry gate.");
      wait on runner.locks until not runner.locks(get_phase(runner_state)).entry_is_locked for max_locked_time_c;
    end if;
    runner.phase <= get_phase(runner_state);
    wait for 0 ns;
    verbose(runner_trace_logger, "Passed " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase entry gate.");
  end procedure entry_gate;

  procedure exit_gate (
    signal runner : in runner_sync_t) is
  begin
    if runner.locks(get_phase(runner_state)).exit_is_locked then
      verbose(runner_trace_logger, "Halting on " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase exit gate.");
      wait on runner.locks until not runner.locks(get_phase(runner_state)).exit_is_locked for max_locked_time_c;
    end if;
    verbose(runner_trace_logger, "Passed " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase exit gate.");
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
