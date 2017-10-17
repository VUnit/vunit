-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

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
  -- Deprecated interface to better support legacy testbenches. Calls to this
  -- procedure will be mapped to contemporary functionality using best effort:
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

end package check_deprecated_pkg;

package body check_deprecated_pkg is
  constant anonymous_counter : integer_vector_ptr_t := allocate(1);

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
      checker := new_checker(name.all, logger, default_level);
      deallocate(name);
    elsif default_src /= "" and default_src /= get_name(checker) then
      core_failure("Changing checker name is not supported");
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

end package body check_deprecated_pkg;
