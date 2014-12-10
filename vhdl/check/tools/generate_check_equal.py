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
    check(checker, pass, got = expected,
          equality_error_msg(to_string(got), to_string(expected), msg),
          level, line_num, file_name);
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
                 "to_unsigned(natural'left,32)", "to_unsigned(natural'left,32)",
                 "to_unsigned(natural'right,32)", "to_unsigned(natural'right,32)",
                 """unsigned'(X"5A")""",
                 '10100101', '01011010'),
                ('unsigned', 'natural',
                 """unsigned'(X"A5")""", "natural'(165)",
                 "to_unsigned(natural'left,32)", "natural'left",
                 "to_unsigned(natural'right,32)", "natural'right",
                 "natural'(90)",
                 '10100101', '90'),
                ('natural', 'unsigned',
                 "natural'(165)", """unsigned'(X"A5")""",
                 "natural'left", "to_unsigned(natural'left,32)",
                 "natural'right", "to_unsigned(natural'right,32)",
                 """unsigned'(X"5A")""",
                 '165', '01011010'),
                ('unsigned', 'std_logic_vector',
                 """unsigned'(X"A5")""", """std_logic_vector'(X"A5")""",
                 "to_unsigned(natural'left,32)", "std_logic_vector(to_unsigned(natural'left,32))",
                 "to_unsigned(natural'right,32)", "std_logic_vector(to_unsigned(natural'right,32))",
                 """std_logic_vector'(X"5A")""",
                 '10100101', '01011010'),
                ('std_logic_vector', 'unsigned',
                 """std_logic_vector'(X"A5")""", """unsigned'(X"A5")""",
                 "std_logic_vector(to_unsigned(natural'left,32))", "to_unsigned(natural'left,32)",
                 "std_logic_vector(to_unsigned(natural'right,32))", "to_unsigned(natural'right,32)",
                 """unsigned'(X"5A")""",
                 '10100101', '01011010'),
                ('std_logic_vector', 'std_logic_vector',
                 """std_logic_vector'(X"A5")""", """std_logic_vector'(X"A5")""",
                 "std_logic_vector(to_unsigned(natural'left,32))", "std_logic_vector(to_unsigned(natural'left,32))",
                 "std_logic_vector(to_unsigned(natural'right,32))", "std_logic_vector(to_unsigned(natural'right,32))",
                 """std_logic_vector'(X"5A")""",
                 '10100101', '01011010'),
                ('signed', 'signed',
                 """signed'(X"A5")""", """signed'(X"A5")""",
                 "to_signed(integer'left,32)", "to_signed(integer'left,32)",
                 "to_signed(integer'right,32)", "to_signed(integer'right,32)",
                 """signed'(X"5A")""",
                 '10100101', '01011010'),
                ('signed', 'integer',
                 """signed'(X"A5")""", "integer'(-91)",
                 "to_signed(integer'left,32)", "integer'left",
                 "to_signed(integer'right,32)", "integer'right",
                 "integer'(90)",
                 '10100101', "90"),
                ('integer', 'signed',
                 "integer'(-91)", """signed'(X"A5")""",
                 "integer'left", "to_signed(integer'left,32)",
                 "integer'right", "to_signed(integer'right,32)",
                 """signed'(X"5A")""",
                 '-91', '01011010'),
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

#print("API:\n\n" + api)

impl = ''
for c in combinations:
    t = Template(impl_template)
    impl += t.substitute(got_type=c[0], expected_type=c[1])

#print("Implementation:\n\n" + impl)

test = """      if run("Test should handle comparsion of vectors longer than 32 bits") then
        get_checker_stat(stat);
        check_equal(unsigned'(X"A5A5A5A5A"), unsigned'(X"A5A5A5A5A"));
        check_equal(std_logic_vector'(X"A5A5A5A5A"), unsigned'(X"A5A5A5A5A"));
        check_equal(unsigned'(X"A5A5A5A5A"), std_logic_vector'(X"A5A5A5A5A"));
        check_equal(std_logic_vector'(X"A5A5A5A5A"), std_logic_vector'(X"A5A5A5A5A"));
        verify_passed_checks(stat, 4);

        check_equal(unsigned'(X"A5A5A5A5A"), unsigned'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! Got 101001011010010110100101101001011010. Expected 101101011010010110100101101001011010.");
        check_equal(std_logic_vector'(X"A5A5A5A5A"), unsigned'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! Got 101001011010010110100101101001011010. Expected 101101011010010110100101101001011010.");
        check_equal(unsigned'(X"A5A5A5A5A"), std_logic_vector'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! Got 101001011010010110100101101001011010. Expected 101101011010010110100101101001011010.");
        check_equal(std_logic_vector'(X"A5A5A5A5A"), std_logic_vector'(X"B5A5A5A5A"));
        verify_log_call(inc_count, "Equality check failed! Got 101001011010010110100101101001011010. Expected 101101011010010110100101101001011010.");
"""
natural_equal_natural = [('natural', 'natural',
                          "natural'(165)", "natural'(165)",
                 "natural'left", "natural'left",
                 "natural'right", "natural'right",
                 "natural'(90)",
                 '165', '90')]

for c in combinations + natural_equal_natural:
    t = Template(test_template)
    test += t.substitute(left_type=c[0], right_type=c[1], left_pass=c[2], right_pass=c[3], left_min=c[4], right_min=c[5], left_max=c[6], right_max=c[7], right_fail=c[8], pass_str=c[9], fail_str=c[10])
    
print("Test:\n\n" + test)
