-- This test suite verifies the check_not_unknown checker.
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
use vunit_lib.string_ops.all;
use work.test_support.all;

entity tb_check_not_unknown is
  generic (
    runner_cfg : string);
end entity tb_check_not_unknown;

architecture test_fixture of tb_check_not_unknown is
  signal clk : std_logic := '0';
  signal check_not_unknown_in_1, check_not_unknown_in_2, check_not_unknown_in_3 : std_logic_vector(8 downto 0) := (others => '0');
  signal check_not_unknown_in_4, check_not_unknown_in_5, check_not_unknown_in_6 : std_logic_vector(1 downto 0) := (others => '0');
  alias expr_1 : std_logic_vector(7 downto 0) is check_not_unknown_in_1(8 downto 1);
  alias expr_2 : std_logic_vector(7 downto 0) is check_not_unknown_in_2(8 downto 1);
  alias expr_3 : std_logic_vector(7 downto 0) is check_not_unknown_in_3(8 downto 1);
  alias expr_4 : std_logic is check_not_unknown_in_4(1);
  alias expr_5 : std_logic is check_not_unknown_in_5(1);
  alias expr_6 : std_logic is check_not_unknown_in_6(1);
  alias en_1 : std_logic is check_not_unknown_in_1(0);
  alias en_2 : std_logic is check_not_unknown_in_2(0);
  alias en_3 : std_logic is check_not_unknown_in_3(0);
  alias en_4 : std_logic is check_not_unknown_in_4(0);
  alias en_5 : std_logic is check_not_unknown_in_5(0);
  alias en_6 : std_logic is check_not_unknown_in_6(0);

  constant my_checker2 : checker_t := new_checker("my_checker2");
  constant my_checker3 : checker_t := new_checker("my_checker3", default_log_level => info);
  constant my_checker5 : checker_t := new_checker("my_checker5");
  constant my_checker6 : checker_t := new_checker("my_checker6", default_log_level => info);


begin
  clock: process is
  begin
    while get_phase(runner_state) < test_runner_exit loop
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
    end loop;
    wait;
  end process clock;

  check_not_unknown_1 : check_not_unknown(clk, en_1, expr_1);
  check_not_unknown_2 : check_not_unknown(my_checker2, clk, en_2, expr_2, active_clock_edge => falling_edge);
  check_not_unknown_3 : check_not_unknown(my_checker3, clk, en_3, expr_3);
  check_not_unknown_4 : check_not_unknown(clk, en_4, expr_4);
  check_not_unknown_5 : check_not_unknown(my_checker5, clk, en_5, expr_5, active_clock_edge => falling_edge);
  check_not_unknown_6 : check_not_unknown(my_checker6, clk, en_6, expr_6);

  check_not_unknown_runner : process
    variable passed : boolean;
    variable stat : checker_stat_t;
    variable test_expr : std_logic_vector(7 downto 0);
    constant metadata : std_logic_vector(1 to 5) := "UXZW-";
    constant not_unknowns : string(1 to 4) := "01LH";
    constant reversed_and_offset_expr : std_logic_vector(23 downto 16) := "10100101";
    constant default_level : log_level_t := error;

    procedure test_concurrent_check (
      signal clk                        : in  std_logic;
      signal check_input                : out std_logic_vector;
      checker                           : checker_t ;
      constant level                    : in  log_level_t := error;
      constant active_rising_clock_edge : in  boolean := true) is
      variable test_expr : string(1 to check_input'length - 1);
      variable test_expr_slv : std_logic_vector(0 to test_expr'length - 1);
    begin
      -- Forced and weak zeros and ones should pass regardless of en
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      get_checker_stat(checker, stat);
      for i in 1 to 4 loop
        test_expr := (others => not_unknowns(i));
        apply_sequence(test_expr & "0" & test_expr & "1", clk, check_input, active_rising_clock_edge);
        wait until clock_edge(clk, active_rising_clock_edge);
      end loop;
      wait for 1 ns;
      verify_passed_checks(checker, stat, 4);
      verify_failed_checks(checker, stat, 0);

      -- Values other than strong/weak zeros/ones should fail when en is high,
      -- pass otherwise
      for i in metadata'range loop
        get_checker_stat(checker, stat);
        test_expr_slv := (others => metadata(i));
        test_expr := (others => std_logic'image(metadata(i))(2));
        apply_sequence(test_expr & "0" & test_expr & "L", clk, check_input, active_rising_clock_edge);
        wait until clock_edge(clk, active_rising_clock_edge);
        wait for 1 ns;
        verify_passed_checks(checker, stat, 0);
        verify_failed_checks(checker, stat, 0);

        mock(get_logger(checker));
        apply_sequence(test_expr & "1" & test_expr & "H", clk, check_input, active_rising_clock_edge);
        wait until clock_edge(clk, active_rising_clock_edge);
        wait for 1 ns;

        for k in 0 to 1 loop
          check_log(get_logger(checker),
                    "Not unknown check failed - Got " & to_nibble_string(test_expr_slv) & ".",
                    level);
        end loop;
        unmock(get_logger(checker));
        verify_passed_checks(checker, stat, 0);
        verify_failed_checks(checker, stat, 2);
        reset_checker_stat(checker);
      end loop;

      test_expr := (others => '0');
      apply_sequence(test_expr & "0", clk, check_input, active_rising_clock_edge);
    end procedure test_concurrent_check;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should pass on zeros and ones") then
        get_checker_stat(stat);
        check_not_unknown('0');
        check_not_unknown('1');
        check_not_unknown("10100101");
        check_not_unknown(passed, "10100101");
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_not_unknown('0');
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_not_unknown('1');
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_not_unknown("10100101");
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(stat, 7);

        get_checker_stat(my_checker3, stat);
        check_not_unknown(my_checker3, '0');
        check_not_unknown(my_checker3, '1');
        check_not_unknown(my_checker3, "10100101");
        check_not_unknown(my_checker3, passed, "10100101");
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_not_unknown(my_checker3, '0');
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_not_unknown(my_checker3, '1');
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_not_unknown(my_checker3, "10100101");
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(my_checker3, stat, 7);

      elsif run("Test pass message") then
        mock(check_logger);
        check_not_unknown('0');
        check_only_log(check_logger, "Not unknown check passed - Got 0.", pass);

        check_not_unknown("00110");
        check_only_log(check_logger, "Not unknown check passed - Got 0_0110 (6).", pass);

        check_not_unknown('0', "");
        check_only_log(check_logger, "Got 0.", pass);

        check_not_unknown("00110", "");
        check_only_log(check_logger, "Got 0_0110 (6).", pass);

        check_not_unknown('0', "Checking my data");
        check_only_log(check_logger, "Checking my data - Got 0.", pass);

        check_not_unknown("00110", "Checking my data");
        check_only_log(check_logger, "Checking my data - Got 0_0110 (6).", pass);

        check_not_unknown('0', result("for my data"));
        check_only_log(check_logger, "Not unknown check passed for my data - Got 0.", pass);

        check_not_unknown("00110", result("for my data"));
        check_only_log(check_logger, "Not unknown check passed for my data - Got 0_0110 (6).", pass);
        unmock(check_logger);

      elsif run("Test should fail on all std logic values except zero and one") then
        for i in metadata'range loop
          get_checker_stat(stat);
          test_expr := (others => metadata(i));
          mock(check_logger);
          check_not_unknown(metadata(i));
          check_only_log(check_logger, "Not unknown check failed - Got " & std_logic'image(metadata(i))(2) & ".", default_level);

          check_not_unknown(test_expr);
          check_only_log(check_logger, "Not unknown check failed - Got " & to_nibble_string(test_expr) & ".", default_level);

          check_not_unknown(passed, metadata(i));
          assert_true(not passed, "Should return pass = false on failing check");
          check_only_log(check_logger, "Not unknown check failed - Got " & std_logic'image(metadata(i))(2) & ".", default_level);

          check_not_unknown(passed, test_expr);
          assert_true(not passed, "Should return pass = false on failing check");
          check_only_log(check_logger, "Not unknown check failed - Got " & to_nibble_string(test_expr) & ".", default_level);

          passed := check_not_unknown(metadata(i));
          assert_true(not passed, "Should return pass = false on failing check");
          check_only_log(check_logger, "Not unknown check failed - Got " & std_logic'image(metadata(i))(2) & ".", default_level);

          passed := check_not_unknown(test_expr);
          assert_true(not passed, "Should return pass = false on failing check");
          check_only_log(check_logger, "Not unknown check failed - Got " & to_nibble_string(test_expr) & ".", default_level);
          unmock(check_logger);
          verify_passed_checks(stat, 0);
          verify_failed_checks(stat, 6);
          reset_checker_stat;

          get_checker_stat(my_checker3, stat);
          mock(get_logger(my_checker3));
          check_not_unknown(my_checker3, metadata(i));
          check_only_log(get_logger(my_checker3), "Not unknown check failed - Got " & std_logic'image(metadata(i))(2) & ".",
                          info);
          check_not_unknown(my_checker3, test_expr);
          check_only_log(get_logger(my_checker3), "Not unknown check failed - Got " & to_nibble_string(test_expr) & ".",
                          info);
          check_not_unknown(my_checker3, passed, metadata(i));
          assert_true(not passed, "Should return pass = false on failing check");
          check_only_log(get_logger(my_checker3), "Not unknown check failed - Got " & std_logic'image(metadata(i))(2) & ".",
                         info);
          check_not_unknown(my_checker3, passed, test_expr);
          assert_true(not passed, "Should return pass = false on failing check");
          check_only_log(get_logger(my_checker3), "Not unknown check failed - Got " & to_nibble_string(test_expr) & ".",
                         info);

          passed := check_not_unknown(my_checker3, metadata(i));
          assert_true(not passed, "Should return pass = false on failing check");
          check_only_log(get_logger(my_checker3),
                         "Not unknown check failed - Got " & std_logic'image(metadata(i))(2) & ".", info);

          passed := check_not_unknown(my_checker3, test_expr);
          assert_true(not passed, "Should return pass = false on failing check");
          check_only_log(get_logger(my_checker3),
                         "Not unknown check failed - Got " & to_nibble_string(test_expr) & ".", info);
          unmock(get_logger(my_checker3));
          verify_passed_checks(my_checker3, stat, 0);
          verify_failed_checks(my_checker3, stat, 6);
          reset_checker_stat(my_checker3);
        end loop;

      elsif run("Test should be possible to use concurrently") then
        test_concurrent_check(clk, check_not_unknown_in_1, default_checker);
        test_concurrent_check(clk, check_not_unknown_in_4, default_checker);

      elsif run("Test should be possible to use concurrently with negative active clock edge") then
        test_concurrent_check(clk, check_not_unknown_in_2, my_checker2, error, false);
        test_concurrent_check(clk, check_not_unknown_in_5, my_checker5, error, false);

      elsif run("Test should be possible to use concurrently with custom checker") then
        test_concurrent_check(clk, check_not_unknown_in_3, my_checker3, info);
        test_concurrent_check(clk, check_not_unknown_in_6, my_checker6, info);

      elsif run("Test should handle reversed and or offset expressions") then
        get_checker_stat(stat);
        check_not_unknown(reversed_and_offset_expr);
        verify_passed_checks(stat, 1);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;
