-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity tb_example is
  generic (runner_cfg : string := runner_cfg_default);
end entity tb_example;

architecture test of tb_example is
  constant some_true_condition : boolean := true;
  constant some_false_condition, operation_completed : boolean := false;
  signal status_ok : std_logic;
  signal clk : std_logic := '0';
  signal check_en : std_logic := '0';
  signal start_event, end_event : std_logic := '0';
  signal stability_en, next_en, sequence_en : std_logic := '0';
  signal stability_signal, next_signal : std_logic := '0';
  signal event_sequence : std_logic_vector(1 to 4) := (others => '0');
begin
  example_process: process is
    constant my_data, reference_value : integer := 17;
    variable stat, expected_stat : checker_stat_t;
    variable my_checker : checker_t;
    variable check_ok, found_errors : boolean;
  begin
    test_runner_setup(runner, runner_cfg);

    -- Introduction
    -- This file contains a number of runnable examples that you can step through. Supporting information
    -- is brief. It is assumed that you've already read the user guide.

    -- The default settings is to stop on error but for these examples I want to continue
    -- on errors so I'm going to raise the stop level.
    set_stop_level(failure);

    -- Check
    -- The basic check is like a VHDL assert. The difference is that error messages are reported using the
    -- VUnit logging library.
    check(some_true_condition, "Expect to pass so this should not be displayed");
    check(some_false_condition, "Expected to fail");

    -- The default log level of error can also be overridden in a specific check call.
    check(some_false_condition, "This is not very good", warning);

    -- Note that every failing check will be regarded as a failure from a testing point of view regardless
    -- of which level that was used for reporting.
    info("Error statistics before warning: " & LF & to_string(get_checker_stat));
    check(some_false_condition, "This warning is also collected in the error statistsics.", warning);
    info("Error statistics after warning: " & LF & to_string(get_checker_stat));

    -- Logging Passing Checks
    -- You can also have the check message logged on a passing check to create a debug trace. If you use
    -- the result function the message becomes nice in both the passing and failing case.
    show(get_logger(default_checker), display_handler, pass);

    check(some_false_condition, result("for error status flag"));
    check(some_true_condition, result("for error status flag"));

    -- Message Format
    -- Some checks provide a context in addition to the user message in order to help debugging.
    -- A context is only given if it can provide information not already known from the type of
    -- check used. For example, a failing basic check is caused by the input expression being false.
    -- No need to bloat the output with such information.
    check_equal(my_data - 1, reference_value, result("for my_data"));
    check_equal(my_data, reference_value, result("for my_data"));

    -- Check Location
    -- Check calls are also detected by the location preprocessor such that ""anonymous"" checks can be
    -- more easily traced. Location preprocessing has been disabled for all checks but check_false to
    -- make this example file cleaner.
    check_false(some_true_condition, "Something is wrong somewhere.");

    -- Many Checkers
    -- As with loggers it's possible to create many checkers, so far we've used the default one.
    my_checker := new_checker("my_checker");

    -- The default checker is not affected by my_checker errors as shown in this after - before diff.
    stat := get_checker_stat;
    check(my_checker, some_false_condition);
    info("Changes in default checker stats after a my_checker error:" & LF & to_string(get_checker_stat - stat));
    get_checker_stat(my_checker, stat);
    info("my_checker has its own stats:" & LF & to_string(stat));

    -- Acting on Failing Checks
    -- You can act on the result of a single check. Calls to the default checker are implemented with
    -- both procedures and functions while calls to custom checkers have to be procedures (the checker
    -- parameter is a protected type).
    if check(some_true_condition) then
      info("Expected to be here.");
    else
      info("This was not expected.");
    end if;

    check(my_checker, check_ok, some_true_condition);
    if check_ok then
      info("Expected to be here.");
    else
      info("This was not expected.");
    end if;

    -- You can also ask if a checker has detected any errors.
    stat := get_checker_stat(default_checker);
    if stat.n_failed > 0 then
      info("Expected to be here.");
    else
      info("This was not expected.");
    end if;

    if stat.n_failed > 0 then
      info("Expected to be here.");
    else
      info("This was not expected.");
    end if;

    -- Concurrent checks
    -- Checks can be called concurrently as well (see bottom of file). The concurrent call for check
    -- takes a std_logic condition ('1' = true) and checks that on every enabled clock_edge
    -- (either rising, falling, or both).
    wait until rising_edge(clk);
    check_en <= '1';
    wait until falling_edge(clk); -- NOTE. Falling edge.
    wait for 1 ns;

    -- Don't expect the concurrent status check to report any errors yet since it's setup to check
    -- on positive edges.

    wait until rising_edge(clk);
    wait for 1 ns;

    -- Now you should have seen an error report.");
    check_en <= '0';

    -- Point Checks
    -- check is a point check checking a condition at a specific point in time. Here are some other
    -- point checks which have the same type of subprograms as check. Only one type of each is shown here.

    ---- True Check
    ---- check_true does the same thing as check but has a more verbose name and result message.
    check_true(false);
    check_true(true);

    ---- False Check
    ---- check_false is the inverse of check_true.
    check_false(true);
    check_false(false);

    ---- Implication Check
    ---- check_implication checks if a logical implication holds.
    check_implication(true, false);
    check_implication(false, true);

    ---- Not Unknown Check
    ---- check_not_unknown fails when meta values are present.
    check_not_unknown("00001U0");
    check_not_unknown("0000110");

    ---- Zero One-Hot Check
    ---- check_zero_one_hot requires zero or one bit to be active.
    check_zero_one_hot("10001");
    check_zero_one_hot("10000");

    ---- One-Hot Check
    ---- check_one_hot requires exactly one bit to be active.
    check_one_hot("00000");
    check_one_hot("10000");

    -- Relation Checks
    -- Checks are used to verify a relation, e.g. a = b. The following checks are designed to
    -- target such relations.

    ---- Equality Check
    ---- check_equal checks the equality between common or similar types.
    check_equal(true, '0');
    check_equal(true, '1');
    check_equal(unsigned'("1000"), 7);
    check_equal(-3, signed'("11100"));
    check_equal(std_logic_vector'("101010"), std_logic_vector'("--1010"),
                "Don't care ('-') only equals don't care.");
    check_equal(17, 17);

    ---- Match Check
    ---- check_match is like check_equal with the difference that don't care ('-') equals anything.
    check_match(std_logic_vector'("101010"), std_logic_vector'("--1001"));
    check_match(std_logic_vector'("101010"), std_logic_vector'("--1010"));

    ---- Relation Check
    ---- check_relation together with the check_preprocessor will check any relation between any
    ---- types and present an error context as long as the relation operator and the to_string
    ---- function are defined for those types.
    stat := get_checker_stat;
    expected_stat := (0, 0, 0);
    check_relation(stat = expected_stat, result("for default checker statistics"));
    expected_stat := stat + (1, 1, 0);
    check_relation(get_checker_stat = expected_stat, result("for default checker statistics"));

    -- Sequence Checks
    -- Sequence checks need several clock cycles to determine if the check passes or fails.
    -- The following types are provided:

    ---- Stability Check
    ---- check_stable checks the stability of a signal within a window. The concurrent procedure call
    ---- is at the bottom of this file.

    stability_signal <= '1';
    stability_en <= '1';

    ------ Unstable Case
    start_event <= '1';
    wait until rising_edge(clk);
    start_event <= '0';

    wait until rising_edge(clk);
    stability_signal <= '0';
    wait until rising_edge(clk);

    end_event <= '1';
    wait until rising_edge(clk);
    end_event <= '0';

    ------ Stable Case
    start_event <= '1';
    wait until rising_edge(clk);
    start_event <= '0';

    wait until rising_edge(clk);
    wait until rising_edge(clk);

    end_event <= '1';
    wait until rising_edge(clk);
    end_event <= '0';
    stability_en <= '0';
    wait until rising_edge(clk);

    ---- Next Check
    ---- check_next checks that an event happens with a specified delay from a starting point. The
    ---- concurrent procedure call is at the bottom of this file.

    ------ Too long delay
    next_en <= '1';
    start_event <= '1';
    wait until rising_edge(clk);
    start_event <= '0';

    wait until rising_edge(clk);
    wait until rising_edge(clk);

    next_signal <= '1';
    wait until rising_edge(clk);
    next_signal <= '0';
    wait until rising_edge(clk);

    ------ Expected delay
    start_event <= '1';
    wait until rising_edge(clk);
    start_event <= '0';

    wait until rising_edge(clk);

    next_signal <= '1';
    wait until rising_edge(clk);
    next_signal <= '0';
    next_en <= '0';
    wait until rising_edge(clk);

    ---- Sequence Check
    ---- check_sequence checks that a set of events, represented by the bits in a std_logic_vector,
    ---- are activated in consecutive clock cycles. check_sequence has several modes of operation.
    ---- This example uses the first_pipe mode. The concurrent procedure call is at the bottom of
    ---- this file.

    ------ Broken Sequence
    sequence_en <= '1';
    event_sequence <= "1000";
    wait until rising_edge(clk);
    event_sequence <= "0100";
    wait until rising_edge(clk);
    event_sequence <= "0000";
    wait until rising_edge(clk);
    event_sequence <= "0001";
    wait until rising_edge(clk);
    event_sequence <= "0000";
    wait until rising_edge(clk);

    ------ Complete Sequence
    event_sequence <= "1000";
    wait until rising_edge(clk);
    event_sequence <= "0100";
    wait until rising_edge(clk);
    event_sequence <= "0010";
    wait until rising_edge(clk);
    event_sequence <= "0001";
    wait until rising_edge(clk);
    event_sequence <= "0000";
    sequence_en <= '0';
    wait until rising_edge(clk);

    -- Unconditional Checks
    -- check_failed and check_passed are useful when the pass/fail status is already given by the
    -- normal program flow.
    if operation_completed then
      check_passed("Some operation completed successfully");
    else
      debug("Log some interesting information for debugging");
      check_failed("This was not expected. Read the log file for more debug information.");
    end if;

    -- Wrap-Up
    -- In this testbench I'm expecting failing checks and will suppress these such that the testbench pass.
    -- VUnit automatically tracks the errors for the default checker but if you create your own checker
    -- you have to insert its pass/fail status into the test_runner_cleanup call for those to be recognized.
    expected_stat := (41, 24, 17);
    stat := get_checker_stat;
    if stat = expected_stat then
      reset_checker_stat;
    else
      check_failed("Not the expected number of failing checks for the default checker:" & LF & to_string(stat));
    end if;

    expected_stat := (2, 1, 1);
    get_checker_stat(my_checker, stat);
    if stat = expected_stat then
      reset_checker_stat(my_checker);
    else
      check_failed("Not the expected number of failing checks for my_checker:" & LF & to_string(stat));
    end if;

    -- We reset the log count of the checkers to avoid test suite error in this
    -- example
    reset_log_count(get_logger(my_checker), error);
    reset_log_count(get_logger(default_checker), error);

    test_runner_cleanup(runner);
  end process example_process;

  clk <= not clk after 5 ns;

  status_check: check(clk, check_en, status_ok, "Concurrent status check failed.");
  stability_check : check_stable(clk, stability_en, start_event, end_event, stability_signal, result("for stability_signal."));
  next_check : check_next(clk, next_en, start_event, next_signal, result("for next_signal"), num_cks => 2);
  sequence_check: check_sequence(clk, sequence_en, event_sequence, result("for event_sequence"), first_pipe);
end architecture test;
