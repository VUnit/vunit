-- This test suite verifies the check_equal checker.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;
library vunit_lib;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.check_2008p_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.string_ptr_pkg.all;
use vunit_lib.core_pkg.all;
use work.test_support.all;

use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;

entity tb_check_equal_2008p is
  generic (
    runner_cfg : string);
end entity tb_check_equal_2008p;

architecture test_fixture of tb_check_equal_2008p is
begin
  check_equal_runner : process
    variable stat : checker_stat_t;
    variable my_checker : checker_t := new_checker("my_checker");
    variable my_logger : logger_t := get_logger(my_checker);
    variable passed : boolean;
    variable check_result : check_result_t;
    constant default_level : log_level_t := error;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should handle comparison of vectors longer than 32 bits") then
        get_checker_stat(stat);
        check_equal(ufixed'(from_hstring("A5A5A5A5A", 31, -4)), ufixed'(from_hstring("A5A5A5A5A", 31, -4)));
        check_equal(sfixed'(from_hstring("A5A5A5A5A", 31, -4)), sfixed'(from_hstring("A5A5A5A5A", 31, -4)));
        verify_passed_checks(stat, 2);
        verify_failed_checks(stat, 0);

        mock(check_logger);
        check_equal(ufixed'(from_hstring("A5A5A5A5A", 31, -4)), ufixed'(from_hstring("B5A5A5A5A", 31, -4)));
        check_only_log(check_logger, "Equality check failed - Got 10100101101001011010010110100101.1010 (2779096485.625000). Expected 10110101101001011010010110100101.1010 (3047531941.625000).", default_level);

        check_equal(ufixed'(from_hstring("A5A5A5A5A", 31, -4)), 3047531941.625);
        check_only_log(check_logger, "Equality check failed - Got 10100101101001011010010110100101.1010 (2779096485.625000). Expected 3047531941.625000.", default_level);

        check_equal(sfixed'(from_hstring("A5A5A5A5A", 31, -4)), sfixed'(from_hstring("B5A5A5A5A", 31, -4)));
        check_only_log(check_logger, "Equality check failed - Got 10100101101001011010010110100101.1010 (-1515870810.375000). Expected 10110101101001011010010110100101.1010 (-1247435354.375000).", default_level);

        check_equal(sfixed'(from_hstring("A5A5A5A5A", 31, -4)), -1247435354.375);
        check_only_log(check_logger, "Equality check failed - Got 10100101101001011010010110100101.1010 (-1515870810.375000). Expected -1247435354.375000.", default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 2);
        verify_failed_checks(stat, 4);
        reset_checker_stat;


      elsif run("Test should pass on ufixed equal ufixed") then
        get_checker_stat(stat);
        check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)));
        check_equal(passed, ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)));
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)));
        assert_true(passed, "Should return pass = true on passing check");
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)));
        assert_true(check_result.p_is_pass, "Should return check_result.p_is_pass = true on passing check");
        assert_true(check_result.p_checker = default_checker);
        check_equal(to_ufixed(natural'left,30), to_ufixed(natural'left,30));
        check_equal(to_ufixed(natural'right,30), to_ufixed(natural'right,30));
        verify_passed_checks(stat, 6);

        get_checker_stat(my_checker, stat);
        check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)));
        check_equal(my_checker, passed, ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)));
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)));
        assert_true(passed, "Should return pass = true on passing check");
        check_result := check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)));
        assert_true(check_result.p_is_pass, "Should return check_result.p_is_pass = true on passing check");
        assert_true(check_result.p_checker = my_checker);
        verify_passed_checks(my_checker, stat, 4);

      elsif run("Test pass message on ufixed equal ufixed") then
        mock(check_logger);
        check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)));
        check_only_log(check_logger, "Equality check passed - Got 1010.0101 (10.312500).", pass);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)));
        assert_true(
          to_string(check_result.p_msg) = "Equality check passed - Got 1010.0101 (10.312500).",
          "Got: " & to_string(check_result.p_msg)
        );
        assert_true(check_result.p_level = pass);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)), "");
        check_only_log(check_logger, "Got 1010.0101 (10.312500).", pass);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)), "");
        assert_true(to_string(check_result.p_msg) = "Got 1010.0101 (10.312500).");
        assert_true(check_result.p_level = pass);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)), "Checking my data");
        check_only_log(check_logger, "Checking my data - Got 1010.0101 (10.312500).", pass);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)), "Checking my data");
        assert_true(to_string(check_result.p_msg) = "Checking my data - Got 1010.0101 (10.312500).");
        assert_true(check_result.p_level = pass);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)), result("for my data"));
        check_only_log(check_logger, "Equality check passed for my data - Got 1010.0101 (10.312500).", pass);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)), result("for my data"));
        assert_true(to_string(check_result.p_msg) = "Equality check passed for my data - Got 1010.0101 (10.312500).");
        assert_true(check_result.p_level = pass);
        unmock(check_logger);

      elsif run("Test should fail on ufixed not equal ufixed") then
        get_checker_stat(stat);
        mock(check_logger);
        check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)));
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).",
                       default_level);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)));
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)), "");
        check_only_log(check_logger, "Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).", default_level);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)), "");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)), "Checking my data");
        check_only_log(check_logger, "Checking my data - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).", default_level);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)), "Checking my data");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Checking my data - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)), result("for my data"));
        check_only_log(check_logger, "Equality check failed for my data - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).",
                       default_level);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)), result("for my data"));
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed for my data - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(passed, ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).",
                       default_level);

        passed := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).",
                       default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 10);
        reset_checker_stat;

        get_checker_stat(my_checker, stat);
        mock(my_logger);
        check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)));
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).", default_level);
        check_result := check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)));
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = my_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(my_checker, passed, ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).", default_level);

        passed := check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 0101.1010 (5.625000).", default_level);

        unmock(my_logger);
        verify_passed_checks(my_checker, stat, 0);
        verify_failed_checks(my_checker, stat, 4);
        reset_checker_stat(my_checker);

      elsif run("Test that unhandled pass result for ufixed equal ufixed passes") then
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("A5", 3, -4)));
        assert_true(not p_has_unhandled_checks);

      elsif run("Test that unhandled failed result for ufixed equal ufixed fails") then
        check_result := check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), ufixed'(from_hstring("5A", 3, -4)));
        assert_true(p_has_unhandled_checks);
        mock_core_failure;
        test_runner_cleanup(runner);
        check_core_failure("Unhandled checks.");
        unmock_core_failure;
        p_handle(check_result);


      elsif run("Test should pass on ufixed equal real") then
        get_checker_stat(stat);
        check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125);
        check_equal(passed, ufixed'(from_hstring("A5", 3, -4)), 10.3125);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125);
        assert_true(passed, "Should return pass = true on passing check");
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125);
        assert_true(check_result.p_is_pass, "Should return check_result.p_is_pass = true on passing check");
        assert_true(check_result.p_checker = default_checker);
        check_equal(to_ufixed(2.0**(-32),-1, -32), 2.0**(-32));
        check_equal(to_ufixed(natural'right,30), real(natural'right));
        verify_passed_checks(stat, 6);

        get_checker_stat(my_checker, stat);
        check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), 10.3125);
        check_equal(my_checker, passed, ufixed'(from_hstring("A5", 3, -4)), 10.3125);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), 10.3125);
        assert_true(passed, "Should return pass = true on passing check");
        check_result := check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), 10.3125);
        assert_true(check_result.p_is_pass, "Should return check_result.p_is_pass = true on passing check");
        assert_true(check_result.p_checker = my_checker);
        verify_passed_checks(my_checker, stat, 4);

      elsif run("Test pass message on ufixed equal real") then
        mock(check_logger);
        check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125);
        check_only_log(check_logger, "Equality check passed - Got 1010.0101 (10.312500).", pass);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125);
        assert_true(
          to_string(check_result.p_msg) = "Equality check passed - Got 1010.0101 (10.312500).",
          "Got: " & to_string(check_result.p_msg)
        );
        assert_true(check_result.p_level = pass);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125, "");
        check_only_log(check_logger, "Got 1010.0101 (10.312500).", pass);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125, "");
        assert_true(to_string(check_result.p_msg) = "Got 1010.0101 (10.312500).");
        assert_true(check_result.p_level = pass);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125, "Checking my data");
        check_only_log(check_logger, "Checking my data - Got 1010.0101 (10.312500).", pass);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125, "Checking my data");
        assert_true(to_string(check_result.p_msg) = "Checking my data - Got 1010.0101 (10.312500).");
        assert_true(check_result.p_level = pass);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125, result("for my data"));
        check_only_log(check_logger, "Equality check passed for my data - Got 1010.0101 (10.312500).", pass);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125, result("for my data"));
        assert_true(to_string(check_result.p_msg) = "Equality check passed for my data - Got 1010.0101 (10.312500).");
        assert_true(check_result.p_level = pass);
        unmock(check_logger);

      elsif run("Test should fail on ufixed not equal real") then
        get_checker_stat(stat);
        mock(check_logger);
        check_equal(ufixed'(from_hstring("A5", 3, -4)), 5.625);
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 5.625000.",
                       default_level);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), 5.625);
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed - Got 1010.0101 (10.312500). Expected 5.625000.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), 5.625, "");
        check_only_log(check_logger, "Got 1010.0101 (10.312500). Expected 5.625000.", default_level);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), 5.625, "");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Got 1010.0101 (10.312500). Expected 5.625000.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), 5.625, "Checking my data");
        check_only_log(check_logger, "Checking my data - Got 1010.0101 (10.312500). Expected 5.625000.", default_level);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), 5.625, "Checking my data");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Checking my data - Got 1010.0101 (10.312500). Expected 5.625000.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(ufixed'(from_hstring("A5", 3, -4)), 5.625, result("for my data"));
        check_only_log(check_logger, "Equality check failed for my data - Got 1010.0101 (10.312500). Expected 5.625000.",
                       default_level);
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), 5.625, result("for my data"));
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed for my data - Got 1010.0101 (10.312500). Expected 5.625000.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(passed, ufixed'(from_hstring("A5", 3, -4)), 5.625);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 5.625000.",
                       default_level);

        passed := check_equal(ufixed'(from_hstring("A5", 3, -4)), 5.625);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 5.625000.",
                       default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 10);
        reset_checker_stat;

        get_checker_stat(my_checker, stat);
        mock(my_logger);
        check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), 5.625);
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 5.625000.", default_level);
        check_result := check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), 5.625);
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = my_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed - Got 1010.0101 (10.312500). Expected 5.625000.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(my_checker, passed, ufixed'(from_hstring("A5", 3, -4)), 5.625);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 5.625000.", default_level);

        passed := check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), 5.625);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (10.312500). Expected 5.625000.", default_level);

        unmock(my_logger);
        verify_passed_checks(my_checker, stat, 0);
        verify_failed_checks(my_checker, stat, 4);
        reset_checker_stat(my_checker);

      elsif run("Test that unhandled pass result for ufixed equal real passes") then
        check_result := check_equal(ufixed'(from_hstring("A5", 3, -4)), 10.3125);
        assert_true(not p_has_unhandled_checks);

      elsif run("Test that unhandled failed result for ufixed equal real fails") then
        check_result := check_equal(my_checker, ufixed'(from_hstring("A5", 3, -4)), 5.625);
        assert_true(p_has_unhandled_checks);
        mock_core_failure;
        test_runner_cleanup(runner);
        check_core_failure("Unhandled checks.");
        unmock_core_failure;
        p_handle(check_result);


      elsif run("Test should pass on sfixed equal sfixed") then
        get_checker_stat(stat);
        check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)));
        check_equal(passed, sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)));
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)));
        assert_true(passed, "Should return pass = true on passing check");
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)));
        assert_true(check_result.p_is_pass, "Should return check_result.p_is_pass = true on passing check");
        assert_true(check_result.p_checker = default_checker);
        check_equal(to_sfixed(integer'left,31), to_sfixed(integer'left,31));
        check_equal(to_sfixed(integer'right,31), to_sfixed(integer'right,31));
        verify_passed_checks(stat, 6);

        get_checker_stat(my_checker, stat);
        check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)));
        check_equal(my_checker, passed, sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)));
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)));
        assert_true(passed, "Should return pass = true on passing check");
        check_result := check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)));
        assert_true(check_result.p_is_pass, "Should return check_result.p_is_pass = true on passing check");
        assert_true(check_result.p_checker = my_checker);
        verify_passed_checks(my_checker, stat, 4);

      elsif run("Test pass message on sfixed equal sfixed") then
        mock(check_logger);
        check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)));
        check_only_log(check_logger, "Equality check passed - Got 1010.0101 (-5.687500).", pass);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)));
        assert_true(
          to_string(check_result.p_msg) = "Equality check passed - Got 1010.0101 (-5.687500).",
          "Got: " & to_string(check_result.p_msg)
        );
        assert_true(check_result.p_level = pass);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)), "");
        check_only_log(check_logger, "Got 1010.0101 (-5.687500).", pass);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)), "");
        assert_true(to_string(check_result.p_msg) = "Got 1010.0101 (-5.687500).");
        assert_true(check_result.p_level = pass);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)), "Checking my data");
        check_only_log(check_logger, "Checking my data - Got 1010.0101 (-5.687500).", pass);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)), "Checking my data");
        assert_true(to_string(check_result.p_msg) = "Checking my data - Got 1010.0101 (-5.687500).");
        assert_true(check_result.p_level = pass);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)), result("for my data"));
        check_only_log(check_logger, "Equality check passed for my data - Got 1010.0101 (-5.687500).", pass);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)), result("for my data"));
        assert_true(to_string(check_result.p_msg) = "Equality check passed for my data - Got 1010.0101 (-5.687500).");
        assert_true(check_result.p_level = pass);
        unmock(check_logger);

      elsif run("Test should fail on sfixed not equal sfixed") then
        get_checker_stat(stat);
        mock(check_logger);
        check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)));
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).",
                       default_level);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)));
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)), "");
        check_only_log(check_logger, "Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).", default_level);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)), "");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)), "Checking my data");
        check_only_log(check_logger, "Checking my data - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).", default_level);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)), "Checking my data");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Checking my data - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)), result("for my data"));
        check_only_log(check_logger, "Equality check failed for my data - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).",
                       default_level);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)), result("for my data"));
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed for my data - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(passed, sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).",
                       default_level);

        passed := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).",
                       default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 10);
        reset_checker_stat;

        get_checker_stat(my_checker, stat);
        mock(my_logger);
        check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)));
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).", default_level);
        check_result := check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)));
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = my_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(my_checker, passed, sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).", default_level);

        passed := check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected 0101.1010 (5.625000).", default_level);

        unmock(my_logger);
        verify_passed_checks(my_checker, stat, 0);
        verify_failed_checks(my_checker, stat, 4);
        reset_checker_stat(my_checker);

      elsif run("Test that unhandled pass result for sfixed equal sfixed passes") then
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("A5", 3, -4)));
        assert_true(not p_has_unhandled_checks);

      elsif run("Test that unhandled failed result for sfixed equal sfixed fails") then
        check_result := check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), sfixed'(from_hstring("5A", 3, -4)));
        assert_true(p_has_unhandled_checks);
        mock_core_failure;
        test_runner_cleanup(runner);
        check_core_failure("Unhandled checks.");
        unmock_core_failure;
        p_handle(check_result);


      elsif run("Test should pass on sfixed equal real") then
        get_checker_stat(stat);
        check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875);
        check_equal(passed, sfixed'(from_hstring("A5", 3, -4)), -5.6875);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875);
        assert_true(passed, "Should return pass = true on passing check");
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875);
        assert_true(check_result.p_is_pass, "Should return check_result.p_is_pass = true on passing check");
        assert_true(check_result.p_checker = default_checker);
        check_equal(to_sfixed(-2.0**(-32),-1, -32), -2.0**(-32));
        check_equal(to_sfixed(integer'right,31), real(integer'right));
        verify_passed_checks(stat, 6);

        get_checker_stat(my_checker, stat);
        check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), -5.6875);
        check_equal(my_checker, passed, sfixed'(from_hstring("A5", 3, -4)), -5.6875);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), -5.6875);
        assert_true(passed, "Should return pass = true on passing check");
        check_result := check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), -5.6875);
        assert_true(check_result.p_is_pass, "Should return check_result.p_is_pass = true on passing check");
        assert_true(check_result.p_checker = my_checker);
        verify_passed_checks(my_checker, stat, 4);

      elsif run("Test pass message on sfixed equal real") then
        mock(check_logger);
        check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875);
        check_only_log(check_logger, "Equality check passed - Got 1010.0101 (-5.687500).", pass);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875);
        assert_true(
          to_string(check_result.p_msg) = "Equality check passed - Got 1010.0101 (-5.687500).",
          "Got: " & to_string(check_result.p_msg)
        );
        assert_true(check_result.p_level = pass);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875, "");
        check_only_log(check_logger, "Got 1010.0101 (-5.687500).", pass);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875, "");
        assert_true(to_string(check_result.p_msg) = "Got 1010.0101 (-5.687500).");
        assert_true(check_result.p_level = pass);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875, "Checking my data");
        check_only_log(check_logger, "Checking my data - Got 1010.0101 (-5.687500).", pass);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875, "Checking my data");
        assert_true(to_string(check_result.p_msg) = "Checking my data - Got 1010.0101 (-5.687500).");
        assert_true(check_result.p_level = pass);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875, result("for my data"));
        check_only_log(check_logger, "Equality check passed for my data - Got 1010.0101 (-5.687500).", pass);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875, result("for my data"));
        assert_true(to_string(check_result.p_msg) = "Equality check passed for my data - Got 1010.0101 (-5.687500).");
        assert_true(check_result.p_level = pass);
        unmock(check_logger);

      elsif run("Test should fail on sfixed not equal real") then
        get_checker_stat(stat);
        mock(check_logger);
        check_equal(sfixed'(from_hstring("A5", 3, -4)), -7.25);
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected -7.250000.",
                       default_level);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), -7.25);
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed - Got 1010.0101 (-5.687500). Expected -7.250000.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), -7.25, "");
        check_only_log(check_logger, "Got 1010.0101 (-5.687500). Expected -7.250000.", default_level);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), -7.25, "");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Got 1010.0101 (-5.687500). Expected -7.250000.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), -7.25, "Checking my data");
        check_only_log(check_logger, "Checking my data - Got 1010.0101 (-5.687500). Expected -7.250000.", default_level);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), -7.25, "Checking my data");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Checking my data - Got 1010.0101 (-5.687500). Expected -7.250000.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(sfixed'(from_hstring("A5", 3, -4)), -7.25, result("for my data"));
        check_only_log(check_logger, "Equality check failed for my data - Got 1010.0101 (-5.687500). Expected -7.250000.",
                       default_level);
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), -7.25, result("for my data"));
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed for my data - Got 1010.0101 (-5.687500). Expected -7.250000.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(passed, sfixed'(from_hstring("A5", 3, -4)), -7.25);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected -7.250000.",
                       default_level);

        passed := check_equal(sfixed'(from_hstring("A5", 3, -4)), -7.25);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected -7.250000.",
                       default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 10);
        reset_checker_stat;

        get_checker_stat(my_checker, stat);
        mock(my_logger);
        check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), -7.25);
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected -7.250000.", default_level);
        check_result := check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), -7.25);
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = my_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed - Got 1010.0101 (-5.687500). Expected -7.250000.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(my_checker, passed, sfixed'(from_hstring("A5", 3, -4)), -7.25);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected -7.250000.", default_level);

        passed := check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), -7.25);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Equality check failed - Got 1010.0101 (-5.687500). Expected -7.250000.", default_level);

        unmock(my_logger);
        verify_passed_checks(my_checker, stat, 0);
        verify_failed_checks(my_checker, stat, 4);
        reset_checker_stat(my_checker);

      elsif run("Test that unhandled pass result for sfixed equal real passes") then
        check_result := check_equal(sfixed'(from_hstring("A5", 3, -4)), -5.6875);
        assert_true(not p_has_unhandled_checks);

      elsif run("Test that unhandled failed result for sfixed equal real fails") then
        check_result := check_equal(my_checker, sfixed'(from_hstring("A5", 3, -4)), -7.25);
        assert_true(p_has_unhandled_checks);
        mock_core_failure;
        test_runner_cleanup(runner);
        check_core_failure("Unhandled checks.");
        unmock_core_failure;
        p_handle(check_result);

      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;
