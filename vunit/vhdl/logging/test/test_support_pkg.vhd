-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

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
  procedure check_format(logger : logger_t; handler : log_handler_t; expected : deprecated_log_format_t);
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
    if get_file_name(get_log_handler(logger, 0)) = stdout_file_name then
      return get_log_handler(logger, 0);
    else
      return get_log_handler(logger, 1);
    end if;
  end function;

  impure function get_file_handler(logger : logger_t) return log_handler_t is
  begin
    if get_file_name(get_log_handler(logger, 0)) = stdout_file_name then
      return get_log_handler(logger, 1);
    else
      return get_log_handler(logger, 0);
    end if;
  end function;

  procedure check_stop_level(logger : logger_t; pass_level : log_level_t; stop_level : log_level_t) is
  begin
    log(logger, "Hello world", pass_level);
    mock_core_failure;
    log(logger, "Hello world", stop_level);
    check_and_unmock_core_failure("Stop simulation on log level " & log_level_t'image(stop_level));
    reset_log_count(logger, stop_level);
    reset_log_count(logger, pass_level);
  end;

  procedure check_format(logger : logger_t; handler : log_handler_t; expected : deprecated_log_format_t) is
    variable format : log_format_t;
    variable use_color : boolean;
  begin
    get_format(handler, format, use_color);

    if get_file_name(handler) = stdout_file_name then
      assert_true(use_color);
    else
      assert_true(not use_color);
    end if;

    if expected = off then
      for l in above_all_log_levels - 1 downto below_all_log_levels + 1 loop
        assert_false(is_enabled(logger, handler, log_level_t'val(l)),
                    "Level enabled: " & log_level_t'image(log_level_t'val(l)));
      end loop;
    else
      assert_true(format = expected);
      for l in above_all_log_levels - 1 downto below_all_log_levels + 1 loop
        assert_true(is_enabled(logger, handler, log_level_t'val(l)),
                    "Level disabled: " & log_level_t'image(log_level_t'val(l)));
      end loop;
    end if;
  end;

end package body;
