-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.integer_vector_ptr_pkg.all;
use work.log_levels_pkg.all;
use work.logger_pkg.all;

package log_handler_pkg is

  type log_format_t is (
    -- The raw log format contains just the message without any other information
    raw,

    -- The level log format contains the level and message
    level,

    -- The verbose log format contains all information
    verbose,

    -- The csv format contains all information in machine readable format
    csv);

  -- Log handler record, all fields are private
  type log_handler_t is record
    p_id : natural;
    p_data : integer_vector_ptr_t;
  end record;
  constant null_handler : log_handler_t := (p_id => natural'low, p_data => null_ptr);

  -- Set the format to be used by the log handler
  procedure set_format(log_handler : log_handler_t;
                       format : log_format_t;
                       use_color : boolean := false);

  -- Disable logging for all levels < level to this handler from specific logger
  procedure set_log_level(log_handler : log_handler_t;
                          logger : logger_t;
                          level : log_level_t);

  -- Returns true if a logger at this level is enabled to this handler
  impure function is_enabled(log_handler : log_handler_t;
                             logger : logger_t;
                             level : log_level_t) return boolean;

  -- Get the current log level setting for a specific logger to this log handler
  impure function get_log_level(log_handler : log_handler_t;
                                logger : logger_t) return log_level_t;

  -- Disable all log levels for this handler from specific logger
  -- equivalent with setting log level to above_all_log_levels
  procedure disable_all(log_handler : log_handler_t;
                        logger : logger_t);

  -- Enable all log levels for this handler from specific logger
  -- equivalent with setting log level to below_all_log_levels
  procedure enable_all(log_handler : log_handler_t;
                       logger : logger_t);

  ---------------------------------------------
  -- Private parts not intended for public use
  ---------------------------------------------
  constant stdout_file_name : string := ">1";
  constant null_file_name : string := "";

  procedure set_max_logger_name_length(log_handler : log_handler_t; value : natural);
  impure function get_max_logger_name_length(log_handler : log_handler_t) return natural;

  procedure log_to_handler(log_handler : log_handler_t;
                           logger : logger_t;
                           msg : string;
                           log_level : log_level_t;
                           log_time : time;
                           line_num : natural := 0;
                           file_name : string := "");

  impure function new_log_handler(id : natural;
                                  file_name : string;
                                  format : log_format_t;
                                  use_color : boolean) return log_handler_t;

  procedure init_log_handler(log_handler : log_handler_t;
                             format : log_format_t;
                             file_name : string;
                             use_color : boolean := false);
end package;
