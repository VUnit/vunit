-- This test suite verifies the check_false checker.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- vunit: run_all_in_same_sim

library ieee;
use ieee.std_logic_1164.all;
library vunit_lib;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.runner_pkg.all;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use work.test_support.all;

entity tb_check_false is
  generic (
    runner_cfg : string);
end entity tb_check_false;

architecture test_fixture of tb_check_false is
  signal clk : std_logic := '0';
  signal check_false_in_1, check_false_in_2, check_false_in_3, check_false_in_4 : std_logic := '0';
  signal check_false_en_1, check_false_en_2, check_false_en_3, check_false_en_4 : std_logic := '1';

  constant check_false_checker : checker_t := new_checker("checker1");
  constant check_false_checker2 : checker_t := new_checker("checker2");
  constant check_false_checker3 : checker_t := new_checker("checker3", default_log_level => info);
  constant check_false_checker4 : checker_t := new_checker("checker4");

  constant default_level : log_level_t := error;
begin
  clock: process is
  begin
    while get_phase(runner_state) < test_runner_exit loop
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
    end loop;
    wait;
  end process clock;

  check_false_1 : check_false(clk, check_false_en_1, check_false_in_1);
  check_false_2 : check_false(check_false_checker2, clk, check_false_en_2, check_false_in_2, active_clock_edge => falling_edge);
  check_false_3 : check_false(check_false_checker3, clk, check_false_en_3, check_false_in_3);
  check_false_4 : check_false(check_false_checker4, clk, check_false_en_4, check_false_in_4);

  check_false_runner : process
    variable passed : boolean;
    variable stat : checker_stat_t;

    procedure test_concurrent_check (
      signal clk                        : in  std_logic;
      signal check_input                : out std_logic;
      checker                           : checker_t ;
      constant level                    : in  log_level_t := error;
      constant active_rising_clock_edge : in  boolean := true) is
    begin
      -- Verify that one log is generated on high and that that log is
      -- generated on the correct clock edge. No log on low.
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      get_checker_stat(checker, stat);
      apply_sequence("1", clk, check_input, active_rising_clock_edge);
      wait until clock_edge(clk, not active_rising_clock_edge);
      wait for 1 ns;
      verify_passed_checks(checker, stat, 0);
      verify_failed_checks(checker, stat, 0);
      mock(get_logger(checker));
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      check_only_log(get_logger(checker), "False check failed.", level);
      unmock(get_logger(checker));
      verify_passed_checks(checker, stat, 0);
      verify_failed_checks(checker, stat, 1);
      apply_sequence("0", clk, check_input, active_rising_clock_edge);
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      verify_passed_checks(checker, stat, 1);
      verify_failed_checks(checker, stat, 1);
      reset_checker_stat(checker);
    end procedure test_concurrent_check;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should fail on true and logic 1 inputs to sequential checks") then
        get_checker_stat(stat);
        mock(check_logger);
        check_false(true);
        check_only_log(check_logger, "False check failed.", default_level);

        check_false(true, "");
        check_only_log(check_logger, "", default_level);

        check_false(passed, true, "Checking my data.", default_level);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Checking my data.", default_level);

        passed := check_false(true, result("for my data."), default_level);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "False check failed for my data.", default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 4);
        reset_checker_stat;

        get_checker_stat(check_false_checker, stat);
        mock(get_logger(check_false_checker));
        check_false(check_false_checker, true);
        check_only_log(get_logger(check_false_checker), "False check failed.", default_level);

        check_false(check_false_checker, passed, true, result("for my data."));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(check_false_checker), "False check failed for my data.", default_level);

        passed := check_false(check_false_checker, true, result("for my data."), default_level);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(check_false_checker), "False check failed for my data.", default_level);
        unmock(get_logger(check_false_checker));
        verify_passed_checks(check_false_checker,stat, 0);
        verify_failed_checks(check_false_checker,stat, 3);
        reset_checker_stat(check_false_checker);

      elsif run("Test should pass on false and logic 0 inputs to sequential checks") then
        get_checker_stat(stat);
        check_false(false);
        check_false(passed, false);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_false(false);
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(stat, 3);

        get_checker_stat(check_false_checker, stat);
        check_false(check_false_checker, false);
        check_false(check_false_checker, passed, false);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_false(check_false_checker, false);
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(stat, 3);
        verify_passed_checks(check_false_checker, stat, 3);

      elsif run("Test pass message") then
        mock(check_logger);
        check_false(false);
        check_only_log(check_logger, "False check passed.", pass);

        check_false(false, "");
        check_only_log(check_logger, "", pass);

        check_false(false, "Checking my data.");
        check_only_log(check_logger, "Checking my data.", pass);

        check_false(false, result("for my data."));
        check_only_log(check_logger, "False check passed for my data.", pass);
        unmock(check_logger);

      elsif run("Test should be possible to use concurrently") then
        test_concurrent_check(clk, check_false_in_1, default_checker);
      elsif run("Test should be possible to use concurrently with negative active clock edge") then
        test_concurrent_check(clk, check_false_in_2, check_false_checker2, error, false);
      elsif run("Test should be possible to use concurrently with custom checker") then
        test_concurrent_check(clk, check_false_in_3, check_false_checker3, info);
      elsif run("Test should pass on weak low but fail on other meta values") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(check_false_checker4, stat);
        apply_sequence("0L0", clk, check_false_in_4);
        wait until rising_edge(clk);
        wait for 1 ns;
        mock(get_logger(check_false_checker4));
        verify_passed_checks(check_false_checker4, stat, 3);
        verify_failed_checks(check_false_checker4, stat, 0);
        apply_sequence("0UXZWH-0", clk, check_false_in_4);
        wait until rising_edge(clk);
        wait for 1 ns;
        check_log(get_logger(check_false_checker4), "False check passed.", pass);
        check_log(get_logger(check_false_checker4), "False check failed.", default_level);
        check_log(get_logger(check_false_checker4), "False check failed.", default_level);
        check_log(get_logger(check_false_checker4), "False check failed.", default_level);
        check_log(get_logger(check_false_checker4), "False check failed.", default_level);
        check_log(get_logger(check_false_checker4), "False check failed.", default_level);
        check_log(get_logger(check_false_checker4), "False check failed.", default_level);
        check_log(get_logger(check_false_checker4), "False check passed.", pass);
        unmock(get_logger(check_false_checker4));
        verify_passed_checks(check_false_checker4, stat, 5);
        verify_failed_checks(check_false_checker4, stat, 6);
        reset_checker_stat(check_false_checker4);

      elsif run("Test should pass on logic high inputs when not enabled") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        check_false_en_1 <= '0';
        apply_sequence("10", clk, check_false_in_1);
        check_false_en_1 <= '1';
        wait until rising_edge(clk);
        check_false_en_1 <= 'L';
        apply_sequence("10", clk, check_false_in_1);
        check_false_en_1 <= 'H';
        wait until rising_edge(clk);
        check_false_en_1 <= 'X';
        apply_sequence("10", clk, check_false_in_1);
        check_false_en_1 <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        verify_passed_checks(stat, 3);
        verify_failed_checks(stat, 0);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;
