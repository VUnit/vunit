-- Check base package provides fundamental checking functionality for
-- VHDL 200x.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.check_types_pkg.all;
use work.log_base_pkg.all;
use work.log_pkg.all;

package body check_base_pkg is

  procedure base_init (
    variable checker               : inout checker_t;
    constant default_level        : in    log_level_t := error;
    constant default_src          : in    string      := "";
    constant file_name            : in    string      := "error.csv";
    constant display_format : in    log_format_t  := level;
    constant file_format    : in    log_format_t  := off;
    constant stop_level : in log_level_t := failure;
    constant separator            : in    character   := ',';
    constant append               : in    boolean     := false) is
  begin
    -- pragma translate_off
    checker.init(default_level,
                default_src,
                file_name,
                display_format,
                file_format,
                stop_level,
                separator,
                append);
    -- pragma translate_on
  end base_init;

  procedure base_check(
    variable checker       : inout checker_t;
    constant expr         : in    boolean;
    constant msg          : in    string := "Check failed!";
    constant level        : in    log_level_t := dflt;
    constant line_num : in natural := 0;
    constant file_name : in string := "") is
  begin
    -- pragma translate_off
    checker.check(expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure base_get_checker_stat (
    variable checker : inout checker_t;
    variable stat : out checker_stat_t) is
  begin
    -- pragma translate_off
    stat := checker.get_stat;
    -- pragma translate_on
  end;

  procedure base_reset_checker_stat (
    variable checker : inout checker_t) is
  begin
    -- pragma translate_off
    checker.reset_stat;
    -- pragma translate_on
  end base_reset_checker_stat;

  procedure base_get_checker_cfg (
    variable checker : inout checker_t;
    variable cfg : inout checker_cfg_t) is
    variable export : checker_cfg_export_t;
  begin
    -- pragma translate_off
    export := checker.get_cfg;
    if cfg.logger_cfg.log_default_src /= null then
      deallocate(cfg.logger_cfg.log_default_src);
    end if;
    write(cfg.logger_cfg.log_default_src, export.logger_cfg.log_default_src(1 to export.logger_cfg.log_default_src_length));
    if cfg.logger_cfg.log_file_name /= null then
      deallocate(cfg.logger_cfg.log_file_name);
    end if;
    write(cfg.logger_cfg.log_file_name, export.logger_cfg.log_file_name(1 to export.logger_cfg.log_file_name_length));
    cfg.logger_cfg.log_display_format := export.logger_cfg.log_display_format;
    cfg.logger_cfg.log_file_format := export.logger_cfg.log_file_format;
    cfg.logger_cfg.log_file_is_initialized := export.logger_cfg.log_file_is_initialized;
    cfg.logger_cfg.log_stop_level := export.logger_cfg.log_stop_level;
    cfg.logger_cfg.log_separator := export.logger_cfg.log_separator;
    cfg.default_level := export.default_level;
    -- pragma translate_on
  end;

  procedure base_get_checker_cfg (
    variable checker : inout checker_t;
    variable cfg : inout checker_cfg_export_t) is
  begin
    -- pragma translate_off
    cfg := checker.get_cfg;
    -- pragma translate_on
  end;

  procedure base_get_logger_cfg (
    variable checker : inout checker_t;
    variable cfg : inout logger_cfg_t) is
    variable export : logger_cfg_export_t;
  begin
    -- pragma translate_off
    export := checker.get_logger_cfg;
    if cfg.log_default_src /= null then
      deallocate(cfg.log_default_src);
    end if;
    write(cfg.log_default_src, export.log_default_src(1 to export.log_default_src_length));
    if cfg.log_file_name /= null then
      deallocate(cfg.log_file_name);
    end if;
    write(cfg.log_file_name, export.log_file_name(1 to export.log_file_name_length));
    cfg.log_display_format := export.log_display_format;
    cfg.log_file_format := export.log_file_format;
    cfg.log_file_is_initialized := export.log_file_is_initialized;
    cfg.log_stop_level := export.log_stop_level;
    cfg.log_separator := export.log_separator;
    -- pragma translate_on
  end;

  procedure base_get_logger_cfg (
    variable checker : inout checker_t;
    variable cfg : inout logger_cfg_export_t) is
  begin
    -- pragma translate_off
    cfg := checker.get_logger_cfg;
    -- pragma translate_on
  end;

  procedure base_checker_found_errors (
    variable checker : inout checker_t;
    variable result : out   boolean) is
  begin
    -- pragma translate_off
    result := checker.found_errors;
    -- pragma translate_on
  end;

end package body check_base_pkg;
