-- This test suite verifies the check_next checker.
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

entity tb_check_next is
  generic (
    runner_cfg : string);
end entity tb_check_next;

architecture test_fixture of tb_check_next is
  signal clk : std_logic := '0';

  signal check_next_in_1, check_next_in_2, check_next_in_3, check_next_in_4,
    check_next_in_5, check_next_in_6, check_next_in_7, check_next_in_8 : std_logic_vector(1 to 3) := "001";
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
  alias check_next_start_event_6 : std_logic is check_next_in_6(1);
  alias check_next_expr_6 : std_logic is check_next_in_6(2);
  alias check_next_en_6 : std_logic is check_next_in_6(3);
  alias check_next_start_event_7 : std_logic is check_next_in_7(1);
  alias check_next_expr_7 : std_logic is check_next_in_7(2);
  alias check_next_en_7 : std_logic is check_next_in_7(3);
  alias check_next_start_event_8 : std_logic is check_next_in_8(1);
  alias check_next_expr_8 : std_logic is check_next_in_8(2);
  alias check_next_en_8 : std_logic is check_next_in_8(3);

  constant my_checker2 : checker_t := new_checker("my_checker2");
  constant my_checker3 : checker_t := new_checker("my_checker3", default_log_level => info);
  constant my_checker4 : checker_t := new_checker("my_checker4");
  constant my_checker5 : checker_t := new_checker("my_checker5");
begin
  clock: process is
  begin
    while get_phase(runner_state) < test_runner_exit loop
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

  check_next_2 : check_next(my_checker2,
                            clk,
                            check_next_en_2,
                            check_next_start_event_2,
                            check_next_expr_2,
                            active_clock_edge => falling_edge,
                            num_cks => 4);
  check_next_3 : check_next(my_checker3,
                            clk,
                            check_next_en_3,
                            check_next_start_event_3,
                            check_next_expr_3,
                            num_cks => 4);
  check_next_4 : check_next(my_checker4,
                            clk,
                            check_next_en_4,
                            check_next_start_event_4,
                            check_next_expr_4,
                            result("for my data"),
                            num_cks => 4,
                            allow_overlapping => false);
  check_next_5 : check_next(my_checker5,
                            clk,
                            check_next_en_5,
                            check_next_start_event_5,
                            check_next_expr_5,
                            "Checking my data",
                            num_cks => 4,
                            allow_missing_start => false);
  check_next_6 : check_next(clk,
                            check_next_en_6,
                            check_next_start_event_6,
                            check_next_expr_6,
                            result("for my data"),
                            num_cks => 1);

  check_next_7 : check_next(clk,
                            check_next_en_7,
                            check_next_start_event_7,
                            check_next_expr_7,
                            num_cks => 0);

  check_next_8 : check_next(clk,
                            check_next_en_8,
                            check_next_start_event_8,
                            check_next_expr_8,
                            result("for my data"),
                            num_cks => 0,
                            allow_missing_start => false);

  check_next_runner : process
    variable stat : checker_stat_t;
    constant default_level : log_level_t := error;

    procedure test_concurrent_check (
      signal clk                        : in  std_logic;
      signal check_input                : out std_logic_vector;
      checker                           : checker_t;
      constant level                    : in  log_level_t := error;
      constant active_rising_clock_edge : in  boolean := true) is

    begin
      if enabled("Test should pass when expr is true num_cks enabled cycles after start_event") then
        get_checker_stat(checker, stat);
        apply_sequence("001;101;001;001;000;001;011;001", clk, check_input, active_rising_clock_edge);
        wait for 1 ns;
        verify_passed_checks(checker, stat, 1);

      elsif enabled("Test should fail when expr is false num_cks enabled cycles after start_event") then
        mock(check_logger);
        apply_sequence("001;111;011;011;010;011;001;011;001", clk, check_input, active_rising_clock_edge);
        wait for 1 ns;
        check_only_log(check_logger, "Next check failed - Got 0 at the 4th active and enabled clock edge.", level);
        unmock(check_logger);
        verify_passed_checks(checker, stat, 0);
        verify_failed_checks(checker, stat, 1);
        reset_checker_stat;

      elsif enabled("Test should handle a mix of passing and failing overlapping checks when allowed") then
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
        check_only_log(check_logger, "Next check failed - Got 0 at the 4th active and enabled clock edge.", level);
        verify_passed_checks(checker, stat, 2);
        verify_failed_checks(checker, stat, 1);
        reset_checker_stat(checker);

      elsif enabled("Test should pass a true expr without start_event if missing start is allowed") then
        get_checker_stat(checker, stat);
        apply_sequence("001;001;001;011;001", clk, check_input, active_rising_clock_edge);
        wait for 1 ns;
        verify_passed_checks(checker, stat, 0);
        verify_failed_checks(checker, stat, 0);
      end if;

    end procedure test_concurrent_check;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should pass when expr is true num_cks enabled cycles after start_event") or
        run("Test should fail when expr is false num_cks enabled cycles after start_event") or
        run("Test should handle a mix of passing and failing overlapping checks when allowed") or
        run("Test should pass a true expr without start_event if missing start is allowed") then

        test_concurrent_check(clk, check_next_in_1, default_checker);
        test_concurrent_check(clk, check_next_in_2, my_checker2, error, false);
        test_concurrent_check(clk, check_next_in_3, my_checker3, level => info);
      elsif run("Test should pass when expr is true num_cks=0 enabled cycles after start_event") then
        get_checker_stat(stat);
        apply_sequence("001;111;001;001;100;001;111;111;001", clk, check_next_in_7);
        wait for 1 ns;
        verify_passed_checks(stat, 3);
        verify_failed_checks(stat, 0);
      elsif run("Test should fail when expr is false num_cks=0 enabled cycles after start_event") then
        get_checker_stat(stat);
        mock(check_logger);
        apply_sequence("001;101;001", clk, check_next_in_7);
        wait for 1 ns;
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 1);
        check_only_log(check_logger, "Next check failed - Got 0 at the 0th active and enabled clock edge.", default_level);
        unmock(check_logger);
      elsif run("Test should pass a true expr without start_event if missing start is allowed and num_cks=0") then
        get_checker_stat(stat);
        apply_sequence("001;011;001", clk, check_next_in_7);
        wait for 1 ns;
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 0);
      elsif run("Test should fail when an overlapping check is initiated when not allowed") then
        get_checker_stat(my_checker4, stat);
        mock(get_logger(my_checker4));
        apply_sequence("001;101;001;101;001;011;001;011;001", clk, check_next_in_4);
        wait until rising_edge(clk);
        wait for 1 ns;
        verify_passed_checks(my_checker4, stat, 1);
        verify_failed_checks(my_checker4, stat, 1);
        check_log(get_logger(my_checker4), "Next check failed for my data - Got overlapping start event at the 2nd active and enabled clock edge.", default_level);
        check_log(get_logger(my_checker4), "Next check passed for my data", pass);
        unmock(get_logger(my_checker4));
        apply_sequence("001;101;001;001;001;111;001;001;001;011;001", clk, check_next_in_4);
        wait until rising_edge(clk);
        wait for 1 ns;
        verify_passed_checks(my_checker4, stat, 3);
        verify_failed_checks(my_checker4, stat, 1);
        reset_checker_stat(my_checker4);
      elsif run("Test should fail a true expr without start event if missing start is not allowed") then
        get_checker_stat(my_checker5, stat);
        mock(get_logger(my_checker5));
        apply_sequence("001;001;001;011;001", clk, check_next_in_5);
        wait until rising_edge(clk);
        wait for 1 ns;
        verify_passed_checks(my_checker5, stat, 0);
        verify_failed_checks(my_checker5, stat, 1);
        reset_checker_stat(my_checker5);
        check_only_log(get_logger(my_checker5), "Checking my data - Missing start event for true expression.", default_level);
        unmock(get_logger(my_checker5));
      elsif run("Test should fail a true expr without start event if missing start is not allowed and num_cks=0") then
        get_checker_stat(stat);
        mock(check_logger);
        apply_sequence("001;011;001", clk, check_next_in_8);
        wait for 1 ns;
        verify_passed_checks(stat, 0);
        check_only_log(check_logger, "Next check failed for my data - Missing start event for true expression.", default_level);
        unmock(check_logger);
      elsif run("Test should handle meta values") then
        get_checker_stat(my_checker5, stat);
        apply_sequence("00H;10H;00H;00H;00L;00H;01H;00H;00H", clk, check_next_in_5);
        wait until rising_edge(clk);
        wait for 1 ns;
        verify_passed_checks(my_checker5, stat, 1);
        verify_failed_checks(my_checker5, stat, 0);

        get_checker_stat(my_checker5, stat);
        apply_sequence("0LH;1LH;0LH;0LH;0LL;0LH;0HH;0LH;0LH", clk, check_next_in_5);
        wait for 1 ns;
        verify_passed_checks(my_checker5, stat, 1);
        verify_failed_checks(my_checker5, stat, 0);

        get_checker_stat(my_checker5, stat);
        apply_sequence("LLH;HLH;LLH;LLH;LLL;LLH;LHH;LLH;LLH", clk, check_next_in_5);
        wait for 1 ns;
        verify_passed_checks(my_checker5, stat, 1);
        verify_failed_checks(my_checker5, stat, 0);

        get_checker_stat(my_checker5, stat);
        mock(get_logger(my_checker5));
        apply_sequence("XLH;HLH;LLH;LLH;LXX;LLH;LHH;LLH;LLH", clk, check_next_in_5);
        wait for 1 ns;
        verify_passed_checks(my_checker5, stat, 1);
        verify_failed_checks(my_checker5, stat, 1);
        reset_checker_stat(my_checker5);
        check_log(get_logger(my_checker5), "Checking my data - Start event is X.", default_level);
        check_log(get_logger(my_checker5), "Checking my data", pass);
        unmock(get_logger(my_checker5));

      elsif run("Test pass message and that internal checks don't count") then
        get_checker_stat(stat);
        mock(check_logger);
        apply_sequence("001;101;0U1;011", clk, check_next_in_6);
        wait for 1 ns;
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 1);
        check_only_log(check_logger, "Next check failed for my data - Got U at the 1st active and enabled clock edge.", default_level);
        apply_sequence("011;101;011;001", clk, check_next_in_6);
        wait for 1 ns;
        check_only_log(check_logger, "Next check passed for my data", pass);
        unmock(check_logger);
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 1);
        reset_checker_stat;
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;
