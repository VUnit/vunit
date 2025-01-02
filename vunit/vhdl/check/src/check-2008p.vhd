-- The check package provides the primary checking functionality.
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
use std.textio.all;
use work.checker_pkg.all;
use work.string_ops.all;
use work.location_pkg.all;
use work.integer_vector_ptr_pkg.all;

package body check_2008p_pkg is
  -----------------------------------------------------------------------------
  -- check_equal
  -----------------------------------------------------------------------------
  procedure check_equal(
    constant got         : in ufixed;
    constant expected    : in ufixed;
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
    constant got         : in ufixed;
    constant expected    : in ufixed;
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
    constant got         : in ufixed;
    constant expected    : in ufixed;
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
            "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & "."),
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
          "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ". " &
          "Expected " & to_string(expected) & " (" & to_string(to_real(expected), "%f") & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in ufixed;
    constant expected    : in ufixed;
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
    constant got         : in ufixed;
    constant expected    : in ufixed;
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
    constant got         : in ufixed;
    constant expected    : in ufixed;
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
    constant got         : in ufixed;
    constant expected    : in ufixed;
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
      std_pass_ctx => "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ".",
      std_fail_ctx => "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ". Expected " & to_string(expected) & " (" & to_string(to_real(expected), "%f") & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in ufixed;
    constant expected    : in ufixed;
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


  procedure check_equal(
    constant got         : in ufixed;
    constant expected    : in real;
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
    constant got         : in ufixed;
    constant expected    : in real;
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
    constant got         : in ufixed;
    constant expected    : in real;
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
            "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & "."),
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
          "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ". " &
          "Expected " & to_string(expected, "%f") & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in ufixed;
    constant expected    : in real;
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
    constant got         : in ufixed;
    constant expected    : in real;
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
    constant got         : in ufixed;
    constant expected    : in real;
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
    constant got         : in ufixed;
    constant expected    : in real;
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
      std_pass_ctx => "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ".",
      std_fail_ctx => "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ". Expected " & to_string(expected, "%f") & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in ufixed;
    constant expected    : in real;
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


  procedure check_equal(
    constant got         : in sfixed;
    constant expected    : in sfixed;
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
    constant got         : in sfixed;
    constant expected    : in sfixed;
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
    constant got         : in sfixed;
    constant expected    : in sfixed;
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
            "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & "."),
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
          "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ". " &
          "Expected " & to_string(expected) & " (" & to_string(to_real(expected), "%f") & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in sfixed;
    constant expected    : in sfixed;
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
    constant got         : in sfixed;
    constant expected    : in sfixed;
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
    constant got         : in sfixed;
    constant expected    : in sfixed;
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
    constant got         : in sfixed;
    constant expected    : in sfixed;
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
      std_pass_ctx => "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ".",
      std_fail_ctx => "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ". Expected " & to_string(expected) & " (" & to_string(to_real(expected), "%f") & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in sfixed;
    constant expected    : in sfixed;
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


  procedure check_equal(
    constant got         : in sfixed;
    constant expected    : in real;
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
    constant got         : in sfixed;
    constant expected    : in real;
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
    constant got         : in sfixed;
    constant expected    : in real;
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
            "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & "."),
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
          "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ". " &
          "Expected " & to_string(expected, "%f") & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in sfixed;
    constant expected    : in real;
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
    constant got         : in sfixed;
    constant expected    : in real;
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
    constant got         : in sfixed;
    constant expected    : in real;
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
    constant got         : in sfixed;
    constant expected    : in real;
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
      std_pass_ctx => "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ".",
      std_fail_ctx => "Got " & to_string(got) & " (" & to_string(to_real(got), "%f") & ")" & ". Expected " & to_string(expected, "%f") & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in sfixed;
    constant expected    : in real;
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


  -----------------------------------------------------------------------------

end package body check_2008p_pkg;
