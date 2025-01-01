-- This test suite verifies the VHDL test runner functionality
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.string_ops.all;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use std.textio.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.runner_pkg.all;
use vunit_lib.core_pkg;
use vunit_lib.event_common_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity run_tests is
  generic (output_path : string);
end entity;

architecture test_fixture of run_tests is
  constant locking_proc1_logger : logger_t := get_logger("locking_proc1_logger");
  constant locking_proc2_logger : logger_t := get_logger("locking_proc2");
  constant c : checker_t := new_checker("checker_t", default_log_level => failure);
  signal start_test_process, start_test_process2 : boolean := false;
  signal test_process_completed : boolean := false;
  signal start_locking_process : boolean := false;
  signal start_test_runner_watchdog, test_runner_watchdog_completed : boolean := false;
  signal start_seed_process : boolean := false;

  impure function get_phase return runner_phase_t is
  begin
    return get_phase(runner_state);
  end;

begin
  test_process : process is
    variable t_start : time;
  begin
    wait until start_test_process;
    t_start := now;
    if get_phase /= test_suite_setup then
      wait on runner until get_phase = test_suite_setup for 20 ns;
    end if;
    check_equal(now - t_start, 17 ns, "Expected wait on test_suite_setup phase to be 17 ns.");
    t_start := now;
    if get_phase /= test_case_setup then
      wait on runner until get_phase = test_case_setup for 20 ns;
    end if;
    check_equal(now - t_start, 9 ns, "Expected wait on test_case_setup phase to be 9 ns.");
    test_process_completed <= true;
    wait;
  end process;

  test_process2 : process is
    constant test_suite_setup_entry_key : key_t := get_entry_key(test_suite_setup);
    constant test_suite_setup_exit_key : key_t := get_exit_key(test_suite_setup);
  begin
    wait until start_test_process2;
    lock(runner, test_suite_setup_entry_key);
    lock(runner, test_suite_setup_exit_key);
    wait for 7 ns;
    unlock(runner, test_suite_setup_entry_key);
    wait for 4 ns;
    unlock(runner, test_suite_setup_exit_key);
    wait;
  end process;

  locking_proc1: process is
    constant test_runner_setup_entry_key : key_t := get_entry_key(test_runner_setup);
    constant test_runner_setup_exit_key : key_t := get_exit_key(test_runner_setup);
    constant test_suite_setup_entry_key : key_t := get_entry_key(test_suite_setup);
    constant test_suite_setup_exit_key : key_t := get_exit_key(test_suite_setup);
    constant test_case_setup_entry_key : key_t := get_entry_key(test_case_setup);
    constant test_case_setup_exit_key : key_t := get_exit_key(test_case_setup);
    constant test_case_entry_key : key_t := get_entry_key(test_case);
    constant test_case_exit_key : key_t := get_exit_key(test_case);
    constant test_case_cleanup_entry_key : key_t := get_entry_key(test_case_cleanup);
    constant test_case_cleanup_exit_key : key_t := get_exit_key(test_case_cleanup);
    constant test_suite_cleanup_entry_key : key_t := get_entry_key(test_suite_cleanup);
    constant test_suite_cleanup_exit_key : key_t := get_exit_key(test_suite_cleanup);
    constant test_runner_cleanup_entry_key : key_t := get_entry_key(test_runner_cleanup);
    constant test_runner_cleanup_exit_key : key_t := get_exit_key(test_runner_cleanup);
  begin
    wait until start_locking_process = true;
    lock(runner, test_runner_setup_entry_key, locking_proc1_logger);
    lock(runner, test_runner_setup_exit_key, locking_proc1_logger);
    lock(runner, test_suite_setup_entry_key, locking_proc1_logger);
    lock(runner, test_suite_setup_exit_key, locking_proc1_logger);
    wait for 2 ns;
    unlock(runner, test_runner_setup_entry_key, locking_proc1_logger);
    wait for 1 ns;
    unlock(runner, test_runner_setup_exit_key, locking_proc1_logger);
    wait for 1 ns;
    unlock(runner, test_suite_setup_entry_key, locking_proc1_logger);
    wait for 3 ns;

    lock(runner, test_case_setup_entry_key, locking_proc1_logger);
    lock(runner, test_case_setup_exit_key, locking_proc1_logger);
    lock(runner, test_case_entry_key, locking_proc1_logger);
    lock(runner, test_case_exit_key, locking_proc1_logger);
    lock(runner, test_case_cleanup_entry_key, locking_proc1_logger);
    lock(runner, test_case_cleanup_exit_key, locking_proc1_logger);
    lock(runner, test_suite_cleanup_entry_key, locking_proc1_logger);
    lock(runner, test_suite_cleanup_exit_key, locking_proc1_logger);
    lock(runner, test_runner_cleanup_entry_key, locking_proc1_logger);
    lock(runner, test_runner_cleanup_exit_key, locking_proc1_logger);

    wait for 1 ns;
    unlock(runner, test_suite_setup_exit_key, locking_proc1_logger);
    wait for 1 ns;
    unlock(runner, test_case_setup_entry_key, locking_proc1_logger);
    wait for 2 ns;
    unlock(runner, test_case_setup_exit_key, locking_proc1_logger);
    wait for 1 ns;
    unlock(runner, test_case_entry_key, locking_proc1_logger);
    wait for 2 ns;
    unlock(runner, test_case_exit_key, locking_proc1_logger);
    wait for 1 ns;
    unlock(runner, test_case_cleanup_entry_key, locking_proc1_logger);
    wait for 2 ns;
    unlock(runner, test_case_cleanup_exit_key, locking_proc1_logger);
    wait for 4 ns;
    unlock(runner, test_suite_cleanup_entry_key, locking_proc1_logger);
    wait for 2 ns;
    unlock(runner, test_suite_cleanup_exit_key, locking_proc1_logger);
    wait for 1 ns;
    unlock(runner, test_runner_cleanup_entry_key, locking_proc1_logger);
    wait for 1 ns;
    unlock(runner, test_runner_cleanup_exit_key, locking_proc1_logger);
    wait;
  end process locking_proc1;

  locking_proc2: process is
    constant key : key_t := get_exit_key(test_runner_cleanup);
  begin
    wait until start_locking_process = true;
    wait for 6 ns;
    lock(runner, key, locking_proc2_logger);
    wait for 21 ns;
    unlock(runner, key, locking_proc2_logger);
    wait;
  end process locking_proc2;

  watchdog: process is
  begin
    wait until start_test_runner_watchdog;
    test_runner_watchdog(runner, 10 ns);
    test_runner_watchdog_completed <= true;
    runner(runner_exit_status_idx) <= runner_exit_with_errors;
  end process watchdog;

  seed_process : process is
    variable seed : string(1 to 16);
    variable timestamp : time;
  begin
    wait until start_seed_process;
    timestamp := now;
    get_seed(seed);
    check(c, now - timestamp = 1 ns, "Expected delay = 1 ns but got " & time'image(now - timestamp));
    timestamp := now;
    get_seed(seed, "salt");
    check(c, now - timestamp = 0 ns, "Expected no delay but got " & time'image(now - timestamp));
    wait;
  end process;

  test_runner : process
    procedure banner (
      constant s : in string) is
      variable dashes : string(1 to 256) := (others => '-');
    begin
      info(dashes(s'range) & LF & s & LF & dashes(s'range) & LF);
    end banner;

    function to_string(value : integer) return string is
    begin
      return integer'image(value);
    end;

    procedure test_case_setup is
    begin
      runner_init(runner_state);
      runner(runner_exit_status_idx) <= runner_exit_with_errors;
      notify(runner_phase);
    end;

    procedure test_case_cleanup is
      variable stat : checker_stat_t;
    begin
      get_checker_stat(c, stat);
      reset_checker_stat(c);

      info("Number of checks: " & natural'image(stat.n_checks));
      info("Number of passing checks: " & natural'image(stat.n_passed));
      info("Number of failing checks: " & natural'image(stat.n_failed));

      assert stat.n_failed = 0 report "Expected no failed checks" severity failure;
    end;

    variable i : natural;
    variable n_run_a, n_run_b, n_run_c : natural := 0;
    variable t_start : time;
    variable runner_cfg : line;
    variable passed : boolean;
    variable seed : string_seed_t;
    variable seed_unsigned : unsigned_seed_t;
    variable seed_signed : signed_seed_t;
    variable seed_int : integer;
    variable seed1, seed2 : positive;
    constant test_case_setup_entry_key : key_t := get_entry_key(test_case_setup);
    constant test_case_setup_exit_key : key_t := get_exit_key(test_case_setup);

  begin
    banner("Should extract single enabled test case from input string");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : Should foo");
    check(c, num_of_enabled_test_cases = 1, "Expected 1 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should foo"), "Expected ""Should foo"" test case to be enabled");
    check_false(c, enabled("Should bar"), "Didn't expected ""Should bar"" test case to be enabled.");
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should extract multiple enabled test cases from input string");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : Should bar,,Should zen");
    check(c, num_of_enabled_test_cases = 2, "Expected 2 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should bar"), "Expected ""Should bar"" test case to be enabled");
    check(c, enabled("Should zen"), "Expected ""Should zen"" test case to be enabled");
    check_false(c, enabled("Should toe"), "Didn't expected ""Should zen"" test case to be enabled.");
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should strip leading and trailing spaces from test case names");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : Should one ,,  Should two  ,, Should three");
    check(c, num_of_enabled_test_cases = 3, "Expected 3 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one"), "Expected ""Should one"" test case to be enabled");
    check(c, enabled("Should two"), "Expected ""Should two"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should not enable any test cases on empty input string for enabled test cases");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases:");
    check(c, num_of_enabled_test_cases = 0, "Expected 0 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should not enable any test cases on space input string for enabled test cases");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases:   ");
    check(c, num_of_enabled_test_cases = 0, "Expected 0 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should ignore test case names with only spaces");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : Should one ,,    ,, Should three");
    check(c, num_of_enabled_test_cases = 2, "Expected 2 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one"), "Expected ""Should one"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should allow comma in test case name");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : Should one ,,,,  Should two  ,, Should three");
    check(c, num_of_enabled_test_cases = 2, "Expected 2 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one ,  Should two"), "Expected ""Should one ,  Should two"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should enable all on __all__ input string");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : __all__");
    check(c, num_of_enabled_test_cases = unknown_num_of_test_cases_c, "Expected " & integer'image(unknown_num_of_test_cases_c) & " enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one"), "Expected ""Should one"" test case to be enabled");
    check(c, enabled("Should two"), "Expected ""Should two"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should enable all by default");
    test_case_setup;
    test_runner_setup(runner);
    check(c, num_of_enabled_test_cases = unknown_num_of_test_cases_c, "Expected " & integer'image(unknown_num_of_test_cases_c) & " enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one"), "Expected ""Should one"" test case to be enabled");
    check(c, enabled("Should two"), "Expected ""Should two"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should enable all on empty string");
    test_case_setup;
    test_runner_setup(runner, "");
    check(c, num_of_enabled_test_cases = unknown_num_of_test_cases_c, "Expected " & integer'image(unknown_num_of_test_cases_c) & " enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one"), "Expected ""Should one"" test case to be enabled");
    check(c, enabled("Should two"), "Expected ""Should two"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Mocked logger should cause failure on test_runner_cleanup");
    test_case_setup;
    mock(get_logger("parent:unmocked_logger"));

    core_pkg.mock_core_failure;
    test_runner_cleanup(runner);
    core_pkg.check_and_unmock_core_failure;

    unmock(get_logger("parent:unmocked_logger"));
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Error log cause failure on test_runner_cleanup");
    test_case_setup;
    error(get_logger("parent:my_logger"), "error message");
    core_pkg.mock_core_failure;
    test_runner_cleanup(runner);
    core_pkg.check_and_unmock_core_failure;
    test_case_cleanup;
    reset_log_count(get_logger("parent:my_logger"), error);

    ---------------------------------------------------------------------------
    banner("Error log cause failure on test_runner_cleanup");
    test_case_setup;
    disable_stop(get_logger("parent:my_logger"), failure);
    failure(get_logger("parent:my_logger"), "failure message 1");
    failure(get_logger("parent:my_logger"), "failure message 2");
    set_stop_count(get_logger("parent:my_logger"), failure, 1);
    core_pkg.mock_core_failure;
    test_runner_cleanup(runner);
    core_pkg.check_and_unmock_core_failure;
    test_case_cleanup;
    reset_log_count(get_logger("parent:my_logger"), failure);

    ---------------------------------------------------------------------------
    banner("Should loop over enabled_test_case once and in order unless re-initialized.");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : Should one ,,  Should two  ,, Should three");
    i := 0;
    while test_suite loop
      case i is
        when 0 =>
          check(c, run("Should one"), "Expected ""Should one"" to run.");
          check_false(c, run("Should two"), "Didn't expect ""Should two"" to run.");
          check_false(c, run("Should three"), "Didn't expect ""Should three"" to run.");
        when 1 =>
          check_false(c, run("Should one"), "Didn't expected ""Should one"" to run.");
          check(c, run("Should two"), "Expected ""Should two"" to run.");
          check_false(c, run("Should three"), "Didn't expect ""Should three"" to run.");
        when 2 =>
          check_false(c, run("Should one"), "Didn't expected ""Should one"" to run.");
          check_false(c, run("Should two"), "Didn't expect ""Should two"" to run.");
          check(c, run("Should three"), "Expected ""Should three"" to run.");
        when others =>
          check(c, false, "Should be only three iterations");
      end case;
      i := i + 1;
    end loop;
    check(c, i = 3, "Expected three iterations but got i = " & natural'image(i) & ".");
    check_false(c, run("Should one"), "Didn't expect ""Should one"" to run.");
    check_false(c, run("Should two"), "Didn't expect ""Should two"" to run.");
    check_false(c, run("Should three"), "Didn't expect ""Should three"" to run.");
    test_runner_setup(runner, "enabled_test_cases : Should one ,,  Should two  ,, Should three");
    while test_suite loop
      check(c, run("Should one"), "Expected ""Should one"" to run.");
      check_false(c, run("Should two"), "Didn't expect ""Should two"" to run.");
      check_false(c, run("Should three"), "Didn't expect ""Should three"" to run.");
      exit;
    end loop;

    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should loop a set of test cases without repetition when all test cases are enabled.");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : __all__");
    i := 0;
    while test_suite and (i < 5) loop
      i := i + 1;
      if run("Should a") then
        n_run_a := n_run_a + 1;
      elsif run("Should b") then
        n_run_b := n_run_b + 1;
      elsif run("Should c") then
        n_run_c := n_run_c + 1;
      end if;
    end loop;
    check_false(c, i = 5, "Too many loop iterations. Expected only 4.");
    check(c, n_run_a = 1, "Expected ""Should a"" to run once but it was run " & natural'image(n_run_a) & " times.");
    check(c, n_run_b = 1, "Expected ""Should b"" to run once but it was run " & natural'image(n_run_b) & " times.");
    check(c, n_run_c = 1, "Expected ""Should c"" to run once but it was run " & natural'image(n_run_c) & " times.");
    check_false(c, run("Should a"), "Didn't expect ""Should a"" to run.");
    check_false(c, run("Should b"), "Didn't expect ""Should b"" to run.");
    check_false(c, run("Should c"), "Didn't expect ""Should c"" to run.");
    check_false(c, run("Should d"), "Didn't expect ""Should d"" to run.");
    test_case_setup;
    test_runner_setup(runner);
    check(c, run("Should a"), "Expected ""Should a"" to run.");

    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should maintain correct phase when using the full run mode of operation without any early exits");
    test_case_setup;
    check(c, get_phase = test_runner_entry, "Phase should be test runner entry");
    test_runner_setup(runner, "enabled_test_cases : test a,, test b");
    check(c, get_phase = test_suite_setup, "Phase should be test suite setup");
    i := 0;
    while test_suite loop
      check(c, get_phase = test_case_setup, "Phase should be test case setup." & " Got " & runner_phase_t'image(get_phase) & ".");
      while in_test_case loop
        check(c, get_phase = test_case, "Phase should be test case main."  & " Got " & runner_phase_t'image(get_phase) & ".");
        if i = 0 then
          check_false(c, run("test b"), "Test b should not be enabled at this time.");
          check(c, run("test a"), "Test a should be enabled at this time");
        else
          check_false(c, run("test a"), "Test a should not be enabled at this time.");
          check(c, run("test b"), "Test b should be enabled at this time");
        end if;
        i := i + 1;
      end loop;
    end loop;
    check(c, get_phase = test_suite_cleanup, "Phase should be test suite cleanup" & " Got " & runner_phase_t'image(get_phase) & ".");
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    check(c, get_phase = test_runner_exit, "Phase should be test runner exit" & " Got " & runner_phase_t'image(get_phase) & ".");

    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should maintain correct phase when using the full run mode of operation and there is a premature exit of a test case.");
    test_case_setup;
    check(c, get_phase = test_runner_entry, "Phase should be test runner entry");
    test_runner_setup(runner, "enabled_test_cases : test a,, test b");
    check(c, get_phase = test_suite_setup, "Phase should be test suite setup");
    i := 0;
    while test_suite loop
      check(c, get_phase = test_case_setup, "Phase should be test case setup." & " Got " & runner_phase_t'image(get_phase) & ".");
      while in_test_case loop
        check(c, get_phase = test_case, "Phase should be test case main."  & " Got " & runner_phase_t'image(get_phase) & ".");
        if i = 0 then
          check_false(c, run("test b"), "Test b should not be enabled at this time.");
          check(c, run("test a"), "Test a should be enabled at this time");
          i := i + 1;
          exit when test_case_error(true);
        else
          check_false(c, run("test a"), "Test a should not be enabled at this time.");
          check(c, run("test b"), "Test b should be enabled at this time");
          i := i + 1;
        end if;
      end loop;
      check(c, get_phase = test_case_cleanup, "Phase should be test case cleanup."  & " Got " & runner_phase_t'image(get_phase) & ".");
    end loop;
    check(c, get_phase = test_suite_cleanup, "Phase should be test suite cleanup" & " Got " & runner_phase_t'image(get_phase) & ".");
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    check(c, get_phase = test_runner_exit, "Phase should be test runner exit" & " Got " & runner_phase_t'image(get_phase) & ".");


    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should maintain correct phase when using the full run mode of operation and there is a premature exit of a test suite.");
    test_case_setup;
    check(c, get_phase = test_runner_entry, "Phase should be test runner entry");
    test_runner_setup(runner, "enabled_test_cases : test a,, test b");
    check(c, get_phase = test_suite_setup, "Phase should be test suite setup");
    i := 0;
    while test_suite loop
      check(c, get_phase = test_case_setup, "Phase should be test case setup." & " Got " & runner_phase_t'image(get_phase) & ".");
      while in_test_case loop
        check(c, get_phase = test_case, "Phase should be test case main."  & " Got " & runner_phase_t'image(get_phase) & ".");
        check(c, i = 0, "The second test case should never be activated");
        check_false(c, run("test b"), "Test b should not be enabled at this time.");
        check(c, run("test a"), "Test a should be enabled at this time");
        i := i + 1;
        exit when test_suite_error(true);
      end loop;
      check(c, get_phase = test_case_cleanup, "Phase should be test case cleanup."  & " Got " & runner_phase_t'image(get_phase) & ".");
    end loop;
    check(c, get_phase = test_suite_cleanup, "Phase should be test suite cleanup." & " Got " & runner_phase_t'image(get_phase) & ".");
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    check(c, get_phase = test_runner_exit, "Phase should be test runner exit" & " Got " & runner_phase_t'image(get_phase) & ".");

    test_case_cleanup;

    ---------------------------------------------------------------------------
    --banner("Should be possible to exit a test case or test suite with an error message that can be caught afterwards.");
    --test_case_setup;
    --test_runner_setup(runner, "test a, test b");
    --check_false(c, test_exit, "Test_exit should be false before error");
    --check_false(c, test_case_exit, "Test_case_exit should be false before error");
    --check_false(c, test_suite_exit, "Test_suite_exit should be false before error");
    --loop
    --  exit when test_case_error(true, "Something is wrong");
    --end loop;
    --check_false(c, test_exit, "Test_exit should be false before error");
    --check_false(c, test_case_exit, "Test_case_exit should be false before error");
    --check_false(c, test_suite_exit, "Test_suite_exit should be false before error");

    ---------------------------------------------------------------------------
    banner("Should be possible to exit a test suite from the test case/suite from the test case setup code.");
    test_case_setup;
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should be possible to exit a test suite from the test case/suite from the test case cleanup code.");
    test_case_setup;
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should be possible to stall execution and stall the exit of a phase");
    test_case_setup;
    start_test_process2 <= true;
    t_start := now;
    wait for 1 ns;
    test_runner_setup(runner, "enabled_test_cases : test a");
    entry_gate(runner);
    check(c, now - t_start = 7 ns, "Expected a 7 ns delay due to phase lock");
    t_start := now;
    exit_gate(runner);
    while test_suite loop
      check(c, now - t_start = 4 ns, "Expected a 4 ns delay due to phase lock");
      while in_test_case loop
      end loop;
    end loop;
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should be possible to suspend a process/procedure waiting for a specific phase");
    test_case_setup;
    start_test_process <= true;
    wait for 17 ns;
    test_runner_setup(runner, "enabled_test_cases : test a");
    wait for 9 ns;
    while test_suite loop
      entry_gate(runner);
      wait for 1 ns;
      while in_test_case loop
      end loop;
    end loop;
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    if not test_process_completed then
      wait until test_process_completed;
    end if;
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should be possible to read current test case name");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : test a,, test b");
    i := 0;
    while test_suite loop
      while in_test_case loop
        if i = 0 then
          passed := active_test_case = "test a";
          check(c, passed, "Expected active test case to be ""test a"" but got " & active_test_case);
        else
          passed := active_test_case = "test b";
          check(c, passed, "Expected active test case to be ""test b"" but got " & active_test_case);
        end if;
        i := i + 1;
      end loop;
    end loop;
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should read active test case name = "" when enabled tests are __all__");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : __all__");
    while test_suite loop
      while in_test_case loop
          passed := active_test_case = "";
          check(c, passed, "Expected active test case to be """" but got " & active_test_case);
      end loop;
    end loop;
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should run all when the runner hasn't been initialized");
    test_case_setup;
    i := 0;
    while test_suite loop
      if run("Should a") then
        i := i + 1;
      elsif run("Should b") then
        i := i + 1;
      elsif run("Should c") then
        i := i + 1;
      end if;
    end loop;
    check(c, i = 3, "Not all test cases were run.");
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should have a trace log where source of locking/unlocking commands can be logged.");
    test_case_setup;

    mock(locking_proc1_logger);
    mock(locking_proc2_logger);
    mock(runner_trace_logger);
    start_locking_process <= true;

    wait for 1 ns;
    check_log(locking_proc1_logger, "Locked test runner setup phase entry gate.", trace);
    check_log(locking_proc1_logger, "Locked test runner setup phase exit gate.", trace);
    check_log(locking_proc1_logger, "Locked test suite setup phase entry gate.", trace);
    check_log(locking_proc1_logger, "Locked test suite setup phase exit gate.", trace);
    check_no_log;

    test_runner_setup(runner, "enabled_test_cases : test a");
    check_log(runner_trace_logger, "Entering test runner setup phase.", trace);
    check_log(runner_trace_logger, "Halting on test runner setup phase entry gate.", trace);
    check_log(locking_proc1_logger, "Unlocked test runner setup phase entry gate.", trace);
    check_log(runner_trace_logger, "Passed test runner setup phase entry gate.", trace);
    check_log(runner_trace_logger, "Halting on test runner setup phase exit gate.", trace);
    check_log(locking_proc1_logger, "Unlocked test runner setup phase exit gate.", trace);
    check_log(runner_trace_logger, "Passed test runner setup phase exit gate.", trace);
    check_log(runner_trace_logger, "Entering test suite setup phase.", trace);
    check_log(runner_trace_logger, "Halting on test suite setup phase entry gate.", trace);
    check_log(locking_proc1_logger, "Unlocked test suite setup phase entry gate.", trace);
    check_log(runner_trace_logger, "Passed test suite setup phase entry gate.", trace);
    check_no_log;

    test_suite_setup_entry_gate(runner);
    wait for 1 ns;

    test_suite_setup_exit_gate(runner);
    check_log(runner_trace_logger, "Passed test suite setup phase entry gate.", trace);
    check_log(runner_trace_logger, "Halting on test suite setup phase exit gate.", trace);
    check_log(locking_proc2_logger, "Locked test runner cleanup phase exit gate.", trace);
    check_log(locking_proc1_logger, "Locked test case setup phase entry gate.", trace);
    check_log(locking_proc1_logger, "Locked test case setup phase exit gate.", trace);
    check_log(locking_proc1_logger, "Locked test case phase entry gate.", trace);
    check_log(locking_proc1_logger, "Locked test case phase exit gate.", trace);
    check_log(locking_proc1_logger, "Locked test case cleanup phase entry gate.", trace);
    check_log(locking_proc1_logger, "Locked test case cleanup phase exit gate.", trace);
    check_log(locking_proc1_logger, "Locked test suite cleanup phase entry gate.", trace);
    check_log(locking_proc1_logger, "Locked test suite cleanup phase exit gate.", trace);
    check_log(locking_proc1_logger, "Locked test runner cleanup phase entry gate.", trace);
    check_log(locking_proc1_logger, "Locked test runner cleanup phase exit gate.", trace);
    check_log(locking_proc1_logger, "Unlocked test suite setup phase exit gate.", trace);
    check_log(runner_trace_logger, "Passed test suite setup phase exit gate.", trace);
    check_no_log;

    while test_suite loop
      check_only_log(runner_trace_logger, "Entering test case setup phase.", trace);

      test_case_setup_entry_gate(runner);
      check_log(runner_trace_logger, "Halting on test case setup phase entry gate.", trace);
      check_log(locking_proc1_logger, "Unlocked test case setup phase entry gate.", trace);
      check_log(runner_trace_logger, "Passed test case setup phase entry gate.", trace);
      check_no_log;

      wait for 1 ns;
      test_case_setup_exit_gate(runner);
      check_log(runner_trace_logger, "Halting on test case setup phase exit gate.", trace);
      check_log(locking_proc1_logger, "Unlocked test case setup phase exit gate.", trace);
      check_log(runner_trace_logger, "Passed test case setup phase exit gate.", trace);
      check_no_log;

      while in_test_case loop
        check_only_log(runner_trace_logger, "Entering test case phase.", trace);

        test_case_entry_gate(runner);
        check_log(runner_trace_logger, "Halting on test case phase entry gate.", trace);
        check_log(locking_proc1_logger, "Unlocked test case phase entry gate.", trace);
        check_log(runner_trace_logger, "Passed test case phase entry gate.", trace);
        check_no_log;

        if run("test a") then
          wait for 1 ns;
        end if;
        check_only_log(runner_trace_logger, "Test case: test a", info);

        test_case_exit_gate(runner);
        check_log(runner_trace_logger, "Halting on test case phase exit gate.", trace);
        check_log(locking_proc1_logger, "Unlocked test case phase exit gate.", trace);
        check_log(runner_trace_logger, "Passed test case phase exit gate.", trace);
        check_no_log;
      end loop;
      check_only_log(runner_trace_logger, "Entering test case cleanup phase.", trace);

      test_case_cleanup_entry_gate(runner);
      check_log(runner_trace_logger, "Halting on test case cleanup phase entry gate.", trace);
      check_log(locking_proc1_logger, "Unlocked test case cleanup phase entry gate.", trace);
      check_log(runner_trace_logger, "Passed test case cleanup phase entry gate.", trace);
      check_no_log;

      wait for 1 ns;
      test_case_cleanup_exit_gate(runner);

      check_log(runner_trace_logger, "Halting on test case cleanup phase exit gate.", trace);
      check_log(locking_proc1_logger, "Unlocked test case cleanup phase exit gate.", trace);
      check_log(runner_trace_logger, "Passed test case cleanup phase exit gate.", trace);
      check_no_log;
    end loop;
    check_only_log(runner_trace_logger, "Entering test suite cleanup phase.", trace);

    test_suite_cleanup_entry_gate(runner);
    check_log(runner_trace_logger, "Halting on test suite cleanup phase entry gate.", trace);
    check_log(locking_proc1_logger, "Unlocked test suite cleanup phase entry gate.", trace);
    check_log(runner_trace_logger, "Passed test suite cleanup phase entry gate.", trace);
    check_no_log;

    wait for 1 ns;
    test_suite_cleanup_exit_gate(runner);
    check_log(runner_trace_logger, "Halting on test suite cleanup phase exit gate.", trace);
    check_log(locking_proc1_logger, "Unlocked test suite cleanup phase exit gate.", trace);
    check_log(runner_trace_logger, "Passed test suite cleanup phase exit gate.", trace);
    check_no_log;

    core_pkg.mock_core_failure;
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    core_pkg.check_core_failure("Final log check failed");
    core_pkg.unmock_core_failure;

    check_log(runner_trace_logger, "Entering test runner cleanup phase.", trace);
    check_log(runner_trace_logger, "Halting on test runner cleanup phase entry gate.", trace);
    check_log(locking_proc1_logger, "Unlocked test runner cleanup phase entry gate.", trace);
    check_log(runner_trace_logger, "Passed test runner cleanup phase entry gate.", trace);
    check_log(runner_trace_logger, "Halting on test runner cleanup phase exit gate.", trace);
    check_log(locking_proc1_logger, "Unlocked test runner cleanup phase exit gate.", trace);
    check_log(locking_proc2_logger, "Unlocked test runner cleanup phase exit gate.", trace);
    check_log(runner_trace_logger, "Passed test runner cleanup phase exit gate.", trace);
    check_log(runner_trace_logger, "Entering test runner exit phase.", trace);
    unmock(locking_proc1_logger);
    unmock(locking_proc2_logger);
    unmock(runner_trace_logger);
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should be possible to track (un)lock commands to file and line number");
    test_case_setup;

    test_runner_setup(runner, "enabled_test_cases : test a");
    mock(runner_trace_logger);
    lock(runner, test_case_setup_entry_key, runner_trace_logger, line_num => 17, file_name => "foo1.vhd");
    lock(runner, test_case_setup_exit_key, runner_trace_logger, line_num => 18, file_name => "foo2.vhd");
    unlock(runner, test_case_setup_entry_key, runner_trace_logger, line_num => 19, file_name => "foo3.vhd");
    unlock(runner, test_case_setup_exit_key, runner_trace_logger, line_num => 20, file_name => "foo4.vhd");
    check_log(runner_trace_logger, "Locked test case setup phase entry gate.", trace,
              line_num => 17, file_name => "foo1.vhd");
    check_log(runner_trace_logger, "Locked test case setup phase exit gate.", trace,
              line_num => 18, file_name => "foo2.vhd");
    check_log(runner_trace_logger, "Unlocked test case setup phase entry gate.", trace,
              line_num => 19, file_name => "foo3.vhd");
    check_log(runner_trace_logger, "Unlocked test case setup phase exit gate.", trace,
              line_num => 20, file_name => "foo4.vhd");
    unmock(runner_trace_logger);
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should be possible to identify fatal exits in cleanup code");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : test a,, test b,, test c,, test d");
    while test_suite loop
      while in_test_case loop
        if run("test a") then
          null;
        elsif run("test b") then
          exit when test_case_error(true);
        elsif run("test c") then
          exit when test_suite_error(true);
        end if;
      end loop;
      check_implication(c, active_test_case = "test a",
                        not test_case_exit and not test_suite_exit and not test_exit,
                        "Didn't expect (test_case_exit, test_suite_exit, test_exit) = ("
                        & boolean'image(test_case_exit) & ", " & boolean'image(test_suite_exit) & ", " & boolean'image(test_exit) & ") after " & active_test_case);
      check_implication(c, active_test_case = "test b",
                        test_case_exit and not test_suite_exit and test_exit,
                        "Didn't expect (test_case_exit, test_suite_exit, test_exit) = ("
                        & boolean'image(test_case_exit) & ", " & boolean'image(test_suite_exit) & ", " & boolean'image(test_exit) & ") after " & active_test_case);
      check_implication(c, active_test_case = "test c",
                        not test_case_exit and test_suite_exit and test_exit,
                        "Didn't expect (test_case_exit, test_suite_exit, test_exit) = ("
                        & boolean'image(test_case_exit) & ", " & boolean'image(test_suite_exit) & ", " & boolean'image(test_exit) & ") after " & active_test_case);
      check_false(c, active_test_case = "test d", "Test case d should not be executed");
    end loop;
    check(c, active_test_case = "test c", "Expected test suite to end on test c");
    check(c, not test_case_exit and test_suite_exit and test_exit,
          "Didn't expect (test_case_exit, test_suite_exit, test_exit) = ("
          & boolean'image(test_case_exit) & ", " & boolean'image(test_suite_exit) & ", " & boolean'image(test_exit) & ") after " & active_test_case);
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should be possible to time-out a test runner that is stuck");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : test a,, test b,, test c,, test d");
    start_test_runner_watchdog <= true;
    wait for 0 ns;
    start_test_runner_watchdog <= false;
    t_start := now;
    core_pkg.mock_core_failure;
    wait until test_runner_watchdog_completed for 11 ns;
    check(c, test_runner_watchdog_completed and (now - t_start = 10 ns), "Test runner watchdog failed to time-out");
    core_pkg.check_and_unmock_core_failure;

    assert get_log_count(runner_trace_logger, error) = 1;
    assert get_log_count(runner_trace_logger, failure) = 0;
    reset_log_count(runner_trace_logger, error);

    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should be possible to externally figure out if the test runner terminated without errors.");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : test a,, test b,, test c,, test d");
    wait for 0 ns;
    check_equal(c, runner(runner_exit_status_idx), runner_exit_with_errors,
          "Expected exit with error status after runner setup");
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    wait for 0 ns;
    check_equal(c, runner(runner_exit_status_idx), runner_exit_without_errors,
          "Expected exit without error status after runner cleanup");
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should be possible to read running test case when running all");
    test_case_setup;
    i := 0;
    while test_suite loop
      check_implication(c, i = 0, running_test_case = "", "Expected running test case to be """"");
      if run("Should a") then
        check_equal(c, running_test_case, "Should a", "Expected running test case to be ""Should a""");
      elsif run("Should b") then
        check_equal(c, running_test_case, "Should b", "Expected running test case to be ""Should b""");
      elsif run("Should c") then
        check_equal(c, running_test_case, "Should c", "Expected running test case to be ""Should c""");
      else
        check_equal(c, running_test_case, "", "Expected running test case to be """"");
      end if;
      i := i + 1;
    end loop;
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should be able to parse runner configuration using convenience functions");
    test_case_setup;
    if runner_cfg /= null then
      deallocate(runner_cfg);
    end if;
    write(runner_cfg,
          string'("active python runner : true, enabled_test_cases : foo,, bar, output path : some_dir/out, tb path : some_other_dir/test"));
    check(c, active_python_runner(runner_cfg.all), "Expected active python runner to be true");
    passed := vunit_lib.run_pkg.output_path(runner_cfg.all) = "some_dir/out";
    check(c, passed, "Expected output path to be ""some_dir/out"" but got " & vunit_lib.run_pkg.output_path(runner_cfg.all));
    passed := enabled_test_cases(runner_cfg.all) = "foo, bar";
    check(c, passed, "Expected enabled_test_cases to be ""foo, bar"" but got " & enabled_test_cases(runner_cfg.all));
    passed := vunit_lib.run_pkg.tb_path(runner_cfg.all) = "some_other_dir/test";
    check(c, passed, "Expected tb path to be ""some_other_dir/test"" but got " & vunit_lib.run_pkg.tb_path(runner_cfg.all));

    check_false(c, active_python_runner(""), "Expected active python runner to be false");
    passed := vunit_lib.run_pkg.output_path("") = "";
    check(c, passed, "Expected output path to be """" but got " & vunit_lib.run_pkg.output_path(""));
    passed := enabled_test_cases("") = "__all__";
    check(c, passed, "Expected enabled_test_cases to be ""__all__"" but got " & enabled_test_cases(""));
    passed := vunit_lib.run_pkg.tb_path("") = "";
    check(c, passed, "Expected tb path to be """" but got " & vunit_lib.run_pkg.tb_path(""));

    ---------------------------------------------------------------------------
    banner("Should recognize runner_cfg_t for backward compatibility");
    test_case_setup;
    check(runner_cfg_t'("foo") = string'("foo"));
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should dervive seeds");
    test_case_setup;

    -- Golden values retrieved from https://md5calc.com/hash/fnv1a64
    seed := vunit_lib.run_pkg.get_seed("active python runner : true,enabled_test_cases : foo,seed : dbe809ff2fc90f23");
    passed := seed = "ea8ad912addacf64";
    check(c, passed, "Expected seed from runner_cfg to be ""ea8ad912addacf64"" but got """ & seed & """");

    seed := vunit_lib.run_pkg.get_string_seed("active python runner : true,enabled_test_cases : foo,seed : 075bd4fa7dc381cb", "Adding some salt");
    passed := seed = "30b243ae942e63d8";
    check(c, passed, "Expected seed from runner_cfg to be ""30b243ae942e63d8"" but got """ & seed & """");

    seed := vunit_lib.run_pkg.get_seed("active python runner : true,enabled_test_cases : foo,seed : &");
    passed := seed = "af639b4c86017e19";
    check(c, passed, "Expected seed from runner_cfg to be ""af639b4c86017e19"" but got """ & seed & """");

    seed := vunit_lib.run_pkg.get_seed("active python runner : true,enabled_test_cases : foo,seed : kjdabhsdye3773hllajhhd88JKK8");
    passed := seed = "20f0a7bc0a0413d9";
    check(c, passed, "Expected seed from runner_cfg to be ""20f0a7bc0a0413d9"" but got """ & seed & """");

    seed_unsigned := vunit_lib.run_pkg.get_unsigned_seed("active python runner : true,enabled_test_cases : foo,seed : 075bd4fa7dc381cb", "Adding some salt");
    passed := seed_unsigned = x"30b243ae942e63d8";
    check(c, passed, "Expected seed from runner_cfg to be x""30b243ae942e63d8"" but got """ &
          hex_image(std_logic_vector(seed_unsigned)) & """");

    seed_signed := vunit_lib.run_pkg.get_signed_seed("active python runner : true,enabled_test_cases : foo,seed : 075bd4fa7dc381cb", "Adding some salt");
    passed := seed_signed = x"30b243ae942e63d8";
    check(c, passed, "Expected seed from runner_cfg to be x""30b243ae942e63d8"" but got """ &
          hex_image(std_logic_vector(seed_signed)) & """");

    seed_int := vunit_lib.run_pkg.get_integer_seed("active python runner : true,enabled_test_cases : foo,seed : 075bd4fa7dc381cb", "Adding some salt");
    passed := seed_int = -1808899112;
    check(c, passed, "Expected seed from runner_cfg to be -1808899112 but got " & integer'image(seed_int));

    start_seed_process <= true;
    wait for 1 ns;

    test_runner_setup(runner, "active python runner : true,enabled_test_cases : foo,seed : ce29981ce6db0c97");

    get_seed(seed);
    passed := seed = "e288ad7e1c4dbcb5";
    check(c, passed, "Expected seed to be ""e288ad7e1c4dbcb5"" but got """ & seed & """");

    get_seed(seed, "Another seed");
    passed := seed = "0237b40b3d893879";
    check(c, passed, "Expected seed to be ""0237b40b3d893879"" but got """ & seed & """");

    get_seed(seed_unsigned, "Another seed");
    passed := seed_unsigned = x"0237b40b3d893879";
    check(c, passed, "Expected seed to be x""0237b40b3d893879"" but got """ &
          hex_image(std_logic_vector(seed_unsigned)) & """");

    get_seed(seed_signed, "Another seed");
    passed := seed_signed = x"0237b40b3d893879";
    check(c, passed, "Expected seed to be x""0237b40b3d893879"" but got """ &
          hex_image(std_logic_vector(seed_signed)) & """");

    get_seed(seed_int, "Another seed");
    passed := seed_int = 1032403065;
    check(c, passed, "Expected seed to be 1032403065 but got " & integer'image(seed_int));

    get_uniform_seed(seed1, seed2);
    passed := seed1 = 1653124479;
    check(c, passed, "Expected seed1 to be 1653124479 but got " & integer'image(seed1));
    passed := seed2 = 474856630;
    check(c, passed, "Expected seed2 to be 474856630 but got " & integer'image(seed2));

    get_uniform_seed(seed1, seed2, "Some seed!");
    passed := seed1 = 481347971;
    check(c, passed, "Expected seed1 to be 481347971 but got " & integer'image(seed1));
    passed := seed2 = 80218126;
    check(c, passed, "Expected seed2 to be 80218126 but got " & integer'image(seed2));

    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    test_case_cleanup;

    ---------------------------------------------------------------------------

    core_pkg.setup(output_path & "vunit_results");
    core_pkg.test_suite_done;
    core_pkg.stop(0);
    wait;
  end process;
end test_fixture;
