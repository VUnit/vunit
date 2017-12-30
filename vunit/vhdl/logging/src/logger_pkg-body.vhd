-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ptr_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.queue_pkg.all;
use work.core_pkg.core_failure;
use work.string_ops.all;

package body logger_pkg is
  constant root_logger_id : natural := 0;
  constant next_logger_id : integer_vector_ptr_t := new_integer_vector_ptr(1, value => root_logger_id + 1);
  constant global_log_count : integer_vector_ptr_t := new_integer_vector_ptr(1, value => 0);

  constant id_idx : natural := 0;
  constant name_idx : natural := 1;
  constant parent_idx : natural := 2;
  constant children_idx : natural := 3;
  constant log_count_idx : natural := 4;
  constant stop_counts_idx : natural := 5;
  constant handlers_idx : natural := 6;
  constant is_mocked_idx : natural := 7;
  constant mock_log_count_idx : natural := 8;
  constant mocked_log_queue_meta_idx : natural := 9;
  constant mocked_log_queue_data_idx : natural := 10;
  constant log_level_filters_idx : natural := 11;
  constant logger_length : natural := 12;

  constant log_level_disabled : integer := 0;
  constant log_level_enabled : integer := 1;

  constant n_log_levels : natural := log_level_t'pos(log_level_t'high) + 1;

  impure function to_integer(logger : logger_t) return integer is
  begin
    return to_integer(logger.p_data);
  end;

  procedure add_child(logger : logger_t; child : logger_t) is
    constant children : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, children_idx));
  begin
    resize(children, length(children)+1);
    set(children, length(children)-1, to_integer(child));
  end;

  impure function new_logger(id : natural;
                             name : string;
                             parent : logger_t) return logger_t is
    variable logger : logger_t;
    variable log_handler : log_handler_t;
    variable mocked_log_queue : queue_t := new_queue;
  begin
    logger := (p_data => new_integer_vector_ptr(logger_length));
    set(logger.p_data, id_idx, id);
    set(logger.p_data, name_idx, to_integer(new_string_ptr(name)));
    set(logger.p_data, parent_idx, to_integer(parent));
    set(logger.p_data, children_idx, to_integer(new_integer_vector_ptr));
    set(logger.p_data, log_count_idx, to_integer(new_integer_vector_ptr(log_level_t'pos(log_level_t'high)+1, value => 0)));
    set(logger.p_data, mock_log_count_idx, to_integer(new_integer_vector_ptr(log_level_t'pos(log_level_t'high)+1, value => 0)));
    set(logger.p_data, stop_counts_idx, to_integer(new_integer_vector_ptr));
    set(logger.p_data, handlers_idx, to_integer(new_integer_vector_ptr));
    set(logger.p_data, is_mocked_idx, 0);
    set(logger.p_data, mocked_log_queue_meta_idx, to_integer(mocked_log_queue.p_meta));
    set(logger.p_data, mocked_log_queue_data_idx, to_integer(mocked_log_queue.data));
    set(logger.p_data, log_level_filters_idx, to_integer(new_integer_vector_ptr));

    if parent /= null_logger then
      add_child(parent, logger);

      -- Re-use parent log handlers and log level settings
      set_log_handlers(logger, get_log_handlers(parent));

      for i in 0 to num_log_handlers(parent)-1 loop
        log_handler := get_log_handler(parent, i);
        enable(logger, log_handler, get_enabled_log_levels(parent, log_handler));
        disable(logger, log_handler, get_disabled_log_levels(parent, log_handler));
      end loop;

    end if;

    return logger;
  end;

  procedure p_set_log_handlers(logger : logger_t;
                               log_handlers : log_handler_vec_t) is
    constant handlers : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, handlers_idx));
  begin
    resize(handlers, log_handlers'length);

    for i in log_handlers'range loop
      set(handlers, i, to_integer(log_handlers(i).p_data));
      update_max_logger_name_length(log_handlers(i), get_full_name(logger)'length);
    end loop;
  end;

  -- @NOTE this procedure needs to be above root logger creation to around
  -- Riviera-PRO elaboration bug
  procedure set_log_level_filter(logger : logger_t;
                                 log_handler : log_handler_t;
                                 log_levels : log_level_vec_t;
                                 enabled : boolean) is
    constant log_level_filters : integer_vector_ptr_t :=
      to_integer_vector_ptr(get(logger.p_data, log_level_filters_idx));
    constant handler_id : natural := get_id(log_handler);
    variable log_level_filter : integer_vector_ptr_t;
    variable log_level_setting : natural;

  begin
    if handler_id >= length(log_level_filters) then
      resize(log_level_filters, handler_id + 1, value => to_integer(null_ptr));
    end if;

    log_level_filter := to_integer_vector_ptr(get(log_level_filters, handler_id));

    if log_level_filter = null_ptr then
      -- Only enable valid log levels by default
      log_level_filter := new_integer_vector_ptr(length => n_log_levels, value => log_level_disabled);
      for log_level in log_level_t'low to log_level_t'high loop
        if is_valid(log_level) then
          set(log_level_filter, log_level_t'pos(log_level), log_level_enabled);
        end if;
      end loop;

      set(log_level_filters, handler_id, to_integer(log_level_filter));
    end if;

    if enabled then
      log_level_setting := log_level_enabled;
    else
      log_level_setting := log_level_disabled;
    end if;

    for i in log_levels'range loop
      set(log_level_filter, log_level_t'pos(log_levels(i)), log_level_setting);
    end loop;

    for i in 0 to num_children(logger)-1 loop
      set_log_level_filter(get_child(logger, i), log_handler, log_levels, enabled);
    end loop;
  end;

  impure function new_root_logger return logger_t is
    variable logger : logger_t := new_logger(root_logger_id, "", null_logger);
  begin
    p_set_log_handlers(logger, (display_handler, file_handler));
    disable_all(logger, display_handler);
    enable(logger, display_handler, (info, warning, error, failure));
    disable_all(logger, file_handler);
    enable(logger, file_handler, (debug, info, warning, error, failure));
    return logger;
  end;

  constant p_root_logger : logger_t := new_root_logger;
  impure function root_logger return logger_t is
  begin
    return p_root_logger;
  end;

  impure function new_logger(name : string; parent : logger_t) return logger_t is
    constant id : natural := get(next_logger_id, 0);
  begin
    set(next_logger_id, 0, id + 1);
    return new_logger(id, name, parent);
  end;

  impure function get_id(logger : logger_t) return natural is
  begin
    return get(logger.p_data, id_idx);
  end;

  impure function get_real_parent(parent : logger_t) return logger_t is
  begin
    if parent = null_logger then
      return root_logger;
    end if;
    return parent;
  end;

  impure function head(name : string; dot_idx : natural) return string is
  begin
    if dot_idx = 0 then
      return name;
    else
      return name(name'left to dot_idx-1);
    end if;
  end;

  impure function tail(name : string; dot_idx : natural) return string is
  begin
    if dot_idx = 0 then
      return "";
    else
      return name(dot_idx+1 to name'right);
    end if;
  end;

  impure function validate_logger_name(name : string;
                                       parent : logger_t) return boolean is
    function join(s1, s2 : string) return string is
    begin
      if s1 = "" then
        return s2;
      else
        return s1 & ":" & s2;
      end if;
    end;

    constant full_name : string := join(get_name(parent), name);
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

  impure function get_logger(name : string;
                             parent : logger_t := null_logger) return logger_t is
    constant real_parent : logger_t := get_real_parent(parent);
    variable child, logger : logger_t;
    constant stripped_name : string := strip(name, ":");
    constant dot_idx : integer := find(stripped_name, ':');
    constant head_name : string := head(stripped_name, dot_idx);
    constant tail_name : string := tail(stripped_name, dot_idx);
  begin
    if not validate_logger_name(head_name, real_parent) then
      return null_logger;
    end if;

    logger := null_logger;
    for i in 0 to num_children(real_parent)-1 loop
      child := get_child(real_parent, i);

      if get_name(child) = head_name then
        logger := child;
        exit;
      end if;
    end loop;

    if logger = null_logger then
      logger := new_logger(head_name, real_parent);
      set_log_handlers(logger, get_log_handlers(real_parent));
    end if;

    if dot_idx /= 0 then
      return get_logger(tail_name, logger);
    end if;

    return logger;
  end;

  impure function get_full_name(logger : logger_t) return string is
    variable parent : logger_t := get_parent(logger);
  begin
    if parent = null_logger or get_id(parent) = root_logger_id then
      return get_name(logger);
    else
      return get_full_name(parent) & ":" & get_name(logger);
    end if;
  end;

  impure function get_max_name_length(logger : logger_t) return natural is
    variable result : natural := 0;
    variable child_result : natural;
  begin
    if num_children(logger) = 0 then
      return get_full_name(logger)'length;
    end if;

    for i in 0 to num_children(logger)-1 loop
      child_result := get_max_name_length(get_child(logger, i));
      if child_result > result then
        result := child_result;
      end if;
    end loop;

    return result;
  end;

  impure function get_name(logger : logger_t) return string is
  begin
    return to_string(to_string_ptr(get(logger.p_data, name_idx)));
  end;

  impure function get_parent(logger : logger_t) return logger_t is
  begin
    return (p_data => to_integer_vector_ptr(get(logger.p_data, parent_idx)));
  end;

  impure function is_mocked(logger : logger_t) return boolean is
  begin
    return get(logger.p_data, is_mocked_idx) = 1;
  end;

  impure function num_children(logger : logger_t) return natural is
    constant children : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, children_idx));
  begin
    return length(children);
  end;

  impure function get_child(logger : logger_t; idx : natural) return logger_t is
    constant children : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, children_idx));
  begin
    return (p_data => to_integer_vector_ptr(get(children, idx)));
  end;

  procedure set_stop_count(logger : logger_t;
                           log_level : log_level_t;
                           value : positive) is

    -- Add that saturates on integer'high
    function add(value1, value2 : natural) return natural is
    begin
      if integer'high - value1 < value2 then
        return integer'high;
      else
        return value1 + value2;
      end if;
    end;

    constant stop_counts : integer_vector_ptr_t := to_integer_vector_ptr(
      get(logger.p_data, stop_counts_idx));
    constant log_level_idx : natural := log_level_t'pos(log_level);
    constant log_count : natural := get_log_count(logger, log_level);
  begin
    if log_level_idx >= length(stop_counts) then
      resize(stop_counts, log_level_idx + 1, value => integer'high);
    end if;

    -- Add stop level to existing log count
    set(stop_counts, log_level_idx, add(log_count, value));

    for child_idx in 0 to num_children(logger)-1 loop
      set_stop_count(get_child(logger, child_idx), log_level, value);
    end loop;
  end;

  impure function get_stop_count(logger : logger_t;
                                 log_level : log_level_t) return natural is
    constant stop_counts : integer_vector_ptr_t := to_integer_vector_ptr(
      get(logger.p_data, stop_counts_idx));
    constant log_level_idx : natural := log_level_t'pos(log_level);
  begin
    if log_level_idx >= length(stop_counts) then
      resize(stop_counts, log_level_idx + 1, value => integer'high);
    end if;

    return get(stop_counts, log_level_idx);
  end;

  procedure set_stop_count(log_level : log_level_t;
                           value : positive) is
  begin
    set_stop_count(root_logger, log_level, value);
  end;

  procedure set_stop_level(level : standard_log_level_t) is
  begin
    set_stop_level(root_logger, level);
  end;

  -- Stop simulation for all levels >= level for this logger and all children
  procedure set_stop_level(logger : logger_t;
                           log_level : standard_log_level_t) is
  begin
    for level in log_level_t'low to log_level_t'high loop
      if is_standard(level) then
        if level >= log_level then
          set_stop_count(logger, level, 1);
        else
          set_stop_count(logger, level, integer'high);
        end if;
      end if;
    end loop;
  end;

  procedure disable_stop is
  begin
    disable_stop(root_logger);
  end;

  -- Disable stopping simulation
  procedure disable_stop(logger : logger_t) is
  begin
    for level in log_level_t'low to log_level_t'high loop
      set_stop_count(logger, level, integer'high);
    end loop;
  end;

  impure function get_log_level_filter(logger : logger_t;
                                       log_handler : log_handler_t) return integer_vector_ptr_t is
    constant log_level_filters : integer_vector_ptr_t :=
      to_integer_vector_ptr(get(logger.p_data, log_level_filters_idx));
    constant handler_id : natural := get_id(log_handler);
  begin
    if handler_id >= length(log_level_filters) then
      resize(log_level_filters, handler_id + 1, value => to_integer(null_ptr));
    end if;

    return to_integer_vector_ptr(get(log_level_filters, handler_id));
  end;

  impure function get_log_level_filter(logger : logger_t;
                                       log_handler : log_handler_t;
                                       enabled : boolean) return log_level_vec_t is
    variable ret : log_level_vec_t(0 to n_log_levels - 1);
    variable idx : natural := 0;
    constant log_level_filter : integer_vector_ptr_t := get_log_level_filter(logger, log_handler);
    variable log_level_setting : natural;
    variable log_level : log_level_t;
  begin
    if log_level_filter = null_ptr then
      return null_vec;
    end if;

    if enabled then
      log_level_setting := log_level_enabled;
    else
      log_level_setting := log_level_disabled;
    end if;

    for i in 0 to length(log_level_filter) - 1 loop
      log_level := log_level_t'val(i);
      if get(log_level_filter, i) = log_level_setting and is_valid(log_level) then
        ret(idx) := log_level;
        idx := idx + 1;
      end if;
    end loop;

    return ret(0 to idx - 1);
  end;

  impure function get_enabled_log_levels(logger : logger_t;
                                         log_handler : log_handler_t) return log_level_vec_t is
  begin
    return get_log_level_filter(logger, log_handler, enabled => true);
  end;

  impure function get_disabled_log_levels(logger : logger_t;
                                          log_handler : log_handler_t) return log_level_vec_t is
  begin
    return get_log_level_filter(logger, log_handler, enabled => false);
  end;

  -- Disable logging for all levels < level to this handler for this specific logger
  procedure set_log_level(logger : logger_t;
                          log_handler : log_handler_t;
                          level : standard_log_level_t) is
  begin
    for lvl in log_level_t'low to log_level_t'high loop
      if is_standard(lvl) then
        if lvl < level then
          disable(logger, log_handler, lvl);
        else
          enable(logger, log_handler, lvl);
        end if;
      end if;
    end loop;
  end;

  -- Disable logging for all levels < level to this handler
  procedure set_log_level(log_handler : log_handler_t;
                          level : standard_log_level_t) is
  begin
    set_log_level(root_logger, log_handler, level);
  end;

  -- Disable logging for the specified level to this handler from specific
  -- logger and all children.
  procedure disable(logger : logger_t;
                    log_handler : log_handler_t;
                    level : log_level_t) is
  begin
    set_log_level_filter(logger, log_handler, (0 => level), enabled => false);
  end;

  -- Disable logging for the specified level to this handler
  procedure disable(log_handler : log_handler_t;
                    level : log_level_t) is
  begin
    disable(root_logger, log_handler, level);
  end;
  -- Disable logging for the specified levels to this handler from specific
  -- logger and all children.
  procedure disable(logger : logger_t;
                    log_handler : log_handler_t;
                    levels : log_level_vec_t) is
  begin
    set_log_level_filter(logger, log_handler, levels, enabled => false);
  end;

  -- Disable logging for the specified levels to this handler
  procedure disable(log_handler : log_handler_t;
                    levels : log_level_vec_t) is
  begin
    disable(root_logger, log_handler, levels);
  end;

  procedure disable_all(logger : logger_t;
                        log_handler : log_handler_t) is
  begin
    for log_level in log_level_t'low to log_level_t'high loop
      disable(logger, log_handler, log_level);
    end loop;
  end;

  procedure disable_all(log_handler : log_handler_t) is
  begin
    disable_all(root_logger, log_handler);
  end;

  -- Enable logging for the specified level to this handler from specific
  -- logger and all children.
  procedure enable(logger : logger_t;
                   log_handler : log_handler_t;
                   level : log_level_t) is
  begin
    set_log_level_filter(logger, log_handler, (0 => level), enabled => true);
  end;

  -- Enable logging for the specified level to this handler
  procedure enable(log_handler : log_handler_t;
                    level : log_level_t) is
  begin
    enable(root_logger, log_handler, level);
  end;

  -- Enable logging for the specified levels to this handler from specific
  -- logger and all children.
  procedure enable(logger : logger_t;
                   log_handler : log_handler_t;
                   levels : log_level_vec_t) is
  begin
    set_log_level_filter(logger, log_handler, levels, enabled => true);
  end;

  -- Enable logging for the specified levels to this handler
  procedure enable(log_handler : log_handler_t;
                   levels : log_level_vec_t) is
  begin
    enable(root_logger, log_handler, levels);
  end;

  procedure enable_all(logger : logger_t;
                       log_handler : log_handler_t) is
  begin
    for log_level in log_level_t'low to log_level_t'high loop
      enable(logger, log_handler, log_level);
    end loop;
  end;

  procedure enable_all(log_handler : log_handler_t) is
  begin
    enable_all(root_logger, log_handler);
  end;

  impure function is_enabled(logger : logger_t;
                             level : log_level_t) return boolean is
  begin
    if is_mocked(logger) then
      return true;
    end if;

    for i in 0 to num_log_handlers(logger)-1 loop
      if is_enabled(logger, get_log_handler(logger, i), level) then
        return true;
      end if;
    end loop;

    return false;
  end;

  impure function is_enabled(logger : logger_t;
                             log_handler : log_handler_t;
                             level : log_level_t) return boolean is
    constant log_level_filter : integer_vector_ptr_t := get_log_level_filter(logger, log_handler);
  begin
    assert log_level_filter /= null_ptr;
    return get(log_level_filter, log_level_t'pos(level)) = log_level_enabled;
  end;

  impure function num_log_handlers(logger : logger_t) return natural is
    constant handlers : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, handlers_idx));
  begin
    return length(handlers);
  end;

  impure function get_log_handler(logger : logger_t; idx : natural) return log_handler_t is
    constant handlers : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, handlers_idx));
  begin
    return (p_data => to_integer_vector_ptr(get(handlers, idx)));
  end;

  impure function get_log_handlers(logger : logger_t) return log_handler_vec_t is
    constant handlers : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, handlers_idx));
    variable result : log_handler_vec_t(0 to length(handlers)-1);
  begin
    for i in result'range loop
      result(i) := (p_data => to_integer_vector_ptr(get(handlers, i)));
    end loop;
    return result;
  end;

  procedure set_log_handlers(logger : logger_t;
                             log_handlers : log_handler_vec_t) is
  begin
    p_set_log_handlers(logger, log_handlers);

    for i in 0 to num_children(logger)-1 loop
      set_log_handlers(get_child(logger, i), log_handlers);
    end loop;
  end;

  procedure clear_log_count(logger : logger_t; idx : natural) is
    constant log_counts : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, idx));
  begin
    for lvl in log_level_t'low to log_level_t'high loop
      set(log_counts, log_level_t'pos(lvl), 0);
    end loop;
  end;

  impure function get_log_count(logger : logger_t;
                                idx : natural;
                                log_level : log_level_t := null_log_level) return natural is
    constant log_counts : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, idx));
    variable result : natural;
  begin
    if log_level = null_log_level then
      result := 0;
      for lvl in log_level_t'low to log_level_t'high loop
        result := result + get(log_counts, log_level_t'pos(lvl));
      end loop;
    else
      result := get(log_counts, log_level_t'pos(log_level));
    end if;

    return result;
  end;

  procedure reset_log_count(
    logger : logger_t;
    log_level : log_level_t := null_log_level) is
    constant log_counts : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, log_count_idx));
  begin
    if log_level = null_log_level then
      for lvl in log_level_t'low to log_level_t'high loop
        set(log_counts, log_level_t'pos(lvl), 0);
      end loop;
    else
      set(log_counts, log_level_t'pos(log_level), 0);
    end if;
  end;

  impure function get_log_count return natural is
  begin
    return get(global_log_count, 0);
  end;

  impure function get_log_count(logger : logger_t; log_level : log_level_t := null_log_level) return natural is
  begin
    return get_log_count(logger, log_count_idx, log_level);
  end;

  -- Helper method to count either the normal log count or the mocked log count
  procedure count_log_helper(logger : logger_t;
                             idx : natural; -- Index in p_data for log count vector
                             log_level : log_level_t) is
    constant log_counts : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, idx));
  begin
    set(log_counts, log_level_t'pos(log_level), get(log_counts, log_level_t'pos(log_level)) + 1);
  end;

  procedure check_stop_condition(logger : logger_t;
                                 log_level : log_level_t) is
    constant log_count : natural := get_log_count(logger, log_level);
    constant stop_count : natural := get_stop_count(logger, log_level);
  begin
    if log_count >= stop_count then
      core_failure("Stop simulation on log level " & get_name(log_level) & ". " &
                   "Log count " & integer'image(log_count) & " >= " &
                   "stop count " & integer'image(stop_count));
    end if;
  end;

  procedure count_log_no_mock(logger : logger_t; log_level : log_level_t) is
  begin
    set(global_log_count, 0, get(global_log_count, 0) + 1);
    count_log_helper(logger, log_count_idx, log_level);
    check_stop_condition(logger, log_level);
  end;

  procedure mock(logger : logger_t) is
  begin
    set(logger.p_data, is_mocked_idx, 1);
  end;

  impure function get_mocked_log_queue(logger : logger_t) return queue_t is
  begin
    return (p_meta => to_integer_vector_ptr(get(logger.p_data, mocked_log_queue_meta_idx)),
            data => to_string_ptr(get(logger.p_data, mocked_log_queue_data_idx)));
  end;

  impure function make_string(msg : string;
                              log_level : log_level_t;
                              log_time : time;
                              line_num : natural;
                              file_name : string;
                              check_time : boolean) return string is
    constant without_time : string := ("   log_level = " & get_name(log_level) & LF &
                                       "   msg = " & msg & LF &
                                       "   file_name:line_num = " & file_name & ":" & integer'image(line_num));
  begin
    if check_time then
      return "   time = " & time'image(log_time) & LF & without_time;
    else
      return without_time;
    end if;
  end;

  impure function pop_log_item_string(logger : logger_t; check_time : boolean) return string is
    constant queue : queue_t := get_mocked_log_queue(logger);
    constant got_level : log_level_t := log_level_t'val(pop_byte(queue));
    constant got_msg : string := pop_string(queue);
    constant got_log_time : time := pop_time(queue);
    constant got_line_num : natural := pop_integer(queue);
    constant got_file_name : string := pop_string(queue);
  begin
    return make_string(got_msg, got_level, got_log_time, got_line_num, got_file_name, check_time);
  end;

  impure function get_mock_log_count(logger : logger_t; log_level : log_level_t := null_log_level) return natural is
  begin
    return get_log_count(logger, mock_log_count_idx, log_level);
  end;

  procedure check_log(logger : logger_t;
                      msg : string;
                      log_level : log_level_t;
                      log_time : time := no_time_check;
                      line_num : natural := 0;
                      file_name : string := "") is

    constant expected_item : string := make_string(msg, log_level, log_time, line_num, file_name,
                                                   log_time /= no_time_check);

    constant queue : queue_t := get_mocked_log_queue(logger);

    procedure check_log_when_not_empty is
      constant got_item : string := pop_log_item_string(logger, log_time /= no_time_check);
    begin
      if expected_item /= got_item then
        core_failure("log item mismatch:" & LF & LF & "Got:" & LF & got_item & LF & LF & "expected:" & LF & expected_item & LF);
      end if;
    end;
  begin
    if length(queue) > 0 then
      check_log_when_not_empty;
    else
      core_failure("log item mismatch - Got no log item " & LF & LF & "expected" & LF & expected_item & LF);
    end if;
  end;

  procedure check_only_log(logger : logger_t;
                           msg : string;
                           log_level : log_level_t;
                           log_time : time := no_time_check;
                           line_num : natural := 0;
                           file_name : string := "") is
  begin
    check_log(logger, msg, log_level, log_time, line_num, file_name);
    check_no_log(logger);
  end;

  procedure check_no_log(logger : logger_t) is
    constant queue : queue_t := get_mocked_log_queue(logger);
    variable fail : boolean := length(queue) > 0;
  begin
    while length(queue) > 0 loop
      report "Got unexpected log item " & LF & LF & pop_log_item_string(logger, true) & LF;
    end loop;

    if fail then
      core_failure("Got unexpected log items");
    end if;
  end;

  procedure unmock(logger : logger_t) is
  begin
    check_no_log(logger);
    set(logger.p_data, is_mocked_idx, 0);
    clear_log_count(logger, mock_log_count_idx);
  end;

  procedure mock_log(logger : logger_t;
                     msg : string;
                     log_level : log_level_t;
                     log_time : time;
                     line_num : natural := 0;
                     file_name : string := "") is
    constant queue : queue_t := get_mocked_log_queue(logger);
  begin
    report ("Got mocked log item to (" & get_full_name(logger) & ")" & LF &
            make_string(msg, log_level, log_time, line_num, file_name, check_time => true)
            & LF);
    count_log_helper(logger, mock_log_count_idx, log_level);

    push_byte(queue, log_level_t'pos(log_level));
    push_string(queue, msg);
    push_time(queue, log_time);
    push_integer(queue, line_num);
    push_string(queue, file_name);
  end;

  procedure log(logger : logger_t;
                msg : string;
                log_level : log_level_t := info;
                line_num : natural := 0;
                file_name : string := "") is

    variable log_handler : log_handler_t;
    constant t_now : time := now;
    constant sequence_number : natural := get_log_count;
  begin
    if logger = null_logger then
      core_failure("Attempt to log to uninitialized logger");
    elsif is_mocked(logger) then
      mock_log(logger, msg, log_level, t_now, line_num, file_name);
    else
      for i in 0 to num_log_handlers(logger) - 1 loop
        log_handler := get_log_handler(logger, i);
        if is_enabled(logger, log_handler, log_level) then
          log_to_handler(log_handler, get_full_name(logger), msg, log_level,
                         t_now, sequence_number,
                         line_num, file_name);
        end if;
      end loop;

      count_log_no_mock(logger, log_level);
    end if;
  end procedure;

  procedure debug(logger : logger_t;
                  msg : string;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    log(logger, msg, debug, line_num, file_name);
  end procedure;

  procedure verbose(logger : logger_t;
                    msg : string;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    log(logger, msg, verbose, line_num, file_name);
  end procedure;

  procedure info(logger : logger_t;
                 msg : string;
                 line_num : natural := 0;
                 file_name : string := "") is
  begin
    log(logger, msg, info, line_num, file_name);
  end procedure;

  procedure warning(logger : logger_t;
                    msg : string;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    log(logger, msg, warning, line_num, file_name);
  end procedure;

  procedure error(logger : logger_t;
                  msg : string;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    log(logger, msg, error, line_num, file_name);
  end procedure;

  procedure failure(logger : logger_t;
                    msg : string;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    log(logger, msg, failure, line_num, file_name);
  end procedure;

  constant p_default_logger : logger_t := get_logger("default");
  impure function default_logger return logger_t is
  begin
    return p_default_logger;
  end;

  procedure log(msg : string;
                log_level : log_level_t := info;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    log(default_logger, msg, log_level, line_num, file_name);
  end;

  procedure debug(msg : string;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    debug(default_logger, msg, line_num, file_name);
  end procedure;

  procedure verbose(msg : string;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    verbose(default_logger, msg, line_num, file_name);
  end procedure;

  procedure info(msg : string;
                 line_num : natural := 0;
                 file_name : string := "") is
  begin
    info(default_logger, msg, line_num, file_name);
  end procedure;

  procedure warning(msg : string;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    warning(default_logger, msg, line_num, file_name);
  end procedure;

  procedure error(msg : string;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    error(default_logger, msg, line_num, file_name);
  end procedure;

  procedure failure(msg : string;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    failure(default_logger, msg, line_num, file_name);
  end procedure;

end package body;
