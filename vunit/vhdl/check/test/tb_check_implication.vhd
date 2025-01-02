-- This test suite verifies the check_implication checker.
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

entity tb_check_implication is
  generic (
    runner_cfg : string);
end entity tb_check_implication;

architecture test_fixture of tb_check_implication is
  signal clk : std_logic := '0';

  signal check_implication_in_1,
    check_implication_in_2,
    check_implication_in_3,
    check_implication_in_4 : std_logic_vector(1 to 2) := "00";
  alias antecedent_1 : std_logic is check_implication_in_1(1);
  alias consequent_1 : std_logic is check_implication_in_1(2);
  alias antecedent_2 : std_logic is check_implication_in_2(1);
  alias consequent_2 : std_logic is check_implication_in_2(2);
  alias antecedent_3 : std_logic is check_implication_in_3(1);
  alias consequent_3 : std_logic is check_implication_in_3(2);
  alias antecedent_4 : std_logic is check_implication_in_4(1);
  alias consequent_4 : std_logic is check_implication_in_4(2);
  signal check_implication_en_1, check_implication_en_2, check_implication_en_3, check_implication_en_4 : std_logic := '1';

  constant my_checker : checker_t := new_checker("my_checker1");
  constant my_checker2 : checker_t := new_checker("my_checker2");
  constant my_checker3 : checker_t := new_checker("my_checker3", default_log_level => info);
  constant my_checker4 : checker_t := new_checker("my_checker4");

begin
  clock: process is
  begin
    while get_phase(runner_state) < test_runner_exit loop
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
    end loop;
    wait;
  end process clock;

  check_implication_1 : check_implication(clk, check_implication_en_1, antecedent_1, consequent_1);
  check_implication_2 : check_implication(my_checker2, clk, check_implication_en_2, antecedent_2, consequent_2, active_clock_edge => falling_edge);
  check_implication_3 : check_implication(my_checker3, clk, check_implication_en_3, antecedent_3, consequent_3);
  check_implication_4 : check_implication(my_checker4, clk, check_implication_en_4,
                                          antecedent_4, consequent_4, result("between x and y."));

  check_implication_runner : process
    variable passed : boolean;
    type boolean_vector is array (natural range <>) of boolean;
    constant test_antecedents : boolean_vector(1 to 4) := (false, false, true, true);
    constant test_consequents : boolean_vector(1 to 4) := (false, true, false, true);
    constant test_implication_expected_result : boolean_vector(1 to 4) := (true, true, false, true);
    variable stat : checker_stat_t;
    constant default_level : log_level_t := error;

    procedure test_concurrent_check (
      signal clk                        : in  std_logic;
      signal check_input                : out std_logic_vector;
      checker                           : checker_t;
      constant level                    : in  log_level_t := error;
      constant active_rising_clock_edge : in  boolean := true) is
    begin
      -- Verify all combinations of antecedent/consequent inputs
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      get_checker_stat(checker, stat);
      apply_sequence("000110", clk, check_input, active_rising_clock_edge);
      wait for 1 ns;
      verify_passed_checks(checker, stat, 2);
      verify_failed_checks(checker, stat, 0);
      mock(get_logger(checker));
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      check_only_log(get_logger(checker), "Implication check failed.", level);
      unmock(get_logger(checker));
      verify_passed_checks(checker, stat, 2);
      verify_failed_checks(checker, stat, 1);
      apply_sequence("11", clk, check_input, active_rising_clock_edge);
      wait until clock_edge(clk, active_rising_clock_edge);
      wait for 1 ns;
      verify_passed_checks(checker, stat, 3);
      verify_failed_checks(checker, stat, 1);
      reset_checker_stat(checker);
    end procedure test_concurrent_check;

    procedure verify_result (
      constant iteration : in    natural;
      checker            : checker_t;
      variable stat      : inout    checker_stat_t) is
    begin
      if test_implication_expected_result(iteration) then
        verify_passed_checks(checker, stat, 1);
        verify_failed_checks(checker, stat, 0);
        check_only_log(get_logger(checker),
                       "Implication check passed. - Got " &
                       boolean'image(test_antecedents(iteration)) &" -> " & boolean'image(test_consequents(iteration)) &
                       ".", pass);
      else
        verify_passed_checks(checker, stat, 0);
        verify_failed_checks(checker, stat, 1);
        check_only_log(get_logger(checker), "Implication check failed.", default_level);
      end if;
      reset_checker_stat(checker);

    end verify_result;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test sequential checkers should fail on true implies false but pass on other inputs") then
        for i in test_antecedents'range loop
          mock(check_logger);
          get_checker_stat(stat);
          check_implication(test_antecedents(i), test_consequents(i));
          verify_result(i, default_checker, stat);
          unmock(check_logger);

          mock(get_logger(my_checker));
          get_checker_stat(my_checker, stat);
          check_implication(my_checker, test_antecedents(i), test_consequents(i));
          verify_result(i, my_checker, stat);
          unmock(get_logger(my_checker));

          mock(check_logger);
          get_checker_stat(stat);
          check_implication(passed, test_antecedents(i), test_consequents(i));
          verify_result(i, default_checker, stat);
          unmock(check_logger);

          mock(check_logger);
          get_checker_stat(stat);
          passed := check_implication(test_antecedents(i), test_consequents(i));
          verify_result(i, default_checker, stat);
          unmock(check_logger);

          mock(get_logger(my_checker));
          get_checker_stat(my_checker, stat);
          check_implication(my_checker, passed, test_antecedents(i), test_consequents(i));
          verify_result(i, my_checker, stat);
          unmock(get_logger(my_checker));

          mock(get_logger(my_checker));
          get_checker_stat(my_checker, stat);
          passed := check_implication(my_checker, test_antecedents(i), test_consequents(i));
          verify_result(i, my_checker, stat);
          unmock(get_logger(my_checker));
        end loop;

      elsif run("Test should be possible to use concurrently") then
        test_concurrent_check(clk, check_implication_in_1, default_checker);

      elsif run("Test should be possible to use concurrently with negative active clock edge") then
        test_concurrent_check(clk, check_implication_in_2, my_checker2, error, false);

      elsif run("Test should be possible to use concurrently with custom checker") then
        test_concurrent_check(clk, check_implication_in_3, my_checker3, info);

      elsif run("Test should handle weak known meta values as known values and others as unknowns") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(my_checker4, stat);
        apply_sequence("000XLXH1HH00", clk, check_implication_in_4);
        wait for 1 ns;
        verify_passed_checks(my_checker4, stat, 5);
        verify_failed_checks(my_checker4, stat, 0);
        mock(get_logger(my_checker4));
        apply_sequence("00HL00", clk, check_implication_in_4);
        wait until rising_edge(clk);
        wait for 1 ns;
        check_log(get_logger(my_checker4), "Implication check passed between x and y. - Got false -> false.", pass);
        check_log(get_logger(my_checker4), "Implication check failed between x and y.", default_level);
        check_log(get_logger(my_checker4), "Implication check passed between x and y. - Got false -> false.", pass);
        check_no_log;
        verify_passed_checks(my_checker4, stat, 7);
        verify_failed_checks(my_checker4, stat, 1);
        apply_sequence("00H000", clk, check_implication_in_4);
        wait until rising_edge(clk);
        wait for 1 ns;
        check_log(get_logger(my_checker4), "Implication check passed between x and y. - Got false -> false.", pass);
        check_log(get_logger(my_checker4), "Implication check failed between x and y.", default_level);
        check_log(get_logger(my_checker4), "Implication check passed between x and y. - Got false -> false.", pass);
        check_no_log;
        verify_passed_checks(my_checker4, stat, 9);
        verify_failed_checks(my_checker4, stat, 2);
        apply_sequence("00HX00", clk, check_implication_in_4);
        wait until rising_edge(clk);
        wait for 1 ns;
        check_log(get_logger(my_checker4), "Implication check passed between x and y. - Got false -> false.", pass);
        check_log(get_logger(my_checker4), "Implication check failed between x and y.", default_level);
        check_log(get_logger(my_checker4), "Implication check passed between x and y. - Got false -> false.", pass);
        unmock(get_logger(my_checker4));
        verify_passed_checks(my_checker4, stat, 11);
        verify_failed_checks(my_checker4, stat, 3);
        reset_checker_stat(my_checker4);

      elsif run("Test should pass on true implies false when not enabled") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        check_implication_en_1 <= '0';
        apply_sequence("1000", clk, check_implication_in_1);
        check_implication_en_1 <= '1';
        wait until rising_edge(clk);
        check_implication_en_1 <= 'L';
        apply_sequence("1000", clk, check_implication_in_1);
        check_implication_en_1 <= 'H';
        wait until rising_edge(clk);
        check_implication_en_1 <= 'X';
        apply_sequence("1000", clk, check_implication_in_1);
        check_implication_en_1 <= '1';
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
