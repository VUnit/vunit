-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.log_levels_pkg.all;
use work.log_handler_pkg.all;
use work.integer_vector_ptr_pkg.all;

package logger_pkg is

  -- Logger record, all fields are private
  type logger_t is record
    p_data : integer_vector_ptr_t;
  end record;
  constant null_logger : logger_t := (p_data => null_ptr);
  impure function root_logger return logger_t;

  -- Get a logger with name.
  -- Can also optionally be relative to a parent logger
  impure function get_logger(name : string;
                             parent : logger_t := null_logger) return logger_t;

  -------------------------------------
  -- Log procedures for each log level
  -------------------------------------
  procedure debug(logger : logger_t;
                  msg : string;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure verbose(logger : logger_t; msg : string;
                    line_num : natural := 0;
                    file_name : string := "");

  procedure info(logger : logger_t; msg : string;
                 line_num : natural := 0;
                 file_name : string := "");

  procedure warning(logger : logger_t; msg : string;
                    line_num : natural := 0;
                    file_name : string := "");

  procedure error(logger : logger_t; msg : string;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure failure(logger : logger_t; msg : string;
                    line_num : natural := 0;
                    file_name : string := "");

  ------------------------------------------------
  -- Log procedure short hands for default logger
  ------------------------------------------------

  -- The default logger, all log calls without logger argument go to this logger.
  impure function default_logger return logger_t;

  procedure debug(msg : string;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure verbose(msg : string;
                    line_num : natural := 0;
                    file_name : string := "");

  procedure info(msg : string;
                 line_num : natural := 0;
                 file_name : string := "");

  procedure warning(msg : string;
                    line_num : natural := 0;
                    file_name : string := "");

  procedure error(msg : string;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure failure(msg : string;
                    line_num : natural := 0;
                    file_name : string := "");

  -- Log procedure with level as argument
  procedure log(logger : logger_t;
                msg : string;
                log_level : log_level_t := info;
                line_num : natural := 0;
                file_name : string := "");

  procedure log(msg : string;
                log_level : log_level_t := info;
                line_num : natural := 0;
                file_name : string := "");

  -- Get the name of this logger get_name(get_logger("parent:child")) = "child"
  impure function get_name(logger : logger_t) return string;

  -- Get the full name of this logger get_name(get_logger("parent:child")) = "parent:child"
  impure function get_full_name(logger : logger_t) return string;

  -- Get the parent of this logger
  impure function get_parent(logger : logger_t) return logger_t;

  -- Get the number of children of this logger
  impure function num_children(logger : logger_t) return natural;

  -- Get the idx'th child of this logger
  impure function get_child(logger : logger_t; idx : natural) return logger_t;

  -- Set the threshold for stopping simulation for a specific log level and
  -- logger tree
  procedure set_stop_count(logger : logger_t;
                           log_level : log_level_t;
                           value : positive;
                           unset_children : boolean := false);

  -- Set the infinite threshold for stopping simulation for a specific log level and
  -- logger tree
  procedure set_infinite_stop_count(logger : logger_t;
                                    log_level : log_level_t;
                                    unset_children : boolean := false);

  -- Unset stop count for stopping simulation for a specific log level and
  -- logger tree
  procedure unset_stop_count(logger : logger_t;
                             log_level : log_level_t;
                             unset_children : boolean := false);

  -- Returns true if logger has stop count set
  impure function has_stop_count(logger : logger_t;
                                 log_level : log_level_t) return boolean;

  -- Get the stop count for logger and log_level if set, else fail
  impure function get_stop_count(logger : logger_t;
                                 log_level : log_level_t) return positive;

  -- Stop simulation for all levels >= level for this logger and all children
  -- Only affects and can only be used with the standard log levels
  -- where an ordering is defined
  procedure set_stop_level(logger : logger_t;
                           log_level : standard_log_level_t);

  -- Stop simulation for all levels >= level
  -- Only affects and can only be used with the standard log levels
  -- where an ordering is defined
  procedure set_stop_level(level : standard_log_level_t);

  -- Disable stopping simulation for this logger by setting the stop
  -- count to integer'high
  procedure disable_stop(logger : logger_t;
                         include_children : boolean := true);

  -- Disable stopping simulation for all loggers by setting the stop count to integer'high
  procedure disable_stop;

  -- Disable logging for all levels < level to this handler.
  -- Only affects and can only be used with the standard log levels
  -- where an ordering is defined
  procedure set_log_level(log_handler : log_handler_t;
                          level : standard_log_level_t);

  -- Disable logging for all levels < level to this handler from specific
  -- logger and all children.
  -- Only affects and can only be used with the standard log levels
  -- where an ordering is defined
  procedure set_log_level(logger : logger_t;
                          log_handler : log_handler_t;
                          level : standard_log_level_t);

  -- Disable logging for the specified level to this handler.
  procedure disable(log_handler : log_handler_t;
                    level : log_level_t);

  -- Disable logging for the specified level to this handler from specific
  procedure disable(logger : logger_t;
                    log_handler : log_handler_t;
                    level : log_level_t;
                    include_children : boolean := true);

  -- Disable logging for the specified levels to this handler.
  procedure disable(log_handler : log_handler_t;
                    levels : log_level_vec_t);

  -- Disable logging for the specified levels to this handler from specific
  -- logger and all children.
  procedure disable(logger : logger_t;
                    log_handler : log_handler_t;
                    levels : log_level_vec_t;
                    include_children : boolean := true);

  -- Enable logging for the specified level to this handler.
  procedure enable(log_handler : log_handler_t;
                   level : log_level_t);

  -- Enable logging for the specified level to this handler from specific
  -- logger and all children.
  procedure enable(logger : logger_t;
                   log_handler : log_handler_t;
                   level : log_level_t;
                    include_children : boolean := true);

  -- Enable logging for the specified levels to this handler.
  procedure enable(log_handler : log_handler_t;
                   levels : log_level_vec_t);

  -- Enable logging for the specified levels to this handler from specific
  -- logger and all children.
  procedure enable(logger : logger_t;
                   log_handler : log_handler_t;
                   levels : log_level_vec_t;
                    include_children : boolean := true);

  -- Enable all log levels to the log handler
  procedure enable_all(log_handler : log_handler_t);

  -- Enable all log levels for this handler from specific logger
  procedure enable_all(logger : logger_t;
                       log_handler : log_handler_t;
                       include_children : boolean := true);

  -- Disable all log levels for this handler
  procedure disable_all(log_handler : log_handler_t);

  -- Disable all log levels for this handler from specific logger
  procedure disable_all(logger : logger_t;
                        log_handler : log_handler_t;
                        include_children : boolean := true);

  -- Return true if logging to this logger at this level is enabled in any handler
  -- Can be used to avoid expensive string creation when not logging a specific
  -- level
  impure function is_enabled(logger : logger_t;
                             level : log_level_t) return boolean;

  -- Returns true if a logger at this level is enabled to this handler
  impure function is_enabled(logger : logger_t;
                             log_handler : log_handler_t;
                             level : log_level_t) return boolean;

  -- Get the current enabled log levels for a specific logger to this log handler
  impure function get_enabled_log_levels(logger : logger_t;
                                         log_handler : log_handler_t) return log_level_vec_t;

  -- Get the current disabled log levels for a specific logger to this log handler
  impure function get_disabled_log_levels(logger : logger_t;
                                          log_handler : log_handler_t) return log_level_vec_t;

  -- Get the number of log handlers attached to this logger
  impure function num_log_handlers(logger : logger_t) return natural;

  -- Get the idx'th log handler attached to this logger
  impure function get_log_handler(logger : logger_t; idx : natural) return log_handler_t;

  -- Get all log handlers attached to this logger
  impure function get_log_handlers(logger : logger_t) return log_handler_vec_t;

  -- Set the log handlers for this logger
  procedure set_log_handlers(logger : logger_t;
                             log_handlers : log_handler_vec_t;
                             include_children : boolean := true);

  -- Get the total number of log calls to all loggers
  impure function get_log_count return natural;

  -- Get number of log calls to a specific level or all levels when level = null_log_level
  impure function get_log_count(logger : logger_t;
                                log_level : log_level_t := null_log_level) return natural;

  -- Reset the log call count of a specific level or all levels when level = null_log_level
  procedure reset_log_count(logger : logger_t;
                            log_level : log_level_t := null_log_level;
                            include_children : boolean := true);

  ---------------------------------------------------------------------
  -- Mock procedures to enable unit testing of code performing logging
  ---------------------------------------------------------------------

  -- Mock the logger preventing simulaton abort and recording all logs to it
  procedure mock(logger : logger_t);

  -- Unmock the logger returning it to its normal state
  -- Results in failures if there are still unchecked log calls recorded
  procedure unmock(logger : logger_t);

  -- Returns true if the logger is mocked
  impure function is_mocked(logger : logger_t) return boolean;

  -- Get the log count of specific or all log levels occured during mocked state
  impure function get_mock_log_count(
    logger : logger_t;
    log_level : log_level_t := null_log_level) return natural;

  -- Constant to ignore time value when checking log call
  constant no_time_check : time := -1 ns;

  -- Check that the earliest recorded log call in the mock state matches this
  -- call or fails. Also consumes this recorded log call such that subsequent
  -- check_log calls can be used to verify a sequence of log calls
  procedure check_log(logger : logger_t;
                      msg : string;
                      log_level : log_level_t;
                      log_time : time := no_time_check;
                      line_num : natural := 0;
                      file_name : string := "");

  -- Check that there is only one recorded log call remaining
  procedure check_only_log(logger : logger_t;
                           msg : string;
                           log_level : log_level_t;
                           log_time : time := no_time_check;
                           line_num : natural := 0;
                           file_name : string := "");

  -- Check that there are no remaining recorded log calls, automatically called
  -- during unmock
  procedure check_no_log(logger : logger_t);

end package;
