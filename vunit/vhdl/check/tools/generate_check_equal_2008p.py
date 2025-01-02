# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from string import Template
from vunit.vhdl.check.tools.generate_check_equal import replace_region

api_template = """  procedure check_equal(
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  impure function check_equal(
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t;

  impure function check_equal(
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t;

"""

impl_template = """  procedure check_equal(
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & $got_str & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & $got_str & ". " &
          "Expected " & $expected_str & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & $got_str & ".",
      std_fail_ctx => "Got " & $got_str & ". Expected " & $expected_str & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


"""

test_template = """\

      elsif run("Test should pass on $left_type equal $right_type") then
        get_checker_stat(stat);
        check_equal($left_pass, $right_pass);
        check_equal(passed, $left_pass, $right_pass);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_equal($left_pass, $right_pass);
        assert_true(passed, "Should return pass = true on passing check");
        check_result := check_equal($left_pass, $right_pass);
        assert_true(check_result.p_is_pass, "Should return check_result.p_is_pass = true on passing check");
        assert_true(check_result.p_checker = default_checker);
        check_equal($left_min, $right_min);
        check_equal($left_max, $right_max);
        verify_passed_checks(stat, 6);

        get_checker_stat(my_checker, stat);
        check_equal(my_checker, $left_pass, $right_pass);
        check_equal(my_checker, passed, $left_pass, $right_pass);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_equal(my_checker, $left_pass, $right_pass);
        assert_true(passed, "Should return pass = true on passing check");
        check_result := check_equal(my_checker, $left_pass, $right_pass);
        assert_true(check_result.p_is_pass, "Should return check_result.p_is_pass = true on passing check");
        assert_true(check_result.p_checker = my_checker);
        verify_passed_checks(my_checker, stat, 4);

      elsif run("Test pass message on $left_type equal $right_type") then
        mock(check_logger);
        check_equal($left_pass, $right_pass);
        check_only_log(check_logger, "Equality check passed - Got $left_pass_str.", pass);
        check_result := check_equal($left_pass, $right_pass);
        assert_true(
          to_string(check_result.p_msg) = "Equality check passed - Got $left_pass_str.",
          "Got: " & to_string(check_result.p_msg)
        );
        assert_true(check_result.p_level = pass);

        check_equal($left_pass, $right_pass, "");
        check_only_log(check_logger, "Got $left_pass_str.", pass);
        check_result := check_equal($left_pass, $right_pass, "");
        assert_true(to_string(check_result.p_msg) = "Got $left_pass_str.");
        assert_true(check_result.p_level = pass);

        check_equal($left_pass, $right_pass, "Checking my data");
        check_only_log(check_logger, "Checking my data - Got $left_pass_str.", pass);
        check_result := check_equal($left_pass, $right_pass, "Checking my data");
        assert_true(to_string(check_result.p_msg) = "Checking my data - Got $left_pass_str.");
        assert_true(check_result.p_level = pass);

        check_equal($left_pass, $right_pass, result("for my data"));
        check_only_log(check_logger, "Equality check passed for my data - Got $left_pass_str.", pass);
        check_result := check_equal($left_pass, $right_pass, result("for my data"));
        assert_true(to_string(check_result.p_msg) = "Equality check passed for my data - Got $left_pass_str.");
        assert_true(check_result.p_level = pass);
        unmock(check_logger);

      elsif run("Test should fail on $left_type not equal $right_type") then
        get_checker_stat(stat);
        mock(check_logger);
        check_equal($left_pass, $right_fail);
        check_only_log(check_logger, "Equality check failed - Got $left_pass_str. Expected $fail_str.",
                       default_level);
        check_result := check_equal($left_pass, $right_fail);
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed - Got $left_pass_str. Expected $fail_str.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal($left_pass, $right_fail, "");
        check_only_log(check_logger, "Got $left_pass_str. Expected $fail_str.", default_level);
        check_result := check_equal($left_pass, $right_fail, "");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Got $left_pass_str. Expected $fail_str.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal($left_pass, $right_fail, "Checking my data");
        check_only_log(check_logger, "Checking my data - Got $left_pass_str. Expected $fail_str.", default_level);
        check_result := check_equal($left_pass, $right_fail, "Checking my data");
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Checking my data - Got $left_pass_str. Expected $fail_str.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal($left_pass, $right_fail, result("for my data"));
        check_only_log(check_logger, "Equality check failed for my data - Got $left_pass_str. Expected $fail_str.",
                       default_level);
        check_result := check_equal($left_pass, $right_fail, result("for my data"));
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = default_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed for my data - Got $left_pass_str. Expected $fail_str.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(passed, $left_pass, $right_fail);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Equality check failed - Got $left_pass_str. Expected $fail_str.",
                       default_level);

        passed := check_equal($left_pass, $right_fail);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Equality check failed - Got $left_pass_str. Expected $fail_str.",
                       default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 10);
        reset_checker_stat;

        get_checker_stat(my_checker, stat);
        mock(my_logger);
        check_equal(my_checker, $left_pass, $right_fail);
        check_only_log(my_logger, "Equality check failed - Got $left_pass_str. Expected $fail_str.", default_level);
        check_result := check_equal(my_checker, $left_pass, $right_fail);
        assert_true(not check_result.p_is_pass);
        assert_true(check_result.p_checker = my_checker);
        assert_true(to_string(check_result.p_msg) = "Equality check failed - Got $left_pass_str. Expected $fail_str.");
        assert_true(check_result.p_level = default_level);
        p_handle(check_result);

        check_equal(my_checker, passed, $left_pass, $right_fail);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Equality check failed - Got $left_pass_str. Expected $fail_str.", default_level);

        passed := check_equal(my_checker, $left_pass, $right_fail);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Equality check failed - Got $left_pass_str. Expected $fail_str.", default_level);

        unmock(my_logger);
        verify_passed_checks(my_checker, stat, 0);
        verify_failed_checks(my_checker, stat, 4);
        reset_checker_stat(my_checker);

      elsif run("Test that unhandled pass result for $left_type equal $right_type passes") then
        check_result := check_equal($left_pass, $right_pass);
        assert_true(not p_has_unhandled_checks);

      elsif run("Test that unhandled failed result for $left_type equal $right_type fails") then
        check_result := check_equal(my_checker, $left_pass, $right_fail);
        assert_true(p_has_unhandled_checks);
        mock_core_failure;
        test_runner_cleanup(runner);
        check_core_failure("Unhandled checks.");
        unmock_core_failure;
        p_handle(check_result);

"""

combinations = [
    (
        "ufixed",
        "ufixed",
        """ufixed'(from_hstring("A5", 3, -4))""",
        """ufixed'(from_hstring("A5", 3, -4))""",
        "to_ufixed(natural'left,30)",
        "to_ufixed(natural'left,30)",
        "to_ufixed(natural'right,30)",
        "to_ufixed(natural'right,30)",
        """ufixed'(from_hstring("5A", 3, -4))""",
        "1010.0101 (10.312500)",
        "1010.0101 (10.312500)",
        "0101.1010 (5.625000)",
    ),
    (
        "ufixed",
        "real",
        """ufixed'(from_hstring("A5", 3, -4))""",
        "10.3125",
        "to_ufixed(2.0**(-32),-1, -32)",
        "2.0**(-32)",
        "to_ufixed(natural'right,30)",
        "real(natural'right)",
        "5.625",
        "1010.0101 (10.312500)",
        "10.312500",
        "5.625000",
    ),
    (
        "sfixed",
        "sfixed",
        """sfixed'(from_hstring("A5", 3, -4))""",
        """sfixed'(from_hstring("A5", 3, -4))""",
        "to_sfixed(integer'left,31)",
        "to_sfixed(integer'left,31)",
        "to_sfixed(integer'right,31)",
        "to_sfixed(integer'right,31)",
        """sfixed'(from_hstring("5A", 3, -4))""",
        "1010.0101 (-5.687500)",
        "1010.0101 (-5.687500)",
        "0101.1010 (5.625000)",
    ),
    (
        "sfixed",
        "real",
        """sfixed'(from_hstring("A5", 3, -4))""",
        "-5.6875",
        "to_sfixed(-2.0**(-32),-1, -32)",
        "-2.0**(-32)",
        "to_sfixed(integer'right,31)",
        "real(integer'right)",
        "-7.25",
        "1010.0101 (-5.687500)",
        "1010.0101 (-5.687500)",
        "-7.250000",
    ),
]


def generate_api():
    api = ""
    for c in combinations:
        t = Template(api_template)
        api += t.substitute(got_type=c[0], expected_type=c[1])
    return api


def generate_impl():
    impl = ""
    for c in combinations:
        t = Template(impl_template)
        got_str = 'to_string(got) & " (" & to_string(to_real(got), "%f") & ")"'
        if c[1] in ["ufixed", "sfixed"]:
            expected_str = 'to_string(expected) & " (" & to_string(to_real(expected), "%f") & ")"'
        else:
            expected_str = 'to_string(expected, "%f")'
        impl += t.substitute(
            got_type=c[0],
            expected_type=c[1],
            got_str=got_str,
            expected_str=expected_str,
        )
    return impl


def generate_test():
    test = """\
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
        check_only_log(check_logger, "\
Equality check failed - Got 10100101101001011010010110100101.1010 (2779096485.625000). \
Expected 10110101101001011010010110100101.1010 (3047531941.625000).", default_level);

        check_equal(ufixed'(from_hstring("A5A5A5A5A", 31, -4)), 3047531941.625);
        check_only_log(check_logger, "\
Equality check failed - Got 10100101101001011010010110100101.1010 (2779096485.625000). \
Expected 3047531941.625000.", default_level);

        check_equal(sfixed'(from_hstring("A5A5A5A5A", 31, -4)), sfixed'(from_hstring("B5A5A5A5A", 31, -4)));
        check_only_log(check_logger, "\
Equality check failed - Got 10100101101001011010010110100101.1010 (-1515870810.375000). \
Expected 10110101101001011010010110100101.1010 (-1247435354.375000).", default_level);

        check_equal(sfixed'(from_hstring("A5A5A5A5A", 31, -4)), -1247435354.375);
        check_only_log(check_logger, "\
Equality check failed - Got 10100101101001011010010110100101.1010 (-1515870810.375000). \
Expected -1247435354.375000.", default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 2);
        verify_failed_checks(stat, 4);
        reset_checker_stat;

"""

    for c in combinations:
        t = Template(test_template)
        test += t.substitute(
            left_type=c[0],
            right_type=c[1],
            left_pass=c[2],
            right_pass=c[3],
            left_min=c[4],
            right_min=c[5],
            left_max=c[6],
            right_max=c[7],
            right_fail=c[8],
            left_pass_str=c[9],
            right_pass_str=c[10],
            fail_str=c[11],
        )

    test += """\
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;
"""
    return test


def main():
    replace_region(
        "check_equal",
        str(Path(__file__).parent.parent / "src" / "check_api-2008p.vhd"),
        generate_api(),
    )
    replace_region(
        "check_equal",
        str(Path(__file__).parent.parent / "src" / "check-2008p.vhd"),
        generate_impl(),
    )
    with (Path(__file__).parent.parent / "test" / "tb_check_equal-2008p.vhd").open("wb") as fptr:
        fptr.write(generate_test().encode())


if __name__ == "__main__":
    main()
