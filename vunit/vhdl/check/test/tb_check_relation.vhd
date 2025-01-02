-- This test suite verifies the check_relation checker.
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
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_support.all;

entity tb_check_relation is
  generic (
    runner_cfg : string);
end entity;

architecture test_fixture of tb_check_relation is
begin

  test_runner : process
    type cash_t is record
      dollars : natural;
      cents   : natural range 0 to 99;
    end record cash_t;

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

    function to_string (
      constant value : integer)
      return string is
    begin
      return integer'image(value);
    end function to_string;

    variable passed : boolean;
    variable stat : checker_stat_t;
    variable my_checker : checker_t := new_checker("my_checker");
    variable my_logger : logger_t := get_logger(my_checker);
    constant cash : cash_t := (99,95);
    constant default_level : log_level_t := error;
    variable data : natural;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that a true relation does not generate an error") then
        data := 5;
        get_checker_stat(stat);
        check_relation(data > 3);
        check_relation(passed, data > 3);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_relation(data > 3);
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(stat, 3);

        get_checker_stat(my_checker, stat);
        check_relation(my_checker, data > 3);
        check_relation(my_checker, passed, data > 3);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_relation(my_checker, data > 3);
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(my_checker, stat, 3);

      elsif run("Test pass message") then
        data := 5;
        mock(check_logger);
        check_relation(data > 3);
        check_only_log(check_logger, "Relation check passed - Expected data > 3. Left is 5. Right is 3.", pass);

        check_relation(data > 3, "");
        check_only_log(check_logger, "Expected data > 3. Left is 5. Right is 3.", pass);

        check_relation(data > 3, "Checking my data");
        check_only_log(check_logger, "Checking my data - Expected data > 3. Left is 5. Right is 3.", pass);

        check_relation(data > 3, result("for my data"));
        check_only_log(check_logger, "Relation check passed for my data - Expected data > 3. Left is 5. Right is 3.", pass);
        unmock(check_logger);

      elsif run("Test that all pre VHDL 2008 relational operators are supported") then
        get_checker_stat(stat);
        data := 5;
        mock(check_logger);
        check_relation(data = 3);
        check_only_log(check_logger, "Relation check failed - Expected data = 3. Left is 5. Right is 3.", default_level);

        check_relation(data /= 5);
        check_only_log(check_logger, "Relation check failed - Expected data /= 5. Left is 5. Right is 5.", default_level);

        check_relation(data < 5);
        check_only_log(check_logger, "Relation check failed - Expected data < 5. Left is 5. Right is 5.", default_level);

        check_relation(data <= 4);
        check_only_log(check_logger, "Relation check failed - Expected data <= 4. Left is 5. Right is 4.", default_level);

        check_relation(data > 5);
        check_only_log(check_logger, "Relation check failed - Expected data > 5. Left is 5. Right is 5.", default_level);

        check_relation(data >= 6);
        check_only_log(check_logger, "Relation check failed - Expected data >= 6. Left is 5. Right is 6.", default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 6);
        reset_checker_stat;

      elsif run("Test that a generated message can contain string containing operands") then
        get_checker_stat(stat);
        mock(check_logger);
        check_relation(len("foo") = 4);
        check_only_log(check_logger, "Relation check failed - Expected len(""foo"") = 4. Left is 3. Right is 4.", default_level);

        check_relation(passed, len("foo") = 4);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Relation check failed - Expected len(""foo"") = 4. Left is 3. Right is 4.", default_level);

        passed := check_relation(len("foo") = 4);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Relation check failed - Expected len(""foo"") = 4. Left is 3. Right is 4.", default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 3);
        reset_checker_stat;

        get_checker_stat(my_checker, stat);
        mock(my_logger);
        check_relation(my_checker, len("foo") = 4);
        check_only_log(my_logger, "Relation check failed - Expected len(""foo"") = 4. Left is 3. Right is 4.", default_level);

        check_relation(my_checker, passed, len("foo") = 4);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Relation check failed - Expected len(""foo"") = 4. Left is 3. Right is 4.", default_level);

        passed := check_relation(my_checker, len("foo") = 4);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Relation check failed - Expected len(""foo"") = 4. Left is 3. Right is 4.", default_level);
        unmock(my_logger);
        verify_passed_checks(my_checker, stat, 0);
        verify_failed_checks(my_checker, stat, 3);
        reset_checker_stat(my_checker);

      elsif run("Test that custom types can be used") then
        get_checker_stat(stat);
        mock(check_logger);
        check_relation(cash > cash_t'((100,0)));
        check_only_log(check_logger, "Relation check failed - Expected cash > cash_t'((100,0)). Left is $99.95. Right is $100.0.", default_level);

        check_relation(passed, cash > cash_t'((100,0)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Relation check failed - Expected cash > cash_t'((100,0)). Left is $99.95. Right is $100.0.", default_level);

        passed := check_relation(cash > cash_t'((100,0)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Relation check failed - Expected cash > cash_t'((100,0)). Left is $99.95. Right is $100.0.", default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 3);
        reset_checker_stat;

        get_checker_stat(my_checker, stat);
        mock(my_logger);
        check_relation(my_checker, cash > cash_t'((100,0)));
        check_only_log(my_logger, "Relation check failed - Expected cash > cash_t'((100,0)). Left is $99.95. Right is $100.0.", default_level);

        check_relation(my_checker, passed, cash > cash_t'((100,0)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Relation check failed - Expected cash > cash_t'((100,0)). Left is $99.95. Right is $100.0.", default_level);

        passed := check_relation(my_checker, cash > cash_t'((100,0)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Relation check failed - Expected cash > cash_t'((100,0)). Left is $99.95. Right is $100.0.", default_level);
        unmock(my_logger);
        verify_passed_checks(my_checker, stat, 0);
        verify_failed_checks(my_checker, stat, 3);
        reset_checker_stat(my_checker);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 1 us);

end test_fixture;
