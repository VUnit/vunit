-- This test suite verifies the check_not_unknown checker.
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

  shared variable check_not_unknown_checker, check_not_unknown_checker2, check_not_unknown_checker3 : checker_t;
  shared variable check_not_unknown_checker5, check_not_unknown_checker6 : checker_t;

begin
  clock: process is
  begin
    while runner.phase < test_runner_exit loop
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
    end loop;
    wait;
  end process clock;

  check_not_unknown_1 : check_not_unknown(clk, en_1, expr_1);
  check_not_unknown_2 : check_not_unknown(check_not_unknown_checker2, clk, en_2, expr_2, active_clock_edge => falling_edge);
  check_not_unknown_3 : check_not_unknown(check_not_unknown_checker3, clk, en_3, expr_3);
  check_not_unknown_4 : check_not_unknown(clk, en_4, expr_4);
  check_not_unknown_5 : check_not_unknown(check_not_unknown_checker5, clk, en_5, expr_5, active_clock_edge => falling_edge);
  check_not_unknown_6 : check_not_unknown(check_not_unknown_checker6, clk, en_6, expr_6);

  check_not_unknown_runner : process
    variable pass : boolean;
    variable stat : checker_stat_t;
    variable test_expr : std_logic_vector(7 downto 0);
    constant metadata : std_logic_vector(1 to 5) := "UXZW-";
    constant not_unknowns : string(1 to 4) := "01LH";
    variable reversed_and_offset_expr : std_logic_vector(23 downto 16) := "10100101";

    procedure test_concurrent_check (
      signal clk                        : in  std_logic;
      signal check_input                : out std_logic_vector;
      variable checker : inout checker_t ;
      constant level                    : in  log_level_t := error;
      constant active_rising_clock_edge : in  boolean := true) is
      variable test_expr : string(1 to check_input'length - 1);
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

      -- Values other than strong/weak zeros/ones should fail when en is high,
      -- pass otherwise
      for i in metadata'range loop
        get_checker_stat(checker, stat);
        test_expr := (others => std_logic'image(metadata(i))(2));
        apply_sequence(test_expr & "0" & test_expr & "L", clk, check_input, active_rising_clock_edge);
        wait until clock_edge(clk, active_rising_clock_edge);
        wait for 1 ns;
        verify_passed_checks(checker, stat, 0);
        verify_failed_checks(checker, stat, 0);
        apply_sequence(test_expr & "1" & test_expr & "H", clk, check_input, active_rising_clock_edge);
        wait until clock_edge(clk, active_rising_clock_edge);
        wait for 1 ns;
        verify_log_call(set_count(get_count + 2), expected_level => level);
      end loop;
      test_expr := (others => '0');
      apply_sequence(test_expr & "0", clk, check_input, active_rising_clock_edge);
    end procedure test_concurrent_check;

  begin
    custom_checker_init_from_scratch(check_not_unknown_checker3, default_level => info);
    custom_checker_init_from_scratch(check_not_unknown_checker6, default_level => info);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should pass on zeros and ones") then
        get_checker_stat(stat);
        check_not_unknown('0');
        check_not_unknown('1');
        check_not_unknown("10100101");
        check_not_unknown(pass, "10100101");
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_not_unknown('0');
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_not_unknown('1');
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_not_unknown("10100101");
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(stat, 7);

        get_checker_stat(check_not_unknown_checker3, stat);
        check_not_unknown(check_not_unknown_checker3, '0');
        check_not_unknown(check_not_unknown_checker3, '1');
        check_not_unknown(check_not_unknown_checker3, "10100101");
        check_not_unknown(check_not_unknown_checker3, pass, "10100101");
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_not_unknown_checker3, stat, 4);
      elsif run("Test should fail on all std logic values except zero and one") then
        for i in metadata'range loop
          test_expr := (others => metadata(i));
          check_not_unknown(metadata(i));
          verify_log_call(inc_count);
          check_not_unknown(test_expr);
          verify_log_call(inc_count);
          check_not_unknown(pass, metadata(i));
          counting_assert(not pass, "Should return pass = false on failing check");
          verify_log_call(inc_count);
          check_not_unknown(pass, test_expr);
          counting_assert(not pass, "Should return pass = false on failing check");
          verify_log_call(inc_count);
          pass := check_not_unknown(metadata(i));
          counting_assert(not pass, "Should return pass = false on failing check");
          verify_log_call(inc_count);
          pass := check_not_unknown(test_expr);
          counting_assert(not pass, "Should return pass = false on failing check");
          verify_log_call(inc_count);

          check_not_unknown(check_not_unknown_checker3, metadata(i));
          verify_log_call(inc_count, expected_level => info);
          check_not_unknown(check_not_unknown_checker3, test_expr);
          verify_log_call(inc_count, expected_level => info);
          check_not_unknown(check_not_unknown_checker3, pass, metadata(i));
          counting_assert(not pass, "Should return pass = false on failing check");
          verify_log_call(inc_count, expected_level => info);
          check_not_unknown(check_not_unknown_checker3, pass, test_expr);
          counting_assert(not pass, "Should return pass = false on failing check");
          verify_log_call(inc_count, expected_level => info);
        end loop;
      elsif run("Test should be possible to use concurrently") then
        test_concurrent_check(clk, check_not_unknown_in_1, default_checker);
        test_concurrent_check(clk, check_not_unknown_in_4, default_checker);
      elsif run("Test should be possible to use concurrently with negative active clock edge") then
        test_concurrent_check(clk, check_not_unknown_in_2, check_not_unknown_checker2, error, false);
        test_concurrent_check(clk, check_not_unknown_in_5, check_not_unknown_checker5, error, false);
      elsif run("Test should be possible to use concurrently with custom checker") then
        test_concurrent_check(clk, check_not_unknown_in_3, check_not_unknown_checker3, info);
        test_concurrent_check(clk, check_not_unknown_in_6, check_not_unknown_checker6, info);
      elsif run("Test should handle reversed and or offset expressions") then
        get_checker_stat(stat);
        check_not_unknown(reversed_and_offset_expr);
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
