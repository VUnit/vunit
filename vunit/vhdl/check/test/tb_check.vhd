-- This test suite verifies the check checker.
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
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.runner_pkg.all;
use vunit_lib.string_ptr_pkg.all;
use vunit_lib.core_pkg.all;
use work.test_support.all;
use ieee.numeric_std.all;

entity tb_check is
  generic (
    use_check_not_check_true : boolean := true;
    runner_cfg : string);
end entity tb_check;

architecture test_fixture of tb_check is
  signal clk : std_logic := '0';
  signal check_in_1, check_in_2, check_in_3, check_in_4 : std_logic := '1';
  signal check_en_1, check_en_2, check_en_3, check_en_4 : std_logic := '1';

  constant check_checker : checker_t := new_checker("checker");
  constant check_checker2 : checker_t := new_checker("checker2");
  constant check_checker3 : checker_t := new_checker("checker3", default_log_level => info);
  constant check_checker4 : checker_t := new_checker("checker4");

begin
  clock: process is
  begin
    while get_phase(runner_state) < test_runner_exit loop
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
    end loop;
    wait;
  end process clock;

  concurrent_checks: if use_check_not_check_true generate
    check_1 : check(clk, check_en_1, check_in_1);
    check_2 : check(check_checker2, clk, check_en_2, check_in_2, active_clock_edge => falling_edge);
    check_3 : check(check_checker3, clk, check_en_3, check_in_3);
    check_4 : check(check_checker4, clk, check_en_4, check_in_4);
  end generate concurrent_checks;

  concurrent_true_checks: if not use_check_not_check_true generate
    check_1 : check_true(clk, check_en_1, check_in_1);
    check_2 : check_true(check_checker2, clk, check_en_2, check_in_2, active_clock_edge => falling_edge);
    check_3 : check_true(check_checker3, clk, check_en_3, check_in_3);
    check_4 : check_true(check_checker4, clk, check_en_4, check_in_4);
  end generate concurrent_true_checks;

  check_runner : process
    variable passed : boolean;
    variable check_result : check_result_t;
    variable stat : checker_stat_t;
    constant default_level : log_level_t := error;

    function prefix return string is
    begin
      if use_check_not_check_true then
        return "Check ";
      else
        return "True check ";
      end if;
    end function prefix;

    procedure test_concurrent_check (
      signal clk                        : in  std_logic;
      signal check_input                : out std_logic;
      checker                           : checker_t;
      constant level                    : in  log_level_t := error;
      constant active_rising_clock_edge : in  boolean := true) is
    begin
      -- Verify that one log is generated on false and that that log is
      -- generated on the correct clock edge. No log on true.
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      get_checker_stat(checker, stat);
      apply_sequence("0", clk, check_input, active_rising_clock_edge);
      wait until clock_edge(clk, not active_rising_clock_edge);
      wait for 1 ns;
      verify_passed_checks(checker, stat, 0);
      verify_failed_checks(checker, stat, 0);
      mock(get_logger(checker));
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      check_only_log(get_logger(checker), prefix & "failed.", level);
      unmock(get_logger(checker));
      verify_passed_checks(checker, stat, 0);
      verify_failed_checks(checker, stat, 1);
      apply_sequence("1", clk, check_input, active_rising_clock_edge);
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      verify_passed_checks(checker, stat, 1);
      verify_failed_checks(checker, stat, 1);
      reset_checker_stat(checker);
    end procedure test_concurrent_check;

    procedure internal_check(
      checker   : checker_t;
      variable pass      : out   boolean;
      constant expr      : in    boolean;
      constant msg       : in    string := result(".")) is
    begin
      if use_check_not_check_true then
        check(checker, pass, expr, msg);
      else
        check_true(checker, pass, expr, msg);
      end if;
    end;

    procedure internal_check(
      checker   : checker_t;
      constant expr      : in    boolean;
      constant msg       : in    string := result(".")) is
    begin
      if use_check_not_check_true then
        check(checker, expr, msg);
      else
        check_true(checker, expr, msg);
      end if;
    end;

    procedure internal_check(
      constant expr      : in boolean;
      constant msg       : in string := result(".")) is
    begin
      if use_check_not_check_true then
        check(expr, msg);
      else
        check_true(expr, msg);
      end if;
    end;

    procedure internal_check(
      variable pass      : out boolean;
      constant expr      : in  boolean;
      constant msg       : in  string := result(".")) is
    begin
      if use_check_not_check_true then
        check(pass, expr, msg);
      else
        check_true(pass, expr, msg);
      end if;
    end;

    impure function internal_check(
      constant expr      : in boolean;
      constant msg       : in string := result("."))
      return boolean is
    begin
      if use_check_not_check_true then
        return check(expr, msg);
      else
        return check_true(expr, msg);
      end if;
    end;

    impure function internal_check(checker : checker_t; expr : boolean; msg : string := result("."))
      return boolean is
    begin
      if use_check_not_check_true then
        return check(checker, expr, msg);
      else
        return check_true(checker, expr, msg);
      end if;
    end;

    impure function internal_check(
      constant expr      : in boolean;
      constant msg       : in string := result("."))
      return check_result_t is
    begin
      if use_check_not_check_true then
        return check(expr, msg);
      else
        return check_true(expr, msg);
      end if;
    end;

    impure function internal_check(checker : checker_t; expr : boolean; msg : string := result("."))
      return check_result_t is
    begin
      if use_check_not_check_true then
        return check(checker, expr, msg);
      else
        return check_true(checker, expr, msg);
      end if;
    end;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should pass on true inputs to sequential checks") then
        get_checker_stat(stat);
        internal_check(true);
        internal_check(passed, true);
        assert_true(passed, "Should return pass = true on passing check");
        passed := internal_check(true);
        assert_true(passed, "Should return pass = true on passing check");
        check_result := internal_check(true);
        assert_true(check_result.p_is_pass, "Should return check_result.is_pass = true on passing check");
        assert_true(check_result.p_checker = default_checker);
        verify_passed_checks(stat, 4);

        get_checker_stat(check_checker, stat);
        internal_check(check_checker, true);
        internal_check(check_checker, passed, true);
        assert_true(passed, "Should return pass = true on passing check");
        passed := internal_check(check_checker, true);
        assert_true(passed, "Should return pass = true on passing check");
        check_result := internal_check(check_checker, true);
        assert_true(check_result.p_is_pass, "Should return check_result.is_pass = true on passing check");
        assert_true(check_result.p_checker = check_checker);
        verify_passed_checks(check_checker, stat, 4);

      elsif run("Test pass message") then
        mock(check_logger);
        internal_check(true);
        check_only_log(check_logger, prefix & "passed.", pass);
        check_result := internal_check(true);
        assert_true(to_string(check_result.p_msg) = prefix & "passed.", "Got : " & to_string(check_result.p_msg));
        assert_true(check_result.p_level = pass);

        internal_check(true, "");
        check_only_log(check_logger, "", pass);
        check_result := internal_check(true, "");
        assert_true(to_string(check_result.p_msg) = "");
        assert_true(check_result.p_level = pass);

        internal_check(true, "Checking my data.");
        check_only_log(check_logger, "Checking my data.", pass);
        check_result := internal_check(true, "Checking my data.");
        assert_true(to_string(check_result.p_msg) = "Checking my data.");
        assert_true(check_result.p_level = pass);

        internal_check(true, result("for my data."));
        check_only_log(check_logger, prefix & "passed for my data.", pass);
        check_result := internal_check(true, result("for my data."));
        assert_true(to_string(check_result.p_msg) = prefix & "passed for my data.");
        assert_true(check_result.p_level = pass);

        unmock(check_logger);

      elsif run("Test should fail on false inputs to sequential checks") then
        get_checker_stat(stat);
        mock(check_logger);
        internal_check(false);
        check_only_log(check_logger, prefix & "failed.", default_level);
        check_result := internal_check(false);
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = prefix & "failed.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        internal_check(false, "");
        check_only_log(check_logger, "", default_level);
        check_result := internal_check(false, "");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        internal_check(passed, false, "Checking my data.");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Checking my data.", default_level);
        check_result := internal_check(false, "Checking my data.");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Checking my data.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        passed := internal_check(false, result("for my data."));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, prefix & "failed for my data.", default_level);
        check_result := internal_check(false, result("for my data."));
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = prefix & "failed for my data.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        unmock(check_logger);
        verify_failed_checks(stat, 8);
        reset_checker_stat;

        get_checker_stat(check_checker, stat);
        mock(get_logger(check_checker));
        internal_check(check_checker, false);
        check_only_log(get_logger(check_checker), prefix & "failed.", default_level);
        check_result := internal_check(check_checker, false);
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = check_checker);
        assert_true(to_string(check_result.p_msg) = prefix & "failed.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        internal_check(check_checker, passed, false, "Checking my data.");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(check_checker), "Checking my data.", default_level);
        check_result := internal_check(check_checker, false, "Checking my data.");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = check_checker);
        assert_true(to_string(check_result.p_msg) = "Checking my data.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        passed := internal_check(check_checker, false, result("for my data."));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(check_checker), prefix & "failed for my data.", default_level);
        check_result := internal_check(check_checker, false, result("for my data."));
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = check_checker);
        assert_true(to_string(check_result.p_msg) = prefix & "failed for my data.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        unmock(get_logger(check_checker));
        verify_failed_checks(check_checker, stat, 6);
        reset_checker_stat(check_checker);

      elsif run("Test that unhandled pass result passes") then
        check_result := internal_check(true);
        assert_true(not p_has_unhandled_checks);

      elsif run("Test that unhandled failed result fails") then
        check_result := internal_check(check_checker, false);
        assert_true(p_has_unhandled_checks);
        mock_core_failure;
        test_runner_cleanup(runner);
        check_core_failure("Unhandled checks.");
        unmock_core_failure;
        p_handle(check_result);

      elsif run("Test should be possible to use concurrently") then
        test_concurrent_check(clk, check_in_1, default_checker);

      elsif run("Test should be possible to use concurrently with negative active clock edge") then
        test_concurrent_check(clk, check_in_2, check_checker2, error, false);

      elsif run("Test should be possible to use concurrently with custom checker") then
        test_concurrent_check(clk, check_in_3, check_checker3, info);

      elsif run("Test should pass on weak high but fail on other meta values") then

        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(check_checker4, stat);
        apply_sequence("1H1", clk, check_in_4);
        wait until rising_edge(clk);
        wait for 1 ns;
        mock(get_logger(check_checker4));
        verify_passed_checks(check_checker4, stat, 3);
        get_checker_stat(check_checker4, stat);
        apply_sequence("1UXZWL-1", clk, check_in_4);
        wait until rising_edge(clk);
        wait for 1 ns;
        check_log(get_logger(check_checker4), prefix & "passed.", pass);
        check_log(get_logger(check_checker4), prefix & "failed.", default_level);
        check_log(get_logger(check_checker4), prefix & "failed.", default_level);
        check_log(get_logger(check_checker4), prefix & "failed.", default_level);
        check_log(get_logger(check_checker4), prefix & "failed.", default_level);
        check_log(get_logger(check_checker4), prefix & "failed.", default_level);
        check_log(get_logger(check_checker4), prefix & "failed.", default_level);
        check_log(get_logger(check_checker4), prefix & "passed.", pass);
        unmock(get_logger(check_checker4));
        verify_passed_checks(check_checker4, stat, 2);
        verify_failed_checks(check_checker4, stat, 6);
        reset_checker_stat(check_checker4);

      elsif run("Test should pass on logic low inputs when not enabled") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        check_en_1 <= '0';
        apply_sequence("01", clk, check_in_1);
        check_en_1 <= '1';
        wait until rising_edge(clk);
        check_en_1 <= 'L';
        apply_sequence("01", clk, check_in_1);
        check_en_1 <= 'H';
        wait until rising_edge(clk);
        check_en_1 <= 'X';
        apply_sequence("01", clk, check_in_1);
        check_en_1 <= '1';
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
