-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body logger_pkg is
  constant global_log_count : integer_vector_ptr_t := new_integer_vector_ptr(1, value => 0);
  constant p_mock_queue_length : integer_vector_ptr_t := new_integer_vector_ptr(1, value => 0);
  constant mock_queue : queue_t := new_queue;

  constant id_idx : natural := 0;
  constant parent_idx : natural := 1;
  constant children_idx : natural := 2;
  constant log_count_idx : natural := 3;
  constant stop_counts_idx : natural := 4;
  constant handlers_idx : natural := 5;
  constant state_idx : natural := 6;
  constant log_level_filters_idx : natural := 7;
  constant logger_length : natural := 8;

  constant log_level_invisible : integer := 0;
  constant log_level_visible : integer := 1;

  constant stop_count_unset : integer := 0;
  constant stop_count_infinite : integer := integer'high;

  constant enabled_state : natural := 0;
  constant disabled_state : natural := 1;
  constant mocked_state : natural := 2;

  constant n_log_levels : natural := log_level_t'pos(log_level_t'high) + 1;

  impure function to_integer(logger : logger_t) return integer is
  begin
    return to_integer(logger.p_data);
  end;

  impure function to_logger(value : integer) return logger_t is
  begin
    return (p_data => to_integer_vector_ptr(value));
  end;

  procedure add_child(logger : logger_t; child : logger_t) is
    constant children : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, children_idx));
  begin
    resize(children, length(children)+1);
    set(children, length(children)-1, to_integer(child));
  end;

  impure function new_logger(id : id_t;
                             parent : logger_t) return logger_t is
    variable logger : logger_t;
    variable log_handler : log_handler_t;
  begin
    logger := (p_data => new_integer_vector_ptr(logger_length));
    set(logger.p_data, id_idx, to_integer(id));

    set(logger.p_data, parent_idx, to_integer(parent));
    set(logger.p_data, children_idx, to_integer(new_integer_vector_ptr));
    set(logger.p_data, log_count_idx, to_integer(new_integer_vector_ptr(log_level_t'pos(log_level_t'high)+1, value => 0)));
    set(logger.p_data, stop_counts_idx, to_integer(new_integer_vector_ptr(log_level_t'pos(log_level_t'high)+1, value => stop_count_unset)));
    set(logger.p_data, handlers_idx, to_integer(new_integer_vector_ptr));
    set(logger.p_data, state_idx, to_integer(new_integer_vector_ptr(log_level_t'pos(log_level_t'high)+1, value => enabled_state)));
    set(logger.p_data, log_level_filters_idx, to_integer(new_integer_vector_ptr));

    if parent /= null_logger then
      add_child(parent, logger);

      -- Re-use parent log handlers and log level settings
      set_log_handlers(logger, get_log_handlers(parent));

      for i in 0 to num_log_handlers(parent)-1 loop
        log_handler := get_log_handler(parent, i);
        show(logger, log_handler, get_visible_log_levels(parent, log_handler));
        hide(logger, log_handler, get_invisible_log_levels(parent, log_handler));
      end loop;

    end if;

    return logger;
  end;

  procedure p_set_log_handlers(logger : logger_t;
                               log_handlers : log_handler_vec_t) is
    constant handlers : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, handlers_idx));
    constant full_logger_name : string := get_full_name(logger);
  begin
    resize(handlers, log_handlers'length);

    for i in log_handlers'range loop
      set(handlers, i, to_integer(log_handlers(i).p_data));
      update_max_logger_name_length(log_handlers(i), full_logger_name'length);
    end loop;
  end;

  -- @NOTE this procedure needs to be above root logger creation to around
  -- Riviera-PRO elaboration bug
  procedure set_log_level_filter(logger : logger_t;
                                 log_handler : log_handler_t;
                                 log_levels : log_level_vec_t;
                                 visible : boolean;
                                 include_children : boolean) is
    constant log_level_filters : integer_vector_ptr_t :=
      to_integer_vector_ptr(get(logger.p_data, log_level_filters_idx));
    constant handler_id_number : natural := get_id_number(log_handler);
    variable log_level_filter : integer_vector_ptr_t;
    variable log_level_setting : natural;

  begin
    if handler_id_number >= length(log_level_filters) then
      resize(log_level_filters, handler_id_number + 1, value => to_integer(null_ptr));
    end if;

    log_level_filter := to_integer_vector_ptr(get(log_level_filters, handler_id_number));

    if log_level_filter = null_ptr then
      -- Only show valid log levels by default
      log_level_filter := new_integer_vector_ptr(length => n_log_levels, value => log_level_invisible);
      for log_level in log_level_t'low to log_level_t'high loop
        if is_valid(log_level) then
          set(log_level_filter, log_level_t'pos(log_level), log_level_visible);
        end if;
      end loop;

      set(log_level_filters, handler_id_number, to_integer(log_level_filter));
    end if;

    if visible then
      log_level_setting := log_level_visible;
    else
      log_level_setting := log_level_invisible;
    end if;

    for i in log_levels'range loop
      set(log_level_filter, log_level_t'pos(log_levels(i)), log_level_setting);
    end loop;

    if include_children then
      for i in 0 to num_children(logger)-1 loop
        set_log_level_filter(get_child(logger, i), log_handler, log_levels, visible,
                             include_children => true);
      end loop;
    end if;
  end;

  impure function get_id(logger : logger_t) return id_t is
  begin
    return to_id(get(logger.p_data, id_idx));
  end;

  impure function get_real_parent(parent : logger_t) return logger_t is
  begin
    if parent = null_logger then
      return root_logger;
    end if;
    return parent;
  end;

  impure function has_logger(id : id_t) return boolean is
    impure function has_logger(lineage : id_vec_t; search_root : logger_t) return boolean is
      constant n_children : natural := num_children(search_root);
      variable child : logger_t;
      variable child_id : id_t;
    begin
      for idx in 0 to n_children - 1 loop
        child := get_child(search_root, idx);
        child_id := get_id(child);

        if child_id = lineage(lineage'left) then
          if lineage'length = 1 then
            return true;
          end if;

          return has_logger(lineage(lineage'left + 1 to lineage'right), child);
        end if;
      end loop;

      return false;
    end;

    constant lineage : id_vec_t := get_lineage(id);
  begin
    if id = root_id then
      return false;
    end if;

    return has_logger(lineage(lineage'left + 1 to lineage'right), root_logger);
  end;

  impure function get_logger(id : id_t) return logger_t is
    impure function get_logger(lineage : id_vec_t; parent : logger_t) return logger_t is
      constant n_children : natural := num_children(parent);
      variable child : logger_t;
      variable child_id : id_t;
      variable logger : logger_t := null_logger;
    begin
      for idx in 0 to n_children - 1 loop
        child := get_child(parent, idx);
        child_id := get_id(child);
        if child_id = lineage(lineage'left) then
          logger := child;
          exit;
        end if;
      end loop;

      if logger = null_logger then
        logger := new_logger(lineage(lineage'left), parent);
        set_log_handlers(logger, get_log_handlers(parent));
      end if;

      if lineage'length > 1 then
        return get_logger(lineage(lineage'left + 1 to lineage'right), logger);
      end if;

      return logger;
    end;

    constant lineage : id_vec_t := get_lineage(id);
  begin
    if id = null_id then
      return null_logger;
    end if;

    return get_logger(lineage(lineage'left + 1 to lineage'right), root_logger);
  end;

  impure function get_logger(name : string;
                             parent : logger_t := null_logger) return logger_t is
    constant real_parent : logger_t := get_real_parent(parent);
    constant id : id_t := get_id(name, get_id(real_parent));
  begin
    if id = null_id then
      return null_logger;
    end if;

    return get_logger(id);
  end;

  impure function get_full_name(logger : logger_t) return string is
  begin
    return full_name(get_id(logger));
  end;

  impure function get_max_name_length(logger : logger_t) return natural is
    constant full_name : string := get_full_name(logger);
    variable result : natural := 0;
    variable child_result : natural;
  begin
    if num_children(logger) = 0 then
      return full_name'length;
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
    return name(get_id(logger));
  end;

  impure function get_parent(logger : logger_t) return logger_t is
  begin
    return (p_data => to_integer_vector_ptr(get(logger.p_data, parent_idx)));
  end;

  impure function get_state(logger : logger_t; log_level : log_level_t) return natural is
    constant state_vec : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, state_idx));
  begin
    return get(state_vec, log_level_t'pos(log_level));
  end;

  procedure set_state(logger : logger_t; log_level : log_level_t; state : natural) is
    constant state_vec : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, state_idx));
  begin
    set(state_vec, log_level_t'pos(log_level), state);
  end;

  impure function is_disabled(logger : logger_t;
                              log_level : log_level_t) return boolean is
  begin
    return get_state(logger, log_level) = disabled_state;
  end;

  impure function is_mocked(logger : logger_t; log_level : log_level_t) return boolean is
  begin
    return get_state(logger, log_level) = mocked_state;
  end;

  impure function is_mocked(logger : logger_t) return boolean is
  begin
    for log_level in legal_log_level_t'low to legal_log_level_t'high loop
      if is_mocked(logger, log_level) then
        return true;
      end if;
    end loop;
    return false;
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

  procedure p_set_stop_count(logger : logger_t;
                             log_level : log_level_t;
                             value : natural;
                             unset_children : boolean := false) is
    constant stop_counts : integer_vector_ptr_t := to_integer_vector_ptr(
      get(logger.p_data, stop_counts_idx));
    constant log_level_idx : natural := log_level_t'pos(log_level);
  begin
    if log_level_idx >= length(stop_counts) then
      resize(stop_counts, log_level_idx + 1, value => integer'high);
    end if;

    set(stop_counts, log_level_idx, value);

    if unset_children then
      for idx in 0 to num_children(logger)-1 loop
        p_set_stop_count(get_child(logger, idx), log_level, stop_count_unset,
                         unset_children => true);
      end loop;
    end if;
  end;


  procedure set_stop_count(logger : logger_t;
                           log_level : log_level_t;
                           value : positive;
                           unset_children : boolean := false) is
  begin
    p_set_stop_count(logger, log_level, value, unset_children);
  end;

  procedure disable_stop(logger : logger_t;
                                    log_level : log_level_t;
                                    unset_children : boolean := false) is
  begin
    p_set_stop_count(logger, log_level, stop_count_infinite, unset_children);
  end;

  procedure set_stop_count(log_level : log_level_t;
                           value : positive) is
  begin
    set_stop_count(root_logger, log_level, value, unset_children => true);
  end;

  procedure disable_stop(log_level : log_level_t) is
  begin
    disable_stop(root_logger, log_level, unset_children => true);
  end;

  procedure set_stop_level(level : alert_log_level_t) is
  begin
    set_stop_level(root_logger, level);
  end;

  procedure set_stop_level(logger : logger_t;
                           log_level : alert_log_level_t) is
  begin
    for level in log_level_t'low to log_level_t'high loop
      disable_stop(logger, level,
                              unset_children => true);
    end loop;

    for level in alert_log_level_t'low to alert_log_level_t'high loop
      if level >= log_level then
        set_stop_count(logger, level, 1,
                       unset_children => true);
      end if;
    end loop;
  end;

  procedure unset_stop_count(logger : logger_t;
                             log_level : log_level_t;
                             unset_children : boolean := false) is
  begin
    p_set_stop_count(logger, log_level, stop_count_unset, unset_children);
  end;

  impure function p_get_stop_count(logger : logger_t;
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

  impure function get_stop_count(logger : logger_t;
                                 log_level : log_level_t) return positive is
    constant stop_count : integer := p_get_stop_count(logger, log_level);
  begin
    if stop_count = stop_count_unset then
      core_failure("Logger " & get_full_name(logger) & " has no stop count set");
    end if;

    return stop_count;
  end;

  impure function has_stop_count(logger : logger_t;
                                 log_level : log_level_t) return boolean is
    constant stop_count : integer := p_get_stop_count(logger, log_level);
  begin
    return stop_count /= stop_count_unset;
  end;

  impure function get_log_level_filter(logger : logger_t;
                                       log_handler : log_handler_t) return integer_vector_ptr_t is
    constant log_level_filters : integer_vector_ptr_t :=
      to_integer_vector_ptr(get(logger.p_data, log_level_filters_idx));
    constant handler_id_number : natural := get_id_number(log_handler);
  begin
    if handler_id_number >= length(log_level_filters) then
      resize(log_level_filters, handler_id_number + 1, value => to_integer(null_ptr));
    end if;

    return to_integer_vector_ptr(get(log_level_filters, handler_id_number));
  end;

  impure function get_log_level_filter(logger : logger_t;
                                       log_handler : log_handler_t;
                                       visible : boolean) return log_level_vec_t is
    variable ret : log_level_vec_t(0 to n_log_levels - 1);
    variable idx : natural := 0;
    constant log_level_filter : integer_vector_ptr_t := get_log_level_filter(logger, log_handler);
    variable log_level_setting : natural;
    variable log_level : log_level_t;
  begin
    if log_level_filter = null_ptr then
      return null_vec;
    end if;

    if visible then
      log_level_setting := log_level_visible;
    else
      log_level_setting := log_level_invisible;
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

  impure function get_visible_log_levels(logger : logger_t;
                                         log_handler : log_handler_t) return log_level_vec_t is
  begin
    return get_log_level_filter(logger, log_handler, visible => true);
  end;

  impure function get_invisible_log_levels(logger : logger_t;
                                           log_handler : log_handler_t) return log_level_vec_t is
  begin
    return get_log_level_filter(logger, log_handler, visible => false);
  end;

  procedure disable(logger : logger_t;
                    log_level : log_level_t;
                    include_children : boolean := true) is
  begin
    set_state(logger, log_level, disabled_state);

    if include_children then
      for idx in 0 to num_children(logger)-1 loop
        disable(get_child(logger, idx), log_level, include_children => true);
      end loop;
    end if;
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
    hide(root_logger, log_handler, log_level, include_children => true);
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
    hide(root_logger, log_handler, log_levels);
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
    hide_all(root_logger, log_handler, include_children => true);
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
    show(root_logger, log_handler, log_level, include_children => true);
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
    show(root_logger, log_handler, log_levels, include_children => true);
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
    show_all(root_logger, log_handler, include_children => true);
  end;

  impure function is_visible(logger : logger_t;
                             log_level : log_level_t) return boolean is
    constant state : natural := get_state(logger, log_level);
  begin
    if state = mocked_state then
      return true;
    elsif state = disabled_state then
      return false;
    end if;

    for i in 0 to num_log_handlers(logger)-1 loop
      if is_visible(logger, get_log_handler(logger, i), log_level) then
        return true;
      end if;
    end loop;

    return false;
  end;

  impure function is_visible(logger : logger_t;
                             log_handler : log_handler_t;
                             log_level : log_level_t) return boolean is
    constant log_level_filter : integer_vector_ptr_t := get_log_level_filter(logger, log_handler);
  begin
    if log_level_filter /= null_ptr then
      return get(log_level_filter, log_level_t'pos(log_level)) = log_level_visible;
    else
      return false;
    end if;
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
                             log_handlers : log_handler_vec_t;
                             include_children : boolean := true) is
  begin
    p_set_log_handlers(logger, log_handlers);

    if include_children then
      for i in 0 to num_children(logger)-1 loop
        set_log_handlers(get_child(logger, i), log_handlers,
                         include_children => true);
      end loop;
    end if;
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

  procedure reset_log_count(logger : logger_t;
                            log_level : log_level_t := null_log_level;
                            include_children : boolean := true) is
    constant log_counts : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, log_count_idx));
  begin
    if log_level = null_log_level then
      for lvl in log_level_t'low to log_level_t'high loop
        set(log_counts, log_level_t'pos(lvl), 0);
      end loop;
    else
      set(log_counts, log_level_t'pos(log_level), 0);
    end if;

    if include_children then
      for idx in 0 to num_children(logger)-1 loop
        reset_log_count(get_child(logger, idx), log_level, include_children => true);
      end loop;
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

  procedure decrease_stop_count(logger : logger_t;
                                log_level : log_level_t) is
    constant stop_count : natural := p_get_stop_count(logger, log_level);
    variable parent : logger_t;
  begin
    if stop_count = stop_count_unset then
      parent := get_parent(logger);
      if parent = null_logger then
        core_failure("Stop condition not set on root_logger");
      else
        decrease_stop_count(parent, log_level);
      end if;
    elsif stop_count = stop_count_infinite then
      null;
    elsif stop_count = 1 then
      core_failure("Stop simulation on log level " & get_name(log_level));
    else
      p_set_stop_count(logger, log_level, stop_count - 1, unset_children => false);
    end if;
  end;

  procedure count_log(logger : logger_t; log_level : log_level_t) is
    constant log_counts : integer_vector_ptr_t := to_integer_vector_ptr(get(logger.p_data, log_count_idx));
  begin
    set(global_log_count, 0, get(global_log_count, 0) + 1);
    set(log_counts, log_level_t'pos(log_level), get(log_counts, log_level_t'pos(log_level)) + 1);
  end;

  procedure mock(logger : logger_t) is
  begin
    for log_level in legal_log_level_t'low to legal_log_level_t'high loop
      mock(logger, log_level);
    end loop;
  end;

  procedure mock(logger : logger_t; log_level : log_level_t) is
  begin
    set_state(logger, log_level, mocked_state);
  end;

  impure function make_string(logger_name : string;
                              msg : string;
                              log_level : log_level_t;
                              log_time : time;
                              line_num : natural;
                              file_name : string;
                              check_time : boolean) return string is
    constant without_time : string := ("   logger = " & logger_name & LF &
                                       "   log_level = " & get_name(log_level) & LF &
                                       "   msg = " & msg & LF &
                                       "   file_name:line_num = " & file_name & ":" & integer'image(line_num));
  begin
    if check_time then
      return "   time = " & time'image(log_time) & LF & without_time;
    else
      return without_time;
    end if;
  end;

  impure function pop_log_item_string(check_time : boolean) return string is
    constant got_logger_name : string := pop_string(mock_queue);
    constant got_level : log_level_t := log_level_t'val(pop_byte(mock_queue));
    constant got_msg : string := pop_string(mock_queue);
    constant got_log_time : time := pop_time(mock_queue);
    constant got_line_num : natural := pop_integer(mock_queue);
    constant got_file_name : string := pop_string(mock_queue);
  begin
    set(p_mock_queue_length, 0, get(p_mock_queue_length, 0) - 1);
    return make_string(got_logger_name, got_msg, got_level, got_log_time, got_line_num, got_file_name, check_time);
  end;

  procedure check_log(logger : logger_t;
                      msg : string;
                      log_level : log_level_t;
                      log_time : time := no_time_check;
                      line_num : natural := 0;
                      file_name : string := "") is

    constant expected_item : string := make_string(get_full_name(logger),
                                                   msg, log_level, log_time, line_num, file_name,
                                                   log_time /= no_time_check);

    procedure check_log_when_not_empty is
      constant got_item : string := pop_log_item_string(log_time /= no_time_check);
    begin
      if expected_item /= got_item then
        core_failure("log item mismatch:" & LF & LF & "Got:" & LF & got_item & LF & LF & "expected:" & LF & expected_item & LF);
      end if;
    end;
  begin
    if length(mock_queue) > 0 then
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
    check_no_log;
  end;

  procedure check_no_log is
    constant fail : boolean := length(mock_queue) > 0;
  begin
    while length(mock_queue) > 0 loop
      report "Got unexpected log item " & LF & LF & pop_log_item_string(true) & LF;
    end loop;

    if fail then
      core_failure("Got unexpected log items");
    end if;
  end;

  impure function mock_queue_length return natural is
  begin
    return get(p_mock_queue_length, 0);
  end;

  procedure unmock(logger : logger_t) is
  begin
    check_no_log;

    for log_level in legal_log_level_t'low to legal_log_level_t'high loop
      if is_mocked(logger, log_level) then
        set_state(logger, log_level, enabled_state);
      end if;
    end loop;
  end;

  procedure mock_log(logger : logger_t;
                     msg : string;
                     log_level : log_level_t;
                     log_time : time;
                     line_num : natural := 0;
                     file_name : string := "") is
  begin
    report ("Got mocked log item " & LF &
            make_string(get_full_name(logger), msg, log_level, log_time, line_num, file_name,
                        check_time => true) & LF);
    push_string(mock_queue, get_full_name(logger));
    push_byte(mock_queue, log_level_t'pos(log_level));
    push_string(mock_queue, msg);
    push_time(mock_queue, log_time);
    push_integer(mock_queue, line_num);
    push_string(mock_queue, file_name);

    set(p_mock_queue_length, 0, get(p_mock_queue_length, 0) + 1);
  end;

  procedure log(logger : logger_t;
                msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "") is

    variable log_handler : log_handler_t;
    constant t_now : time := now;
    constant sequence_number : natural := get_log_count;
    variable state : natural;
    variable location : location_t := get_location(path_offset + 1, line_num, file_name);
  begin
    if logger = null_logger then
      core_failure("Attempt to log to uninitialized logger");
      deallocate(location);
      return;
    end if;

    state := get_state(logger, log_level);

    if state = mocked_state then
      mock_log(logger, msg, log_level, t_now, location.line_num, location.file_name.all);
    else
      if state = enabled_state then
        for i in 0 to num_log_handlers(logger) - 1 loop
          log_handler := get_log_handler(logger, i);
          if is_visible(logger, log_handler, log_level) then
            log_to_handler(log_handler, get_full_name(logger), msg, log_level,
                           t_now, sequence_number,
                           location.line_num, location.file_name.all);
          end if;
        end loop;

        decrease_stop_count(logger, log_level);
      end if;

      -- Count even if disabled
      count_log(logger, log_level);
    end if;

    deallocate(location);
  end procedure;

  procedure debug(logger : logger_t;
                  msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    log(logger, msg, debug, path_offset + 1, line_num, file_name);
  end procedure;

  procedure pass(logger : logger_t;
                 msg : string;
                 path_offset : natural := 0;
                 line_num : natural := 0;
                 file_name : string := "") is
  begin
    log(logger, msg, pass, path_offset + 1, line_num, file_name);
  end procedure;

  procedure trace(logger : logger_t;
                  msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    log(logger, msg, trace, path_offset + 1, line_num, file_name);
  end procedure;

  procedure info(logger : logger_t;
                 msg : string;
                 path_offset : natural := 0;
                 line_num : natural := 0;
                 file_name : string := "") is
  begin
    log(logger, msg, info, path_offset + 1, line_num, file_name);
  end procedure;

  procedure warning(logger : logger_t;
                    msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    log(logger, msg, warning, path_offset + 1, line_num, file_name);
  end procedure;

  procedure error(logger : logger_t;
                  msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    log(logger, msg, error, path_offset + 1, line_num, file_name);
  end procedure;

  procedure failure(logger : logger_t;
                    msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    log(logger, msg, failure, path_offset + 1, line_num, file_name);
  end procedure;

  procedure warning_if(logger : logger_t;
                       condition : boolean;
                       msg : string;
                       path_offset : natural := 0;
                       line_num : natural := 0;
                       file_name : string := "") is
  begin
    if condition then
      warning(logger, msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  procedure error_if(logger : logger_t;
                     condition : boolean;
                     msg : string;
                     path_offset : natural := 0;
                     line_num : natural := 0;
                     file_name : string := "") is
  begin
    if condition then
      error(logger, msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  procedure failure_if(logger : logger_t;
                       condition : boolean;
                       msg : string;
                       path_offset : natural := 0;
                       line_num : natural := 0;
                       file_name : string := "") is
  begin
    if condition then
      failure(logger, msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  impure function new_root_logger return logger_t is
    constant logger : logger_t := new_logger(root_id, null_logger);
  begin
    p_set_log_handlers(logger, (0 => display_handler));

    for log_level in legal_log_level_t'low to legal_log_level_t'high loop
      case log_level is
        when error|failure =>
          set_stop_count(logger, log_level, 1);
        when others =>
          disable_stop(logger, log_level);
      end case;
    end loop;

    hide_all(logger, display_handler);
    show(logger, display_handler, (info, warning, error, failure));
    return logger;
  end;

  constant p_root_logger : logger_t := new_root_logger;
  impure function root_logger return logger_t is
  begin
    return p_root_logger;
  end;

  constant p_default_logger : logger_t := get_logger("default");
  impure function default_logger return logger_t is
  begin
    return p_default_logger;
  end;

  procedure log(msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "") is
  begin
    log(default_logger, msg, log_level, path_offset + 1, line_num, file_name);
  end;

  procedure debug(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    debug(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure pass(msg : string;
                 path_offset : natural := 0;
                 line_num : natural := 0;
                 file_name : string := "") is
  begin
    pass(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure trace(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    trace(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure info(msg : string;
                 path_offset : natural := 0;
                 line_num : natural := 0;
                 file_name : string := "") is
  begin
    info(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure warning(msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    warning(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure error(msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "") is
  begin
    error(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure failure(msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "") is
  begin
    failure(default_logger, msg, path_offset + 1, line_num, file_name);
  end procedure;

  procedure warning_if(condition : boolean;
                       msg : string;
                       path_offset : natural := 0;
                       line_num : natural := 0;
                       file_name : string := "") is
  begin
    if condition then
      warning(msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  procedure error_if(condition : boolean;
                     msg : string;
                     path_offset : natural := 0;
                     line_num : natural := 0;
                     file_name : string := "") is
  begin
    if condition then
      error(msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  procedure failure_if(condition : boolean;
                       msg : string;
                       path_offset : natural := 0;
                       line_num : natural := 0;
                       file_name : string := "") is
  begin
    if condition then
      failure(msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  impure function level_to_color(log_level : log_level_t) return string is
  begin
    return colorize(upper(get_name(log_level)), get_color(log_level));
  end;

  impure function source_to_color(logger_name : string) return string is
    variable l : line;

    impure function create_string return string is
      variable lines : lines_t;
      variable num_items : natural;
    begin
      lines := split(logger_name, ":");
      num_items := integer'(lines.all'length);
      for idx in 0 to num_items - 1 loop
        write(l, colorize(lines(idx).all, fg => white, style => bright));
        deallocate(lines(idx));
        if idx /= lines'length - 1 then
          write(l, colorize(":", fg => lightcyan, style => bright));
        end if;
      end loop;
      deallocate(lines);
      return l.all;
    end;

    constant result : string := create_string;
  begin
    deallocate(l);
    return result;
  end;

  impure function final_log_check(allow_disabled_errors : boolean := false;
                                  allow_disabled_failures : boolean := false;
                                  fail_on_warning : boolean := false) return boolean is

    impure function p_final_log_check(logger : logger_t) return boolean is

      impure function check_log_level(log_level : log_level_t; allow_disabled : boolean) return boolean is

        function disabled_str(disabled : boolean) return string is
        begin
          if disabled then
            return " disabled";
          else
            return "";
          end if;
        end;

        function plural_suffix(is_plural : boolean) return string is
        begin
          if is_plural then
            return "s";
          else
            return "";
          end if;
        end;

        variable count : natural;
        constant level_is_disabled : boolean := is_disabled(logger, log_level);
      begin
        count := get_log_count(logger, log_level);
        if count > 0 and not (allow_disabled and level_is_disabled) then
          print(level_to_color(failure) & " - Logger " & source_to_color(get_full_name(logger)) &
                " has " & integer'image(count) & disabled_str(level_is_disabled) & " " &
                get_name(log_level) & plural_suffix(count > 1));
          return false;
        end if;
        return true;
      end;

      variable failed : boolean := false;
    begin
      for idx in 0 to num_children(logger)-1 loop
        if not p_final_log_check(get_child(logger, idx)) then
          failed := true;
        end if;
      end loop;

      if is_mocked(logger) then
        print(level_to_color(failure) & " - Logger " & source_to_color(get_full_name(logger)) &
              " is still mocked.");
        failed := true;
      end if;

      if fail_on_warning and not check_log_level(warning, true) then
        failed := true;
      end if;

      if not check_log_level(error, allow_disabled_errors) then
        failed := true;
      end if;

      if not check_log_level(failure, allow_disabled_failures) then
        failed := true;
      end if;

      return not failed;
    end;

  begin
    if p_final_log_check(root_logger) then
      return true;
    else
      core_failure("Final log check failed");
      return false;
    end if;
  end;

  procedure final_log_check(allow_disabled_errors : boolean := false;
                            allow_disabled_failures : boolean := false;
                            fail_on_warning : boolean := false) is
    variable result : boolean;
  begin
    result := final_log_check(allow_disabled_errors => allow_disabled_errors,
                              allow_disabled_failures => allow_disabled_failures,
                              fail_on_warning => fail_on_warning);
  end;

end package body;
