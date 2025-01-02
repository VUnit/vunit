-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.log_handler_pkg.all;
use vunit_lib.core_pkg.all;

package test_support_pkg is
  procedure assert_true(value : boolean; msg : string := "");
  procedure assert_false(value : boolean; msg : string := "");
  procedure assert_equal(got, expected, msg : string := "");
  procedure assert_equal(got, expected : integer; msg : string := "");
  impure function get_display_handler(logger : logger_t) return log_handler_t;
  impure function get_file_handler(logger : logger_t) return log_handler_t;
  procedure check_stop_level(logger : logger_t; pass_level : log_level_t; stop_level : log_level_t);
end package;

package body test_support_pkg is
  impure function msg_suffix(msg : string) return string is
  begin
    if msg = "" then
      return "";
    else
      return " - " & msg;
    end if;
  end;

  procedure assert_true(value : boolean; msg : string := "") is
  begin
    assert value report "assert_true failed" & msg_suffix(msg) severity failure;
  end;

  procedure assert_false(value : boolean; msg : string := "") is
  begin
    assert not value report "assert_false failed" & msg_suffix(msg) severity failure;
  end;

  procedure assert_equal(got, expected, msg : string := "") is
  begin
    assert got = expected report "Got " & got & " expected " & expected & msg_suffix(msg) severity failure;
  end;

  procedure assert_equal(got, expected : integer; msg : string := "") is
  begin
    assert_equal(integer'image(got), integer'image(expected), msg);
  end;

  impure function get_display_handler(logger : logger_t) return log_handler_t is
  begin
    for idx in 0 to num_log_handlers(logger) - 1 loop
      if get_file_name(get_log_handler(logger, idx)) = stdout_file_name then
        return get_log_handler(logger, idx);
      end if;
    end loop;

    return null_log_handler;
  end function;

  impure function get_file_handler(logger : logger_t) return log_handler_t is
  begin
    for idx in 0 to num_log_handlers(logger) - 1 loop
      if get_file_name(get_log_handler(logger, idx)) /= stdout_file_name then
        return get_log_handler(logger, idx);
      end if;
    end loop;

    return null_log_handler;
  end function;

  procedure check_stop_level(logger : logger_t; pass_level : log_level_t; stop_level : log_level_t) is
  begin
    log(logger, "Hello world", pass_level);
    mock_core_failure;
    log(logger, "Hello world", stop_level);
    check_and_unmock_core_failure;
    reset_log_count(logger, stop_level);
    reset_log_count(logger, pass_level);
  end;

end package body;
