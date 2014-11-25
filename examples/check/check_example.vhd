-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity check_example is
end entity check_example;

architecture test of check_example is
  constant some_true_condition : boolean := true;
  constant some_false_condition : boolean := false;
  signal status_ok : std_logic;
  signal clk : std_logic := '0';
  signal check_en : std_logic := '0';
begin
  example_process: process is
    alias note is info_low2[string, string, natural, string];
    variable all_reports : logger_t;
    variable my_checker : checker_t;
    variable pass, found_errors : boolean;
  begin  -- process example_process
    logger_init(display_format => level);
    rename_level(info_low2, "note");
    info("The basic check is like a VHDL assert where the report/severity statements are replaced by a call to the error logging function");
    check(some_true_condition, "Expect to pass so this should never be displayed");
    check(some_false_condition, "Expected to fail");

    ---------------------------------------------------------------------------

    info("Without any checker initialization the logger will use the raw formatter. If you do a checker initialization you will by default get the level formatter which better emphasis that there is an error.");
    checker_init;
    check(some_false_condition, "Expected to fail");

    ---------------------------------------------------------------------------
    
    info("The checker_init takes all the inputs logger_init does to configure the logger that errors are reported to. It also takes a default_level input that controls the level reported to the logger. This is error unless specified.");
    info("The default level can be overridden in a specific check call.");
    check(some_false_condition, "This is not very good", level => warning);
    note("Every failing check will be regarded as an error from a unit testing point of view regardless of which level used for reporting.");
    info(LF & to_string(get_checker_stat));
    check(some_false_condition, "This is also collected in the error statistsics.", level => warning);
    info(LF & to_string(get_checker_stat));

    ---------------------------------------------------------------------------

    info("The default stop level for a checker is failure which means that detected errors won't stop the simulation unless that level is changed or the level is raised for very severe errors.");
    check(some_false_condition, "No point in continuing after this error... Hopefully your simulator allows you to single-step to complete this example.", level => failure);
    note("When using the Python test runner the stop_level is set to error. The reason is that the Python test runner has the ability to restart the simulation with the next test case and thereby cleaning the error state in between.");

    ---------------------------------------------------------------------------

    info("Check calls are also detected by the location preprocessor such that ""anonymous"" checks can be more easily traced.");
    checker_init(display_format => verbose);
    check(some_false_condition);

    ---------------------------------------------------------------------------

    info("Checkers have an internal logger used for reporting but another logger can be used, for example if you want all your logs and all error reports to end up in the same file.");
    logger_init(all_reports, display_format => level, file_format => verbose_csv, file_name => "all_reports.csv");
    checker_init(logger => all_reports);
    info(all_reports, "This log will end up in all_reports.csv.");
    check(some_false_condition, "This error will also end up in all_reports.csv.");

    ---------------------------------------------------------------------------

    info("As with loggers it's possible to create many checkers, so far we've used the default one.");
    checker_init(my_checker, display_format => level, file_format => verbose_csv, file_name => "not_all_reports.csv");
    check(my_checker, some_false_condition, "This error won't show in all_reports.csv but in not_all_reports.csv.");

    ---------------------------------------------------------------------------

    info("You can act on the result of a single check. Calls to the default checker are implemented with both procedures and functions while calls to custom checkers have to be procedures (the checker parameter is a protected type).");
    if check(some_true_condition) then
      info("Expected to be here.");
    else
      info("This was not expected.");
    end if;
    check(my_checker, pass, some_true_condition);
    if pass then
      info("Expected to be here.");
    else
      info("This was not expected.");
    end if;
    info("You can also ask if a checker has detected any errors.");
    if check(checker_found_errors) then
      info("Expected to be here.");
    else
      info("This was not expected.");
    end if;
    checker_found_errors(my_checker, found_errors);
    if check(found_errors) then
      info("Expected to be here.");
    else
      info("This was not expected.");
    end if;
    
    ---------------------------------------------------------------------------

    info("Uptil now we've only used the basic sequential check call. There is a more generic check_true call that can be called concurrently as well. The concurrent call takes a std_logic condition ('1' = true) and checks that on every enabled clock_edge (either rising, falling, or both)");
    wait until rising_edge(clk);
    check_en <= '1';
    wait until falling_edge(clk);
    wait for 1 ns;
    info("Don't expect the concurrent status check to report any errors since it's setup to check on positive edges.");
    wait until rising_edge(clk);
    wait for 1 ns;
    info("Now you should have seen an error report.");
    check_en <= '0';

    ---------------------------------------------------------------------------

    info("There are also a number of other check types which differ in how the error condition is calculated but apart from that can be used in the same way as check/check_true.");
    info("Just a brief description is given here.");
    info("check_equal - Automatically generates error messages with left and right values in checks of equality between two values. Several types and combinations thereof are supported.");
    info("check_false - Checks that a condition is false.");
    info("check_implication - Checks that if the antecedent is true then the consequent must also be true.");
    info("check_stable - Checks that the input is stable between a start end an end event.");
    info("check_not_unknown - Checks that there are no unknown values (values other than '0', '1', 'L', and 'H') in the std_logic(_vector) input.");
    info("check_zero_one_hot - Checks that there is at most one '1' in the input vector.");
    info("check_one_hot - Checks that there is exactly one '1' in the input vector.");
    info("check_next - Checks that the input condition is true a specified number of clock cycles after a start event.");
    info("check_sequence - Checks that there sequence of events happens in the order specified.");
    
    wait;
  end process example_process;

  clk <= not clk after 5 ns;

  status_check: check_true(clk, check_en, status_ok, "Concurrent status check failed.");
end architecture test;
