# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

from string import Template

api_template = """  procedure check_match(
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable pass            : out boolean;
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable checker         : inout checker_t;
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_match(
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

"""

impl_template = """  procedure check_match(
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable pass            : out boolean;
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    if std_match(got, expected) then
      pass := true;
      check_passed(checker);
    else
      pass := false;
      check_failed(checker,
                   failed_expectation_msg("Matching", $got_str, $expected_str, msg),
                   level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_match(
    variable checker         : inout checker_t;
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_match(
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

"""

test_template = """      elsif run("Test should pass on $left_type matching $right_type") then
        get_checker_stat(stat);
        check_match($left_pass, $right_pass);
        check_match($left_pass_dc, $right_pass);
        check_match($left_pass, $right_pass_dc);
        check_match($left_pass_dc, $right_pass_dc);
        check_match(pass, $left_pass, $right_pass);
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_match($left_pass, $right_pass);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(stat, 6);

        get_checker_stat(check_match_checker, stat);
        check_match(check_match_checker, $left_pass, $right_pass);
        check_match(check_match_checker, pass, $left_pass, $right_pass);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_match_checker,stat, 2);

      elsif run("Test should fail on $left_type not matching $right_type") then
        check_match($left_pass, $right_fail_dc);
        verify_log_call(inc_count, "Matching failed! Got $pass_str. Expected $fail_dc_str.");
        check_match($left_pass, $right_fail_dc, "Extra info.");
        verify_log_call(inc_count, "Matching failed! Got $pass_str. Expected $fail_dc_str. Extra info.");
        check_match(pass, $left_pass, $right_fail);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Matching failed! Got $pass_str. Expected $fail_str.");
        pass := check_match($left_pass, $right_fail);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Matching failed! Got $pass_str. Expected $fail_str.");

        check_match(check_match_checker, $left_pass, $right_fail);
        verify_log_call(inc_count, "Matching failed! Got $pass_str. Expected $fail_str.");
        check_match(check_match_checker, pass, $left_pass, $right_fail);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Matching failed! Got $pass_str. Expected $fail_str.");
"""

combinations = [
    ('unsigned', 'unsigned',
     """unsigned'(X"A5")""", """unsigned'(X"A5")""",
     """unsigned'("1010----")""", """unsigned'("1010----")""",
     """unsigned'(X"5A")""", """unsigned'("0101----")""",
     '1010_0101 (165)', '0101_1010 (90)', '0101_---- (NaN)'),
    ('std_logic_vector', 'std_logic_vector',
     """std_logic_vector'(X"A5")""", """std_logic_vector'(X"A5")""",
     """std_logic_vector'("1010----")""", """std_logic_vector'("1010----")""",
     """std_logic_vector'(X"5A")""", """std_logic_vector'("0101----")""",
     '1010_0101 (165)', '0101_1010 (90)', '0101_---- (NaN)'),
    ('signed', 'signed',
     """signed'(X"A5")""", """signed'(X"A5")""",
     """signed'("1010----")""", """signed'("1010----")""",
     """signed'(X"5A")""", """signed'("0101----")""",
     '1010_0101 (-91)', '0101_1010 (90)', '0101_---- (NaN)'),
    ('std_logic', 'std_logic',
     "'1'", "'1'",
     "'-'", "'-'",
     "'0'", "'0'",
     "1", "0", "0")]

api = ''
for c in combinations:
    t = Template(api_template)
    api += t.substitute(got_type=c[0], expected_type=c[1])

print("API:\n\n" + api)


def dual_format(base_type, got_or_expected):
    if got_or_expected == 'got':
        expected_or_got = 'expected'
    else:
        expected_or_got = 'got'

    if base_type in ['unsigned', 'signed', 'std_logic_vector']:
        return ('to_nibble_string(%s) & " (" & ' % got_or_expected +
                "to_integer_string(%s) & " % got_or_expected + '")"')
    elif base_type == 'integer':
        return ('to_string(%s) & " (" & ' % got_or_expected +
                "to_nibble_string(to_sufficient_signed(%s, %s'length)) & " % (got_or_expected, expected_or_got) +
                '")"')
    else:
        return ('to_string(%s) & " (" & ' % got_or_expected +
                "to_nibble_string(to_sufficient_unsigned(%s, %s'length)) & " % (got_or_expected, expected_or_got) +
                '")"')

impl = ''
for c in combinations:
    t = Template(impl_template)
    if (c[0] in ['unsigned', 'signed', 'std_logic_vector']) or (c[1] in ['unsigned', 'signed', 'std_logic_vector']):
        got_str = dual_format(c[0], 'got')
        expected_str = dual_format(c[1], 'expected')
    else:
        got_str = 'to_string(got)'
        expected_str = 'to_string(expected)'
    impl += t.substitute(got_type=c[0], expected_type=c[1], got_str=got_str, expected_str=expected_str)

print("Implementation:\n\n" + impl)

test = ''

for c in combinations:
    t = Template(test_template)
    test += t.substitute(left_type=c[0], right_type=c[1],
                         left_pass=c[2], right_pass=c[3],
                         left_pass_dc=c[4], right_pass_dc=c[5],
                         right_fail=c[6], right_fail_dc=c[7],
                         pass_str=c[8], fail_str=c[9],
                         fail_dc_str=c[10])

print("Test:\n\n" + test)
