-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.logger_pkg.all;
use work.log_handler_pkg.all;
use work.log_system_pkg.all;

package log_pkg is

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
                log_level : log_level_t;
                line_num : natural := 0;
                file_name : string := "");

  -- Stop simulation for all levels >= level
  procedure set_stop_level(level : log_level_config_t);

  -- Disable stopping simulation
  -- Equivalent with set_stop_level(all_levels)
  procedure disable_stop;

  -- Return true if logging to this logger at this level is enabled in any handler
  -- Can be used to avoid expensive string creation when not logging a specific
  -- level
  impure function is_enabled(logger : logger_t;
                             level : log_level_t) return boolean;

  -- Disable logging for all levels < level to the log handler
  procedure set_log_level(log_handler : log_handler_t;
                          level : log_level_config_t);

  -- Disable all log levels to the log handler
  -- equivalent with setting log level to all_levels
  procedure disable_all(log_handler : log_handler_t);

  -- Enable all log levels to the log handler
  -- equivalent with setting log level to no_level
  procedure enable_all(log_handler : log_handler_t);

  -- The default log system
  constant log_system : log_system_t := new_log_system;

  -- The default logger, all log calls without logger argument go to this logger.
  constant default_logger : logger_t := get_logger(log_system, "default");

  -- Display handler; Write to stdout
  constant display_handler : log_handler_t := new_log_handler(log_system,
                                                              stdout_file_name,
                                                              format => verbose,
                                                              use_color => true,
                                                              log_level => info);

  -- File handler; Write to file
  -- Is configured to output_path/log.csv by test_runner_setup
  constant file_handler : log_handler_t := new_log_handler(log_system,
                                                           null_file_name,
                                                           format => verbose,
                                                           use_color => false,
                                                           log_level => debug);
end package;
