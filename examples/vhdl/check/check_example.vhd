-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
library vunit_lib;
use vunit_lib.lang.all;
use vunit_lib.string_ops.all;
use vunit_lib.dictionary.all;
use vunit_lib.path.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.log_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_special_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_types.all;
use work.test_type_methods.all;

entity check_example is
end entity check_example;

architecture test of check_example is
  constant some_true_condition : boolean := true;
  constant some_false_condition : boolean := false;
  signal status_ok : std_logic;
  signal clk : std_logic := '0';
  signal check_en : std_logic := '0';
  shared variable counter : shared_natural;
begin
  example_process: process is
    alias note is info_low2[string, string, natural, string];
    type cash_t is record
      dollars : natural;
      cents   : natural range 0 to 99;
    end record cash_t;
    type messages_t is array (boolean range <>) of string(1 to 6);

    function "-" (
      constant l : cash_t;
      constant r : cash_t)
      return cash_t is
      variable diff : cash_t;
    begin

      if r.cents > l.cents then
        diff.cents := 100 + l.cents - r.cents;
        diff.dollars := l.dollars - r.dollars - 1;
      else
        diff.cents := l.cents - r.cents;
        diff.dollars := l.dollars - r.dollars;
      end if;

      return diff;
    end function;

    function ">" (
      constant l : cash_t;
      constant r : cash_t)
      return boolean is
    begin
      return ((l.dollars > r.dollars) or
              ((l.dollars = r.dollars) and (l.cents >= r.cents)));
    end function;

    function to_string (
      constant value : cash_t)
      return string is
    begin
      return "$" & natural'image(value.dollars) & "." & natural'image(value.cents);
    end function to_string;

    function len (
      constant s : string)
      return integer is
    begin
      return s'length;
    end function len;

    function "=" (
      constant l : string;
      constant r : string)
      return string is
    begin
      return l & r;
    end function "=";

    function to_string (
      constant s : string)
      return string is
    begin
      return s;
    end function to_string;

    impure function inc
      return integer is
      variable ret_val : integer;
    begin
      add(counter, 1);
      get(counter, ret_val);
      return ret_val;
    end function inc;

    procedure set (
      constant value : integer) is
    begin
      set(counter, value);
    end procedure set;

    variable savings, price : cash_t;
    variable all_reports : logger_t;
    variable my_checker : checker_t;
    variable pass, found_errors : boolean;
    variable cnt : integer;

    constant messages : messages_t := ("failed", "FAILED");
    constant use_upper_case : boolean := true;
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

    info("Checks are often used to verify a relation, e.g. a = b.");
    info("check_relation together with the check_preprocessor will do that check while automatically generate the error message.");
    info("It works on any type as long as the relation operator and the to_string function are defined for that type.");
    price := (99, 95);
    savings := (120,00);
    if check_relation(savings > price, "Can't afford it.") then
      info("Buying one.");
      savings := savings - price;
      check_relation(savings > price, "Can't afford another one.");
    end if;

    info("The check preprocessor isn't a full parser so a number of assumption are made to make it work");
    info("   1. The expression given is an actual relation.");
    info("   2. The relation must not contain calls to impure functions.");
    info("   3. Only the relation parameter contains a top-level relational operator.");

    info("This is not a relation but a boolean expression that will fail. However, the preprocessor treats it like an equality and the generated error message will say that left = right = false, i.e. it shouldn't have failed");
    check_relation(false = false and false);

    info("inc and set are two impure functions that increment and set the value of a counter respectively. The inc function returns the counter value after the increment.");
    set(7);
    check_relation(inc = 9, "This will give a confusing error message since the inc function is called twice. First when evaluating the relation and second when printing the value of the left side in the error message.");

    info("One work-around is to extract the impure function call from the relation");
    set(7);
    cnt := inc;
    check_relation(cnt = 9, "Now the error message makes sense.");

    info("in case your relation is an equality between two ""standard"" types you can use check_equal.");
    set(7);
    check_equal(inc, 9, "Also a correct error message.");

    info("""="" has been defined on string to be the same as ""&"". This will confuse the parser. Not a very likely use case!");
    check_relation(msg => string'("Something ") = string'("failed!"), expr => 3 > 5);
    info("Relations not at the top level are safe but still unlikely.");
    check_relation(msg => messages(use_upper_case = true), expr => 3 > 5);

    info("Follow these rules and it tries to handle other tricky things such as embedded comments and strings containing relational operators");
    check_relation(len("""Heart"" => <3") = -- The string contains <, so does
                                            -- this comment
                   12, "Incorrect length of ""<3 message"".");

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

    assert false report "End of example" severity failure;
  end process example_process;

  clk <= not clk after 5 ns;

  status_check: check_true(clk, check_en, status_ok, "Concurrent status check failed.");
end architecture test;
