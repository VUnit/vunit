-- Log types specific to the VHDL 2002 and 2008 implementations.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.lang.all;
use work.string_ops.all;
use work.log_formatting_pkg.all;
use work.log_types_pkg.all;

package log_special_types_pkg is
  type logger_t is protected

    procedure init (
      constant default_src          : in string     := "";
      constant file_name            : in string     := "log.csv";
      constant display_format : in log_format_t := raw;
      constant file_format    : in log_format_t := off;
      constant stop_level : in log_level_t := failure;
      constant separator            : in character  := ',';
      constant append               : in boolean    := false);

    procedure log(msg   : string;
                  log_level : log_level_t := info;
                  src : string := "";
                  line_num : in natural := 0;
                  file_name : in string := "");

    impure function get_logger_cfg
    return logger_cfg_export_t;

    procedure add_filter (
      variable filter   : out log_filter_t;
      constant levels   : in  log_level_vector_t := null_log_level_vector;
      constant src      : in  string             := "";
      constant pass     : in  boolean            := false;
      constant handlers : in  log_handler_vector_t);

    procedure remove_filter (
      constant filter : in log_filter_t);

    procedure rename_level (
      constant level  : in    log_level_t;
      constant name   : in    string);

    impure function pass_filters (
      constant level   : in log_level_t;
      constant src     : in string;
      constant handler : in log_handler_t)
      return boolean;

  end protected logger_t;
end package;

package body log_special_types_pkg is
  type global_sequence_number_t is protected
    impure function next_num
      return natural;
  end protected global_sequence_number_t;

  type filter_list_t is protected
    procedure append (
      constant filter : in log_filter_t);

    procedure remove (
      constant filter : in log_filter_t);

    impure function length
      return natural;

    impure function get (
      constant index : natural)
      return log_filter_t;
  end protected filter_list_t;

  type filter_list_t is protected body
    type list_entry_t is record
      active : boolean;
      filter : log_filter_t;
    end record;
    type list_t is array (natural range <>) of list_entry_t;

    variable list : list_t(1 to 10);
    variable tail : natural := 0;

    procedure append (
      constant filter : in log_filter_t) is
    begin
      tail := tail + 1;
      list(tail) := (true, filter);
    end append;

    procedure remove (
      constant filter : in log_filter_t) is
    begin
      for i in tail downto 1 loop
        if list(i).filter.id = filter.id then
          list(i).active := false;
          list(i to 9) := list(i + 1 to 10);
          tail := tail - 1;
        end if;
      end loop;
    end remove;

    impure function length
      return natural is
    begin
      return tail;
    end length;

    impure function get (
      constant index : natural)
      return log_filter_t is
    begin
      assert index <= tail report "Index " & natural'image(index) & " is out of range 1 to " & natural'image(tail) & "." severity failure;
      assert index > 0 report "Index " & natural'image(index) & " is out of range 1 to " & natural'image(tail) & "." severity failure;
      return list(index).filter;
    end get;
  end protected body filter_list_t;

  type global_sequence_number_t is protected body
    variable seq_num : natural := 0;

    impure function next_num
      return natural is
    begin
      seq_num := seq_num + 1;
      return seq_num - 1;
    end next_num;
  end protected body global_sequence_number_t;

  shared variable global_sequence_number : global_sequence_number_t;

  type logger_t is protected body
    type level_names_t is array (log_level_t range <>) of line;

    variable cfg : logger_cfg_t := (null, null, raw, off, false, failure, ',');
    variable filter_list : filter_list_t;
    variable id : natural := 0;
    variable level_names : level_names_t(failure_high2 to verbose_low2) := (others => null);

    procedure open_log(append : boolean := false) is
      variable status : file_open_status;
      file log_file   : text;
    begin
      if append then
        file_open(status, log_file, cfg.log_file_name.all, append_mode);
      else
        file_open(status, log_file, cfg.log_file_name.all, write_mode);
      end if;
      assert status = open_ok report "Failed opening " & cfg.log_file_name.all & " (" & file_open_status'image(status) & ")." severity failure;
      file_close(log_file);
    end;

    procedure init (
      constant default_src          : in string     := "";
      constant file_name            : in string     := "log.csv";
      constant display_format : in log_format_t := raw;
      constant file_format    : in log_format_t := off;
      constant stop_level : in log_level_t := failure;
      constant separator            : in character  := ',';
      constant append               : in boolean    := false) is
    begin
      if cfg.log_default_src /= null then
        deallocate(cfg.log_default_src);
      end if;
      write(cfg.log_default_src, default_src);
      if cfg.log_file_name /= null then
        deallocate(cfg.log_file_name);
      end if;
      write(cfg.log_file_name, file_name);
      if display_format = dflt then
        cfg.log_display_format := raw;
      else
        cfg.log_display_format := display_format;
      end if;
      if file_format = dflt then
        cfg.log_file_format    := off;
      else
        cfg.log_file_format    := file_format;
      end if;
      if stop_level = dflt then
        cfg.log_stop_level := failure;
      else
        cfg.log_stop_level := stop_level;
      end if;
      cfg.log_separator            := separator;
      open_log(append);
      cfg.log_file_is_initialized  := true;
    end init;

  procedure log(msg          : string;
                log_level        : log_level_t := info;
                src          : string      := "";
                line_num : in natural := 0;
                file_name : in string := "") is

    variable status  : file_open_status;
    variable l       : line;
    file log_file    : text;
    variable seq_num : natural;
    variable selected_src : line;
    variable selected_level : log_level_t;
    variable pass_to_display, pass_to_file : boolean;
    variable selected_level_name : line;
  begin
    if selected_src /= null then
      deallocate(selected_src);
    end if;
    if src /= "" then
      write(selected_src, src);
    elsif cfg.log_default_src = null then
      write(selected_src, string'(""));
    else
      selected_src := cfg.log_default_src;
    end if;

    if log_level = dflt then
      selected_level := info;
    else
      selected_level := log_level;
    end if;

    if selected_src /= null then
      pass_to_display := pass_filters(selected_level, selected_src.all, display_handler);
      pass_to_file := pass_filters(selected_level, selected_src.all, file_handler);
    else
      pass_to_display := pass_filters(selected_level, "", display_handler);
      pass_to_file := pass_filters(selected_level, "", file_handler);
    end if;

    if pass_to_display or pass_to_file then
      if (cfg.log_display_format = verbose_csv) or (cfg.log_file_format = verbose_csv) or
         (cfg.log_display_format = verbose) or (cfg.log_file_format = verbose) then
        seq_num := global_sequence_number.next_num;
      end if;

      if selected_level_name /= null then
        deallocate(selected_level_name);
      end if;
      if level_names(selected_level) /= null then
        selected_level_name := level_names(selected_level);
      else
        write(selected_level_name, log_level_t'image(selected_level));
      end if;

      if pass_to_display and cfg.log_display_format /= off then
        lang_write(output, format(cfg.log_display_format, msg,
                                  seq_num, cfg.log_separator, now,
                                  selected_level_name.all, line_num,
                                  file_name, selected_src.all) & LF);
      end if;

      if pass_to_file and cfg.log_file_format /= off then
        write(l, format(cfg.log_file_format, msg,
                           seq_num, cfg.log_separator, now,
                           selected_level_name.all, line_num,
                           file_name, selected_src.all));
        file_open(status, log_file, cfg.log_file_name.all, append_mode);
        assert status = open_ok report "Failed opening " & cfg.log_file_name.all & " (" & file_open_status'image(status) & ")." severity failure;
        writeline(log_file, l);
        file_close(log_file);
      end if;
    end if;

    if selected_level <= cfg.log_stop_level then
      lang_report("", failure);
    end if;
  end log;

  impure function get_logger_cfg
    return logger_cfg_export_t is
    variable cfg_export : logger_cfg_export_t;
  begin
    if not cfg.log_file_is_initialized then
      cfg_export.log_file_is_initialized := false;
      return cfg_export;
    end if;

    assert cfg.log_default_src'length <= cfg_export.log_default_src'length
      report "Default source name is more than " &
      natural'image(cfg_export.log_default_src'length) &
      " characters." severity failure;
    cfg_export.log_default_src_length := cfg.log_default_src'length;
    read(cfg.log_default_src, cfg_export.log_default_src(1 to cfg.log_default_src'length));
    write(cfg.log_default_src, cfg_export.log_default_src(1 to cfg_export.log_default_src_length));

    assert cfg.log_file_name'length <= cfg_export.log_file_name'length
      report "Log file name is more than " &
      natural'image(cfg_export.log_file_name'length) &
      " characters." severity failure;
    cfg_export.log_file_name_length := cfg.log_file_name'length;
    read(cfg.log_file_name, cfg_export.log_file_name(1 to cfg.log_file_name'length));
    write(cfg.log_file_name, cfg_export.log_file_name(1 to cfg_export.log_file_name_length));

    cfg_export.log_display_format := cfg.log_display_format;
    cfg_export.log_file_format := cfg.log_file_format;
    cfg_export.log_file_is_initialized := cfg.log_file_is_initialized;
    cfg_export.log_stop_level := cfg.log_stop_level;
    cfg_export.log_separator := cfg.log_separator;

    return cfg_export;
  end;

  procedure add_filter (
    variable filter   : out log_filter_t;
    constant levels   : in  log_level_vector_t := null_log_level_vector;
    constant src      : in  string             := "";
    constant pass     : in  boolean            := false;
    constant handlers : in  log_handler_vector_t) is
    variable temp_filter : log_filter_t;
  begin
    temp_filter.id := id;
    id := id + 1;
    temp_filter.pass_filter := pass;
    temp_filter.levels(1 to levels'length) := levels;
    temp_filter.n_levels := levels'length;
    temp_filter.src := (others => NUL);
    temp_filter.src(src'range) := src;
    temp_filter.src_length := src'length;
    temp_filter.handlers(1 to handlers'length) := handlers;
    temp_filter.n_handlers := handlers'length;
    filter := temp_filter;
    filter_list.append(temp_filter);
  end;

  procedure remove_filter (
    constant filter : in log_filter_t) is
  begin
    filter_list.remove(filter);
  end remove_filter;

  procedure rename_level (
    constant level  : in    log_level_t;
    constant name   : in    string) is
  begin
    if level_names(level) /= null then
      deallocate(level_names(level));
    end if;
    write(level_names(level), name);
  end;

  impure function pass_filters (
    constant level   : in log_level_t;
    constant src     : in string;
    constant handler : in log_handler_t)
    return boolean is
    variable pass : boolean := true;
    variable match, level_match, source_match : boolean := false;
    variable filter : log_filter_t;
  begin
    list_loop :for i in 1 to filter_list.length loop
      filter := filter_list.get(i);
      for h in 1 to filter.n_handlers loop
        match := filter.handlers(h) = handler;
        exit when match;
      end loop;

      next list_loop when not match;

      level_match := (filter.n_levels = 0);
      for l in 1 to filter.n_levels loop
        level_match := filter.levels(l) = level;
        exit when level_match;
      end loop;

      source_match := (filter.src_length = 0);
      if filter.src_length > 0 then
        if replace(filter.src, ':', '.')(1) /= '.' then
          if (filter.src(src'range) = src) and (filter.src_length = src'length) then
            source_match := true;
          end if;
        else
          if filter.src_length <= src'length then
            if (replace(src, ':', '.')(1 to filter.src_length) = replace(filter.src(1 to filter.src_length), ':', '.')) then
              source_match := true;
            end if;
          end if;
        end if;
      end if;

      match := source_match and level_match;
      if (match and not filter.pass_filter) or (not match and filter.pass_filter) then
        pass := false;
      end if;

      exit list_loop when pass = false;

    end loop;
    return pass;
  end pass_filters;

  end protected body logger_t;
end package body log_special_types_pkg;
