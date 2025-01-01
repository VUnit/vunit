-- Run package provides test runner functionality to VHDL 2002+ testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.log_levels_pkg.all;
use work.log_handler_pkg.all;
use work.ansi_pkg.enable_colors;
use work.string_ops.all;
use work.dictionary.all;
use work.path.all;
use work.core_pkg;
use std.textio.all;
use work.event_common_pkg.all;
use work.event_pkg.all;
use work.checker_pkg.all;
use work.dict_pkg.all;

package body run_pkg is
  procedure test_runner_setup(
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
      if has_key(runner_cfg, "seed") then
        set_base_seed(runner_state, get(runner_cfg, "seed"));
      end if;
      core_pkg.setup(output_path(runner_cfg) & "vunit_results");
      hide(runner_trace_logger, display_handler, info);
    end if;

    if has_key(runner_cfg, "use_color") and boolean'value(get(runner_cfg, "use_color")) then
      enable_colors;
    end if;

    set_string(run_db, "output_path", output_path(runner_cfg));

    if not active_python_runner(runner_cfg) then
      set_stop_level(failure);
    end if;

    set_phase(runner_state, test_runner_setup);
    runner(runner_exit_status_idx) <= runner_exit_with_errors;
    trace(runner_trace_logger, "Entering test runner setup phase.");
    notify(runner(runner_phase_idx to runner_phase_idx + basic_event_length - 1));

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
    trace(runner_trace_logger, "Entering test suite setup phase.");
    notify(runner(runner_phase_idx to runner_phase_idx + basic_event_length - 1));
    entry_gate(runner);
  end test_runner_setup;

  procedure test_runner_cleanup(
    signal runner : inout runner_sync_t;
    external_failure : boolean := false;
    allow_disabled_errors : boolean := false;
    allow_disabled_failures : boolean := false;
    fail_on_warning : boolean := false) is
  begin
    set_phase(runner_state, test_runner_cleanup);
    set_gate_status(runner_state, false);
    trace(runner_trace_logger, "Entering test runner cleanup phase.");
    notify(runner(runner_phase_idx to runner_phase_idx + basic_event_length - 1));
    entry_gate(runner);
    failure_if(runner_trace_logger, external_failure, "External failure.");

    if p_has_unhandled_checks then
      core_pkg.core_failure("Unhandled checks.");
      return;
    end if;

    exit_gate(runner);
    set_phase(runner_state, test_runner_exit);
    trace(runner_trace_logger, "Entering test runner exit phase.");
    notify(runner(runner_phase_idx to runner_phase_idx + basic_event_length - 1));

    if not final_log_check(allow_disabled_errors => allow_disabled_errors,
                             allow_disabled_failures => allow_disabled_failures,
                             fail_on_warning => fail_on_warning) then
      return;
    end if;

    runner(runner_exit_status_idx) <= runner_exit_without_errors;
    notify(runner(runner_phase_idx to runner_phase_idx + basic_event_length - 1));

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

  function fnv_1a_64(str : string) return unsigned is
    variable hash : unsigned(63 downto 0) := x"cbf29ce484222325";
    variable product : unsigned(104 downto 0);
  begin
    for idx in str'range loop
      hash(7 downto 0) := hash(7 downto 0) xor to_unsigned(character'pos(str(idx)), 8);

      -- This is a performance optimized version of product := hash * fnv_prime
      -- where fnv_prime = 0x00000100000001b3.
      product := to_unsigned(to_integer(hash(15 downto 0)) * 435, 105) +
      (to_unsigned(to_integer(hash(31 downto 16)) * 435, 105) sll 16) +
      (to_unsigned(to_integer(hash(47 downto 32)) * 435, 105) sll 32) +
      (to_unsigned(to_integer(hash(63 downto 48)) * 435, 105) sll 48) +
      (hash sll 40);

      hash := product(63 downto 0);
    end loop;

    return hash;
  end;

  impure function get_seed(runner_cfg : string; salt : string := "") return unsigned is
  begin
    if has_key(runner_cfg, "seed") then
      return fnv_1a_64(get(runner_cfg, "seed") & salt);
    end if;

    core_pkg.core_failure("Seed not found in runner_cfg = " & runner_cfg);
    return "";
  end;

  impure function get_seed(runner_cfg : string; salt : string := "") return signed is
    constant seed : unsigned := get_seed(runner_cfg, salt);
  begin
    return signed(seed);
  end;

  impure function get_seed(runner_cfg : string; salt : string := "") return integer is
    constant seed : unsigned := get_seed(runner_cfg, salt);
  begin
    return to_integer(signed(seed(31 downto 0)));
  end;

  impure function get_seed(runner_cfg : string; salt : string := "") return string is
    variable seed : unsigned(63 downto 0);
    variable seed_image : string(1 to 19);
  begin
    seed := get_seed(runner_cfg, salt);
    seed_image := hex_image(std_logic_vector(seed));

    return seed_image(3 to 18);
  end;

  procedure wait_until_test_runner_is_setup is
  begin
    if get_phase(runner_state) <= test_runner_setup then
      wait on runner until (get_phase(runner_state) > test_runner_setup) or
        log_active(runner_timeout,
                   decorate("while get_seed procedure waiting on test_runner_setup completion."),
                   logger => runner_trace_logger);
    end if;
  end;

  procedure get_seed(seed : out unsigned; salt : string := "") is
  begin
    wait_until_test_runner_is_setup;

    seed := fnv_1a_64(get_base_seed(runner_state) & salt);
  end;

  procedure get_seed(seed : out signed; salt : string := "") is
    variable seed_unsigned : unsigned(63 downto 0);
  begin
    get_seed(seed_unsigned, salt);
    seed := signed(seed_unsigned);
  end;

  procedure get_seed(seed : out integer; salt : string := "") is
    variable seed_unsigned : unsigned(63 downto 0);
  begin
    get_seed(seed_unsigned, salt);
    seed := to_integer(signed(seed_unsigned(31 downto 0)));
  end;

  procedure get_seed(seed : out string; salt : string := "") is
    variable unsigned_seed : unsigned(63 downto 0);
    variable unsigned_seed_image : string(1 to 19);
  begin
    get_seed(unsigned_seed, salt);
    unsigned_seed_image := hex_image(std_logic_vector(unsigned_seed));
    seed := unsigned_seed_image(3 to 18);
  end;

  procedure get_uniform_seed(seed1, seed2 : out positive; salt : string := "") is
    variable hash : unsigned(63 downto 0);
  begin
    wait_until_test_runner_is_setup;

    hash := fnv_1a_64(get_base_seed(runner_state) & salt);
    -- The math_real.uniform procedure requires 1 <= seed11 <= 2147483562; 1 <= seed2 <= 2147483398.
    seed1 := 1 + (to_integer(hash(62 downto 32)) mod 2147483562);
    seed2 := 1 + (to_integer(hash(30 downto 0)) mod 2147483398);
  end;

  impure function enabled(
    constant name : string)
  return boolean is
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

  impure function run(
    constant name : string)
  return boolean is

    impure function has_run(
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

    procedure register_run(
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
    notify(runner(runner_timeout_update_idx to runner_timeout_update_idx + basic_event_length - 1));
  end;

  procedure test_runner_watchdog(
    signal runner : inout runner_sync_t;
    constant timeout : in time;
    constant do_runner_cleanup : boolean := true;
    constant line_num : in natural := 0;
    constant file_name : in string := "") is

    variable current_timeout : time := timeout;
  begin

    loop
      wait until (runner(runner_exit_status_idx) = runner_exit_without_errors) or is_active(runner_timeout_update) for current_timeout;

      if is_active(runner_timeout_update) then
        debug(runner_trace_logger, "Update watchdog timeout " & time'image(current_timeout) & ".");
        current_timeout := get_timeout(runner_state);
      else
        exit;
      end if;
    end loop;

    if not (runner(runner_exit_status_idx) = runner_exit_without_errors) then
      -- TODO: Only stop if error count is 1
      notify(
        runner(runner_timeout_idx to runner_timeout_idx + basic_event_length - 1),
        runner(vunit_error_idx to vunit_error_idx + basic_event_length - 1)
      );
      error(runner_trace_logger,
            "Test runner timeout after " & time'image(current_timeout) & ".",
            path_offset => 1, line_num => line_num, file_name => file_name);
      if do_runner_cleanup then
        test_runner_cleanup(runner);
      end if;
    end if;
  end;

  function timeout_notification(
    signal runner : runner_sync_t
  ) return boolean is
  begin
    -- Cannot use better logging functions since timeout_notification is pure
    report "timeout_notification(runner) is deprecated and will be removed in future releases. Use is_active(test_runner_timeout) instead.";
    return runner(runner_timeout_idx to runner_timeout_idx + 1) /= p_inactive_event;
  end;

  impure function test_suite_error(
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

  impure function test_case_error(
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

  impure function get_entry_key(phase : runner_legal_phase_t) return key_t is
  begin
    return get_entry_key(runner_state, phase);
  end;

  impure function get_exit_key(phase : runner_legal_phase_t) return key_t is
  begin
    return get_exit_key(runner_state, phase);
  end;

  impure function is_locked(key : key_t) return boolean is
  begin
    return is_locked(runner_state, key);
  end;

  procedure lock(
    signal runner : inout runner_sync_t;
    constant key : in key_t;
    constant logger : in logger_t := null_logger;
    constant path_offset : in natural := 0;
    constant line_num : in natural := 0;
    constant file_name : in string := "") is
  begin
    lock(runner_state, key);
    if logger /= null_logger then
      if key.p_is_entry_key then
        log(logger, "Locked " & replace(runner_phase_t'image(key.p_phase), "_", " ") & " phase entry gate.", trace, path_offset + 1, line_num, file_name);
      else
        log(logger, "Locked " & replace(runner_phase_t'image(key.p_phase), "_", " ") & " phase exit gate.", trace, path_offset + 1, line_num, file_name);
      end if;
    end if;
  end;

  procedure unlock(
    signal runner : inout runner_sync_t;
    constant key : in key_t;
    constant logger : in logger_t := null_logger;
    constant path_offset : in natural := 0;
    constant line_num : in natural := 0;
    constant file_name : in string := "") is
  begin
    unlock(runner_state, key);
    if logger /= null_logger then
      if key.p_is_entry_key then
        log(logger, "Unlocked " & replace(runner_phase_t'image(key.p_phase), "_", " ") & " phase entry gate.", trace, path_offset + 1, line_num, file_name);
      else
        log(logger, "Unlocked " & replace(runner_phase_t'image(key.p_phase), "_", " ") & " phase exit gate.", trace, path_offset + 1, line_num, file_name);
      end if;
    end if;
    notify(runner(runner_phase_idx to runner_phase_idx + basic_event_length - 1));
  end;

  procedure wait_until(
    signal runner : in runner_sync_t;
    constant phase : in runner_legal_phase_t;
    constant logger : in logger_t := null_logger;
    constant path_offset : in natural := 0;
    constant line_num : in natural := 0;
    constant file_name : in string := "") is
  begin
    if get_phase(runner_state) /= phase then
      if logger /= null_logger then
        log(logger, "Waiting for phase = " & replace(runner_phase_t'image(phase), "_", " ") & ".", trace, path_offset + 1, line_num, file_name);
      end if;
      wait until is_active(runner_phase) and get_phase(runner_state) = phase;
      if logger /= null_logger then
        log(logger, "Waking up. Phase is " & replace(runner_phase_t'image(phase), "_", " ") & ".", trace, path_offset + 1, line_num, file_name);
      end if;
    end if;
  end;

  impure function get_phase return runner_phase_t is
  begin
    return get_phase(runner_state);
  end;

  impure function is_within_gates_of(phase : runner_legal_phase_t) return boolean is
  begin
    return is_within_gates(runner_state, phase);
  end;

  procedure entry_gate(
    signal runner : inout runner_sync_t) is
  begin
    if entry_is_locked(runner_state, get_phase(runner_state)) then
      trace(runner_trace_logger, "Halting on " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase entry gate.");
      wait on runner until not entry_is_locked(runner_state, get_phase(runner_state));
    end if;
    set_gate_status(runner_state, true);
    trace(runner_trace_logger, "Passed " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase entry gate.");
    notify(runner(runner_phase_idx to runner_phase_idx + basic_event_length - 1));
  end procedure entry_gate;

  procedure exit_gate(
    signal runner : inout runner_sync_t) is
  begin
    if exit_is_locked(runner_state, get_phase(runner_state)) then
      trace(runner_trace_logger, "Halting on " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase exit gate.");
      wait on runner until not exit_is_locked(runner_state, get_phase(runner_state));
    end if;
    set_gate_status(runner_state, false);
    trace(runner_trace_logger, "Passed " & replace(runner_phase_t'image(get_phase(runner_state)), "_", " ") & " phase exit gate.");
    notify(runner(runner_phase_idx to runner_phase_idx + basic_event_length - 1));
  end procedure exit_gate;

  impure function active_python_runner(
    constant runner_cfg : string)
  return boolean is
  begin
    if has_key(runner_cfg, "active python runner") then
      return get(runner_cfg, "active python runner") = "true";
    else
      return false;
    end if;
  end;

  impure function output_path(
    constant runner_cfg : string)
  return string is
  begin
    if has_key(runner_cfg, "output path") then
      return get(runner_cfg, "output path");
    else
      return "";
    end if;
  end;

  impure function enabled_test_cases(
    constant runner_cfg : string)
  return test_cases_t is
  begin
    if has_key(runner_cfg, "enabled_test_cases") then
      return get(runner_cfg, "enabled_test_cases");
    else
      return "__all__";
    end if;
  end;

  impure function tb_path(
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
