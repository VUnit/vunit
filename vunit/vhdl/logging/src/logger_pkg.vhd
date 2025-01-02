-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

use work.ansi_pkg.all;
use work.core_pkg.core_failure;
use work.id_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.location_pkg.all;
use work.log_handler_pkg.all;
use work.log_levels_pkg.all;
use work.print_pkg.print;
use work.queue_pkg.all;
use work.string_ops.all;

package logger_pkg is

  -- Logger record, all fields are private
  type logger_t is record
    p_data : integer_vector_ptr_t;
  end record;
  constant null_logger : logger_t := (p_data => null_ptr);
  type logger_vec_t is array (natural range <>) of logger_t;
  impure function root_logger return logger_t;

  -- Get a logger with name. A new one is created if it doesn't
  -- already exist. Can also optionally be relative to a parent logger.
  -- If a new logger is created then a new identity with the name/parent
  -- is also created.
  impure function get_logger(name : string;
                             parent : logger_t := null_logger) return logger_t;

  -- Get logger by identity. Create a new identity and/or logger if they
  -- don't already exist.
  impure function get_logger(id : id_t) return logger_t;

  -- Return true if logger with id already exists, false otherwise.
  impure function has_logger(id : id_t) return boolean;

  -------------------------------------
  -- Log procedures for each log level
  -------------------------------------
  procedure trace(logger : logger_t;
                  msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure debug(logger : logger_t;
                  msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure pass(logger : logger_t;
                 msg : string;
                 path_offset : natural := 0;
                 line_num : natural := 0;
                 file_name : string := "");

  procedure info(logger : logger_t;
                 msg : string;
                 path_offset : natural := 0;
                 line_num : natural := 0;
                 file_name : string := "");

  procedure warning(logger : logger_t;
                    msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "");

  procedure error(logger : logger_t;
                  msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure failure(logger : logger_t;
                    msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "");

  procedure warning_if(logger : logger_t;
                       condition : boolean;
                       msg : string;
                       path_offset : natural := 0;
                       line_num : natural := 0;
                       file_name : string := "");

  procedure error_if(logger : logger_t;
                     condition : boolean;
                     msg : string;
                     path_offset : natural := 0;
                     line_num : natural := 0;
                     file_name : string := "");

  procedure failure_if(logger : logger_t;
                       condition : boolean;
                       msg : string;
                       path_offset : natural := 0;
                       line_num : natural := 0;
                       file_name : string := "");

  ------------------------------------------------
  -- Log procedure short hands for default logger
  ------------------------------------------------

  -- The default logger, all log calls without logger argument go to this logger.
  impure function default_logger return logger_t;

  procedure trace(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure debug(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure pass(msg : string;
                 path_offset : natural := 0;
                 line_num : natural := 0;
                 file_name : string := "");

  procedure info(msg : string;
                 path_offset : natural := 0;
                 line_num : natural := 0;
                 file_name : string := "");

  procedure warning(msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "");

  procedure error(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure failure(msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "");

  procedure warning_if(condition : boolean;
                       msg : string;
                       path_offset : natural := 0;
                       line_num : natural := 0;
                       file_name : string := "");

  procedure error_if(condition : boolean;
                     msg : string;
                     path_offset : natural := 0;
                     line_num : natural := 0;
                     file_name : string := "");

  procedure failure_if(condition : boolean;
                       msg : string;
                       path_offset : natural := 0;
                       line_num : natural := 0;
                       file_name : string := "");

  -- Log procedure with level as argument
  procedure log(logger : logger_t;
                msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "");

  procedure log(msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "");

  -- Get the name of this logger get_name(get_logger("parent:child")) = "child"
  impure function get_name(logger : logger_t) return string;

  -- Get the full name of this logger get_name(get_logger("parent:child")) = "parent:child"
  impure function get_full_name(logger : logger_t) return string;

  -- Get identity for this logger.
  impure function get_id(logger : logger_t) return id_t;

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

  -- Disable stopping simulation for a specific log level and
  -- logger tree
  procedure disable_stop(logger : logger_t;
                         log_level : log_level_t;
                         unset_children : boolean := false);

  -- Set the threshold for stopping simulation for a specific log level in
  -- the entire logging tree.

  -- NOTE: Removes all other stop count settings for log_level in entire tree.
  procedure set_stop_count(log_level : log_level_t;
                           value : positive);

  -- Disable stopping simulation for a specific log level in
  -- the entire logging tree.

  -- NOTE: Removes all other stop count settings for log_level in entire tree.
  procedure disable_stop(log_level : log_level_t);

  -- Shorthand for configuring the stop counts for (warning, error, failure) in
  -- a logger subtree. Set stop count to infinite for all levels < log_level and
  -- 1 for all (warning, error, failure) >= log_level.

  -- NOTE: Removes all other stop count settings from logger subtree.
  procedure set_stop_level(logger : logger_t;
                           log_level : alert_log_level_t);

  -- Shorthand for configuring the stop counts in entire logger tree.
  -- Same behavior as set_stop_level for specific logger subtree above
  procedure set_stop_level(level : alert_log_level_t);

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

  -- Disable a log_level from specific logger including all children.
  -- Disable is used when a log message is unwanted and it should be ignored.

  -- NOTE: A disabled log message is still counted to get a disabled log count
  --       statistics.
  --       errors and failures can be disabled but the final_log_check must
  --       explicitly allow it as well as an extra safety mechanism.
  procedure disable(logger : logger_t;
                    log_level : log_level_t;
                    include_children : boolean := true);

  -- Returns true if the logger and log_level is disabled
  impure function is_disabled(logger : logger_t;
                              log_level : log_level_t) return boolean;

  -- Hide log messages of specified level to this handler.
  procedure hide(log_handler : log_handler_t;
                 log_level : log_level_t);

  -- Hide log messages from the logger of the specified level to this handler
  procedure hide(logger : logger_t;
                 log_handler : log_handler_t;
                 log_level : log_level_t;
                 include_children : boolean := true);

  -- Hide log messages of the specified levels to this handler.
  procedure hide(log_handler : log_handler_t;
                 log_levels : log_level_vec_t);

  -- Hide log messages from the logger of the specified levels to this handler
  procedure hide(logger : logger_t;
                 log_handler : log_handler_t;
                 log_levels : log_level_vec_t;
                 include_children : boolean := true);

  -- Show log messages of the specified log_level to this handler
  procedure show(log_handler : log_handler_t;
                 log_level : log_level_t);

  -- Show log messages from the logger of the specified log_level to this handler
  procedure show(logger : logger_t;
                 log_handler : log_handler_t;
                 log_level : log_level_t;
                 include_children : boolean := true);

  -- Show log messages of the specified log_levels to this handler
  procedure show(log_handler : log_handler_t;
                 log_levels : log_level_vec_t);

  -- Show log messages from the logger of the specified log_levels to this handler
  procedure show(logger : logger_t;
                 log_handler : log_handler_t;
                 log_levels : log_level_vec_t;
                 include_children : boolean := true);

  -- Show all log levels to the log handler
  procedure show_all(log_handler : log_handler_t);

  -- Show all log levels to the handler from specific logger
  procedure show_all(logger : logger_t;
                     log_handler : log_handler_t;
                     include_children : boolean := true);

  -- Hide all log levels from this handler
  procedure hide_all(log_handler : log_handler_t);

  -- Hide all log levels from this handler from specific logger
  procedure hide_all(logger : logger_t;
                     log_handler : log_handler_t;
                     include_children : boolean := true);

  -- Return true if logging to this logger at this level is visible anywhere
  -- Can be used to avoid expensive string creation when not logging a specific
  -- level
  impure function is_visible(logger : logger_t;
                             log_level : log_level_t) return boolean;

  -- Return true if logging to this logger at this level is visible to handler
  impure function is_visible(logger : logger_t;
                             log_handler : log_handler_t;
                             log_level : log_level_t) return boolean;

  -- Get the current visible log levels for a specific logger to this log handler
  impure function get_visible_log_levels(logger : logger_t;
                                         log_handler : log_handler_t) return log_level_vec_t;

  -- Get the current invisible log levels for a specific logger to this log handler
  impure function get_invisible_log_levels(logger : logger_t;
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


  -- Perform a check of the log counts and fail unless there are no errors or failures.
  -- By default no disabled errors or failures are not allowed.
  -- Disabled errors and failrues can be allowed by setting the corresponding
  -- arguments to true.
  -- By default warnings are allowed but failure on warning can be enabled.
  -- When fail on warning is enabled it also allows disabled warnings.
  procedure final_log_check(allow_disabled_errors : boolean := false;
                            allow_disabled_failures : boolean := false;
                            fail_on_warning : boolean := false);

  impure function final_log_check(allow_disabled_errors : boolean := false;
                                  allow_disabled_failures : boolean := false;
                                  fail_on_warning : boolean := false) return boolean;

  ---------------------------------------------------------------------
  -- Mock procedures to enable unit testing of code performing logging
  ---------------------------------------------------------------------

  -- Mock the logger preventing simulaton abort and recording all logs to it
  procedure mock(logger : logger_t);

  -- Mock log_level of logger preventing simulaton abort and recording all logs to it
  procedure mock(logger : logger_t; log_level : log_level_t);

  -- Unmock the logger returning it to its normal state
  -- Results in failures if there are still unchecked log calls recorded
  procedure unmock(logger : logger_t);

  -- Returns true if the logger is mocked
  impure function is_mocked(logger : logger_t) return boolean;

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
  procedure check_no_log;

  -- Return the number of unchecked messages in the mock queue
  impure function mock_queue_length return natural;

  -----------------------------------------------------------------------------
  -- Misc
  -----------------------------------------------------------------------------
  impure function to_integer(logger : logger_t) return integer;
  impure function to_logger(value : integer) return logger_t;


end package;
