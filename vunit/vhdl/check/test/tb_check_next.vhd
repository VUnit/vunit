-- This test suite verifies the check_next checker.
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

entity tb_check_next is
  generic (
    runner_cfg : string);
end entity tb_check_next;

architecture test_fixture of tb_check_next is
  signal clk : std_logic := '0';
  signal one : std_logic := '1';
  signal zero : std_logic := '0';

  signal check_next_in_1, check_next_in_2, check_next_in_3, check_next_in_4, check_next_in_5 : std_logic_vector(1 to 3) := "001";
  alias check_next_start_event_1 : std_logic is check_next_in_1(1);
  alias check_next_expr_1 : std_logic is check_next_in_1(2);
  alias check_next_en_1 : std_logic is check_next_in_1(3);
  alias check_next_start_event_2 : std_logic is check_next_in_2(1);
  alias check_next_expr_2 : std_logic is check_next_in_2(2);
  alias check_next_en_2 : std_logic is check_next_in_2(3);
  alias check_next_start_event_3 : std_logic is check_next_in_3(1);
  alias check_next_expr_3 : std_logic is check_next_in_3(2);
  alias check_next_en_3 : std_logic is check_next_in_3(3);
  alias check_next_start_event_4 : std_logic is check_next_in_4(1);
  alias check_next_expr_4 : std_logic is check_next_in_4(2);
  alias check_next_en_4 : std_logic is check_next_in_4(3);
  alias check_next_start_event_5 : std_logic is check_next_in_5(1);
  alias check_next_expr_5 : std_logic is check_next_in_5(2);
  alias check_next_en_5 : std_logic is check_next_in_5(3);

  shared variable check_next_checker2, check_next_checker3, check_next_checker4, check_next_checker5 : checker_t;
begin
  clock: process is
  begin
    while runner.phase < test_runner_exit loop
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
    end loop;
    wait;
  end process clock;

  check_next_1 : check_next(clk,
                            check_next_en_1,
                            check_next_start_event_1,
                            check_next_expr_1,
                            num_cks => 4);
  check_next_2 : check_next(check_next_checker2,
                            clk,
                            check_next_en_2,
                            check_next_start_event_2,
                            check_next_expr_2,
                            active_clock_edge => falling_edge,
                            num_cks => 4);
  check_next_3 : check_next(check_next_checker3,
                            clk,
                            check_next_en_3,
                            check_next_start_event_3,
                            check_next_expr_3,
                            num_cks => 4);
  check_next_4 : check_next(check_next_checker4,
                            clk,
                            check_next_en_4,
                            check_next_start_event_4,
                            check_next_expr_4,
                            num_cks => 4,
                            allow_overlapping => false);
  check_next_5 : check_next(check_next_checker5,
                            clk,
                            check_next_en_5,
                            check_next_start_event_5,
                            check_next_expr_5,
                            num_cks => 4,
                            allow_missing_start => false);

  check_next_runner : process
    variable pass : boolean;
    variable stat : checker_stat_t;

    procedure test_concurrent_check (
      signal clk                        : in  std_logic;
      signal check_input                : out std_logic_vector;
      variable checker : inout checker_t;
      constant level                    : in  log_level_t := error;
      constant active_rising_clock_edge : in  boolean := true) is

    begin
      if running_test_case = "Test should pass when expr is true num cks enabled cycles after start event" then
        get_checker_stat(checker, stat);
        apply_sequence("001;101;001;001;000;001;011;001", clk, check_input, active_rising_clock_edge);
        wait for 1 ns;
        verify_passed_checks(checker, stat, 1);
      elsif running_test_case = "Test should fail when expr is false num cks enabled cycles after start event" then
        apply_sequence("001;111;011;011;010;011;001;011;001", clk, check_input, active_rising_clock_edge);
        wait for 1 ns;
        verify_log_call(inc_count, expected_level => level);
      elsif running_test_case = "Test should handle a mix of passing and failing overlapping checks when allowed" then
        get_checker_stat(checker, stat);
        apply_sequence("001;101;001;101;101;000;011;001", clk, check_input, active_rising_clock_edge);
        wait for 1 ns;
        verify_passed_checks(checker, stat, 1);
        verify_failed_checks(checker, stat, 0);
        apply_sequence("001;011;001", clk, check_input, active_rising_clock_edge);
        wait for 1 ns;
        verify_passed_checks(checker, stat, 2);
        verify_failed_checks(checker, stat, 0);
        apply_sequence("001;001", clk, check_input, active_rising_clock_edge);
        wait for 1 ns;
        verify_log_call(inc_count, expected_level => level);
      elsif running_test_case = "Test should pass a true expr without start event if missing start is allowed" then
        get_checker_stat(checker, stat);
        apply_sequence("001;001;001;011;001", clk, check_input, active_rising_clock_edge);
        wait for 1 ns;
        verify_passed_checks(checker, stat, 1);
        verify_failed_checks(checker, stat, 0);
      end if;

    end procedure test_concurrent_check;

  begin
    custom_checker_init_from_scratch(check_next_checker3, default_level => info);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should pass when expr is true num cks enabled cycles after start event") or
        run("Test should fail when expr is false num cks enabled cycles after start event") or
        run("Test should handle a mix of passing and failing overlapping checks when allowed") or
        run("Test should pass a true expr without start event if missing start is allowed") then

        test_concurrent_check(clk, check_next_in_1, default_checker);
        test_concurrent_check(clk, check_next_in_2, check_next_checker2, error, false);
        test_concurrent_check(clk, check_next_in_3, check_next_checker3, level => info);
      elsif run("Test should fail when an overlapping check is initiated when not allowed") then
        get_checker_stat(check_next_checker4, stat);
        apply_sequence("001;101;001;101;001;011;001;011;001", clk, check_next_in_4);
        wait for 1 ns;
        verify_passed_checks(check_next_checker4, stat, 2);
        verify_log_call(inc_count, "Overlapping not allowed.");
        get_checker_stat(check_next_checker4, stat);
        apply_sequence("001;101;001;001;001;111;001;001;001;011;001", clk, check_next_in_4);
        wait for 1 ns;
        verify_passed_checks(check_next_checker4, stat, 2);
        verify_failed_checks(check_next_checker4, stat, 0);
      elsif run("Test should fail a true expr without start event if missing start is not allowed") then
        get_checker_stat(check_next_checker5, stat);
        apply_sequence("001;001;001;011;001", clk, check_next_in_5);
        wait for 1 ns;
        verify_passed_checks(check_next_checker5, stat, 0);
        verify_log_call(inc_count, "Missing start event for true expression.");
      elsif run("Test should handle meta values") then
        get_checker_stat(check_next_checker5, stat);
        apply_sequence("00H;10H;00H;00H;00L;00H;01H;00H;00H", clk, check_next_in_5);
        wait for 1 ns;
        verify_passed_checks(check_next_checker5, stat, 1);
        verify_failed_checks(check_next_checker5, stat, 0);

        get_checker_stat(check_next_checker5, stat);
        apply_sequence("0LH;1LH;0LH;0LH;0LL;0LH;0HH;0LH;0LH", clk, check_next_in_5);
        wait for 1 ns;
        verify_passed_checks(check_next_checker5, stat, 1);
        verify_failed_checks(check_next_checker5, stat, 0);

        get_checker_stat(check_next_checker5, stat);
        apply_sequence("LLH;HLH;LLH;LLH;LLL;LLH;LHH;LLH;LLH", clk, check_next_in_5);
        wait for 1 ns;
        verify_passed_checks(check_next_checker5, stat, 1);
        verify_failed_checks(check_next_checker5, stat, 0);

        get_checker_stat(check_next_checker5, stat);
        apply_sequence("XLH;HLH;LLH;LLH;LXX;LLH;LHH;LLH;LLH", clk, check_next_in_5);
        wait for 1 ns;
        verify_passed_checks(check_next_checker5, stat, 1);
        verify_failed_checks(check_next_checker5, stat, 1);
      end if;
    end loop;

    get_and_print_test_result(stat);
    test_runner_cleanup(runner, stat);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;

-- vunit_pragma run_all_in_same_sim
