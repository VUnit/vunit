-- Run package provides test runner functionality to VHDL 2002+ testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

use work.log_types_pkg.all;
use work.log_special_types_pkg.all;
use work.log_pkg.all;
use work.check_types_pkg.all;
use work.check_pkg.all;
use work.string_ops.all;
use work.dictionary.all;
use work.path.all;
use work.vunit_stop_pkg.vunit_stop;
use work.vunit_core_pkg;
use std.textio.all;

package body run_pkg is
  procedure test_runner_setup (
    signal runner : inout runner_sync_t;
    constant runner_cfg : in string := runner_cfg_default) is
    variable test_case_candidates : lines_t;
    variable logger_cfg : logger_cfg_export_t;
    variable checker_cfg : checker_cfg_export_t;
    variable selected_enabled_test_cases : line;
  begin

    -- fake active python runner key is only used during testing in tb_run.vhd
    -- to avoid creating vunit_results file
    runner_init(active_python_runner => (active_python_runner(runner_cfg) and
                                         not has_key(runner_cfg, "fake active python runner")));

    if has_active_python_runner then
      vunit_core_pkg.setup(output_path(runner_cfg) & "vunit_results");
    end if;

    get_logger_cfg(runner_trace_logger, logger_cfg);
    if not logger_cfg.log_file_is_initialized then
        logger_init(runner_trace_logger,
                    "Test Runner",
                  join(output_path(runner_cfg), "test_runner_trace.csv"),
                    off,
                    verbose_csv);
    end if;

    get_checker_cfg(checker_cfg);
    if active_python_runner(runner_cfg) then
      if checker_cfg.logger_cfg.log_file_is_initialized then
        checker_cfg.logger_cfg.log_stop_level := checker_cfg.default_level;
        checker_init(checker_cfg.default_level,
                     checker_cfg.logger_cfg.log_default_src(1 to checker_cfg.logger_cfg.log_default_src_length),
                     checker_cfg.logger_cfg.log_file_name(1 to checker_cfg.logger_cfg.log_file_name_length),
                     checker_cfg.logger_cfg.log_display_format,
                     checker_cfg.logger_cfg.log_file_format,
                     checker_cfg.logger_cfg.log_stop_level,
                     checker_cfg.logger_cfg.log_separator,
                     true);
      else
        checker_init(stop_level => error,
                     file_name => join(output_path(runner_cfg), "error.csv"),
                     file_format => verbose_csv);
      end if;
    elsif not checker_cfg.logger_cfg.log_file_is_initialized then
      checker_init(file_name => join(output_path(runner_cfg), "error.csv"),
                   file_format => verbose_csv);
    end if;

    set_phase(test_runner_setup);
    runner.phase <= test_runner_setup;
    runner.exit_without_errors <= false;
    wait for 0 ns;
    debug(runner_trace_logger, "Entering test runner setup phase.");
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

    set_cfg(runner_cfg);

    set_run_all(strip(test_case_candidates(0).all) = "__all__");
    if get_run_all then
      set_num_of_test_cases(unknown_num_of_test_cases_c);
    else
      set_num_of_test_cases(0);
      for i in 1 to test_case_candidates'length loop
        if strip(test_case_candidates(i - 1).all) /= "" then
          inc_num_of_test_cases;

          set_test_case_name(get_num_of_test_cases, replace(strip(test_case_candidates(i - 1).all), "__comma__", ","));
        end if;
      end loop;
    end if;
    exit_gate(runner);
    set_phase(test_suite_setup);
    runner.phase <= test_suite_setup;
    wait for 0 ns;
    debug(runner_trace_logger, "Entering test suite setup phase.");
    entry_gate(runner);
  end test_runner_setup;

  procedure test_runner_cleanup (
    signal runner: inout runner_sync_t;
    constant external_failure : in boolean;
    constant disable_simulation_exit : in boolean := false) is
    variable stat : checker_stat_t;
  begin
    set_phase(test_runner_cleanup);
    runner.phase <= test_runner_cleanup;
    wait for 0 ns;
    debug(runner_trace_logger, "Entering test runner cleanup phase.");
    entry_gate(runner);
    exit_gate(runner);
    set_phase(test_runner_exit);
    runner.phase <= test_runner_exit;
    wait for 0 ns;
    debug(runner_trace_logger, "Entering test runner exit phase.");
    get_checker_stat(stat);
    runner.exit_without_errors <= (stat.n_failed = 0) and not external_failure;

    runner_init(has_active_python_runner); -- @TODO Why?
    runner.locks(test_runner_setup to test_runner_cleanup) <= (others => (false, false));

    wait for 0 ns;

    if runner.exit_without_errors then
      if has_active_python_runner then
        vunit_core_pkg.test_suite_done;
      end if;
    end if;

    if not disable_simulation_exit then
      runner.exit_simulation <= true;
      if runner.exit_without_errors then
        vunit_stop(0);
      else
        vunit_stop(1);
      end if;
      report "Test runner exit." severity failure;
    end if;
  end procedure test_runner_cleanup;

  procedure test_runner_cleanup (
    signal runner: inout runner_sync_t;
    constant checker_stat : in checker_stat_t := (0, 0, 0);
    constant disable_simulation_exit : in boolean := false) is
  begin
    test_runner_cleanup(runner, checker_stat.n_failed > 0, disable_simulation_exit);
  end procedure test_runner_cleanup;

  impure function num_of_enabled_test_cases
    return integer is
  begin
    return get_num_of_test_cases;
  end;

  impure function enabled (
    constant name : string)
    return boolean is
    variable i : natural := 1;
  begin
    if get_run_all then
      return true;
    end if;

    for i in 1 to get_num_of_test_cases loop
      if get_test_case_name(i) = name then
        return true;
      end if;
    end loop;

    return false;
  end;

  impure function test_suite
    return boolean is
    variable ret_val : boolean;
  begin
    init_test_case_iteration;

    if get_test_suite_completed then
      ret_val := false;
    elsif get_run_all then
      ret_val := get_has_run_since_last_loop_check;
    else
      if get_test_suite_iteration > 0 then
        inc_active_test_case_index;
      end if;

      ret_val := get_active_test_case_index <= get_num_of_test_cases;
    end if;

    clear_has_run_since_last_loop_check;

    if ret_val then
      inc_test_suite_iteration;
      set_phase(test_case_setup);
      debug(runner_trace_logger, "Entering test case setup phase.");
    else
      set_test_suite_completed;
      set_phase(test_suite_cleanup);
      debug(runner_trace_logger, "Entering test suite cleanup phase.");
    end if;

    return ret_val;
  end;

  impure function test_case
    return boolean is
  begin
    if get_test_case_iteration = 0 then
      set_phase(test_case);
      debug(runner_trace_logger, "Entering test case phase.");
      inc_test_case_iteration;
      clear_test_case_exit_after_error;
      clear_test_suite_exit_after_error;
      set_running_test_case("");
      return true;
    else
      set_phase(test_case_cleanup);
      debug(runner_trace_logger, "Entering test case cleanup phase.");
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
      for i in 1 to get_num_of_run_test_cases loop
        if get_run_test_case(i) = name then
          return true;
        end if;
      end loop;
      return false;
    end function has_run;

    procedure register_run (
      constant name : in string) is
    begin
      inc_num_of_run_test_cases;
      set_has_run_since_last_loop_check;
      set_run_test_case(get_num_of_run_test_cases, name);
    end procedure register_run;

  begin
    if get_test_suite_completed then
      set_running_test_case("");
      return false;
    elsif get_run_all then
      if not has_run(name) then
        register_run(name);
        info(runner_trace_logger, "Test case: " & name);
        if has_active_python_runner then
          vunit_core_pkg.test_start(name);
        end if;
        set_running_test_case(name);
        return true;
      end if;
    elsif get_test_case_name(get_active_test_case_index) = name then
      info(runner_trace_logger, "Test case: " & name);
      if has_active_python_runner then
        vunit_core_pkg.test_start(name);
      end if;
      set_running_test_case(name);
      return true;
    end if;

    set_running_test_case("");
    return false;
  end;

  impure function active_test_case
    return string is
  begin
    if get_run_all then
      return "";
    end if;
    return get_test_case_name(get_active_test_case_index);
  end;

  impure function running_test_case
    return string is
  begin
    return get_running_test_case;
  end;

  procedure test_runner_watchdog (
    signal runner                    : inout runner_sync_t;
    constant timeout                 : in    time;
    constant disable_simulation_exit : in    boolean := false) is
  begin
    wait until runner.exit_without_errors for timeout;
    check(runner.exit_without_errors, "Test runner timeout after " & time'image(timeout) & ".");
    if not runner.exit_without_errors then
      test_runner_cleanup(runner, disable_simulation_exit => disable_simulation_exit);
    end if;
  end;

  impure function test_suite_error (
    constant err : boolean)
    return boolean is
  begin
    if err then
      set_test_suite_completed;
      set_phase(test_case_cleanup);
      debug(runner_trace_logger, "Entering test case cleanup phase.");
      set_test_suite_exit_after_error;
    end if;

    return err;
  end function test_suite_error;

  impure function test_case_error (
    constant err : boolean)
    return boolean is
  begin
    if err then
      set_phase(test_case_cleanup);
      debug(runner_trace_logger, "Entering test case cleanup phase.");
      set_test_case_exit_after_error;
    end if;

    return err;
  end function test_case_error;

  impure function test_suite_exit
    return boolean is
  begin
    return get_test_suite_exit_after_error;
  end function test_suite_exit;

  impure function test_case_exit
    return boolean is
  begin
    return get_test_case_exit_after_error;
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
    debug(runner_trace_logger, "Locked " & replace(runner_phase_t'image(phase), "_", " ") & " phase entry gate.", me, line_num, file_name);
  end;

  procedure unlock_entry (
    signal runner : out runner_sync_t;
    constant phase : in runner_phase_t;
    constant me : in string := "";
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    runner.locks(phase).entry_is_locked <= false;
    debug(runner_trace_logger, "Unlocked " & replace(runner_phase_t'image(phase), "_", " ") & " phase entry gate.", me, line_num, file_name);
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
    debug(runner_trace_logger, "Locked " & replace(runner_phase_t'image(phase), "_", " ") & " phase exit gate.", me, line_num, file_name);
  end;

  procedure unlock_exit (
    signal runner : out runner_sync_t;
    constant phase : in runner_phase_t;
    constant me : in string := "";
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    runner.locks(phase).exit_is_locked <= false;
    debug(runner_trace_logger, "Unlocked " & replace(runner_phase_t'image(phase), "_", " ") & " phase exit gate.", me, line_num, file_name);
    wait for 0 ns;
  end;

  procedure wait_until (
    signal runner : in runner_sync_t;
    constant phase : in runner_phase_t;
    constant me : in string := "";
    constant line_num  : in natural := 0;
    constant file_name : in string := "") is
  begin
    if runner.phase /= phase then
      debug(runner_trace_logger, "Waiting for phase = " & replace(runner_phase_t'image(phase), "_", " ") & ".", me, line_num, file_name);
      wait until runner.phase = phase;
      debug(runner_trace_logger, "Waking up. Phase is " & replace(runner_phase_t'image(phase), "_", " ") & ".", me, line_num, file_name);
    end if;
  end;

  procedure entry_gate (
    signal runner : inout runner_sync_t) is
  begin
    if runner.locks(get_phase).entry_is_locked then
      debug(runner_trace_logger, "Halting on " & replace(runner_phase_t'image(get_phase), "_", " ") & " phase entry gate.");
      wait on runner.locks until not runner.locks(get_phase).entry_is_locked for max_locked_time_c;
    end if;
    runner.phase <= get_phase;
    wait for 0 ns;
    debug(runner_trace_logger, "Passed " & replace(runner_phase_t'image(get_phase), "_", " ") & " phase entry gate.");
  end procedure entry_gate;

  procedure exit_gate (
    signal runner : in runner_sync_t) is
  begin
    if runner.locks(get_phase).exit_is_locked then
      debug(runner_trace_logger, "Halting on " & replace(runner_phase_t'image(get_phase), "_", " ") & " phase exit gate.");
      wait on runner.locks until not runner.locks(get_phase).exit_is_locked for max_locked_time_c;
    end if;
    debug(runner_trace_logger, "Passed " & replace(runner_phase_t'image(get_phase), "_", " ") & " phase exit gate.");
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

end package body run_pkg;
