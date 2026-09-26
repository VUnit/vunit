-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

package body logger_pkg is

  procedure info(msg : string;
                 line_num : natural := 0;
                 file_name : string := "") is
  begin
    report(msg);
  end procedure;

  constant default_logger : logger_t := null_logger;

  constant log_level_invisible : integer := 0;
  constant log_level_visible : integer := 1;

  constant log_level_filter : integer_vector_ptr_t := new_integer_vector_ptr(length => 16, value => log_level_invisible);

  procedure log(logger : logger_t;
                msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    report(msg);
  end procedure;

  procedure log(msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    log(default_logger, msg, log_level, path_offset + 1, line_num, file_name);
  end;

  procedure debug(logger : logger_t;
                  msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    log(logger, msg, debug, path_offset + 1, line_num, file_name);
  end procedure;

  procedure failure(logger : logger_t;
                    msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    log(logger, msg, failure, path_offset + 1, line_num, file_name);
  end procedure;

  impure function is_visible(logger : logger_t;
                             log_level : log_level_t) return boolean is
  begin
    return get(log_level_filter, log_level_t'pos(log_level)) = log_level_visible;
  end;

  impure function get_logger(name : string;
                             parent : logger_t := null_logger) return logger_t is
  begin
    return null_logger;
  end;

  procedure set_log_level_filter(logger : logger_t;
                                 log_handler : log_handler_t;
                                 log_levels : log_level_vec_t;
                                 visible : boolean;
                                 include_children : boolean) is
    variable log_level_setting : natural;
  begin
    if visible then
      log_level_setting := log_level_visible;
    else
      log_level_setting := log_level_invisible;
    end if;

    for i in log_levels'range loop
      set(log_level_filter, log_level_t'pos(log_levels(i)), log_level_setting);
    end loop;
  end;

  -- Disable logging for the specified level to this handler from specific
  -- logger and all children.
  procedure hide(logger : logger_t;
                 log_handler : log_handler_t;
                 log_level : log_level_t;
                 include_children : boolean := true) is
  begin
    set_log_level_filter(logger, log_handler, (0 => log_level), visible => false,
                         include_children => include_children);
  end;

  -- Disable logging for the specified level to this handler
  procedure hide(log_handler : log_handler_t;
                 log_level : log_level_t) is
  begin
    hide(null_logger, log_handler, log_level, include_children => true);
  end;
  -- Disable logging for the specified levels to this handler from specific
  -- logger and all children.
  procedure hide(logger : logger_t;
                 log_handler : log_handler_t;
                 log_levels : log_level_vec_t;
                 include_children : boolean := true) is
  begin
    set_log_level_filter(logger, log_handler, log_levels, visible => false,
                         include_children => include_children);
  end;

  -- Disable logging for the specified levels to this handler
  procedure hide(log_handler : log_handler_t;
                 log_levels : log_level_vec_t) is
  begin
    hide(null_logger, log_handler, log_levels);
  end;

  procedure hide_all(logger : logger_t;
                     log_handler : log_handler_t;
                     include_children : boolean := true) is
  begin
    for log_level in log_level_t'low to log_level_t'high loop
      hide(logger, log_handler, log_level, include_children => include_children);
    end loop;
  end;

  procedure hide_all(log_handler : log_handler_t) is
  begin
    hide_all(null_logger, log_handler, include_children => true);
  end;

  procedure show(logger : logger_t;
                 log_handler : log_handler_t;
                 log_level : log_level_t;
                 include_children : boolean := true) is
  begin
    set_log_level_filter(logger, log_handler, (0 => log_level), visible => true,
                         include_children => include_children);
  end;

  procedure show(log_handler : log_handler_t;
                 log_level : log_level_t) is
  begin
    show(null_logger, log_handler, log_level, include_children => true);
  end;

  procedure show(logger : logger_t;
                 log_handler : log_handler_t;
                 log_levels : log_level_vec_t;
                 include_children : boolean := true) is
  begin
    set_log_level_filter(logger, log_handler, log_levels, visible => true,
                         include_children => include_children);
  end;

  procedure show(log_handler : log_handler_t;
                 log_levels : log_level_vec_t) is
  begin
    show(null_logger, log_handler, log_levels, include_children => true);
  end;

  procedure show_all(logger : logger_t;
                     log_handler : log_handler_t;
                     include_children : boolean := true) is
  begin
    for log_level in log_level_t'low to log_level_t'high loop
      show(logger, log_handler, log_level,
           include_children => include_children);
    end loop;
  end;

  procedure show_all(log_handler : log_handler_t) is
  begin
    show_all(null_logger, log_handler, include_children => true);
  end;

end package body;
