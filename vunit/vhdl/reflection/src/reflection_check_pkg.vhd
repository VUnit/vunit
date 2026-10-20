-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
--
-- reflection_check_pkg provides check_equal for any type, using VHDL-2019 reflection to name every
-- element that differs when the check fails.

use std.reflection.all;
use std.textio.all;

use work.checker_pkg.all;
use work.check_pkg.default_checker;
use work.log_levels_pkg.all;
use work.reflection_util_pkg.p_diff;

package reflection_check_pkg is
  -- Instantiate once per type, also in a process, then call like check_pkg's check_equal:
  --
  --   procedure check_equal is new check_equal generic map (t => packet_t);
  --   procedure check_equal is new check_equal_with_checker generic map (t => packet_t);
  --   ...
  --   check_equal(got_packet, expected_packet);
  --   check_equal(my_checker, got_packet, expected_packet);
  --
  -- reflection_check_generic_pkg gives both with one package instantiation. The check uses the
  -- predefined "=" of the type.
  --
  -- The default of msg is the value of check_result_tag. NVC can't call an instance of a generic
  -- subprogram that leaves out a parameter with a string constant default (nickg/nvc#1695).
  procedure check_equal
    generic (type t)
    parameter (
      constant got         : in t;
      constant expected    : in t;
      constant msg         : in string      := "<+/->";
      constant level       : in log_level_t := null_log_level;
      constant path_offset : in natural     := 0;
      constant line_num    : in natural     := 0;
      constant file_name   : in string      := "");

  procedure check_equal_with_checker
    generic (type t)
    parameter (
      constant checker     : in checker_t;
      constant got         : in t;
      constant expected    : in t;
      constant msg         : in string      := "<+/->";
      constant level       : in log_level_t := null_log_level;
      constant path_offset : in natural     := 0;
      constant line_num    : in natural     := 0;
      constant file_name   : in string      := "");
end package;

package body reflection_check_pkg is
  -- The mirrors are only used when is_equal is false
  procedure p_check_equal(
    constant checker     : in checker_t;
    constant is_equal    : in boolean;
    variable got         : inout value_mirror;
    variable expected    : inout value_mirror;
    constant msg         : in string;
    constant level       : in log_level_t;
    constant path_offset : in natural;
    constant line_num    : in natural;
    constant file_name   : in string) is
    variable diff : line;
  begin
    if is_equal then
      if is_pass_visible(checker) then
        passing_check(checker, p_std_msg("Equality check passed", msg, ""), path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
      return;
    end if;

    p_diff(got, expected, "", diff);
    if diff = null then
      -- The diff compares images, which can hide a difference, such as between two close real values
      write(diff, LF & "  values differ");
    end if;
    -- One row for each difference, below the message
    failing_check(checker, p_std_msg("Equality check failed", msg, "") & diff.all, level, path_offset + 1, line_num,
                  file_name);
    deallocate(diff);
  end;

  procedure check_equal
    generic (type t)
    parameter (
      constant got         : in t;
      constant expected    : in t;
      constant msg         : in string      := "<+/->";
      constant level       : in log_level_t := null_log_level;
      constant path_offset : in natural     := 0;
      constant line_num    : in natural     := 0;
      constant file_name   : in string      := "") is
    constant is_equal : boolean := got = expected;
    variable got_mirror, expected_mirror : value_mirror;
  begin
    if not is_equal then
      got_mirror := got'reflect;
      expected_mirror := expected'reflect;
    end if;
    p_check_equal(default_checker, is_equal, got_mirror, expected_mirror, msg, level, path_offset + 1, line_num,
                  file_name);
  end;

  procedure check_equal_with_checker
    generic (type t)
    parameter (
      constant checker     : in checker_t;
      constant got         : in t;
      constant expected    : in t;
      constant msg         : in string      := "<+/->";
      constant level       : in log_level_t := null_log_level;
      constant path_offset : in natural     := 0;
      constant line_num    : in natural     := 0;
      constant file_name   : in string      := "") is
    constant is_equal : boolean := got = expected;
    variable got_mirror, expected_mirror : value_mirror;
  begin
    if not is_equal then
      got_mirror := got'reflect;
      expected_mirror := expected'reflect;
    end if;
    p_check_equal(checker, is_equal, got_mirror, expected_mirror, msg, level, path_offset + 1, line_num, file_name);
  end;
end package body;
