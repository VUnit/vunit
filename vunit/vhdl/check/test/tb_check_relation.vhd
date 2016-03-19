-- This test suite verifies the check_relation checker.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
library vunit_lib;
use vunit_lib.log_types_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_support.all;
use work.test_count.all;

entity tb_check_relation is
  generic (
    runner_cfg : string);
end entity tb_check_relation;

architecture test_fixture of tb_check_relation is
  signal sl_0 : std_logic := '0';
  signal sl_1 : std_logic := '1';
  signal bit_0 : bit := '0';
  signal bit_1 : bit := '1';
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

    variable pass : boolean;
    variable stat : checker_stat_t;
    variable check_relation_checker : checker_t;
    variable cash : cash_t := (99,95);
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that a true relation does not generate an error") then
        get_checker_stat(stat);
        check_relation(5 > 3);
        check_relation(pass, 5 > 3);
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_relation(5 > 3);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(stat, 3);

        get_checker_stat(check_relation_checker, stat);
        check_relation(check_relation_checker, 5 > 3);
        check_relation(check_relation_checker, pass, 5 > 3);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_relation_checker, stat, 2);
      elsif run("Test that generated message is combined with a custom message") then
        check_relation(5 < 3, "Something is wrong.");
        verify_log_call(inc_count, "Relation 5 < 3 failed! Left is 5. Right is 3. Something is wrong.");
        check_relation(pass, 5 < 3, "Something is wrong.");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Relation 5 < 3 failed! Left is 5. Right is 3. Something is wrong.");
        pass := check_relation(5 < 3, "Something is wrong.");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Relation 5 < 3 failed! Left is 5. Right is 3. Something is wrong.");

        check_relation(check_relation_checker, 5 < 3, "Something is wrong.");
        verify_log_call(inc_count, "Relation 5 < 3 failed! Left is 5. Right is 3. Something is wrong.");
        check_relation(check_relation_checker, pass, 5 < 3, "Something is wrong.");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Relation 5 < 3 failed! Left is 5. Right is 3. Something is wrong.");
      elsif run("Test that all pre VHDL 2008 relational operators are supported") then
        check_relation(5 = 3);
        verify_log_call(inc_count, "Relation 5 = 3 failed! Left is 5. Right is 3.");
        check_relation(5 /= 5);
        verify_log_call(inc_count, "Relation 5 /= 5 failed! Left is 5. Right is 5.");
        check_relation(5 < 5);
        verify_log_call(inc_count, "Relation 5 < 5 failed! Left is 5. Right is 5.");
        check_relation(5 <= 4);
        verify_log_call(inc_count, "Relation 5 <= 4 failed! Left is 5. Right is 4.");
        check_relation(5 > 5);
        verify_log_call(inc_count, "Relation 5 > 5 failed! Left is 5. Right is 5.");
        check_relation(4 >= 5);
        verify_log_call(inc_count, "Relation 4 >= 5 failed! Left is 4. Right is 5.");

      elsif run("Test that all matching relational operators are supported") then
        check_relation(sl_1 ?= sl_0);
        verify_log_call(inc_count, "Relation sl_1 ?= sl_0 failed! Left is 1. Right is 0.");
        check_relation(bit_1 ?= bit_0);
        verify_log_call(inc_count, "Relation bit_1 ?= bit_0 failed! Left is 1. Right is 0.");
        check_relation(sl_1 ?/= sl_1);
        verify_log_call(inc_count, "Relation sl_1 ?/= sl_1 failed! Left is 1. Right is 1.");
        check_relation(sl_1 ?< sl_0);
        verify_log_call(inc_count, "Relation sl_1 ?< sl_0 failed! Left is 1. Right is 0.");
        check_relation(sl_1 ?<= sl_0);
        verify_log_call(inc_count, "Relation sl_1 ?<= sl_0 failed! Left is 1. Right is 0.");
        check_relation(sl_0 ?> sl_1);
        verify_log_call(inc_count, "Relation sl_0 ?> sl_1 failed! Left is 0. Right is 1.");
        check_relation(sl_0 ?>= sl_1);
        verify_log_call(inc_count, "Relation sl_0 ?>= sl_1 failed! Left is 0. Right is 1.");

      elsif run("Test that a generated message can contain string containing operands") then
        check_relation(len("foo") = 4);
        verify_log_call(inc_count, "Relation len(""foo"") = 4 failed! Left is 3. Right is 4.");
        check_relation(pass, len("foo") = 4);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Relation len(""foo"") = 4 failed! Left is 3. Right is 4.");
        pass := check_relation(len("foo") = 4);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Relation len(""foo"") = 4 failed! Left is 3. Right is 4.");

        check_relation(check_relation_checker, len("foo") = 4);
        verify_log_call(inc_count, "Relation len(""foo"") = 4 failed! Left is 3. Right is 4.");
        check_relation(check_relation_checker, pass, len("foo") = 4);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Relation len(""foo"") = 4 failed! Left is 3. Right is 4.");
      elsif run("Test that custom types can be used") then
        check_relation(cash > cash_t'((100,0)));
        verify_log_call(inc_count, "Relation cash > cash_t'((100,0)) failed! Left is $99.95. Right is $100.0.");
        check_relation(pass, cash > cash_t'((100,0)));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Relation cash > cash_t'((100,0)) failed! Left is $99.95. Right is $100.0.");
        pass := check_relation(cash > cash_t'((100,0)));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Relation cash > cash_t'((100,0)) failed! Left is $99.95. Right is $100.0.");

        check_relation(check_relation_checker, cash > cash_t'((100,0)));
        verify_log_call(inc_count, "Relation cash > cash_t'((100,0)) failed! Left is $99.95. Right is $100.0.");
        check_relation(check_relation_checker, pass, cash > cash_t'((100,0)));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Relation cash > cash_t'((100,0)) failed! Left is $99.95. Right is $100.0.");
      end if;
    end loop;

    get_and_print_test_result(stat);
    test_runner_cleanup(runner, stat);
    wait;
  end process;

  test_runner_watchdog(runner, 1 us);

end test_fixture;

-- vunit_pragma run_all_in_same_sim
