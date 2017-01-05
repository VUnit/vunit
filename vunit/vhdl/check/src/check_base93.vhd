-- Check base package provides fundamental checking functionality for
-- VHDL 93.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.check_types_pkg.all;
use work.log_base_pkg.all;
use work.log_pkg.all;

package body check_base_pkg is
  constant pass_level : log_level_t := debug_low2;

  procedure base_init (
    variable checker        : inout checker_t;
    constant default_level  : in    log_level_t  := error;
    constant default_src    : in    string       := "";
    constant file_name      : in    string       := "error.csv";
    constant display_format : in    log_format_t := level;
    constant file_format    : in    log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in    character    := ',';
    constant append         : in    boolean      := false) is
  begin
    -- pragma translate_off
    checker.default_log_level := default_level;
    logger_init(checker.logger, default_src, file_name, display_format, file_format, stop_level, separator, append);
    rename_level(checker.logger, debug_low2, "pass");
    remove_filter(checker.logger, checker.pass_display_filter);
    remove_filter(checker.logger, checker.pass_file_filter);
    work.log_pkg.stop_level(checker.logger, pass_level, display_handler, checker.pass_display_filter);
    work.log_pkg.stop_level(checker.logger, pass_level, file_handler, checker.pass_file_filter);

    -- pragma translate_on
  end base_init;

  procedure base_enable_pass_msg (
    variable checker : inout checker_t;
    constant handler : in log_handler_t) is
  begin
    -- pragma translate_off
    if (handler = display_handler) and not checker.pass_display_filter_inactive then
      checker.pass_display_filter_inactive := true;
      remove_filter(checker.logger, checker.pass_display_filter);
    elsif (handler = file_handler) and not checker.pass_file_filter_inactive then
      checker.pass_file_filter_inactive := true;
      remove_filter(checker.logger, checker.pass_file_filter);
    end if;
    -- pragma translate_on
  end;

  procedure base_disable_pass_msg (
    variable checker : inout checker_t;
    constant handler : in log_handler_t) is
  begin
    -- pragma translate_off
    if (handler = display_handler) and checker.pass_display_filter_inactive then
      checker.pass_display_filter_inactive := false;
      stop_level(checker.logger, pass_level, display_handler, checker.pass_display_filter);
    elsif (handler = file_handler) and checker.pass_file_filter_inactive then
      checker.pass_file_filter_inactive := false;
      stop_level(checker.logger, pass_level, file_handler, checker.pass_file_filter);
    end if;
    -- pragma translate_on
  end;

  procedure base_pass_msg_enabled (
    variable checker : inout checker_t;
    variable en : out boolean) is
  begin
    en := checker.pass_display_filter_inactive or checker.pass_file_filter_inactive;
  end;

  procedure base_check_true(
    variable checker   : inout checker_t;
    constant msg       : in      string := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
  begin
    -- pragma translate_off
    checker.stat.n_checks := checker.stat.n_checks + 1;
    checker.stat.n_passed := checker.stat.n_passed + 1;
    if checker.pass_display_filter_inactive or checker.pass_file_filter_inactive then
      log(checker.logger, msg, pass_level, "", line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure base_check_false(
    variable checker   : inout checker_t;
    constant msg       : in      string;
    constant level     : in      log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
  begin
    -- pragma translate_off
    checker.stat.n_checks := checker.stat.n_checks + 1;
    checker.stat.n_failed := checker.stat.n_failed + 1;
    if (level = dflt) and (checker.default_log_level = dflt) then
      log(checker.logger, msg, error, "", line_num, file_name);
    elsif level = dflt then
      log(checker.logger, msg, checker.default_log_level, "", line_num, file_name);
    else
      log(checker.logger, msg, level, "", line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure base_get_checker_stat (
    variable checker : inout checker_t;
    variable stat    : out   checker_stat_t) is
  begin
    -- pragma translate_off
    stat := checker.stat;
    -- pragma translate_on
  end;

  procedure base_reset_checker_stat (
    variable checker : inout checker_t) is
  begin
    -- pragma translate_off
    checker.stat := (0, 0, 0);
    -- pragma translate_on
  end base_reset_checker_stat;

  procedure base_get_checker_cfg (
    variable checker : inout checker_t;
    variable cfg     : inout checker_cfg_t) is
  begin
    -- pragma translate_off
    cfg.default_level := checker.default_log_level;
    base_get_logger_cfg(checker, cfg.logger_cfg);
    -- pragma translate_on
  end;

  procedure base_get_checker_cfg (
    variable checker : inout checker_t;
    variable cfg     : inout checker_cfg_export_t) is
  begin
    -- pragma translate_off
    cfg.default_level := checker.default_log_level;
    base_get_logger_cfg(checker, cfg.logger_cfg);
    -- pragma translate_on
  end;

  procedure base_get_logger_cfg (
    variable checker : inout checker_t;
    variable cfg     : inout logger_cfg_t) is
  begin
    -- pragma translate_off
    get_logger_cfg(checker.logger, cfg);
    -- pragma translate_on
  end;

  procedure base_get_logger_cfg (
    variable checker : inout checker_t;
    variable cfg     : inout logger_cfg_export_t) is
  begin
    -- pragma translate_off
    get_logger_cfg(checker.logger, cfg);
    -- pragma translate_on
  end;

  procedure base_checker_found_errors (
    variable checker : inout checker_t;
    variable result  : out   boolean) is
  begin
    -- pragma translate_off
    result := checker.stat.n_failed > 0;
    -- pragma translate_on
  end;

end package body check_base_pkg;
