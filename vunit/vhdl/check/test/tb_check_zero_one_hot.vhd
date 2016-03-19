-- This test suite verifies the check_zero_one_hot checker.
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

entity tb_check_zero_one_hot is
  generic (
    runner_cfg : string);
end entity tb_check_zero_one_hot;

architecture test_fixture of tb_check_zero_one_hot is
  signal clk : std_logic := '0';
  signal one : std_logic := '1';
  signal zero : std_logic := '0';

  signal check_zero_one_hot_in_1, check_zero_one_hot_in_2, check_zero_one_hot_in_3 : std_logic_vector(3 downto 0) := (others => '0');
  signal check_zero_one_hot_en_1, check_zero_one_hot_en_2, check_zero_one_hot_en_3 : std_logic := '1';

  shared variable check_zero_one_hot_checker2, check_zero_one_hot_checker3 : checker_t;

begin
  clock: process is
  begin
    while runner.phase < test_runner_exit loop
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
    end loop;
    wait;
  end process clock;

  check_zero_one_hot_1 : check_zero_one_hot(clk, check_zero_one_hot_en_1, check_zero_one_hot_in_1);
  check_zero_one_hot_2 : check_zero_one_hot(check_zero_one_hot_checker2, clk, check_zero_one_hot_en_2, check_zero_one_hot_in_2, active_clock_edge => falling_edge);
  check_zero_one_hot_3 : check_zero_one_hot(check_zero_one_hot_checker3, clk, check_zero_one_hot_en_3, check_zero_one_hot_in_3);

  check_zero_one_hot_runner : process
    variable pass : boolean;
    variable stat : checker_stat_t;
    variable reversed_and_offset_expr : std_logic_vector(23 downto 20) := "1000";

    procedure test_concurrent_check (
      signal clk                        : in  std_logic;
      signal check_input                : out std_logic_vector;
      variable checker : inout checker_t ;
      constant level                    : in  log_level_t := error;
      constant active_rising_clock_edge : in  boolean := true) is
    begin
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      get_checker_stat(checker, stat);
      apply_sequence("0000;LL00;1000;HL00", clk, check_input, active_rising_clock_edge);
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      verify_passed_checks(checker, stat, 4);
      apply_sequence("1001;100H;000X", clk, check_input, active_rising_clock_edge);
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      verify_log_call(set_count(get_count + 3), expected_level => level);
      apply_sequence("0000", clk, check_input, active_rising_clock_edge);
    end procedure test_concurrent_check;

  begin
    custom_checker_init_from_scratch(check_zero_one_hot_checker3, default_level => info);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should pass on zero or one high bit") then
        get_checker_stat(stat);
        check_zero_one_hot("0000");
        check_zero_one_hot("LL00");
        check_zero_one_hot("1000");
        check_zero_one_hot("HL00");
        verify_passed_checks(stat, 4);

        get_checker_stat(check_zero_one_hot_checker3, stat);
        check_zero_one_hot(check_zero_one_hot_checker3, "0000");
        check_zero_one_hot(check_zero_one_hot_checker3, "LL00");
        check_zero_one_hot(check_zero_one_hot_checker3, "1000");
        check_zero_one_hot(check_zero_one_hot_checker3, "HL00");
        verify_passed_checks(check_zero_one_hot_checker3, stat, 4);

        get_checker_stat(stat);
        check_zero_one_hot(pass, "0000");
        counting_assert(pass, "Should return pass = true on passing check");
        check_zero_one_hot(pass, "LL00");
        counting_assert(pass, "Should return pass = true on passing check");
        check_zero_one_hot(pass, "1000");
        counting_assert(pass, "Should return pass = true on passing check");
        check_zero_one_hot(pass, "HL00");
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(stat, 4);

        get_checker_stat(stat);
        pass := check_zero_one_hot("0000");
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_zero_one_hot("LL00");
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_zero_one_hot("1000");
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_zero_one_hot("HL00");
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(stat, 4);

        get_checker_stat(check_zero_one_hot_checker3, stat);
        check_zero_one_hot(check_zero_one_hot_checker3, pass, "0000");
        counting_assert(pass, "Should return pass = true on passing check");
        check_zero_one_hot(check_zero_one_hot_checker3, pass, "LL00");
        counting_assert(pass, "Should return pass = true on passing check");
        check_zero_one_hot(check_zero_one_hot_checker3, pass, "1000");
        counting_assert(pass, "Should return pass = true on passing check");
        check_zero_one_hot(check_zero_one_hot_checker3, pass, "HL00");
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_zero_one_hot_checker3, stat, 4);
      elsif run("Test should fail on more than one high bit") then
        check_zero_one_hot("1001");
        verify_log_call(inc_count);
        check_zero_one_hot("100H");
        verify_log_call(inc_count);
        check_zero_one_hot(check_zero_one_hot_checker3, "1001");
        verify_log_call(inc_count, expected_level => info);
        check_zero_one_hot(check_zero_one_hot_checker3, "100H");
        verify_log_call(inc_count, expected_level => info);

        check_zero_one_hot(pass, "1001");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);
        check_zero_one_hot(pass, "100H");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);
        check_zero_one_hot(check_zero_one_hot_checker3, pass, "1001");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, expected_level => info);
        check_zero_one_hot(check_zero_one_hot_checker3, pass, "100H");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, expected_level => info);

        pass := check_zero_one_hot("1001");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);
        pass := check_zero_one_hot("100H");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);
      elsif run("Test should fail on unknowns") then
        check_zero_one_hot("000X");
        verify_log_call(inc_count);
        check_zero_one_hot(check_zero_one_hot_checker3, "000X");
        verify_log_call(inc_count, expected_level => info);

        check_zero_one_hot(pass, "000X");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);
        pass := check_zero_one_hot("000X");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count);
        check_zero_one_hot(check_zero_one_hot_checker3, pass, "000X");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, expected_level => info);
      elsif run("Test should be possible to use concurrently") then
        test_concurrent_check(clk, check_zero_one_hot_in_1, default_checker);
      elsif run("Test should be possible to use concurrently with negative active clock edge") then
        test_concurrent_check(clk, check_zero_one_hot_in_2, check_zero_one_hot_checker2, error, false);
      elsif run("Test should be possible to use concurrently with custom checker") then
        test_concurrent_check(clk, check_zero_one_hot_in_3, check_zero_one_hot_checker3, info);
      elsif run("Test should pass on unknowns when not enabled") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        apply_sequence("0000;100H", clk, check_zero_one_hot_in_1);
        check_zero_one_hot_en_1 <= '0';
        apply_sequence("1001;100H;0000", clk, check_zero_one_hot_in_1);
        check_zero_one_hot_en_1 <= '1';
        apply_sequence("0000;100H", clk, check_zero_one_hot_in_1);
        check_zero_one_hot_en_1 <= 'L';
        apply_sequence("1001;100H;0000", clk, check_zero_one_hot_in_1);
        check_zero_one_hot_en_1 <= 'H';
        apply_sequence("0000;100H", clk, check_zero_one_hot_in_1);
        check_zero_one_hot_en_1 <= 'X';
        apply_sequence("1001;100H;0000", clk, check_zero_one_hot_in_1);
        check_zero_one_hot_en_1 <= '1';
        wait for 1 ns;
        verify_passed_checks(stat, 3);
        verify_failed_checks(stat, 0);
      elsif run("Test should handle reversed and or offset expressions") then
        get_checker_stat(stat);
        check_zero_one_hot(reversed_and_offset_expr);
        verify_passed_checks(stat, 1);
      end if;
    end loop;

    get_and_print_test_result(stat);
    test_runner_cleanup(runner, stat);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;

-- vunit_pragma run_all_in_same_sim
