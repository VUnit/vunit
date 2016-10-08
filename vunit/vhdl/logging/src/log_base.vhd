-- Log base package provides the fundamental log functionality.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use work.log_types_pkg.all;

package body log_base_pkg is
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
    logger.init(default_src,
                file_name,
                display_format,
                file_format,
                stop_level,
                separator,
                append);
  end base_init;

  procedure base_log(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant log_level : in    log_level_t := info;
    constant src       : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
  begin
    logger.log(msg, log_level, src, line_num, file_name);
  end base_log;

  procedure base_get_logger_cfg (
    variable logger : inout logger_t;
    variable cfg    : inout logger_cfg_t) is
    variable export : logger_cfg_export_t;
  begin
    export := logger.get_logger_cfg;
    cfg.log_file_is_initialized := export.log_file_is_initialized;
    if not export.log_file_is_initialized then
      return;
    end if;
    if cfg.log_default_src /= null then
      deallocate(cfg.log_default_src);
    end if;
    write(cfg.log_default_src, export.log_default_src(1 to export.log_default_src_length));
    if cfg.log_file_name /= null then
      deallocate(cfg.log_file_name);
    end if;
    write(cfg.log_file_name, export.log_file_name(1 to export.log_file_name_length));
    cfg.log_display_format      := export.log_display_format;
    cfg.log_file_format         := export.log_file_format;
    cfg.log_stop_level          := export.log_stop_level;
    cfg.log_separator           := export.log_separator;
  end;

  procedure base_get_logger_cfg (
    variable logger : inout logger_t;
    variable cfg    : inout logger_cfg_export_t) is
  begin
    cfg := logger.get_logger_cfg;
  end;

  procedure base_add_filter (
    variable logger : inout logger_t;
    variable filter       : out log_filter_t;
    constant levels : in log_level_vector_t := null_log_level_vector;
    constant src : in string := "";
    constant pass               : in boolean := false;
    constant handlers       : in log_handler_vector_t) is
  begin
    logger.add_filter(filter, levels, src, pass, handlers);
  end;

  procedure base_remove_filter (
    variable logger : inout logger_t;
    constant filter : in log_filter_t) is
  begin
    logger.remove_filter(filter);
  end;

  procedure base_rename_level (
    variable logger : inout logger_t;
    constant level  : in    log_level_t;
    constant name   : in    string) is
  begin
    logger.rename_level(level, name);
  end;

end package body log_base_pkg;
