-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.log_handler_pkg.all;
use work.log_deprecated_pkg.all;
use work.checker_pkg.all;
use work.check_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.core_pkg.core_failure;

use std.textio.all;

package check_deprecated_pkg is
  -- Deprecated interfaces to better support legacy testbenches.

  -- Calls to checker_init will be mapped to contemporary functionality using best effort:
  --
  -- * default_src sets the name of an uninitialized checker. Empty string names are not supported
  --   and will be replaced with "anonymous<a unique number>".
  --
  --
  -- Changing checker
  --   name of an already initialized logger is not allowed. In this case the
  --   empty string is the only valid value.
  -- * Changing the separator and append parameters to non-default values is not
  --   supported
  -- * The logger is configured with private display and file log handlers independent
  --   of the predefined handlers used by default_logger
  procedure checker_init (
    variable checker : inout checker_t;
    constant default_level  : in log_level_t  := error;
    constant default_src    : in string       := "";
    constant file_name      : in string       := "error.csv";
    constant display_format : in deprecated_log_format_t := level;
    constant file_format    : in deprecated_log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in character    := ',';
    constant append         : in boolean      := false);

  -- This checker_init is used to reinitialize the default_checker
  procedure checker_init (
    constant default_level  : in log_level_t  := error;
    constant default_src    : in string       := "";
    constant file_name      : in string       := "error.csv";
    constant display_format : in deprecated_log_format_t := level;
    constant file_format    : in deprecated_log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in character    := ',';
    constant append         : in boolean      := false);

  -- Enabling pass messages is done by setting the log level to pass unless
  -- the current log level already allows pass messages. Disabling pass messages
  -- will set log level to debug unless the current log level already suppresses
  -- pass messages.
  procedure enable_pass_msg(checker : checker_t; handler : log_handler_t);
  procedure disable_pass_msg(checker : checker_t; handler : log_handler_t);
  procedure enable_pass_msg(checker : checker_t);
  procedure disable_pass_msg(checker : checker_t);

  procedure enable_pass_msg(handler : log_handler_t);
  procedure disable_pass_msg(handler : log_handler_t);
  procedure enable_pass_msg;
  procedure disable_pass_msg;

  -- These subprograms can be replaced by calls to get_checker_stat and check for n_failed > 0
  procedure checker_found_errors (
    variable result : out boolean);
  procedure checker_found_errors (
    constant checker : in checker_t;
    variable result : out   boolean);
  impure function checker_found_errors
    return boolean;

  -- Deprecated constant with _c suffix. Use without suffix instead
  constant check_result_tag_c : string := check_result_tag;

end package check_deprecated_pkg;

package body check_deprecated_pkg is
  constant anonymous_counter : integer_vector_ptr_t := new_integer_vector_ptr(1);

  procedure checker_init (
    variable checker : inout checker_t;
    constant default_level  : in log_level_t  := error;
    constant default_src    : in string       := "";
    constant file_name      : in string       := "error.csv";
    constant display_format : in deprecated_log_format_t := level;
    constant file_format    : in deprecated_log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in character    := ',';
    constant append         : in boolean      := false) is
    variable name : line;
    variable logger : logger_t := null_logger;
  begin
    warning("Using deprecated procedure checker_init. Using best effort mapping to contemporary functionality");

    if checker = null_checker then
      if default_src = "" then
        write(name, "anonymous" & integer'image(get(anonymous_counter, 0)));
        warning("Empty string checker names not supported. Using """ & name.all & """");
        set(anonymous_counter, 0, get(anonymous_counter, 0) + 1);
      else
        write(name, default_src);
      end if;
      logger_init(logger, name.all, file_name, display_format, file_format, stop_level, separator, append);
      checker := new_checker(logger, default_level);
      deallocate(name);
    else
      logger := get_logger(checker);
      logger_init(logger, default_src, file_name, display_format, file_format, stop_level, separator, append);
      set_default_log_level(checker, default_level);
    end if;
  end;

  procedure checker_init (
    constant default_level  : in log_level_t  := error;
    constant default_src    : in string       := "";
    constant file_name      : in string       := "error.csv";
    constant display_format : in deprecated_log_format_t := level;
    constant file_format    : in deprecated_log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in character    := ',';
    constant append         : in boolean      := false) is
    variable checker : checker_t := default_checker;
  begin
    checker_init(checker, default_level, default_src, file_name, display_format,
                file_format, stop_level, separator, append);
  end;

  procedure enable_pass_msg(checker : checker_t; handler : log_handler_t) is
  begin
    show(get_logger(checker), handler, pass);
  end;

  procedure disable_pass_msg(checker : checker_t; handler : log_handler_t) is
  begin
    hide(get_logger(checker), handler, pass);
  end;

  procedure enable_pass_msg(checker : checker_t) is
    constant handlers : log_handler_vec_t := get_log_handlers(get_logger(checker));
  begin
    for h in handlers'range loop
      enable_pass_msg(checker, handlers(h));
    end loop;
  end;

  procedure disable_pass_msg(checker : checker_t) is
    constant handlers : log_handler_vec_t := get_log_handlers(get_logger(checker));
  begin
    for h in handlers'range loop
      disable_pass_msg(checker, handlers(h));
    end loop;
  end;

  procedure enable_pass_msg(handler : log_handler_t) is
  begin
    enable_pass_msg(default_checker, handler);
  end;

  procedure disable_pass_msg(handler : log_handler_t) is
  begin
    disable_pass_msg(default_checker, handler);
  end;

  procedure enable_pass_msg is
  begin
    enable_pass_msg(default_checker);
  end;

  procedure disable_pass_msg is
  begin
    disable_pass_msg(default_checker);
  end;

  procedure checker_found_errors (
    variable result : out boolean) is
  begin
    checker_found_errors(default_checker, result);
  end;

  procedure checker_found_errors (
    constant checker :in  checker_t;
    variable result : out   boolean) is
    variable stat : checker_stat_t;
  begin
    warning("Using deprecated checker_found_errors. Use get_checker_stat instead.");
    stat := get_checker_stat(checker);
    result := stat.n_failed > 0;
  end;

  impure function checker_found_errors return boolean is
    variable result : boolean;
  begin
    checker_found_errors(default_checker, result);
    return result;
  end;

end package body check_deprecated_pkg;
