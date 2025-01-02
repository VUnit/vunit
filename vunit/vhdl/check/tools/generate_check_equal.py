# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from string import Template

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
        "unsigned",
        "unsigned",
        """unsigned'(X"A5")""",
        """unsigned'(X"A5")""",
        "to_unsigned(natural'left,31)",
        "to_unsigned(natural'left,31)",
        "to_unsigned(natural'right,31)",
        "to_unsigned(natural'right,31)",
        """unsigned'(X"5A")""",
        "1010_0101 (165)",
        "1010_0101 (165)",
        "0101_1010 (90)",
    ),
    (
        "unsigned",
        "natural",
        """unsigned'(X"A5")""",
        "natural'(165)",
        "to_unsigned(natural'left,31)",
        "natural'left",
        "to_unsigned(natural'right,31)",
        "natural'right",
        "natural'(90)",
        "1010_0101 (165)",
        "165 (1010_0101)",
        "90 (0101_1010)",
    ),
    (
        "natural",
        "unsigned",
        "natural'(165)",
        """unsigned'(X"A5")""",
        "natural'left",
        "to_unsigned(natural'left,31)",
        "natural'right",
        "to_unsigned(natural'right,31)",
        """unsigned'(X"5A")""",
        "165 (1010_0101)",
        "1010_0101 (165)",
        "0101_1010 (90)",
    ),
    (
        "unsigned",
        "std_logic_vector",
        """unsigned'(X"A5")""",
        """std_logic_vector'(X"A5")""",
        "to_unsigned(natural'left,31)",
        "std_logic_vector(to_unsigned(natural'left,31))",
        "to_unsigned(natural'right,31)",
        "std_logic_vector(to_unsigned(natural'right,31))",
        """std_logic_vector'(X"5A")""",
        "1010_0101 (165)",
        "1010_0101 (165)",
        "0101_1010 (90)",
    ),
    (
        "std_logic_vector",
        "unsigned",
        """std_logic_vector'(X"A5")""",
        """unsigned'(X"A5")""",
        "std_logic_vector(to_unsigned(natural'left,31))",
        "to_unsigned(natural'left,31)",
        "std_logic_vector(to_unsigned(natural'right,31))",
        "to_unsigned(natural'right,31)",
        """unsigned'(X"5A")""",
        "1010_0101 (165)",
        "1010_0101 (165)",
        "0101_1010 (90)",
    ),
    (
        "std_logic_vector",
        "std_logic_vector",
        """std_logic_vector'(X"A5")""",
        """std_logic_vector'(X"A5")""",
        "std_logic_vector(to_unsigned(natural'left,31))",
        "std_logic_vector(to_unsigned(natural'left,31))",
        "std_logic_vector(to_unsigned(natural'right,31))",
        "std_logic_vector(to_unsigned(natural'right,31))",
        """std_logic_vector'(X"5A")""",
        "1010_0101 (165)",
        "1010_0101 (165)",
        "0101_1010 (90)",
    ),
    (
        "std_logic_vector",
        "natural",
        """std_logic_vector'(X"A5")""",
        "natural'(165)",
        "std_logic_vector(to_unsigned(natural'left,31))",
        "natural'left",
        "std_logic_vector(to_unsigned(natural'right,31))",
        "natural'right",
        "natural'(90)",
        "1010_0101 (165)",
        "165 (1010_0101)",
        "90 (0101_1010)",
    ),
    (
        "natural",
        "std_logic_vector",
        "natural'(165)",
        """std_logic_vector'(X"A5")""",
        "natural'left",
        "std_logic_vector(to_unsigned(natural'left,31))",
        "natural'right",
        "std_logic_vector(to_unsigned(natural'right,31))",
        """std_logic_vector'(X"5A")""",
        "165 (1010_0101)",
        "1010_0101 (165)",
        "0101_1010 (90)",
    ),
    (
        "signed",
        "signed",
        """signed'(X"A5")""",
        """signed'(X"A5")""",
        "to_signed(integer'left,32)",
        "to_signed(integer'left,32)",
        "to_signed(integer'right,32)",
        "to_signed(integer'right,32)",
        """signed'(X"5A")""",
        "1010_0101 (-91)",
        "1010_0101 (-91)",
        "0101_1010 (90)",
    ),
    (
        "signed",
        "integer",
        """signed'(X"A5")""",
        "integer'(-91)",
        "to_signed(integer'left,32)",
        "integer'left",
        "to_signed(integer'right,32)",
        "integer'right",
        "integer'(90)",
        "1010_0101 (-91)",
        "-91 (1010_0101)",
        "90 (0101_1010)",
    ),
    (
        "integer",
        "signed",
        "integer'(-91)",
        """signed'(X"A5")""",
        "integer'left",
        "to_signed(integer'left,32)",
        "integer'right",
        "to_signed(integer'right,32)",
        """signed'(X"5A")""",
        "-91 (1010_0101)",
        "1010_0101 (-91)",
        "0101_1010 (90)",
    ),
    (
        "integer",
        "integer",
        "integer'(-91)",
        "integer'(-91)",
        "integer'left",
        "integer'left",
        "integer'right",
        "integer'right",
        "integer'(90)",
        "-91",
        "-91",
        "90",
    ),
    (
        "std_logic",
        "std_logic",
        "std_logic'('1')",
        "std_logic'('1')",
        "std_logic'('0')",
        "std_logic'('0')",
        "std_logic'('1')",
        "std_logic'('1')",
        "std_logic'('0')",
        "1",
        "1",
        "0",
    ),
    (
        "std_logic",
        "boolean",
        "std_logic'('1')",
        "true",
        "std_logic'('0')",
        "false",
        "std_logic'('1')",
        "true",
        "false",
        "1",
        "true",
        "false",
    ),
    (
        "boolean",
        "std_logic",
        "true",
        "'1'",
        "false",
        "'0'",
        "true",
        "'1'",
        "'0'",
        "true",
        "1",
        "0",
    ),
    (
        "boolean",
        "boolean",
        "true",
        "true",
        "false",
        "false",
        "true",
        "true",
        "false",
        "true",
        "true",
        "false",
    ),
    (
        "string",
        "string",
        """string'("test")""",
        """string'("test")""",
        """string'("")""",
        """string'("")""",
        """string'("autogenerated test for type with no max value")""",
        """string'("autogenerated test for type with no max value")""",
        """string'("tests")""",
        "test",
        "test",
        "tests",
    ),
    (
        "character",
        "character",
        "character'('x')",
        "character'('x')",
        "character'val(0)",
        "character'val(0)",
        "character'val(255)",
        "character'val(255)",
        "character'('y')",
        "x",
        "x",
        "y",
    ),
    (
        "time",
        "time",
        "time'(-91 ns)",
        "time'(-91 ns)",
        "time'left",
        "time'left",
        "time'right",
        "time'right",
        "time'(90 ns)",
        '" & time\'image(-91 ns) & "',
        '" & time\'image(-91 ns) & "',
        '" & time\'image(90 ns) & "',
    ),
]


def generate_api():
    api = ""
    for c in combinations:
        t = Template(api_template)
        api += t.substitute(got_type=c[0], expected_type=c[1])
    return api


def dual_format(base_type, got_or_expected):
    expected_or_got = "expected" if got_or_expected == "got" else "got"

    if base_type in ["unsigned", "signed", "std_logic_vector"]:
        return 'to_nibble_string(%s) & " (" & ' % got_or_expected + "to_integer_string(%s) & " % got_or_expected + '")"'

    return (
        'to_string(%s) & " (" & ' % got_or_expected
        + "to_nibble_string(to_sufficient_%s(%s, %s'length)) & "
        % (
            ("signed" if base_type == "integer" else "unsigned"),
            got_or_expected,
            expected_or_got,
        )
        + '")"'
    )


def generate_impl():
    impl = ""
    for c in combinations:
        t = Template(impl_template)
        if (c[0] in ["unsigned", "signed", "std_logic_vector"]) or (c[1] in ["unsigned", "signed", "std_logic_vector"]):
            got_str = dual_format(c[0], "got")
            expected_str = dual_format(c[1], "expected")
        else:
            got_str = "to_string(got)"
            expected_str = "to_string(expected)"
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
library vunit_lib;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.string_ptr_pkg.all;
use vunit_lib.core_pkg.all;
use work.test_support.all;

use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;

entity tb_check_equal is
  generic (
    runner_cfg : string);
end entity tb_check_equal;

architecture test_fixture of tb_check_equal is
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
        check_equal(unsigned'(X"A5A5A5A5A"), unsigned'(X"A5A5A5A5A"));
        check_equal(std_logic_vector'(X"A5A5A5A5A"), unsigned'(X"A5A5A5A5A"));
        check_equal(unsigned'(X"A5A5A5A5A"), std_logic_vector'(X"A5A5A5A5A"));
        check_equal(std_logic_vector'(X"A5A5A5A5A"), std_logic_vector'(X"A5A5A5A5A"));
        verify_passed_checks(stat, 4);
        verify_failed_checks(stat, 0);

        mock(check_logger);
        check_equal(unsigned'(X"A5A5A5A5A"), unsigned'(X"B5A5A5A5A"));
        check_only_log(check_logger, "\
Equality check failed - Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). \
Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).", default_level);

        check_equal(std_logic_vector'(X"A5A5A5A5A"), unsigned'(X"B5A5A5A5A"));
        check_only_log(check_logger, "\
Equality check failed - Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). \
Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).", default_level);

        check_equal(unsigned'(X"A5A5A5A5A"), std_logic_vector'(X"B5A5A5A5A"));
        check_only_log(check_logger, "\
Equality check failed - Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). \
Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).", default_level);

        check_equal(std_logic_vector'(X"A5A5A5A5A"), std_logic_vector'(X"B5A5A5A5A"));
        check_only_log(check_logger, "\
Equality check failed - Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). \
Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).", default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 4);
        verify_failed_checks(stat, 4);
        reset_checker_stat;

      elsif run("Test print full integer vector when fail on comparison with to short vector") then
        get_checker_stat(stat);
        mock(check_logger);
        check_equal(unsigned'(X"A5"), natural'(256));
        check_only_log(check_logger, "Equality check failed - Got 1010_0101 (165). Expected 256 (1_0000_0000).",
                       default_level);

        check_equal(natural'(256), unsigned'(X"A5"));
        check_only_log(check_logger, "Equality check failed - Got 256 (1_0000_0000). Expected 1010_0101 (165).",
                       default_level);

        check_equal(unsigned'(X"A5"), natural'(2147483647));
        check_only_log(check_logger, "Equality check failed - Got 1010_0101 (165). \
Expected 2147483647 (111_1111_1111_1111_1111_1111_1111_1111).", default_level);

        check_equal(signed'(X"A5"), integer'(-256));
        check_only_log(check_logger, "Equality check failed - Got 1010_0101 (-91). Expected -256 (1_0000_0000).",
                       default_level);

        check_equal(integer'(-256), signed'(X"A5"));
        check_only_log(check_logger, "Equality check failed - Got -256 (1_0000_0000). Expected 1010_0101 (-91).",
                       default_level);

        check_equal(signed'(X"05"), integer'(256));
        check_only_log(check_logger, "Equality check failed - Got 0000_0101 (5). Expected 256 (01_0000_0000).",
                       default_level);

        check_equal(signed'(X"A5"), integer'(-2147483648));
        check_only_log(check_logger, "Equality check failed - Got 1010_0101 (-91). \
Expected -2147483648 (1000_0000_0000_0000_0000_0000_0000_0000).", default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 7);
        reset_checker_stat;
"""

    natural_equal_natural = [
        (
            "natural",
            "natural",
            "natural'(165)",
            "natural'(165)",
            "natural'left",
            "natural'left",
            "natural'right",
            "natural'right",
            "natural'(90)",
            "165",
            "165",
            "90",
        )
    ]

    for c in combinations + natural_equal_natural:
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


def replace_region(region_name, file_name, new_contents):
    result = ""
    inside_region = False

    if not isinstance(file_name, Path):
        file_name = Path(file_name)

    with file_name.open("rb") as fptr:
        contents = fptr.read().decode()

    previous_line = ""
    found_region = False
    for line in contents.splitlines():
        if inside_region:
            if not found_region:
                result += new_contents
                found_region = True

        if line.startswith("  -------------------"):
            inside_region = False

        if not inside_region:
            result += line + "\n"

        if previous_line.startswith("  -- %s" % region_name) and line.startswith("  ----------"):
            assert not found_region
            inside_region = True

        previous_line = line

    assert found_region

    with file_name.open("wb") as fptr:
        fptr.write(result.encode())


def main():
    replace_region(
        "check_equal",
        str(Path(__file__).parent.parent / "src" / "check_api.vhd"),
        generate_api(),
    )
    replace_region(
        "check_equal",
        str(Path(__file__).parent.parent / "src" / "check.vhd"),
        generate_impl(),
    )
    with (Path(__file__).parent.parent / "test" / "tb_check_equal.vhd").open("wb") as fptr:
        fptr.write(generate_test().encode())


if __name__ == "__main__":
    main()
