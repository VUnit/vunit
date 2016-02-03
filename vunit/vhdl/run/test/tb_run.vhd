-- This test suite verifies the VHDL test runner functionality
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.lang.all;
use vunit_lib.string_ops.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use std.textio.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.vunit_core_pkg;
use vunit_lib.vunit_stop_pkg;

entity tb_run is
  generic (output_path : string);
end entity tb_run;

architecture test_fixture of tb_run is
  signal start_test_process, start_test_process2 : boolean := false;
  signal test_process_completed : boolean := false;
  signal start_locking_process : boolean := false;
  signal start_test_runner_watchdog, test_runner_watchdog_completed : boolean := false;
begin
  test_process : process is
    variable t_start : time;
  begin
    wait until start_test_process;
    t_start := now;
    if runner.phase /= test_suite_setup then
      wait until runner.phase = test_suite_setup for 20 ns;
    end if;
    check(now - t_start = 17 ns, "Expected wait on test_suite_setup phase to be 17 ns.");
    t_start := now;
    if runner.phase /= test_case_setup then
      wait until runner.phase = test_case_setup for 20 ns;
    end if;
    check(now - t_start = 9 ns, "Expected wait on test_case_setup phase to be 9 ns.");
    test_process_completed <= true;
    wait;
  end process;

  test_process2 : process is
  begin
    wait until start_test_process2;
    lock_entry(runner, test_suite_setup);
    lock_exit(runner, test_suite_setup);
    wait for 7 ns;
    unlock_entry(runner, test_suite_setup);
    wait for 4 ns;
    unlock_exit(runner, test_suite_setup);
    wait;
  end process;

  locking_proc1: process is
  begin
    wait until start_locking_process = true;
    lock_entry(runner, test_runner_setup, "locking_proc1");
    lock_exit(runner, test_runner_setup, "locking_proc1");
    lock_entry(runner, test_suite_setup, "locking_proc1");
    lock_exit(runner, test_suite_setup, "locking_proc1");
    wait for 2 ns;
    unlock_entry(runner, test_runner_setup, "locking_proc1");
    wait for 1 ns;
    unlock_exit(runner, test_runner_setup, "locking_proc1");
    wait for 1 ns;
    unlock_entry(runner, test_suite_setup, "locking_proc1");
    wait for 2 ns;

    lock_entry(runner, test_case_setup, "locking_proc1");
    lock_exit(runner, test_case_setup, "locking_proc1");
    lock_entry(runner, test_case, "locking_proc1");
    lock_exit(runner, test_case, "locking_proc1");
    lock_entry(runner, test_case_cleanup, "locking_proc1");
    lock_exit(runner, test_case_cleanup, "locking_proc1");
    lock_entry(runner, test_suite_cleanup, "locking_proc1");
    lock_exit(runner, test_suite_cleanup, "locking_proc1");
    lock_entry(runner, test_runner_cleanup, "locking_proc1");
    lock_exit(runner, test_runner_cleanup, "locking_proc1");

    wait for 1 ns;
    unlock_exit(runner, test_suite_setup, "locking_proc1");
    wait for 1 ns;
    unlock_entry(runner, test_case_setup, "locking_proc1");
    wait for 2 ns;
    unlock_exit(runner, test_case_setup, "locking_proc1");
    wait for 1 ns;
    unlock_entry(runner, test_case, "locking_proc1");
    wait for 2 ns;
    unlock_exit(runner, test_case, "locking_proc1");
    wait for 1 ns;
    unlock_entry(runner, test_case_cleanup, "locking_proc1");
    wait for 2 ns;
    unlock_exit(runner, test_case_cleanup, "locking_proc1");
    wait for 4 ns;
    unlock_entry(runner, test_suite_cleanup, "locking_proc1");
    wait for 2 ns;
    unlock_exit(runner, test_suite_cleanup, "locking_proc1");
    wait for 1 ns;
    unlock_entry(runner, test_runner_cleanup, "locking_proc1");
    wait for 1 ns;
    unlock_exit(runner, test_runner_cleanup, "locking_proc1");
    wait;
  end process locking_proc1;

  locking_proc2: process is
  begin
    wait until start_locking_process = true;
    wait for 5 ns;
    lock_exit(runner, test_runner_cleanup, "locking_proc2");
    wait for 21 ns;
    unlock_exit(runner, test_runner_cleanup, "locking_proc2");
    wait;
  end process locking_proc2;

  watchdog: process is
  begin
    wait until start_test_runner_watchdog;
    test_runner_watchdog(runner, 10 ns, true);
    test_runner_watchdog_completed <= true;
    runner.exit_without_errors <= false;
  end process watchdog;

  test_runner : process
    procedure banner (
      constant s : in string) is
      variable dashes : string(1 to 256) := (others => '-');
    begin
      info(dashes(s'range) & LF & s & LF & dashes(s'range) & LF);
    end banner;

    procedure verify_log_file (
      constant log_file_name : in string;
      variable entries   : inout line_vector;
      constant start : in natural;
      constant stop : in natural;
      constant src : string := "";
      constant line_num  : in natural := 0;
      constant file_name : in string := "") is
      file f : text;
      variable l : line;
      variable status : file_open_status;
      variable pass : boolean;
      variable fields : lines_t := new line_vector(0 to 10);
    begin
      file_open(status, f, log_file_name, read_mode);
      check(status = open_ok, "Failed opening " & log_file_name & " (" & file_open_status'image(status) & ").");
      if status = open_ok then
        for i in 1 to start - 1 loop
          check_false(pass, endfile(f), "End of log file when seeking for start line");
          exit when not pass;
          readline(f, l);
        end loop;
        for i in start to stop loop
          check_false(pass, endfile(f), "End of log file when expecting log entry" & LF & entries(i).all);
          exit when not pass;
          readline(f, l);
          fields := split(l.all, ",");
          check(fields(6).all = entries(i).all, "Expected log entry" & LF & entries(i).all & LF & "but got" & LF & fields(6).all);
          if (entries(i).all(1 to 8) = "Unlocked") or (entries(i).all(1 to 6) = "Locked") then
            check(fields(5).all = src, "Expected src = " & src & " but got " & fields(5).all);
          end if;
          if (entries(i).all(1 to 11) = "Test case: ") then
            check(fields(2).all = "info", "Expected info level on test case name log entry.");
          else
            check(fields(2).all = "debug", "Expected debug level on all but test case name log entries.");
          end if;
          if file_name /= "" then
            check(fields(3).all = file_name, "Expected file name = " & file_name & " but got " & fields(3).all);
            pass := fields(4).all = natural'image(line_num);
            check(pass, "Expected line num = " & natural'image(line_num) & " but got " & fields(4).all);
          end if;
        end loop;
      end if;
      file_close(f);
      deallocate(fields);
    end verify_log_file;

    procedure test_case_setup is
    begin
      set_phase(test_runner_entry);
      runner.phase <= test_runner_entry;
      runner.exit_without_errors <= false;
    end procedure test_case_setup;

    variable checker_stat, test_checker_stat : checker_stat_t;
    variable i : natural;
    variable n_run_a, n_run_b, n_run_c : natural := 0;
    variable t_start : time;
    variable test_trace_logger : logger_t;
    variable test_trace_logger_cfg : logger_cfg_export_t;
    variable log_entries : line_vector(1 to 100);
    variable test_checker : checker_t;
    variable c : checker_t;
    variable checker_cfg : checker_cfg_t;
    variable runner_cfg : line;
    variable passed : boolean;
  begin
    logger_init(runner_trace_logger, file_name => output_path & "test_runner_trace.csv");
    checker_init(c, display_format => verbose, default_src => "Test Runner", stop_level => error, file_name => output_path & "error.csv");

    banner("Should extract single enabled test case from input string");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : Should foo");
    check(c, num_of_enabled_test_cases = 1, "Expected 1 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should foo"), "Expected ""Should foo"" test case to be enabled");
    check_false(c, enabled("Should bar"), "Didn't expected ""Should bar"" test case to be enabled.");

    ---------------------------------------------------------------------------
    banner("Should extract multiple enabled test cases from input string");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : Should bar,,Should zen");
    check(c, num_of_enabled_test_cases = 2, "Expected 2 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should bar"), "Expected ""Should bar"" test case to be enabled");
    check(c, enabled("Should zen"), "Expected ""Should zen"" test case to be enabled");
    check_false(c, enabled("Should toe"), "Didn't expected ""Should zen"" test case to be enabled.");

    ---------------------------------------------------------------------------
    banner("Should strip leading and trailing spaces from test case names");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : Should one ,,  Should two  ,, Should three");
    check(c, num_of_enabled_test_cases = 3, "Expected 3 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one"), "Expected ""Should one"" test case to be enabled");
    check(c, enabled("Should two"), "Expected ""Should two"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");

    ---------------------------------------------------------------------------
    banner("Should not enable any test cases on empty input string for enabled test cases");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases:");
    check(c, num_of_enabled_test_cases = 0, "Expected 0 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");

    ---------------------------------------------------------------------------
    banner("Should not enable any test cases on space input string for enabled test cases");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases:   ");
    check(c, num_of_enabled_test_cases = 0, "Expected 0 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");

    ---------------------------------------------------------------------------
    banner("Should ignore test case names with only spaces");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : Should one ,,    ,, Should three");
    check(c, num_of_enabled_test_cases = 2, "Expected 2 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one"), "Expected ""Should one"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");

    ---------------------------------------------------------------------------
    banner("Should allow comma in test case name");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : Should one ,,,,  Should two  ,, Should three");
    check(c, num_of_enabled_test_cases = 2, "Expected 2 enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one ,  Should two"), "Expected ""Should one ,  Should two"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");

    ---------------------------------------------------------------------------
    banner("Should enable all on __all__ input string");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : __all__");
    check(c, num_of_enabled_test_cases = unknown_num_of_test_cases_c, "Expected " & integer'image(unknown_num_of_test_cases_c) & " enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one"), "Expected ""Should one"" test case to be enabled");
    check(c, enabled("Should two"), "Expected ""Should two"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");

    ---------------------------------------------------------------------------
    banner("Should enable all by default");
    test_case_setup;
    test_runner_setup(runner);
    check(c, num_of_enabled_test_cases = unknown_num_of_test_cases_c, "Expected " & integer'image(unknown_num_of_test_cases_c) & " enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one"), "Expected ""Should one"" test case to be enabled");
    check(c, enabled("Should two"), "Expected ""Should two"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");

    ---------------------------------------------------------------------------
    banner("Should enable all on empty string");
    test_case_setup;
    test_runner_setup(runner, "");
    check(c, num_of_enabled_test_cases = unknown_num_of_test_cases_c, "Expected " & integer'image(unknown_num_of_test_cases_c) & " enabled test case but got " & integer'image(num_of_enabled_test_cases) & ".");
    check(c, enabled("Should one"), "Expected ""Should one"" test case to be enabled");
    check(c, enabled("Should two"), "Expected ""Should two"" test case to be enabled");
    check(c, enabled("Should three"), "Expected ""Should three"" test case to be enabled");

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
    test_runner_setup(runner);
    check(c, run("Should a"), "Expected ""Should a"" to run.");



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
    test_runner_cleanup(runner, disable_simulation_exit => true);
    check(c, get_phase = test_runner_exit, "Phase should be test runner exit" & " Got " & runner_phase_t'image(get_phase) & ".");



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
    test_runner_cleanup(runner, disable_simulation_exit => true);
    check(c, get_phase = test_runner_exit, "Phase should be test runner exit" & " Got " & runner_phase_t'image(get_phase) & ".");



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
    test_runner_cleanup(runner, disable_simulation_exit => true);
    check(c, get_phase = test_runner_exit, "Phase should be test runner exit" & " Got " & runner_phase_t'image(get_phase) & ".");

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

    ---------------------------------------------------------------------------
    banner("Should be possible to exit a test suite from the test case/suite from the test case cleanup code.");
    test_case_setup;


    ---------------------------------------------------------------------------
    banner("Should be possible to stall execution and stall the exit of a phase");
    test_case_setup;
    start_test_process2 <= true;
    t_start := now;
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
    test_runner_cleanup(runner, disable_simulation_exit => true);



    ---------------------------------------------------------------------------
    banner("Should be possible to suspend a process/procedure waiting for a specific phase");
    test_case_setup;
    start_test_process <= true;
    wait for 17 ns;
    test_runner_setup(runner, "enabled_test_cases : test a");
    wait for 9 ns;
    while test_suite loop
      entry_gate(runner);
      while in_test_case loop
      end loop;
    end loop;
    test_runner_cleanup(runner, disable_simulation_exit => true);
    if not test_process_completed then
      wait until test_process_completed;
    end if;



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
    test_runner_cleanup(runner, disable_simulation_exit => true);

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
    test_runner_cleanup(runner, disable_simulation_exit => true);

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
    test_runner_cleanup(runner, disable_simulation_exit => true);

    ---------------------------------------------------------------------------
    banner("Should have a trace log where source of locking/unlocking commands can be logged. All but test case name entries should have the debug level.");
    test_case_setup;
    logger_init(runner_trace_logger, "", output_path & "trace.txt", verbose, verbose_csv);

    start_locking_process <= true;

    for i in log_entries'range loop
      deallocate(log_entries(i));
    end loop;

    write(log_entries(1), string'("Locked test runner setup phase entry gate."));
    write(log_entries(2), string'("Locked test runner setup phase exit gate."));
    write(log_entries(3), string'("Locked test suite setup phase entry gate."));
    write(log_entries(4), string'("Locked test suite setup phase exit gate."));
    wait for 1 ns;

    test_runner_setup(runner, "enabled_test_cases : test a");
    write(log_entries(5), string'("Entering test runner setup phase."));
    write(log_entries(6), string'("Halting on test runner setup phase entry gate."));
    write(log_entries(7), string'("Unlocked test runner setup phase entry gate."));
    write(log_entries(8), string'("Passed test runner setup phase entry gate."));
    write(log_entries(9), string'("Halting on test runner setup phase exit gate."));
    write(log_entries(10), string'("Unlocked test runner setup phase exit gate."));
    write(log_entries(11), string'("Passed test runner setup phase exit gate."));
    write(log_entries(12), string'("Entering test suite setup phase."));
    write(log_entries(13), string'("Halting on test suite setup phase entry gate."));
    write(log_entries(14), string'("Unlocked test suite setup phase entry gate."));
    write(log_entries(15), string'("Passed test suite setup phase entry gate."));

    test_suite_setup_entry_gate(runner);
    write(log_entries(16), string'("Passed test suite setup phase entry gate."));
    write(log_entries(17), string'("Halting on test suite setup phase exit gate."));

    write(log_entries(18), string'("Locked test runner cleanup phase exit gate."));
    write(log_entries(19), string'("Locked test case setup phase entry gate."));
    write(log_entries(20), string'("Locked test case setup phase exit gate."));
    write(log_entries(21), string'("Locked test case phase entry gate."));
    write(log_entries(22), string'("Locked test case phase exit gate."));
    write(log_entries(23), string'("Locked test case cleanup phase entry gate."));
    write(log_entries(24), string'("Locked test case cleanup phase exit gate."));
    write(log_entries(25), string'("Locked test suite cleanup phase entry gate."));
    write(log_entries(26), string'("Locked test suite cleanup phase exit gate."));
    write(log_entries(27), string'("Locked test runner cleanup phase entry gate."));
    write(log_entries(28), string'("Locked test runner cleanup phase exit gate."));

    test_suite_setup_exit_gate(runner);
    write(log_entries(29), string'("Unlocked test suite setup phase exit gate."));
    write(log_entries(30), string'("Passed test suite setup phase exit gate."));

    while test_suite loop
      write(log_entries(31), string'("Entering test case setup phase."));

      test_case_setup_entry_gate(runner);
      write(log_entries(32), string'("Halting on test case setup phase entry gate."));
      write(log_entries(33), string'("Unlocked test case setup phase entry gate."));
      write(log_entries(34), string'("Passed test case setup phase entry gate."));
      wait for 1 ns;
      test_case_setup_exit_gate(runner);
      write(log_entries(35), string'("Halting on test case setup phase exit gate."));
      write(log_entries(36), string'("Unlocked test case setup phase exit gate."));
      write(log_entries(37), string'("Passed test case setup phase exit gate."));

      while in_test_case loop
        write(log_entries(38), string'("Entering test case phase."));

        test_case_entry_gate(runner);
        write(log_entries(39), string'("Halting on test case phase entry gate."));
        write(log_entries(40), string'("Unlocked test case phase entry gate."));
        write(log_entries(41), string'("Passed test case phase entry gate."));
        if run("test a") then
          wait for 1 ns;
        end if;
        write(log_entries(42), string'("Test case: test a"));
        test_case_exit_gate(runner);
        write(log_entries(43), string'("Halting on test case phase exit gate."));
        write(log_entries(44), string'("Unlocked test case phase exit gate."));
        write(log_entries(45), string'("Passed test case phase exit gate."));
      end loop;
      write(log_entries(46), string'("Entering test case cleanup phase."));

      test_case_cleanup_entry_gate(runner);
      write(log_entries(47), string'("Halting on test case cleanup phase entry gate."));
      write(log_entries(48), string'("Unlocked test case cleanup phase entry gate."));
      write(log_entries(49), string'("Passed test case cleanup phase entry gate."));
      wait for 1 ns;
      test_case_cleanup_exit_gate(runner);
      write(log_entries(50), string'("Halting on test case cleanup phase exit gate."));
      write(log_entries(51), string'("Unlocked test case cleanup phase exit gate."));
      write(log_entries(52), string'("Passed test case cleanup phase exit gate."));

    end loop;
    write(log_entries(53), string'("Entering test suite cleanup phase."));

    test_suite_cleanup_entry_gate(runner);
    write(log_entries(54), string'("Halting on test suite cleanup phase entry gate."));
    write(log_entries(55), string'("Unlocked test suite cleanup phase entry gate."));
    write(log_entries(56), string'("Passed test suite cleanup phase entry gate."));
    wait for 1 ns;
    test_suite_cleanup_exit_gate(runner);
    write(log_entries(57), string'("Halting on test suite cleanup phase exit gate."));
    write(log_entries(58), string'("Unlocked test suite cleanup phase exit gate."));
    write(log_entries(59), string'("Passed test suite cleanup phase exit gate."));

    test_runner_cleanup(runner, disable_simulation_exit => true);
    write(log_entries(60), string'("Entering test runner cleanup phase."));
    write(log_entries(61), string'("Halting on test runner cleanup phase entry gate."));
    write(log_entries(62), string'("Unlocked test runner cleanup phase entry gate."));
    write(log_entries(63), string'("Passed test runner cleanup phase entry gate."));
    write(log_entries(64), string'("Halting on test runner cleanup phase exit gate."));
    write(log_entries(65), string'("Unlocked test runner cleanup phase exit gate."));
    write(log_entries(66), string'("Unlocked test runner cleanup phase exit gate."));
    write(log_entries(67), string'("Passed test runner cleanup phase exit gate."));
    write(log_entries(68), string'("Entering test runner exit phase."));

    verify_log_file(output_path & "trace.txt", log_entries, 1, 17, "locking_proc1");
    verify_log_file(output_path & "trace.txt", log_entries, 18, 18, "locking_proc2");
    verify_log_file(output_path & "trace.txt", log_entries, 19, 65, "locking_proc1");
    verify_log_file(output_path & "trace.txt", log_entries, 66, 66, "locking_proc2");
    verify_log_file(output_path & "trace.txt", log_entries, 67, 68, "locking_proc1");

    ---------------------------------------------------------------------------
    banner("Should be possible to track (un)lock commands to file and line number");
    test_case_setup;
    logger_init(runner_trace_logger, "", output_path & "trace2.txt", verbose, verbose_csv);

    test_runner_setup(runner, "enabled_test_cases : test a");
    lock_entry(runner, test_case_setup, "me", 17, "foo1.vhd");
    lock_exit(runner, test_case_setup, "me", 18, "foo2.vhd");
    unlock_entry(runner, test_case_setup, "me", 19, "foo3.vhd");
    unlock_exit(runner, test_case_setup, "me", 20, "foo4.vhd");

    for i in log_entries'range loop
      deallocate(log_entries(i));
    end loop;

    write(log_entries(6), string'("Locked test case setup phase entry gate."));
    write(log_entries(7), string'("Locked test case setup phase exit gate."));
    write(log_entries(8), string'("Unlocked test case setup phase entry gate."));
    write(log_entries(9), string'("Unlocked test case setup phase exit gate."));

    test_runner_cleanup(runner, disable_simulation_exit => true);

    verify_log_file(output_path & "trace2.txt", log_entries, 6, 6, "me", 17, "foo1.vhd");
    verify_log_file(output_path & "trace2.txt", log_entries, 7, 7, "me", 18, "foo2.vhd");
    verify_log_file(output_path & "trace2.txt", log_entries, 8, 8, "me", 19, "foo3.vhd");
    verify_log_file(output_path & "trace2.txt", log_entries, 9, 9, "me", 20, "foo4.vhd");

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
    test_runner_cleanup(runner, disable_simulation_exit => true);

    ---------------------------------------------------------------------------
    banner("Should be possible to time-out a test runner that is stuck");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : test a,, test b,, test c,, test d");
    checker_init(file_name =>output_path & "error.csv");
    start_test_runner_watchdog <= true;
    wait for 0 ns;
    start_test_runner_watchdog <= false;
    t_start := now;
    wait until test_runner_watchdog_completed for 11 ns;
    check(c, test_runner_watchdog_completed and (now - t_start = 10 ns), "Test runner watchdog failed to time-out");
    get_checker_stat(checker_stat);
    check(c, checker_stat.n_failed = 1, "Expected 1 error on default checker");
    reset_checker_stat;

    ---------------------------------------------------------------------------
    banner("Should be possible to externally figure out if the test runner terminated without errors.");
    test_case_setup;
    test_runner_setup(runner, "enabled_test_cases : test a,, test b,, test c,, test d");
    check_false(c, runner.exit_without_errors, "Expected exit flag to be false after runner setup");
    test_runner_cleanup(runner, disable_simulation_exit => true);
    check(c, runner.exit_without_errors, "Expected exit flag to be true after runner cleanup");

    ---------------------------------------------------------------------------
    banner("Should be possible to externally figure out if the test runner terminated with or errors.");
    test_case_setup;
    checker_init(test_checker, default_src => "Test Checker", file_name => output_path & "error.csv");
    test_runner_setup(runner, "enabled_test_cases : test a,, test b,, test c,, test d");
    check(test_checker, false, "Should fail");
    get_checker_stat(test_checker, test_checker_stat);
    test_runner_cleanup(runner, test_checker_stat, disable_simulation_exit => true);
    check_false(c, runner.exit_without_errors, "Expected exit flag to be false after runner cleanup");

    ---------------------------------------------------------------------------
    banner("Should be possible to read running test case when running all");
    test_case_setup;
    i := 0;
    while test_suite loop
      check_implication(c, i = 0, running_test_case = "", "Expected running test case to be """"");
      if run("Should a") then
        check(c, running_test_case = "Should a", "Expected running test case to be ""Should a""");
      elsif run("Should b") then
        check(c, running_test_case = "Should b", "Expected running test case to be ""Should b""");
      elsif run("Should c") then
        check(c, running_test_case = "Should c", "Expected running test case to be ""Should c""");
      else
        check(c, running_test_case = "", "Expected running test case to be """"");
      end if;
      i := i + 1;
    end loop;
    test_runner_cleanup(runner, disable_simulation_exit => true);

    ---------------------------------------------------------------------------
    banner("Should set stop level to the default level but maintain all other setting when Python runner is active");
    test_case_setup;
    checker_init(warning, "my_default_checker", output_path & "problems.csv", verbose, level, failure, ';');
    test_runner_setup(runner, "active python runner : true, fake active python runner : true");
    get_checker_cfg(checker_cfg);
    check(c, checker_cfg.default_level = warning, "Expected default level to be warning");
    check(c, checker_cfg.logger_cfg.log_default_src.all = "my_default_checker", "Expected default src to be ""my_default_checker""");
    passed := checker_cfg.logger_cfg.log_file_name.all = output_path & "problems.csv";
    check(c, passed, "Expected file name to be """ & output_path & "problems.csv""");
    check(c, checker_cfg.logger_cfg.log_display_format = verbose, "Expected display format to be verbose");
    check(c, checker_cfg.logger_cfg.log_file_format = level, "Expected file format to be level");
    check(c, checker_cfg.logger_cfg.log_stop_level = warning, "Expected stop level to be warning");
    check(c, checker_cfg.logger_cfg.log_separator = ';', "Expected separator to be ';'");

    ---------------------------------------------------------------------------
    banner("Should leave stop level as is when Python runner is inactive");
    test_case_setup;
    checker_init(warning, "my_default_checker", output_path & "problems.csv", verbose, level, failure, ';');
    test_runner_setup(runner, "active python runner : false");
    get_checker_cfg(checker_cfg);
    check(c, checker_cfg.default_level = warning, "Expected default level to be warning");
    check(c, checker_cfg.logger_cfg.log_default_src.all = "my_default_checker", "Expected default src to be ""my_default_checker""");
    passed := checker_cfg.logger_cfg.log_file_name.all = output_path & "problems.csv";
    check(c, passed, "Expected file name to be """ & output_path & "problems.csv""");
    check(c, checker_cfg.logger_cfg.log_display_format = verbose, "Expected display format to be verbose");
    check(c, checker_cfg.logger_cfg.log_file_format = level, "Expected file format to be level");
    check(c, checker_cfg.logger_cfg.log_stop_level = failure, "Expected stop level to be failure");
    check(c, checker_cfg.logger_cfg.log_separator = ';', "Expected separator to be ';'");

    ---------------------------------------------------------------------------
    banner("Should be able to parse runner configuration using convenience functions");
    test_case_setup;
    if runner_cfg /= null then
      deallocate(runner_cfg);
    end if;
    write(runner_cfg, string'("active python runner : true, enabled_test_cases : foo,, bar, output path : some_dir/out"));
    check(c, active_python_runner(runner_cfg.all), "Expected active python runner to be true");
    passed := vunit_lib.run_pkg.output_path(runner_cfg.all) = "some_dir/out";
    check(c, passed, "Expected output path to be ""some_dir/out"" but got " & vunit_lib.run_pkg.output_path(runner_cfg.all));
    passed := enabled_test_cases(runner_cfg.all) = "foo, bar";
    check(c, passed, "Expected enabled_test_cases to be ""foo, bar"" but got " & enabled_test_cases(runner_cfg.all));

    check_false(c, active_python_runner(""), "Expected active python runner to be false");
    passed := vunit_lib.run_pkg.output_path("") = "";
    check(c, passed, "Expected output path to be """" but got " & vunit_lib.run_pkg.output_path(""));
    passed := enabled_test_cases("") = "__all__";
    check(c, passed, "Expected enabled_test_cases to be ""__all__"" but got " & enabled_test_cases(""));

    ---------------------------------------------------------------------------
    banner("Should recognize runner_cfg_t for backward compatibility");
    check(runner_cfg_t'("foo") = string'("foo"));

    ---------------------------------------------------------------------------
    banner("Result");
    get_checker_stat(c, checker_stat);
    info("Number of checks: " & natural'image(checker_stat.n_checks));
    info("Number of passing checks: " & natural'image(checker_stat.n_passed));
    info("Number of failing checks: " & natural'image(checker_stat.n_failed));

    vunit_core_pkg.setup(output_path & "vunit_results");
    vunit_core_pkg.test_suite_done;
    vunit_stop_pkg.vunit_stop(0);
    wait;
  end process;
end test_fixture;
