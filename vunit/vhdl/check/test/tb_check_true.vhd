-- This test suite verifies the check_true checker.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
library vunit_lib;
use vunit_lib.log_types_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_support.all;
use work.test_count.all;

entity tb_check_true is
  generic (
    runner_cfg : string);
end entity tb_check_true;

architecture test_fixture of tb_check_true is
  signal clk : std_logic := '0';
  signal check_true_in_1, check_true_in_2, check_true_in_3, check_true_in_4 : std_logic := '1';
  signal check_true_en_1, check_true_en_2, check_true_en_3, check_true_en_4 : std_logic := '1';
  signal one : std_logic := '1';
  signal zero : std_logic := '0';

  shared variable check_true_checker, check_true_checker2, check_true_checker3, check_true_checker4 : checker_t;

begin
  clock: process is
  begin
    while runner.phase < test_runner_exit loop
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
    end loop;
    wait;
  end process clock;

  check_true_1 : check_true(clk, check_true_en_1, check_true_in_1);
  check_true_2 : check_true(check_true_checker2, clk, check_true_en_2, check_true_in_2, active_clock_edge => falling_edge);
  check_true_3 : check_true(check_true_checker3, clk, check_true_en_3, check_true_in_3);
  check_true_4 : check_true(check_true_checker4, clk, check_true_en_4, check_true_in_4);

  check_true_runner : process
    variable pass : boolean;
    variable stat : checker_stat_t;

    procedure test_concurrent_check (
      signal clk                        : in  std_logic;
      signal check_input                : out std_logic;
      variable checker : inout checker_t ;
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
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      verify_log_call(inc_count, expected_level => level);
      get_checker_stat(checker, stat);
      apply_sequence("1", clk, check_input, active_rising_clock_edge);
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      verify_passed_checks(checker, stat, 1);
    end procedure test_concurrent_check;

  begin
    custom_checker_init_from_scratch(check_true_checker3, default_level => info);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should pass on true and logic 1 inputs to sequential checks") then
        get_checker_stat(stat);
        check_true(true);
        check_true(pass, true);
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_true(true);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(stat, 3);

        get_checker_stat(check_true_checker, stat);
        check_true(check_true_checker, true);
        check_true(check_true_checker, pass, true);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_true_checker, stat, 2);
      elsif run("Test should fail on false and logic 0 inputs to sequential checks") then
        check_true(false);
        verify_log_call(inc_count);
        check_true(pass, false);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);
        pass := check_true(false);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);

        check_true(check_true_checker, false);
        verify_log_call(inc_count);
        check_true(check_true_checker, pass, false);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);
      elsif run("Test should be possible to use concurrently") then
        test_concurrent_check(clk, check_true_in_1, default_checker);
      elsif run("Test should be possible to use concurrently with negative active clock edge") then
        test_concurrent_check(clk, check_true_in_2, check_true_checker2, error, false);
      elsif run("Test should be possible to use concurrently with custom checker") then
        test_concurrent_check(clk, check_true_in_3, check_true_checker3, info);
      elsif run("Test should pass on weak high but fail on other meta values") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(check_true_checker4, stat);
        apply_sequence("1H1", clk, check_true_in_4);
        wait until rising_edge(clk);
        wait for 1 ns;
        verify_passed_checks(check_true_checker4, stat, 3);
        apply_sequence("1UXZWL-1", clk, check_true_in_4);
        wait for 1 ns;
        verify_log_call(set_count(get_count + 6));
      elsif run("Test should pass on logic low inputs when not enabled") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        check_true_en_1 <= '0';
        apply_sequence("01", clk, check_true_in_1);
        check_true_en_1 <= '1';
        wait until rising_edge(clk);
        check_true_en_1 <= 'L';
        apply_sequence("01", clk, check_true_in_1);
        check_true_en_1 <= 'H';
        wait until rising_edge(clk);
        check_true_en_1 <= 'X';
        apply_sequence("01", clk, check_true_in_1);
        check_true_en_1 <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        verify_passed_checks(stat, 3);
        verify_failed_checks(stat, 0);
      end if;
    end loop;

    get_and_print_test_result(stat);
    test_runner_cleanup(runner, stat);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;

-- vunit_pragma run_all_in_same_sim
