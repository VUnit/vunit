-- This test suite verifies the check_one_hot checker.
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

entity tb_check_one_hot is
  generic (
    runner_cfg : string);
end entity tb_check_one_hot;

architecture test_fixture of tb_check_one_hot is
  signal clk : std_logic := '0';

  signal check_one_hot_in_1, check_one_hot_in_2, check_one_hot_in_3 : std_logic_vector(3 downto 0) := "0001";
  signal check_one_hot_en_1, check_one_hot_en_2, check_one_hot_en_3 : std_logic := '1';

  constant my_checker2 : checker_t := new_checker("my_checker2");
  constant my_checker3 : checker_t := new_checker("my_checker3", default_log_level => info);

begin
  clock: process is
  begin
    while get_phase(runner_state) < test_runner_exit loop
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
    end loop;
    wait;
  end process clock;

  check_one_hot_1 : check_one_hot(clk, check_one_hot_en_1, check_one_hot_in_1);
  check_one_hot_2 : check_one_hot(my_checker2, clk, check_one_hot_en_2, check_one_hot_in_2, active_clock_edge => falling_edge);
  check_one_hot_3 : check_one_hot(my_checker3, clk, check_one_hot_en_3, check_one_hot_in_3);

  check_one_hot_runner : process
    variable passed : boolean;
    variable stat : checker_stat_t;
    constant reversed_and_offset_expr : std_logic_vector(23 downto 20) := "1000";
    constant default_level : log_level_t := error;

    procedure test_concurrent_check (
      signal clk                        : in  std_logic;
      signal check_input                : out std_logic_vector;
      checker                           : checker_t ;
      constant level                    : in  log_level_t := error;
      constant active_rising_clock_edge : in  boolean := true) is
    begin
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      get_checker_stat(checker, stat);
      apply_sequence("1000;HL00", clk, check_input, active_rising_clock_edge);
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      verify_passed_checks(checker, stat, 2);
      verify_failed_checks(checker, stat, 0);
      mock(get_logger(checker));
      apply_sequence("1001;0000;00LL;100H;000X", clk, check_input, active_rising_clock_edge);
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      check_log(get_logger(checker), "One-hot check failed - Got 1001.", level);
      check_log(get_logger(checker), "One-hot check failed - Got 0000.", level);
      check_log(get_logger(checker), "One-hot check failed - Got 00LL.", level);
      check_log(get_logger(checker), "One-hot check failed - Got 100H.", level);
      check_log(get_logger(checker), "One-hot check failed - Got 000X.", level);
      unmock(get_logger(checker));
      verify_passed_checks(checker, stat, 2);
      verify_failed_checks(checker, stat, 5);
      reset_checker_stat(checker);
      apply_sequence("1000", clk, check_input, active_rising_clock_edge);
    end procedure test_concurrent_check;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should pass on one high bit") then
        get_checker_stat(stat);
        check_one_hot("1000");
        check_one_hot("HL00");
        verify_passed_checks(stat, 2);

        get_checker_stat(my_checker3, stat);
        check_one_hot(my_checker3, "1000");
        check_one_hot(my_checker3, "HL00");
        verify_passed_checks(my_checker3, stat, 2);

        get_checker_stat(stat);
        check_one_hot(passed, "1000");
        assert_true(passed, "Should return pass = true on passing check");
        check_one_hot(passed, "HL00");
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(stat, 2);

        get_checker_stat(stat);
        passed := check_one_hot("1000");
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_one_hot("HL00");
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(stat, 2);

        get_checker_stat(my_checker3, stat);
        check_one_hot(my_checker3, passed, "1000");
        assert_true(passed, "Should return pass = true on passing check");
        check_one_hot(my_checker3, passed, "HL00");
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(my_checker3, stat, 2);

        get_checker_stat(my_checker3, stat);
        passed := check_one_hot(my_checker3, "1000");
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_one_hot(my_checker3, "HL00");
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(my_checker3, stat, 2);

      elsif run("Test pass message") then
        mock(check_logger);
        check_one_hot("10000");
        check_only_log(check_logger, "One-hot check passed - Got 1_0000.", pass);

        check_one_hot("10000", "");
        check_only_log(check_logger, "Got 1_0000.", pass);

        check_one_hot("10000", "Checking my data");
        check_only_log(check_logger, "Checking my data - Got 1_0000.", pass);

        check_one_hot("10000", result("for my data"));
        check_only_log(check_logger, "One-hot check passed for my data - Got 1_0000.", pass);
        unmock(check_logger);

      elsif run("Test should fail on zero or more than one high bit") then
        get_checker_stat(stat);
        mock(check_logger);
        check_one_hot("00000");
        check_only_log(check_logger, "One-hot check failed - Got 0_0000.", default_level);

        check_one_hot("0L00L");
        check_only_log(check_logger, "One-hot check failed - Got 0_L00L.", default_level);

        check_one_hot("01001");
        check_only_log(check_logger, "One-hot check failed - Got 0_1001.", default_level);

        check_one_hot("0100H");
        check_only_log(check_logger, "One-hot check failed - Got 0_100H.", default_level);

        check_one_hot(passed, "01001");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "One-hot check failed - Got 0_1001.", default_level);

        check_one_hot(passed, "0100H");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "One-hot check failed - Got 0_100H.", default_level);

        passed := check_one_hot("01001");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "One-hot check failed - Got 0_1001.", default_level);

        passed := check_one_hot("0100H");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "One-hot check failed - Got 0_100H.", default_level);

        check_one_hot(passed, "00000");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "One-hot check failed - Got 0_0000.", default_level);

        check_one_hot(passed, "0L00L");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "One-hot check failed - Got 0_L00L.", default_level);

        passed := check_one_hot("00000");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "One-hot check failed - Got 0_0000.", default_level);

        passed := check_one_hot("0L00L");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "One-hot check failed - Got 0_L00L.", default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 12);
        reset_checker_stat;

        get_checker_stat(my_checker3, stat);
        mock(get_logger(my_checker3));
        check_one_hot(my_checker3, "00000");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_0000.", info);

        check_one_hot(my_checker3, "0L00L");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_L00L.", info);

        check_one_hot(my_checker3, "01001");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_1001.", info);

        check_one_hot(my_checker3, "0100H");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_100H.", info);

        check_one_hot(my_checker3, passed, "01001");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_1001.", info);

        check_one_hot(my_checker3, passed, "0100H");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_100H.", info);

        passed := check_one_hot(my_checker3, "01001");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_1001.", info);

        passed := check_one_hot(my_checker3, "0100H");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_100H.", info);

        check_one_hot(my_checker3, passed, "00000");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_0000.", info);

        check_one_hot(my_checker3, passed, "0L00L");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_L00L.", info);

        passed := check_one_hot(my_checker3, "00000");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_0000.", info);

        passed := check_one_hot(my_checker3, "0L00L");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_L00L.", info);
        unmock(get_logger(my_checker3));
        verify_passed_checks(my_checker3, stat, 0);
        verify_failed_checks(my_checker3, stat, 12);
        reset_checker_stat(my_checker3);

      elsif run("Test should fail on unknowns") then
        get_checker_stat(stat);
        mock(check_logger);
        check_one_hot("0000X");
        check_only_log(check_logger, "One-hot check failed - Got 0_000X.", default_level);

        check_one_hot(passed, "0000X");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "One-hot check failed - Got 0_000X.", default_level);

        passed := check_one_hot("0000X");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "One-hot check failed - Got 0_000X.", default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 3);
        reset_checker_stat;

        get_checker_stat(my_checker3, stat);
        mock(get_logger(my_checker3));
        check_one_hot(my_checker3, "0000X");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_000X.", info);

        check_one_hot(my_checker3, passed, "0000X");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_000X.", info);

        passed := check_one_hot(my_checker3, "0000X");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(get_logger(my_checker3), "One-hot check failed - Got 0_000X.", info);
        unmock(get_logger(my_checker3));
        verify_passed_checks(my_checker3, stat, 0);
        verify_failed_checks(my_checker3, stat, 3);
        reset_checker_stat(my_checker3);

      elsif run("Test should be possible to use concurrently") then
        test_concurrent_check(clk, check_one_hot_in_1, default_checker);

      elsif run("Test should be possible to use concurrently with negative active clock edge") then
        test_concurrent_check(clk, check_one_hot_in_2, my_checker2, error, false);

      elsif run("Test should be possible to use concurrently with custom checker") then
        test_concurrent_check(clk, check_one_hot_in_3, my_checker3, info);

      elsif run("Test should pass on unknowns when not enabled") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        apply_sequence("0001;1001", clk, check_one_hot_in_1);
        check_one_hot_en_1 <= '0';
        apply_sequence("1001;100H;0001", clk, check_one_hot_in_1);
        check_one_hot_en_1 <= '1';
        apply_sequence("0001;100H", clk, check_one_hot_in_1);
        check_one_hot_en_1 <= 'L';
        apply_sequence("1001;100H;0001", clk, check_one_hot_in_1);
        check_one_hot_en_1 <= 'H';
        apply_sequence("0001;100H", clk, check_one_hot_in_1);
        check_one_hot_en_1 <= 'X';
        apply_sequence("1001;100H;0001", clk, check_one_hot_in_1);
        check_one_hot_en_1 <= '1';
        wait for 1 ns;
        verify_passed_checks(stat, 3);
        verify_failed_checks(stat, 0);

      elsif run("Test should handle reversed and or offset expressions") then
        get_checker_stat(stat);
        check_zero_one_hot(reversed_and_offset_expr);
        verify_passed_checks(stat, 1);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;
