-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.log_levels_pkg.all;
use work.integer_vector_ptr_pkg.all;

package logger_pkg is

  -- Logger record, all fields are private
  type logger_t is record
    p_data : integer_vector_ptr_t;
  end record;
  constant null_logger : logger_t := (p_data => null_ptr);

  -- Get the name of this logger get_name(get_logger("parent.child")) = "child"
  impure function get_name(logger : logger_t) return string;

  -- Get the full name of this logger get_name(get_logger("parent.child")) = "parent.child"
  impure function get_full_name(logger : logger_t) return string;

  -- Get the parent of this logger
  impure function get_parent(logger : logger_t) return logger_t;

  -- Get the number of children of this logger
  impure function num_children(logger : logger_t) return natural;

  -- Get the idx'th child of this logger
  impure function get_child(logger : logger_t; idx : natural) return logger_t;

  -- Stop simulation for all levels >= level
  procedure set_stop_level(logger : logger_t; log_level : log_level_t);

  -- Disable stopping simulation
  procedure disable_stop(logger : logger_t);

  -- Get number of logs to a specific level or all levels when level = null_log_level
  impure function get_log_count(
    logger : logger_t;
    log_level : log_level_t := null_log_level) return natural;

  -- Reset the log count of a specific level or all levels when level = null_log_level
  procedure reset_log_count(
    logger : logger_t;
    log_level : log_level_t := null_log_level);

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

  --------------------------------------------------
  -- Private procedures not intended for public use
  --------------------------------------------------
  impure function new_logger(id : natural;
                             name : string;
                             parent : logger_t) return logger_t;
  impure function get_id(logger : logger_t) return natural;
  impure function get_max_name_length(logger : logger_t) return natural;
  procedure count_log(logger : logger_t; log_level : log_level_t);
  procedure mock_log(logger : logger_t;
                     msg : string;
                     log_level : log_level_t;
                     log_time : time;
                     line_num : natural := 0;
                     file_name : string := "");
end package;
