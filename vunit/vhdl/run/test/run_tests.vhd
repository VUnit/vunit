-- This test suite verifies the VHDL test runner functionality
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

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
use vunit_lib.sync_point_db_pkg.all;
use vunit_lib.sync_point_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity run_tests is
  generic(output_path : string);
end entity;

architecture test_fixture of run_tests is
  signal start_test_runner_watchdog, test_runner_watchdog_completed : boolean := false;

  impure function get_phase return runner_phase_t is
  begin
    return get_phase(runner_state);
  end;

begin
  watchdog : process is
  begin
    wait until start_test_runner_watchdog;
    test_runner_watchdog(runner, 10 ns);
    test_runner_watchdog_completed <= true;
    runner(runner_exit_status_idx) <= runner_exit_with_errors;
  end process watchdog;

  test_runner : process
    procedure banner(
      constant s : in string) is
      constant dashes : string(1 to 256) := (others => '-');
    begin
      info(dashes(s'range) & LF & s & LF & dashes(s'range) & LF);
    end banner;

    procedure test_case_setup(join_sync_point : boolean := false) is
    begin
      if join_sync_point then
        join(test_runner_cleanup_entry, runner_id);
      end if;
      runner_init(runner_state);
      runner(runner_exit_status_idx) <= runner_exit_with_errors;
      if runner(runner_event_idx) /= runner_event then
        runner(runner_event_idx) <= runner_event;
        wait until runner(runner_event_idx) = runner_event;
        runner(runner_event_idx) <= idle_runner;
      end if;
    end;

    constant c : checker_t := new_checker("checker_t", default_log_level => failure);

    procedure test_case_cleanup(sync_sync_point : boolean := true) is
      variable stat : checker_stat_t;
    begin
      if sync_sync_point then
        sync(test_runner_cleanup_entry, runner_id);
      end if;
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
    test_case_setup(true);
    mock(get_logger("parent:unmocked_logger"));

    core_pkg.mock_core_failure;
    test_runner_cleanup(runner);
    core_pkg.check_and_unmock_core_failure;

    test_case_setup(true);
    unmock(get_logger("parent:unmocked_logger"));
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Error log cause failure on test_runner_cleanup");
    test_case_setup(true);
    error(get_logger("parent:my_logger"), "error message");
    core_pkg.mock_core_failure;
    test_runner_cleanup(runner);
    test_case_setup(true);
    core_pkg.check_and_unmock_core_failure;
    test_case_cleanup;
    reset_log_count(get_logger("parent:my_logger"), error);

    ---------------------------------------------------------------------------
    banner("Error log cause failure on test_runner_cleanup");
    test_case_setup(true);
    disable_stop(get_logger("parent:my_logger"), failure);
    failure(get_logger("parent:my_logger"), "failure message 1");
    failure(get_logger("parent:my_logger"), "failure message 2");
    set_stop_count(get_logger("parent:my_logger"), failure, 1);
    core_pkg.mock_core_failure;
    test_runner_cleanup(runner);
    test_case_setup(true);
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
    test_case_cleanup;
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
    test_case_cleanup;
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
        check(c, get_phase = test_case, "Phase should be test case main." & " Got " & runner_phase_t'image(get_phase) & ".");
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

    test_case_cleanup(false);

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
        check(c, get_phase = test_case, "Phase should be test case main." & " Got " & runner_phase_t'image(get_phase) & ".");
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
      check(c, get_phase = test_case_cleanup, "Phase should be test case cleanup." & " Got " & runner_phase_t'image(get_phase) & ".");
    end loop;
    check(c, get_phase = test_suite_cleanup, "Phase should be test suite cleanup" & " Got " & runner_phase_t'image(get_phase) & ".");
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    check(c, get_phase = test_runner_exit, "Phase should be test runner exit" & " Got " & runner_phase_t'image(get_phase) & ".");


    test_case_cleanup(false);

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
        check(c, get_phase = test_case, "Phase should be test case main." & " Got " & runner_phase_t'image(get_phase) & ".");
        check(c, i = 0, "The second test case should never be activated");
        check_false(c, run("test b"), "Test b should not be enabled at this time.");
        check(c, run("test a"), "Test a should be enabled at this time");
        i := i + 1;
        exit when test_suite_error(true);
      end loop;
      check(c, get_phase = test_case_cleanup, "Phase should be test case cleanup." & " Got " & runner_phase_t'image(get_phase) & ".");
    end loop;
    check(c, get_phase = test_suite_cleanup, "Phase should be test suite cleanup." & " Got " & runner_phase_t'image(get_phase) & ".");
    p_disable_simulation_exit(runner_state);
    test_runner_cleanup(runner);
    check(c, get_phase = test_runner_exit, "Phase should be test runner exit" & " Got " & runner_phase_t'image(get_phase) & ".");

    test_case_cleanup(false);

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
    test_case_cleanup(false);

    ---------------------------------------------------------------------------
    banner("Should be possible to exit a test suite from the test case/suite from the test case cleanup code.");
    test_case_setup;
    test_case_cleanup(false);

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
    test_case_cleanup(false);

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
    test_case_cleanup(false);

    ---------------------------------------------------------------------------
    banner("Should run all when the runner hasn't been initialized");
    test_case_setup(true);
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
    test_case_cleanup(false);

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
    test_case_cleanup(false);

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

    test_case_cleanup(false);

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
    test_case_cleanup(false);

    ---------------------------------------------------------------------------
    banner("Should be possible to read running test case when running all");
    test_case_setup(true);
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
    test_case_cleanup(false);

    ---------------------------------------------------------------------------
    banner("Should be able to parse runner configuration using convenience functions");
    test_case_setup;
    if runner_cfg /= null then
      deallocate(runner_cfg);
    end if;
    write(runner_cfg, string'("active python runner : true, enabled_test_cases : foo,, bar, output path : some_dir/out, tb path : some_other_dir/test"));
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
    test_case_cleanup;

    ---------------------------------------------------------------------------
    banner("Should recognize runner_cfg_t for backward compatibility");
    test_case_setup;
    check(runner_cfg_t'("foo") = string'("foo"));
    test_case_cleanup;

    ---------------------------------------------------------------------------

    core_pkg.setup(output_path & "vunit_results");
    core_pkg.test_suite_done;
    core_pkg.stop(0);
    wait;
  end process;
end test_fixture;
