-- Log base 93 package provides fundamental log functionality for VHDL 93.
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

package body log_base_pkg is
  procedure append (
    variable logger : inout logger_t;
    constant filter : in log_filter_t) is
  begin
    logger.log_filter_list_tail := logger.log_filter_list_tail + 1;
    logger.log_filter_list(logger.log_filter_list_tail) := (true, filter);
  end append;

  procedure remove (
    variable logger : inout logger_t;
    constant filter : in log_filter_t) is
  begin
    for i in logger.log_filter_list_tail downto 1 loop
      if logger.log_filter_list(i).filter.id = filter.id then
        logger.log_filter_list(i).active := false;
        logger.log_filter_list(i to 9) := logger.log_filter_list(i + 1 to 10);
        logger.log_filter_list_tail := logger.log_filter_list_tail - 1;
      end if;
    end loop;
  end remove;

  procedure get (
    variable logger : inout logger_t;
    constant index  : in    natural;
    variable filter : out log_filter_t) is
  begin
    assert index <= logger.log_filter_list_tail report "Index " & natural'image(index) & " is out of range 1 to " & natural'image(logger.log_filter_list_tail) & "." severity failure;
    assert index > 0 report "Index " & natural'image(index) & " is out of range 1 to " & natural'image(logger.log_filter_list_tail) & "." severity failure;
    filter := logger.log_filter_list(index).filter;
  end procedure get;

  procedure open_log(
    variable logger : inout logger_t;
    constant append : in    boolean := false) is
    variable status : file_open_status;
    file log_file   : text;
  begin
    if append then
      file_open(status, log_file, logger.log_file_name.all, append_mode);
    else
      file_open(status, log_file, logger.log_file_name.all, write_mode);
    end if;
      assert status = open_ok report "Failed opening " & logger.log_file_name.all & " (" & file_open_status'image(status) & ")." severity failure;
    file_close(log_file);
  end;

  procedure base_init (
    variable logger         : inout logger_t;
    constant default_src    : in    string       := "";
    constant file_name      : in    string       := "log.csv";
    constant display_format : in    log_format_t := raw;
    constant file_format    : in    log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in    character    := ',';
    constant append         : in    boolean      := false) is
  begin
    -- pragma translate_off
    if logger.log_default_src /= null then
      deallocate(logger.log_default_src);
    end if;
    write(logger.log_default_src, default_src);
    if logger.log_file_name /= null then
      deallocate(logger.log_file_name);
    end if;
    write(logger.log_file_name, file_name);
    if display_format = dflt then
      logger.log_display_format := raw;
    else
      logger.log_display_format := display_format;
    end if;
    if file_format = dflt then
      logger.log_file_format := off;
    else
      logger.log_file_format := file_format;
    end if;
    if stop_level = dflt then
      logger.log_stop_level := failure;
    else
      logger.log_stop_level := stop_level;
    end if;
    logger.log_separator := separator;
    if logger.log_file_format /= off then
      open_log(logger, append);
    end if;
    logger.log_file_is_initialized := true;
    -- pragma translate_on
  end base_init;

  procedure base_log(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant log_level  : in    log_level_t := info;
    constant src       : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is

    procedure pass_filters (
      variable logger : inout logger_t;
      variable pass    : out  boolean;
      constant level   : in log_level_t;
      constant src     : in string;
      constant handler : in log_handler_t) is
      variable ret_val : boolean := true;
      variable match, level_match, source_match : boolean := false;
      variable filter : log_filter_t;
    begin  -- procedure pass_filters
      list_loop :for i in 1 to logger.log_filter_list_tail loop
        get(logger, i, filter);
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
          ret_val := false;
        end if;

        exit list_loop when ret_val = false;
      end loop;
      pass := ret_val;
    end procedure pass_filters;

    variable status                : file_open_status;
    variable l                     : line;
    file log_file                  : text;
    variable seq_num               : natural;
    variable selected_src          : line;
    variable selected_level        : log_level_t;
    variable pass_to_display, pass_to_file : boolean;
    variable selected_level_name : line;
  begin
    -- pragma translate_off
    if selected_src /= null then
      deallocate(selected_src);
    end if;
    if src /= "" then
      write(selected_src, src);
    elsif logger.log_default_src = null then
      write(selected_src, string'(""));
    else
      selected_src := logger.log_default_src;
    end if;

    if log_level = dflt then
      selected_level := info;
    else
      selected_level := log_level;
    end if;

    if selected_src /= null then
      pass_filters(logger, pass_to_display, selected_level, selected_src.all, display_handler);
      pass_filters(logger, pass_to_file, selected_level, selected_src.all, file_handler);
    else
      pass_filters(logger, pass_to_display, selected_level, "", display_handler);
      pass_filters(logger, pass_to_file, selected_level, "", file_handler);
    end if;

    if pass_to_display or pass_to_file then
      if (logger.log_display_format = verbose_csv) or (logger.log_file_format = verbose_csv) or
         (logger.log_display_format = verbose) or (logger.log_file_format = verbose) then
        seq_num := get_seq_num;
      end if;

      if selected_level_name /= null then
        deallocate(selected_level_name);
      end if;
      if logger.log_level_names(selected_level) /= null then
        selected_level_name := logger.log_level_names(selected_level);
      else
        write(selected_level_name, log_level_t'image(selected_level));
      end if;

      if pass_to_display and logger.log_display_format /= off then
        lang_write(output, format(logger.log_display_format, msg,
                                  seq_num, logger.log_separator, now,
                                  selected_level_name.all, line_num,
                                  file_name, selected_src.all) & LF);
      end if;

      if pass_to_file and (logger.log_file_format /= off and logger.log_file_format /= dflt) then
        write(l, format(logger.log_file_format, msg,
                           seq_num, logger.log_separator, now,
                           selected_level_name.all, line_num,
                           file_name, selected_src.all));
        file_open(status, log_file, logger.log_file_name.all, append_mode);
        assert status = open_ok report "Failed opening " & logger.log_file_name.all & " (" & file_open_status'image(status) & ")." severity failure;
        writeline(log_file, l);
        file_close(log_file);
      end if;
    end if;

    if selected_level <= logger.log_stop_level then
      lang_report("", failure);
    end if;
    -- pragma translate_on
  end base_log;

  procedure base_get_logger_cfg (
    variable logger : inout logger_t;
    variable cfg : inout logger_cfg_t) is
  begin
    -- pragma translate_off
    cfg.log_default_src := logger.log_default_src;
    cfg.log_file_name := logger.log_file_name;
    cfg.log_display_format := logger.log_display_format;
    cfg.log_file_format := logger.log_file_format;
    cfg.log_file_is_initialized := logger.log_file_is_initialized;
    cfg.log_stop_level := logger.log_stop_level;
    cfg.log_separator := logger.log_separator;
    -- pragma translate_on
  end;

  procedure base_get_logger_cfg (
    variable logger : inout logger_t;
    variable cfg : inout logger_cfg_export_t) is
  begin
    -- pragma translate_off
    cfg.log_file_is_initialized := logger.log_file_is_initialized;
    if not logger.log_file_is_initialized then
      return;
    end if;
    cfg.log_default_src(logger.log_default_src'range) := logger.log_default_src.all;
    cfg.log_default_src_length := logger.log_default_src'length;
    cfg.log_file_name(logger.log_file_name'range) := logger.log_file_name.all;
    cfg.log_file_name_length := logger.log_file_name'length;
    cfg.log_display_format := logger.log_display_format;
    cfg.log_file_format := logger.log_file_format;
    cfg.log_stop_level := logger.log_stop_level;
    cfg.log_separator := logger.log_separator;
    -- pragma translate_on
  end;

  procedure base_add_filter (
    variable logger : inout logger_t;
    variable filter       : out log_filter_t;
    constant levels : in log_level_vector_t := null_log_level_vector;
    constant src : in string := "";
    constant pass               : in boolean := false;
    constant handlers       : in log_handler_vector_t) is
    variable temp_filter : log_filter_t;
  begin
    temp_filter.id := logger.log_filter_id;
    logger.log_filter_id := logger.log_filter_id + 1;
    temp_filter.pass_filter := pass;
    temp_filter.levels(1 to levels'length) := levels;
    temp_filter.n_levels := levels'length;
    temp_filter.src := (others => NUL);
    temp_filter.src(src'range) := src;
    temp_filter.src_length := src'length;
    temp_filter.handlers(1 to handlers'length) := handlers;
    temp_filter.n_handlers := handlers'length;
    filter := temp_filter;
    append(logger, temp_filter);
  end;

  procedure base_remove_filter (
    variable logger : inout logger_t;
    constant filter : in log_filter_t) is
  begin
    -- pragma translate_off
    remove(logger, filter);
    -- pragma translate_on
  end;

  procedure base_rename_level (
    variable logger : inout logger_t;
    constant level  : in    log_level_t;
    constant name   : in    string) is
  begin
    -- pragma translate_off
    if logger.log_level_names(level) /= null then
      deallocate(logger.log_level_names(level));
    end if;
    write(logger.log_level_names(level), name);
    -- pragma translate_on
  end;
end package body log_base_pkg;
