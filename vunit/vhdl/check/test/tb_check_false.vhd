-- This test suite verifies the check_false checker.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
library vunit_lib;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use work.test_support.all;
use work.test_count.all;

entity tb_check_false is
  generic (
    runner_cfg : string);
end entity tb_check_false;

architecture test_fixture of tb_check_false is
  signal clk : std_logic := '0';
  signal check_false_in_1, check_false_in_2, check_false_in_3, check_false_in_4 : std_logic := '0';
  signal check_false_en_1, check_false_en_2, check_false_en_3, check_false_en_4 : std_logic := '1';
  signal one : std_logic := '1';
  signal zero : std_logic := '0';

  shared variable check_false_checker, check_false_checker2, check_false_checker3, check_false_checker4  : checker_t;

begin
  clock: process is
  begin
    while runner.phase < test_runner_exit loop
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
    variable pass : boolean;
    variable stat : checker_stat_t;

    procedure test_concurrent_check (
      signal clk                        : in  std_logic;
      signal check_input                : out std_logic;
      variable checker : inout checker_t ;
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
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      verify_log_call(inc_count, expected_level => level);
      get_checker_stat(checker, stat);
      apply_sequence("0", clk, check_input, active_rising_clock_edge);
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      verify_passed_checks(checker, stat, 1);
    end procedure test_concurrent_check;

  begin
    custom_checker_init_from_scratch(check_false_checker3, default_level => info);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should fail on true and logic 1 inputs to sequential checks") then
        check_false(true);
        verify_log_call(inc_count);
        check_false(pass, true);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);
        pass := check_false(true);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);

        check_false(check_false_checker,true);
        verify_log_call(inc_count);
        check_false(check_false_checker,pass, true);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);
      elsif run("Test should pass on false and logic 0 inputs to sequential checks") then
        get_checker_stat(stat);
        check_false(false);
        check_false(pass, false);
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_false(false);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(stat, 3);

        get_checker_stat(check_false_checker, stat);
        check_false(check_false_checker,false);
        check_false(check_false_checker,pass, false);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_false_checker, stat, 2);
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
        verify_passed_checks(check_false_checker4, stat, 3);
        apply_sequence("0UXZWH-0", clk, check_false_in_4);
        wait for 1 ns;
        verify_log_call(set_count(get_count + 6));
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

    get_and_print_test_result(stat);
    test_runner_cleanup(runner, stat);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;

-- vunit_pragma run_all_in_same_sim
