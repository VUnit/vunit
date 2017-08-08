-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

library vunit_lib;
use vunit_lib.integer_vector_ptr_pkg.all;

use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.log_handler_pkg.all;
use work.core_pkg.core_failure;

package log_system_pkg is

  type log_system_t is record
    p_log_handlers : integer_vector_ptr_t;
    p_root_logger : logger_t;
    p_next_logger_id : integer_vector_ptr_t;
  end record;

  impure function new_log_system return log_system_t;

  impure function new_log_handler(log_system : log_system_t;
                                  file_name : string;
                                  format : log_format_t;
                                  log_level : log_level_t;
                                  use_color : boolean) return log_handler_t;

  impure function get_logger(log_system : log_system_t;
                             name : string;
                             parent : logger_t := null_logger) return logger_t;

  -- Return true if logging to this logger at this level is enabled in any handler
  -- Can be used to avoid expensive string creation when not logging
  impure function is_enabled(log_system : log_system_t;
                             logger : logger_t;
                             level : log_level_t) return boolean;

  -- Disable logging for all levels < level to this handler
  procedure set_log_level(log_system : log_system_t;
                          log_handler : log_handler_t;
                          level : log_level_t);

  procedure log(log_system : log_system_t;
                logger : logger_t;
                msg : string;
                log_level : log_level_t;
                line_num : natural := 0;
                file_name : string := "");
end package;

package body log_system_pkg is

  impure function new_log_system return log_system_t is
    constant root_logger : logger_t := new_logger(0, "", null_logger);
  begin
    return (p_log_handlers => allocate,
            p_root_logger => root_logger,
            p_next_logger_id => allocate(1, value => get_id(root_logger) + 1));
  end;

  impure function num_log_handlers(log_system : log_system_t) return natural is
  begin
    return length(log_system.p_log_handlers);
  end;

  impure function get_log_handler(log_system : log_system_t; id : natural) return log_handler_t is
  begin
    return (p_id => id,
            p_data => to_integer_vector_ptr(get(log_system.p_log_handlers, id)));
  end;

  procedure add_logger(log_system : log_system_t;
                       logger : logger_t) is
    variable log_handler : log_handler_t;
    constant full_name_length : natural := get_full_name(logger)'length;
  begin
    set(log_system.p_next_logger_id, 0, get_id(logger) + 1);

    for i in 0 to num_log_handlers(log_system)-1 loop
      log_handler := get_log_handler(log_system, i);
      set_log_level(log_handler, logger, get_log_level(log_handler, get_parent(logger)));

      if full_name_length > get_max_logger_name_length(log_handler) then
        set_max_logger_name_length(log_handler, full_name_length);
      end if;
    end loop;
  end;

  impure function get_real_parent(log_system : log_system_t;
                                  parent : logger_t) return logger_t is
  begin
    if parent = null_logger then
      return log_system.p_root_logger;
    end if;
    return parent;
  end;

  impure function find(str : string; c : character) return integer is
  begin
    for i in str'range loop
      if str(i) = c then
        return i;
      end if;
    end loop;
    return -1;
  end;

  impure function head(name : string; dot_idx : integer) return string is
  begin
    if dot_idx = -1 then
      return name;
    else
      return name(1 to dot_idx-1);
    end if;
  end;

  impure function tail(name : string; dot_idx : integer) return string is
  begin
    if dot_idx = -1 then
      return "";
    else
      return name(dot_idx+1 to name'length);
    end if;
  end;

  impure function validate_logger_name(name : string;
                                       parent : logger_t) return boolean is
    function dotjoin(s1, s2 : string) return string is
    begin
      if s1 = "" then
        return s2;
      else
        return s1 & "." & s2;
      end if;
    end;

    constant full_name : string := dotjoin(get_name(parent), name);
  begin
    if name = "" then
      core_failure("Invalid logger name """ & full_name & """");
    end if;

    for i in full_name'range loop
      if full_name(i) = ',' then
        core_failure("Invalid logger name """ & full_name & """");
        return false;
      end if;
    end loop;

    return true;
  end;

  impure function p_get_logger(log_system : log_system_t;
                             name : string;
                             parent : logger_t := null_logger) return logger_t is
    constant real_parent : logger_t := get_real_parent(log_system, parent);
    constant dot_idx : integer := find(name, '.');
    constant head_name : string := head(name, dot_idx);
    constant tail_name : string := tail(name, dot_idx);
    variable child : logger_t;
  begin
    if not validate_logger_name(head_name, real_parent) then
      return null_logger;
    end if;

    for i in 0 to num_children(real_parent)-1 loop
      child := get_child(real_parent, i);

      if get_name(child) = head_name then
        if dot_idx = -1 then
          return child;
        else
          return p_get_logger(log_system, tail_name, child);
        end if;
      end if;
    end loop;

    return null_logger;
  end;

  impure function new_logger(log_system : log_system_t;
                             name : string;
                             parent : logger_t := null_logger) return logger_t is
    constant real_parent : logger_t := get_real_parent(log_system, parent);
    constant id : natural := get(log_system.p_next_logger_id, 0);
    variable child, logger : logger_t;
    constant dot_idx : integer := find(name, '.');
    constant head_name : string := head(name, dot_idx);
    constant tail_name : string := tail(name, dot_idx);
  begin
    logger := p_get_logger(log_system, head_name, real_parent);

    if logger = null_logger then
      logger := new_logger(id, head_name, real_parent);
      add_logger(log_system, logger);
    end if;

    if dot_idx /= -1 then
      add_logger(log_system, logger);
      child := new_logger(log_system, tail_name, logger);
      return p_get_logger(log_system, name, parent);
    end if;

    return logger;
  end;

  impure function get_logger(log_system : log_system_t;
                             name : string;
                             parent : logger_t := null_logger) return logger_t is
  begin
    return new_logger(log_system, name, parent);
  end;

  impure function new_log_handler(log_system : log_system_t;
                                  file_name : string;
                                  format : log_format_t;
                                  log_level : log_level_t;
                                  use_color : boolean) return log_handler_t is
    constant id : natural := length(log_system.p_log_handlers);
    constant log_handler : log_handler_t := new_log_handler(id, file_name, format, use_color);
  begin
    resize(log_system.p_log_handlers, id + 1);
    set(log_system.p_log_handlers, id, to_integer(log_handler.p_data));
    set_log_level(log_system, log_handler, log_level);
    set_max_logger_name_length(log_handler, get_max_name_length(log_system.p_root_logger));
    return log_handler;
  end;

  impure function is_enabled(log_system : log_system_t;
                             logger : logger_t;
                             level : log_level_t) return boolean is
  begin
    if is_mocked(logger) then
      return true;
    end if;

    for i in 0 to num_log_handlers(log_system)-1 loop
      if is_enabled(get_log_handler(log_system, i), logger, level) then
        return true;
      end if;
    end loop;

    return false;
  end;

  -- Disable logging for all levels < level to this handler
  procedure set_log_level(log_system : log_system_t;
                          log_handler : log_handler_t;
                          level : log_level_t) is
  begin
    set_log_level(log_handler, log_system.p_root_logger, level);
  end;

  procedure log(log_system : log_system_t;
                logger : logger_t;
                msg : string;
                log_level : log_level_t;
                line_num : natural := 0;
                file_name : string := "") is
    variable log_handler : log_handler_t;
    constant t_now : time := now;
  begin

    if is_mocked(logger) then
      mock_log(logger, msg, log_level, t_now, line_num, file_name);
    else
      for i in 0 to num_log_handlers(log_system) - 1 loop
        log_handler := get_log_handler(log_system, i);
        if is_enabled(log_handler, logger, log_level) then
          log_to_handler(log_handler, logger, msg, log_level, t_now, line_num, file_name);
        end if;
      end loop;

      -- Count after message has been displayed
      count_log(logger, log_level);
    end if;
  end procedure;

end package body;
