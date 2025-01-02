# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

from pathlib import Path
from string import Template
from vunit.vhdl.check.tools.generate_check_equal import replace_region

api_template = """  procedure check_match(
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_match(
    variable pass        : out boolean;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_match(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  procedure check_match(
    constant checker     : in checker_t;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "");

  impure function check_match(
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

  impure function check_match(
    constant checker     : in checker_t;
    constant got         : in $got_type;
    constant expected    : in $expected_type;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean;

"""

impl_template = """  procedure check_match(
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
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
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
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
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
    if std_match(got, expected) then
      pass := true;

      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Match check passed", msg,
            "Got " & $got_str & ". " &
            "Expected " & $expected_str & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Match check failed", msg,
          "Got " & $got_str & ". " &
          "Expected " & $expected_str & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_match(
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
    check_match(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_match(
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
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_match(
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
    check_match(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

"""

test_template = """
      $first_if run("Test should pass on $left_type matching $right_type") then
        get_checker_stat(stat);
        check_match($left_pass, $right_pass);
        check_match($left_pass_dc, $right_pass);
        check_match($left_pass, $right_pass_dc);
        check_match($left_pass_dc, $right_pass_dc);
        check_match(passed, $left_pass, $right_pass);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_match($left_pass, $right_pass);
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(stat, 6);

        get_checker_stat(my_checker, stat);
        check_match(my_checker, $left_pass, $right_pass);
        check_match(my_checker, passed, $left_pass, $right_pass);
        assert_true(passed, "Should return pass = true on passing check");
        passed := check_match(my_checker, $left_pass, $right_pass);
        assert_true(passed, "Should return pass = true on passing check");
        verify_passed_checks(my_checker,stat, 3);

      elsif run("Test pass message for $left_type matching $right_type") then
        mock(check_logger);
        check_match($left_pass, $right_pass);
        check_only_log(check_logger, "Match check passed - Got $pass_str. Expected $pass_str.", pass);

        check_match($left_pass_dc, $right_pass, "");
        check_only_log(check_logger, "Got $pass_dc_str. Expected $pass_str.", pass);

        check_match($left_pass, $right_pass_dc, "Checking my data");
        check_only_log(check_logger, "Checking my data - Got $pass_str. Expected $pass_dc_str.", pass);

        check_match($left_pass_dc, $right_pass_dc, result("for my data"));
        check_only_log(check_logger,
                       "Match check passed for my data - Got $pass_dc_str. Expected $pass_dc_str.",
                       pass);
        unmock(check_logger);

      elsif run("Test should fail on $left_type not matching $right_type") then
        get_checker_stat(stat);
        mock(check_logger);
        check_match($left_pass, $right_fail_dc);
        check_only_log(check_logger, "Match check failed - Got $pass_str. Expected $fail_dc_str.", default_level);

        check_match($left_pass, $right_fail_dc, "");
        check_only_log(check_logger, "Got $pass_str. Expected $fail_dc_str.", default_level);

        check_match(passed, $left_pass, $right_fail, "Checking my data");
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Checking my data - Got $pass_str. Expected $fail_str.", default_level);

        passed := check_match($left_pass, $right_fail, result("for my data"));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(check_logger, "Match check failed for my data - Got $pass_str. Expected $fail_str.",
                       default_level);
        unmock(check_logger);
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 4);
        reset_checker_stat;

        get_checker_stat(my_checker, stat);
        mock(my_logger);
        check_match(my_checker, $left_pass, $right_fail);
        check_only_log(my_logger, "Match check failed - Got $pass_str. Expected $fail_str.", default_level);

        check_match(my_checker, passed, $left_pass, $right_fail);
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Match check failed - Got $pass_str. Expected $fail_str.", default_level);

        passed := check_match(my_checker, $left_pass, $right_fail, result("for my data"));
        assert_true(not passed, "Should return pass = false on failing check");
        check_only_log(my_logger, "Match check failed for my data - Got $pass_str. Expected $fail_str.",
                       default_level);
        unmock(my_logger);
        verify_passed_checks(my_checker, stat, 0);
        verify_failed_checks(my_checker, stat, 3);
        reset_checker_stat(my_checker);
"""

combinations = [
    (
        "unsigned",
        "unsigned",
        """unsigned'(X"A5")""",
        """unsigned'(X"A5")""",
        """unsigned'("1010----")""",
        """unsigned'("1010----")""",
        """unsigned'(X"5A")""",
        """unsigned'("0101----")""",
        "1010_0101 (165)",
        "0101_1010 (90)",
        "1010_---- (NaN)",
        "0101_---- (NaN)",
    ),
    (
        "std_logic_vector",
        "std_logic_vector",
        """std_logic_vector'(X"A5")""",
        """std_logic_vector'(X"A5")""",
        """std_logic_vector'("1010----")""",
        """std_logic_vector'("1010----")""",
        """std_logic_vector'(X"5A")""",
        """std_logic_vector'("0101----")""",
        "1010_0101 (165)",
        "0101_1010 (90)",
        "1010_---- (NaN)",
        "0101_---- (NaN)",
    ),
    (
        "signed",
        "signed",
        """signed'(X"A5")""",
        """signed'(X"A5")""",
        """signed'("1010----")""",
        """signed'("1010----")""",
        """signed'(X"5A")""",
        """signed'("0101----")""",
        "1010_0101 (-91)",
        "0101_1010 (90)",
        "1010_---- (NaN)",
        "0101_---- (NaN)",
    ),
    (
        "std_logic",
        "std_logic",
        "std_logic'('1')",
        "'1'",
        "'-'",
        "'-'",
        "'0'",
        "'0'",
        "1",
        "0",
        "-",
        "0",
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

-- vunit: run_all_in_same_sim

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library vunit_lib;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.checker_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use work.test_support.all;

entity tb_check_match is
  generic (
    runner_cfg : string);
end entity tb_check_match;

architecture test_fixture of tb_check_match is
begin
  check_match_runner : process
    variable stat : checker_stat_t;
    variable my_checker : checker_t := new_checker("my_checker");
    constant my_logger : logger_t := get_logger(my_checker);
    variable passed : boolean;
    constant default_level : log_level_t := error;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop"""

    for idx, c in enumerate(combinations):
        t = Template(test_template)
        test += t.substitute(
            first_if="if" if idx == 0 else "elsif",
            left_type=c[0],
            right_type=c[1],
            left_pass=c[2],
            right_pass=c[3],
            left_pass_dc=c[4],
            right_pass_dc=c[5],
            right_fail=c[6],
            right_fail_dc=c[7],
            pass_str=c[8],
            fail_str=c[9],
            pass_dc_str=c[10],
            fail_dc_str=c[11],
        )

    test += """
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
    check_api_file_name = str(Path(__file__).parent.parent / "src" / "check_api.vhd")
    replace_region("check_match", check_api_file_name, generate_api())

    check_file_name = str(Path(__file__).parent.parent / "src" / "check.vhd")
    replace_region("check_match", check_file_name, generate_impl())

    with (Path(__file__).parent.parent / "test" / "tb_check_match.vhd").open("wb") as fptr:
        fptr.write(generate_test().encode())


if __name__ == "__main__":
    main()
