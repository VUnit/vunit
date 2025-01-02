-- This test suite verifies the check_sequence checker.
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

entity tb_check_sequence is
  generic (
    runner_cfg : string);
end entity tb_check_sequence;

architecture test_fixture of tb_check_sequence is
  signal clk : std_logic := '0';

  type slv_vector is array (natural range <>) of std_logic_vector(1 to 5);
  constant n_checks : positive := 5;
  signal inp : slv_vector(1 to n_checks) := (others => "00000");
  signal en : std_logic := '0';
  signal event_sequence : std_logic_vector(23 downto 20) := "0000";

  signal start_check_sequence_4 : boolean := false;
  constant my_checker_2 : checker_t := new_checker("my_checker2");
  constant my_checker_3 : checker_t := new_checker("my_checker3");
  constant my_checker_4 : checker_t := new_checker("my_checker4");
  constant my_checker_5 : checker_t := new_checker("my_checker5");
begin
  clock: process is
  begin
    while get_phase(runner_state) < test_runner_exit loop
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
    end loop;
    wait;
  end process clock;

  check_sequence_1 : check_sequence(clk,
                                    inp(1)(5),
                                    inp(1)(1 to 4),
                                    trigger_event => first_pipe);

  check_sequence_2 : check_sequence(my_checker_2,
                                    clk,
                                    inp(2)(5),
                                    inp(2)(1 to 4),
                                    trigger_event => penultimate);

  check_sequence_3 : check_sequence(my_checker_3,
                                    clk,
                                    inp(3)(5),
                                    inp(3)(1 to 4),
                                    trigger_event => first_no_pipe);

  check_sequence_4 : process
  begin
    wait until start_check_sequence_4;
    check_sequence(my_checker_4, clk, inp(4)(5), inp(4)(1 to 1), result("for my data"));
    wait;
  end process;

  check_sequence_5 : check_sequence(my_checker_5,
                                    clk,
                                    inp(5)(5),
                                    inp(5)(1 to 4),
                                    result("for my data"),
                                    trigger_event => first_pipe);

  check_sequence_6 : check_sequence(clk,
                                    en,
                                    event_sequence,
                                    trigger_event => first_no_pipe);

  check_sequence_runner : process
    variable stat : checker_stat_t;
    constant default_level : log_level_t := error;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should fail on sequences shorter than two events") then
        get_checker_stat(my_checker_4, stat);
        mock(get_logger(my_checker_4));
        start_check_sequence_4 <= true;
        wait for 1 ns;
        check_only_log(get_logger(my_checker_4),
                       "Sequence check failed for my data - Event sequence length must be at least 2. Got 1.",
                       default_level);
        unmock(get_logger(my_checker_4));
        verify_passed_checks(my_checker_4, stat, 0);
        verify_failed_checks(my_checker_4, stat, 1);
        reset_checker_stat(my_checker_4);

      elsif run("Test should pass a penultimate triggered pipelined and sequentially asserted event sequence") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(my_checker_2, stat);
        apply_sequence("0000.1;1000.1;0100.1;1010.1;0101.1;0010.1", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(my_checker_2,stat, 1);
        verify_failed_checks(my_checker_2,stat, 0);
        apply_sequence("0010.1;0001.1;0000.1", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(my_checker_2,stat, 2);
        verify_failed_checks(my_checker_2,stat, 0);
        apply_sequence("0000.1;1000.1;0100.1;0000.1;0001.1;0000.0", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(my_checker_2,stat, 2);
        verify_failed_checks(my_checker_2,stat, 0);

      elsif run("Test should fail a penultimate triggered but interrupted event sequence") then
        get_checker_stat(my_checker_2, stat);
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(my_checker_2, stat);
        apply_sequence("0000.1;1000.1;0100.1;1010.1;0101.1;0010.1", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(my_checker_2, stat, 1);
        verify_failed_checks(my_checker_2, stat, 0);
        mock(get_logger(my_checker_2));
        apply_sequence("0010.1;0000.1;0000.0", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(my_checker_2, stat, 1);
        verify_failed_checks(my_checker_2, stat, 1);
        check_only_log(get_logger(my_checker_2),
                       "Sequence check failed - Missing required event at 3rd active and enabled clock edge.",
                       default_level);
        unmock(get_logger(my_checker_2));
        reset_checker_stat(my_checker_2);

      elsif run("Test should pass a first triggered pipelined and sequentially asserted event sequence when pipelining is supported") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        apply_sequence("0000.1;1000.1;0100.1;1010.1;0101.1;0010.1", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 0);
        apply_sequence("0010.1;0001.1;0000.0", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 2);
        verify_failed_checks(stat, 0);

      elsif run("Test should fail a first triggered but interrupted event sequence") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        apply_sequence("0000.1;1000.1;0100.1;1010.1;0101.1;0000.1", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 0);
        mock(check_logger);
        apply_sequence("0000.1;0000.0", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 1);
        check_only_log(check_logger,
                       "Sequence check failed - Missing required event at 2nd active and enabled clock edge.",
                       default_level);
        unmock(check_logger);
        reset_checker_stat;

      elsif run("Test should ignore a first triggered and simulataneously initiated event sequence when pipelining is not supported") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(my_checker_3, stat);
        apply_sequence("0000.1;1000.1;0100.1;1010.1;0101.1;0010.1", clk, inp(3));
        wait for 1 ns;
        verify_passed_checks(my_checker_3, stat, 1);
        verify_failed_checks(my_checker_3, stat, 0);
        apply_sequence("0010.1;0001.1;0000.0", clk, inp(3));
        wait for 1 ns;
        verify_passed_checks(my_checker_3, stat, 1);
        verify_failed_checks(my_checker_3, stat, 0);

      elsif run("Test should fail on unknowns in event sequence") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(my_checker_2, stat);
        mock(get_logger(my_checker_2));
        apply_sequence("0000.1;1000.1;0100.1;10X0.1;0101.1;0010.1", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(my_checker_2, stat, 0);
        verify_failed_checks(my_checker_2, stat, 1);
        check_only_log(get_logger(my_checker_2), "Sequence check failed - Got 10X0.", default_level);
        unmock(get_logger(my_checker_2));
        apply_sequence("0010.1;0001.1;0000.0", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(my_checker_2, stat, 1);
        verify_failed_checks(my_checker_2, stat, 1);
        reset_checker_stat(my_checker_2);
        get_checker_stat(stat);
        mock(check_logger);
        apply_sequence("0000.1;10X0.1;0100.1", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 1);
        check_only_log(check_logger, "Sequence check failed - Got 10X0.", default_level);
        apply_sequence("0100.1;10X0.1;0101.1;0010.1", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 3);
        check_log(check_logger, "Sequence check failed - Missing required event at 2nd active and enabled clock edge.", default_level);
        check_only_log(check_logger, "Sequence check failed - Got 10X0.", default_level);
        apply_sequence("0010.1;0001.1;0000.0", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 3);
        check_only_log(check_logger, "Sequence check passed", pass);

        apply_sequence("0000.1;1000.1;1100.1;0X10.1;0011.1;0001.1;0000.1", clk, inp(1));
        verify_passed_checks(stat, 2);
        verify_failed_checks(stat, 5);
        check_log(check_logger, "Sequence check failed - Missing required event at 1st active and enabled clock edge.", default_level);
        check_log(check_logger, "Sequence check failed - Got 0X10.", default_level);
        check_only_log(check_logger, "Sequence check passed", pass);
        unmock(check_logger);
        reset_checker_stat;

      elsif run("Test should support weak high and low meta values") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(my_checker_2, stat);
        apply_sequence("0000.1;HL00.H;LH00.1;0010.1;000H.1;0000.0", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(my_checker_2, stat, 1);
        verify_failed_checks(my_checker_2, stat, 0);

      elsif run("Test should handle reversed and or offset expressions") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        en <= '1';
        event_sequence <= "1000";
        wait until rising_edge(clk);
        event_sequence <= "0100";
        wait until rising_edge(clk);
        event_sequence <= "0010";
        wait until rising_edge(clk);
        event_sequence <= "0001";
        wait until rising_edge(clk);
        event_sequence <= "0000";
        en <= '0';
        wait for 1 ns;
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 0);

      elsif run("Test pass message") then
        get_checker_stat(my_checker_5, stat);
        mock(get_logger(my_checker_5));
        apply_sequence("0000.1;1000.1;0100.1;0010.1;0001.1;0000.1", clk, inp(5));
        wait for 1 ns;
        check_only_log(get_logger(my_checker_5), "Sequence check passed for my data", pass);
        unmock(get_logger(my_checker_5));
        verify_passed_checks(my_checker_5, stat, 1);
        verify_failed_checks(my_checker_5, stat, 0);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;
