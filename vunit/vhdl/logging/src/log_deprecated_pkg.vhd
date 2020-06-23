-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.log_handler_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.core_pkg.core_failure;

use std.textio.all;

package log_deprecated_pkg is
  alias verbose_csv is work.log_handler_pkg.csv [return deprecated_log_format_t];
  alias verbose is work.log_levels_pkg.trace [return log_level_t];

  -- Deprecated interface to better support legacy testbenches. Calls to this
  -- procedure will be mapped to contemporary functionality using best effort:
  --
  -- * default_src sets the name of an uninitialized logger. Empty string names are not supported
  --   and will be replaced with "anonymous<a unique number>". Changing logger
  --   name of an already initialized logger is not allowed. In this case the
  --   empty string is the only valid value.
  -- * Changing the separator and append parameters to non-default values is not
  --   supported
  -- * The logger is configured with private display and file log handlers independent
  --   of the predefined handlers used by default_logger
  procedure logger_init (
    variable logger : inout logger_t;
    default_src     :       string                  := "";
    file_name       :       string                  := "log.csv";
    display_format  :       deprecated_log_format_t := raw;
    file_format     :       deprecated_log_format_t := off;
    stop_level      :       log_level_t             := failure;
    separator       :       character               := ',';
    append          :       boolean                 := false);

  -- This logger_init is used to reinitialize the default_logger and its predefined
  -- display and file handlers
  procedure logger_init (
    default_src    : string                  := "";
    file_name      : string                  := "log.csv";
    display_format : deprecated_log_format_t := raw;
    file_format    : deprecated_log_format_t := off;
    stop_level     : log_level_t             := failure;
    separator      : character               := ',';
    append         : boolean                 := false);

  -- VERBOSE is alias for TRACE
  procedure verbose(logger : logger_t;
                    msg : string;
                    line_num : natural := 0;
                    file_name : string := "");
  procedure verbose(msg : string;
                    line_num : natural := 0;
                    file_name : string := "");


end package log_deprecated_pkg;

package body log_deprecated_pkg is
  constant anonymous_counter : integer_vector_ptr_t := new_integer_vector_ptr(1);

  procedure logger_init (
    variable logger : inout logger_t;
    default_src     :       string                  := "";
    file_name       :       string                  := "log.csv";
    display_format  :       deprecated_log_format_t := raw;
    file_format     :       deprecated_log_format_t := off;
    stop_level      :       log_level_t             := failure;
    separator       :       character               := ',';
    append          :       boolean                 := false) is

    variable logger_display_handler, logger_file_handler : log_handler_t;
    variable new_logger : boolean := false;

    procedure create_logger is
      variable name : line;
    begin
      new_logger := true;
      if default_src = "" then
        write(name, "anonymous" & integer'image(get(anonymous_counter, 0)));
        warning("Empty string logger names not supported. Using """ & name.all & """");
        set(anonymous_counter, 0, get(anonymous_counter, 0) + 1);
      else
        write(name, default_src);
      end if;
      logger := get_logger(name.all);
      deallocate(name);
    end procedure create_logger;

    procedure configure_handlers(variable logger_display_handler, logger_file_handler : inout log_handler_t) is
      function real_format(format : deprecated_log_format_t) return log_format_t is
      begin
        if format = off then
          return raw;
        else
          return format;
        end if;
      end function;

      impure function get_logger_display_handler return log_handler_t is
      begin
        for idx in 0 to num_log_handlers(logger) - 1 loop
          if get_file_name(get_log_handler(logger, idx)) = stdout_file_name then
            return get_log_handler(logger, idx);
          end if;
        end loop;

        return null_log_handler;
      end function;

      impure function get_logger_file_handler return log_handler_t is
      begin
        for idx in 0 to num_log_handlers(logger) - 1 loop
          if get_file_name(get_log_handler(logger, idx)) /= stdout_file_name then
            return get_log_handler(logger, idx);
          end if;
        end loop;

        return null_log_handler;
      end function;
    begin
      logger_display_handler := get_logger_display_handler;
      if new_logger or (logger_display_handler = null_log_handler) then
        logger_display_handler := new_log_handler(stdout_file_name, real_format(display_format), true);
      else
        init_log_handler(logger_display_handler, real_format(display_format), stdout_file_name, true);
      end if;

      logger_file_handler := get_logger_file_handler;
      if new_logger or (logger_file_handler = null_log_handler) then
        logger_file_handler := new_log_handler(file_name, real_format(file_format), false);
      else
        init_log_handler(logger_file_handler, real_format(file_format), file_name, false);
      end if;

      set_log_handlers(logger, (logger_display_handler, logger_file_handler));
    end procedure;

    procedure filter_output (
      variable handler   : inout log_handler_t;
      constant format    : in    deprecated_log_format_t) is
    begin
      if format = off then
        hide_all(logger, handler);
      else
        show_all(logger, handler);
      end if;
    end procedure filter_output;

  begin
    warning("Using deprecated procedure logger_init. Using best effort mapping to contemporary functionality");

    if logger = null_logger then
      create_logger;
    elsif default_src /= "" and default_src /= get_full_name(logger) then
      core_failure("Changing logger name is not supported");
    end if;

    configure_handlers(logger_display_handler, logger_file_handler);

    filter_output(logger_display_handler, display_format);
    filter_output(logger_file_handler, file_format);

    set_stop_level(logger, stop_level);

    if separator /= ',' then
      core_failure("Changing CSV separator is not supported");
    end if;

    if append then
      core_failure("Appending new log to existing file is not supported");
    end if;
  end;

  procedure logger_init (
    default_src    : string                  := "";
    file_name      : string                  := "log.csv";
    display_format : deprecated_log_format_t := raw;
    file_format    : deprecated_log_format_t := off;
    stop_level     : log_level_t             := failure;
    separator      : character               := ',';
    append         : boolean                 := false) is
    variable logger : logger_t := default_logger;
  begin
    logger_init(logger, default_src, file_name, display_format, file_format, stop_level, separator, append);
  end;

  procedure verbose(logger : logger_t;
                    msg : string;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    warning("Mapping deprecated procedure verbose to trace");
    trace(logger, msg, line_num, file_name);
  end procedure;

  procedure verbose(msg : string;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    verbose(default_logger, msg, line_num, file_name);
  end procedure;

end package body log_deprecated_pkg;
