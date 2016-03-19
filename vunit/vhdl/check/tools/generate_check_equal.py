# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

from string import Template

api_template = """  procedure check_equal(
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

"""

impl_template = """  procedure check_equal(
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in $got_type;
    constant expected        : in $expected_type;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
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
    if got = expected then
      pass := true;
      check_passed(checker);
    else
      pass := false;
      check_failed(checker,
                   failed_expectation_msg("Equality check", $got_str, $expected_str, msg),
                   level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
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
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
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
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

"""

test_template = """      elsif run("Test should pass on $left_type equal $right_type") then
        get_checker_stat(stat);
        check_equal($left_pass, $right_pass);
        check_equal(pass, $left_pass, $right_pass);
        counting_assert(pass, "Should return pass = true on passing check");
        pass := check_equal($left_pass, $right_pass);
        counting_assert(pass, "Should return pass = true on passing check");
        check_equal($left_min, $right_min);
        check_equal($left_max, $right_max);
        verify_passed_checks(stat, 5);

        get_checker_stat(check_equal_checker, stat);
        check_equal(check_equal_checker, $left_pass, $right_pass);
        check_equal(check_equal_checker, pass, $left_pass, $right_pass);
        counting_assert(pass, "Should return pass = true on passing check");
        verify_passed_checks(check_equal_checker,stat, 2);

      elsif run("Test should fail on $left_type not equal $right_type") then
        check_equal($left_pass, $right_fail);
        verify_log_call(inc_count, "Equality check failed! Got $pass_str. Expected $fail_str.");
        check_equal($left_pass, $right_fail, "Extra info.");
        verify_log_call(inc_count, "Equality check failed! Got $pass_str. Expected $fail_str. Extra info.");
        check_equal(pass, $left_pass, $right_fail);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got $pass_str. Expected $fail_str.");
        pass := check_equal($left_pass, $right_fail);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got $pass_str. Expected $fail_str.");

        check_equal(check_equal_checker, $left_pass, $right_fail);
        verify_log_call(inc_count, "Equality check failed! Got $pass_str. Expected $fail_str.");
        check_equal(check_equal_checker, pass, $left_pass, $right_fail);
        counting_assert(not pass, "Should return pass = false on failing check");
        verify_log_call(inc_count, "Equality check failed! Got $pass_str. Expected $fail_str.");
"""

combinations = [
    ('unsigned', 'unsigned',
     """unsigned'(X"A5")""", """unsigned'(X"A5")""",
     "to_unsigned(natural'left,31)", "to_unsigned(natural'left,31)",
     "to_unsigned(natural'right,31)", "to_unsigned(natural'right,31)",
     """unsigned'(X"5A")""",
     '1010_0101 (165)', '0101_1010 (90)'),
    ('unsigned', 'natural',
     """unsigned'(X"A5")""", "natural'(165)",
     "to_unsigned(natural'left,31)", "natural'left",
     "to_unsigned(natural'right,31)", "natural'right",
     "natural'(90)",
     '1010_0101 (165)', '90 (0101_1010)'),
    ('natural', 'unsigned',
     "natural'(165)", """unsigned'(X"A5")""",
     "natural'left", "to_unsigned(natural'left,31)",
     "natural'right", "to_unsigned(natural'right,31)",
     """unsigned'(X"5A")""",
     '165 (1010_0101)', '0101_1010 (90)'),
    ('unsigned', 'std_logic_vector',
     """unsigned'(X"A5")""", """std_logic_vector'(X"A5")""",
     "to_unsigned(natural'left,31)", "std_logic_vector(to_unsigned(natural'left,31))",
     "to_unsigned(natural'right,31)", "std_logic_vector(to_unsigned(natural'right,31))",
     """std_logic_vector'(X"5A")""",
     '1010_0101 (165)', '0101_1010 (90)'),
    ('std_logic_vector', 'unsigned',
     """std_logic_vector'(X"A5")""", """unsigned'(X"A5")""",
     "std_logic_vector(to_unsigned(natural'left,31))", "to_unsigned(natural'left,31)",
     "std_logic_vector(to_unsigned(natural'right,31))", "to_unsigned(natural'right,31)",
     """unsigned'(X"5A")""",
     '1010_0101 (165)', '0101_1010 (90)'),
    ('std_logic_vector', 'std_logic_vector',
     """std_logic_vector'(X"A5")""", """std_logic_vector'(X"A5")""",
     "std_logic_vector(to_unsigned(natural'left,31))", "std_logic_vector(to_unsigned(natural'left,31))",
     "std_logic_vector(to_unsigned(natural'right,31))", "std_logic_vector(to_unsigned(natural'right,31))",
     """std_logic_vector'(X"5A")""",
     '1010_0101 (165)', '0101_1010 (90)'),
    ('signed', 'signed',
     """signed'(X"A5")""", """signed'(X"A5")""",
     "to_signed(integer'left,32)", "to_signed(integer'left,32)",
     "to_signed(integer'right,32)", "to_signed(integer'right,32)",
     """signed'(X"5A")""",
     '1010_0101 (-91)', '0101_1010 (90)'),
    ('signed', 'integer',
     """signed'(X"A5")""", "integer'(-91)",
     "to_signed(integer'left,32)", "integer'left",
     "to_signed(integer'right,32)", "integer'right",
     "integer'(90)",
     '1010_0101 (-91)', "90 (0101_1010)"),
    ('integer', 'signed',
     "integer'(-91)", """signed'(X"A5")""",
     "integer'left", "to_signed(integer'left,32)",
     "integer'right", "to_signed(integer'right,32)",
     """signed'(X"5A")""",
     '-91 (1010_0101)', '0101_1010 (90)'),
    ('integer', 'integer',
     "integer'(-91)", "integer'(-91)",
     "integer'left", "integer'left",
     "integer'right", "integer'right",
     "integer'(90)",
     '-91', '90'),
    ('std_logic', 'std_logic',
     "'1'", "'1'",
     "'0'", "'0'",
     "'1'", "'1'",
     "'0'",
     "1", "0"),
    ('std_logic', 'boolean',
     "'1'", "true",
     "'0'", "false",
     "'1'", "true",
     "false",
     "1", "false"),
    ('boolean', 'std_logic',
     "true", "'1'",
     "false", "'0'",
     "true", "'1'",
     "'0'",
     "true", "0"),
    ('boolean', 'boolean',
     "true", "true",
     "false", "false",
     "true", "true",
     "false",
     "true", "false")]

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

test = """\
      if run("Test should handle comparison of vectors longer than 32 bits") then
        get_checker_stat(stat);
        check_equal(unsigned'(X"A5A5A5A5A"), unsigned'(X"A5A5A5A5A"));
        check_equal(std_logic_vector'(X"A5A5A5A5A"), unsigned'(X"A5A5A5A5A"));
        check_equal(unsigned'(X"A5A5A5A5A"), std_logic_vector'(X"A5A5A5A5A"));
        check_equal(std_logic_vector'(X"A5A5A5A5A"), std_logic_vector'(X"A5A5A5A5A"));
        verify_passed_checks(stat, 4);

        check_equal(unsigned'(X"A5A5A5A5A"), unsigned'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! \
Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). \
Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).");

        check_equal(std_logic_vector'(X"A5A5A5A5A"), unsigned'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! \
Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). \
Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).");

        check_equal(unsigned'(X"A5A5A5A5A"), std_logic_vector'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! \
Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). \
Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).");

        check_equal(std_logic_vector'(X"A5A5A5A5A"), std_logic_vector'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! \
Got 1010_0101_1010_0101_1010_0101_1010_0101_1010 (44465543770). \
Expected 1011_0101_1010_0101_1010_0101_1010_0101_1010 (48760511066).");

      elsif run("Test print full integer vector when fail on comparison with to short vector") then

        check_equal(unsigned'(X"A5"), natural'(256));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). Expected 256 (1_0000_0000).");

        check_equal(natural'(256), unsigned'(X"A5"));
        verify_log_call(inc_count, "Equality check failed! Got 256 (1_0000_0000). Expected 1010_0101 (165).");

        check_equal(unsigned'(X"A5"), natural'(2147483647));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (165). \
Expected 2147483647 (111_1111_1111_1111_1111_1111_1111_1111).");

        check_equal(signed'(X"A5"), integer'(-256));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). Expected -256 (1_0000_0000).");

        check_equal(integer'(-256), signed'(X"A5"));
        verify_log_call(inc_count, "Equality check failed! Got -256 (1_0000_0000). Expected 1010_0101 (-91).");

        check_equal(signed'(X"05"), integer'(256));
        verify_log_call(inc_count, "Equality check failed! Got 0000_0101 (5). Expected 256 (01_0000_0000).");

        check_equal(signed'(X"A5"), integer'(-2147483648));
        verify_log_call(inc_count, "Equality check failed! Got 1010_0101 (-91). \
Expected -2147483648 (1000_0000_0000_0000_0000_0000_0000_0000).");
"""
natural_equal_natural = [('natural', 'natural',
                          "natural'(165)", "natural'(165)",
                          "natural'left", "natural'left",
                          "natural'right", "natural'right",
                          "natural'(90)",
                          '165', '90')]

for c in combinations + natural_equal_natural:
    t = Template(test_template)
    test += t.substitute(left_type=c[0], right_type=c[1],
                         left_pass=c[2], right_pass=c[3],
                         left_min=c[4], right_min=c[5],
                         left_max=c[6], right_max=c[7],
                         right_fail=c[8],
                         pass_str=c[9], fail_str=c[10])

print("Test:\n\n" + test)
