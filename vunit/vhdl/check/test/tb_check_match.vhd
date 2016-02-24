-- This test suite verifies the check_equal checker.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
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

entity tb_check_match is
  generic (
    runner_cfg : string);
end entity tb_check_match;

architecture test_fixture of tb_check_match is
begin
  check_match_runner : process
    variable stat : checker_stat_t;
    variable check_match_checker : checker_t;
    variable pass : boolean;
    constant pass_level : log_level_t := debug_low2;
  begin
    checker_init(check_match_checker);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should pass on unsigned matching unsigned") then
        get_checker_stat(stat);
        check_match(unsigned'(X"A5"), unsigned'(X"A5"));
        check_match(unsigned'("1010----"), unsigned'(X"A5"));
        check_match(unsigned'(X"A5"), unsigned'("1010----"));
        check_match(unsigned'("1010----"), unsigned'("1010----"));
        check_match(pass, unsigned'(X"A5"), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_match(unsigned'(X"A5"), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(stat, 6);

        get_checker_stat(check_match_checker, stat);
        check_match(check_match_checker, unsigned'(X"A5"), unsigned'(X"A5"));
        check_match(check_match_checker, pass, unsigned'(X"A5"), unsigned'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_match_checker,stat, 2);
        verify_num_of_log_calls(get_count);
      elsif run("Test pass message for unsigned matching unsigned") then
        enable_pass_msg;
        check_match(unsigned'(X"A5"), unsigned'(X"A5"));
        verify_log_call(inc_count, "Match check passed - Got 1010_0101 (165). Expected 1010_0101 (165).", pass_level);
        check_match(unsigned'("1010----"), unsigned'(X"A5"), "");
        verify_log_call(inc_count, "Got 1010_---- (NaN). Expected 1010_0101 (165).", pass_level);
        check_match(unsigned'(X"A5"), unsigned'("1010----"), "Checking my data");
        verify_log_call(inc_count, "Checking my data - Got 1010_0101 (165). Expected 1010_---- (NaN).", pass_level);
        check_match(unsigned'("1010----"), unsigned'("1010----"), result("for my data"));
        verify_log_call(inc_count, "Match check passed for my data - Got 1010_---- (NaN). Expected 1010_---- (NaN).", pass_level);
        disable_pass_msg;
      elsif run("Test should fail on unsigned not matching unsigned") then
        check_match(unsigned'(X"A5"), unsigned'("0101----"));
        verify_log_call(inc_count, "Match check failed - Got 1010_0101 (165). Expected 0101_---- (NaN).");
        check_match(unsigned'(X"A5"), unsigned'("0101----"), "");
        verify_log_call(inc_count, "Got 1010_0101 (165). Expected 0101_---- (NaN).");
        check_match(pass, unsigned'(X"A5"), unsigned'(X"5A"), "Checking my data");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Checking my data - Got 1010_0101 (165). Expected 0101_1010 (90).");
        pass := check_match(unsigned'(X"A5"), unsigned'(X"5A"), result("for my data"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Match check failed for my data - Got 1010_0101 (165). Expected 0101_1010 (90).");

        check_match(check_match_checker, unsigned'(X"A5"), unsigned'(X"5A"));
        verify_log_call(inc_count, "Match check failed - Got 1010_0101 (165). Expected 0101_1010 (90).");
        check_match(check_match_checker, pass, unsigned'(X"A5"), unsigned'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Match check failed - Got 1010_0101 (165). Expected 0101_1010 (90).");
      elsif run("Test should pass on std_logic_vector matching std_logic_vector") then
        get_checker_stat(stat);
        check_match(std_logic_vector'(X"A5"), std_logic_vector'(X"A5"));
        check_match(std_logic_vector'("1010----"), std_logic_vector'(X"A5"));
        check_match(std_logic_vector'(X"A5"), std_logic_vector'("1010----"));
        check_match(std_logic_vector'("1010----"), std_logic_vector'("1010----"));
        check_match(pass, std_logic_vector'(X"A5"), std_logic_vector'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_match(std_logic_vector'(X"A5"), std_logic_vector'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(stat, 6);

        get_checker_stat(check_match_checker, stat);
        check_match(check_match_checker, std_logic_vector'(X"A5"), std_logic_vector'(X"A5"));
        check_match(check_match_checker, pass, std_logic_vector'(X"A5"), std_logic_vector'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_match_checker,stat, 2);
        verify_num_of_log_calls(get_count);
      elsif run("Test pass message for std_logic_vector matching std_logic_vector") then
        enable_pass_msg;
        check_match(std_logic_vector'(X"A5"), std_logic_vector'(X"A5"));
        verify_log_call(inc_count, "Match check passed - Got 1010_0101 (165). Expected 1010_0101 (165).", pass_level);
        check_match(std_logic_vector'("1010----"), std_logic_vector'(X"A5"), "");
        verify_log_call(inc_count, "Got 1010_---- (NaN). Expected 1010_0101 (165).", pass_level);
        check_match(std_logic_vector'(X"A5"), std_logic_vector'("1010----"), "Checking my data");
        verify_log_call(inc_count, "Checking my data - Got 1010_0101 (165). Expected 1010_---- (NaN).", pass_level);
        check_match(std_logic_vector'("1010----"), std_logic_vector'("1010----"), result("for my data"));
        verify_log_call(inc_count, "Match check passed for my data - Got 1010_---- (NaN). Expected 1010_---- (NaN).", pass_level);
        disable_pass_msg;
      elsif run("Test should fail on std_logic_vector not matching std_logic_vector") then
        check_match(std_logic_vector'(X"A5"), std_logic_vector'("0101----"));
        verify_log_call(inc_count, "Match check failed - Got 1010_0101 (165). Expected 0101_---- (NaN).");
        check_match(std_logic_vector'(X"A5"), std_logic_vector'("0101----"), "");
        verify_log_call(inc_count, "Got 1010_0101 (165). Expected 0101_---- (NaN).");
        check_match(pass, std_logic_vector'(X"A5"), std_logic_vector'(X"5A"), "Checking my data");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Checking my data - Got 1010_0101 (165). Expected 0101_1010 (90).");
        pass := check_match(std_logic_vector'(X"A5"), std_logic_vector'(X"5A"), result("for my data"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Match check failed for my data - Got 1010_0101 (165). Expected 0101_1010 (90).");

        check_match(check_match_checker, std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));
        verify_log_call(inc_count, "Match check failed - Got 1010_0101 (165). Expected 0101_1010 (90).");
        check_match(check_match_checker, pass, std_logic_vector'(X"A5"), std_logic_vector'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Match check failed - Got 1010_0101 (165). Expected 0101_1010 (90).");
      elsif run("Test should pass on signed matching signed") then
        get_checker_stat(stat);
        check_match(signed'(X"A5"), signed'(X"A5"));
        check_match(signed'("1010----"), signed'(X"A5"));
        check_match(signed'(X"A5"), signed'("1010----"));
        check_match(signed'("1010----"), signed'("1010----"));
        check_match(pass, signed'(X"A5"), signed'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_match(signed'(X"A5"), signed'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(stat, 6);

        get_checker_stat(check_match_checker, stat);
        check_match(check_match_checker, signed'(X"A5"), signed'(X"A5"));
        check_match(check_match_checker, pass, signed'(X"A5"), signed'(X"A5"));
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_match_checker,stat, 2);
        verify_num_of_log_calls(get_count);
      elsif run("Test pass message for signed matching signed") then
        enable_pass_msg;
        check_match(signed'(X"A5"), signed'(X"A5"));
        verify_log_call(inc_count, "Match check passed - Got 1010_0101 (-91). Expected 1010_0101 (-91).", pass_level);
        check_match(signed'("1010----"), signed'(X"A5"), "");
        verify_log_call(inc_count, "Got 1010_---- (NaN). Expected 1010_0101 (-91).", pass_level);
        check_match(signed'(X"A5"), signed'("1010----"), "Checking my data");
        verify_log_call(inc_count, "Checking my data - Got 1010_0101 (-91). Expected 1010_---- (NaN).", pass_level);
        check_match(signed'("1010----"), signed'("1010----"), result("for my data"));
        verify_log_call(inc_count, "Match check passed for my data - Got 1010_---- (NaN). Expected 1010_---- (NaN).", pass_level);
        disable_pass_msg;
      elsif run("Test should fail on signed not matching signed") then
        check_match(signed'(X"A5"), signed'("0101----"));
        verify_log_call(inc_count, "Match check failed - Got 1010_0101 (-91). Expected 0101_---- (NaN).");
        check_match(signed'(X"A5"), signed'("0101----"), "");
        verify_log_call(inc_count, "Got 1010_0101 (-91). Expected 0101_---- (NaN).");
        check_match(pass, signed'(X"A5"), signed'(X"5A"), "Checking my data");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Checking my data - Got 1010_0101 (-91). Expected 0101_1010 (90).");
        pass := check_match(signed'(X"A5"), signed'(X"5A"), result("for my data"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Match check failed for my data - Got 1010_0101 (-91). Expected 0101_1010 (90).");

        check_match(check_match_checker, signed'(X"A5"), signed'(X"5A"));
        verify_log_call(inc_count, "Match check failed - Got 1010_0101 (-91). Expected 0101_1010 (90).");
        check_match(check_match_checker, pass, signed'(X"A5"), signed'(X"5A"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Match check failed - Got 1010_0101 (-91). Expected 0101_1010 (90).");
      elsif run("Test should pass on std_logic matching std_logic") then
        get_checker_stat(stat);
        check_match(std_logic'('1'), '1');
        check_match('-', '1');
        check_match(std_logic'('1'), '-');
        check_match('-', '-');
        check_match(pass, std_logic'('1'), '1');
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_match(std_logic'('1'), '1');
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(stat, 6);

        get_checker_stat(check_match_checker, stat);
        check_match(check_match_checker, std_logic'('1'), '1');
        check_match(check_match_checker, pass, std_logic'('1'), '1');
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_match_checker,stat, 2);
        verify_num_of_log_calls(get_count);
      elsif run("Test pass message for std_logic matching std_logic") then
        enable_pass_msg;
        check_match(std_logic'('1'), '1');
        verify_log_call(inc_count, "Match check passed - Got 1. Expected 1.", pass_level);
        check_match('-', '1', "");
        verify_log_call(inc_count, "Got -. Expected 1.", pass_level);
        check_match(std_logic'('1'), '-', "Checking my data");
        verify_log_call(inc_count, "Checking my data - Got 1. Expected -.", pass_level);
        check_match('-', '-', result("for my data"));
        verify_log_call(inc_count, "Match check passed for my data - Got -. Expected -.", pass_level);
        disable_pass_msg;
      elsif run("Test should fail on std_logic not matching std_logic") then
        check_match(std_logic'('1'), '0');
        verify_log_call(inc_count, "Match check failed - Got 1. Expected 0.");
        check_match(std_logic'('1'), '0', "");
        verify_log_call(inc_count, "Got 1. Expected 0.");
        check_match(pass, std_logic'('1'), '0', "Checking my data");
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Checking my data - Got 1. Expected 0.");
        pass := check_match(std_logic'('1'), '0', result("for my data"));
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Match check failed for my data - Got 1. Expected 0.");

        check_match(check_match_checker, std_logic'('1'), '0');
        verify_log_call(inc_count, "Match check failed - Got 1. Expected 0.");
        check_match(check_match_checker, pass, std_logic'('1'), '0');
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Match check failed - Got 1. Expected 0.");
      end if;
    end loop;

    reset_checker_stat;
    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;

-- vunit_pragma run_all_in_same_sim
