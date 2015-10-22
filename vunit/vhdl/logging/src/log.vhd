-- Log package provides the primary functionality of the logging library.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.log_base_pkg.all;

package body log_pkg is
  procedure verbose_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, verbose_high2, src, line_num, file_name);
    -- pragma translate_on
  end verbose_high2;

  procedure verbose_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, verbose_high1, src, line_num, file_name);
    -- pragma translate_on
  end verbose_high1;

  procedure verbose(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, verbose, src, line_num, file_name);
    -- pragma translate_on
  end verbose;

  procedure verbose_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, verbose_low1, src, line_num, file_name);
    -- pragma translate_on
  end verbose_low1;

  procedure verbose_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, verbose_low2, src, line_num, file_name);
    -- pragma translate_on
  end verbose_low2;

  procedure debug_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, debug_high1, src, line_num, file_name);
    -- pragma translate_on
  end debug_high2;

  procedure debug_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, debug_high1, src, line_num, file_name);
    -- pragma translate_on
  end debug_high1;

  procedure debug(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, debug, src, line_num, file_name);
    -- pragma translate_on
  end debug;

  procedure debug_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, debug_low1, src, line_num, file_name);
    -- pragma translate_on
  end debug_low1;

  procedure debug_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, debug_low2, src, line_num, file_name);
    -- pragma translate_on
  end debug_low2;

  procedure info_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, info_high2, src, line_num, file_name);
    -- pragma translate_on
  end info_high2;

  procedure info_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, info_high1, src, line_num, file_name);
    -- pragma translate_on
  end info_high1;

  procedure info(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, info, src, line_num, file_name);
    -- pragma translate_on
  end info;

  procedure info_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, info_low1, src, line_num, file_name);
    -- pragma translate_on
  end info_low1;

  procedure info_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, info_low2, src, line_num, file_name);
    -- pragma translate_on
  end info_low2;

  procedure warning_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, warning_high2, src, line_num, file_name);
    -- pragma translate_on
  end warning_high2;

  procedure warning_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, warning_high1, src, line_num, file_name);
    -- pragma translate_on
  end warning_high1;

  procedure warning(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, warning, src, line_num, file_name);
    -- pragma translate_on
  end warning;

  procedure warning_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, warning_low1, src, line_num, file_name);
    -- pragma translate_on
  end warning_low1;

  procedure warning_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, warning_low2, src, line_num, file_name);
    -- pragma translate_on
  end warning_low2;

  procedure error_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, error_high2, src, line_num, file_name);
    -- pragma translate_on
  end error_high2;

  procedure error_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, error_high1, src, line_num, file_name);
    -- pragma translate_on
  end error_high1;

  procedure error(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, error, src, line_num, file_name);
    -- pragma translate_on
  end error;

  procedure error_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, error_low1, src, line_num, file_name);
    -- pragma translate_on
  end error_low1;

  procedure error_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, error_low2, src, line_num, file_name);
    -- pragma translate_on
  end error_low2;

  procedure failure(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, failure, src, line_num, file_name);
    -- pragma translate_on
  end failure;

  procedure failure_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, failure_high2, src, line_num, file_name);
    -- pragma translate_on
  end failure_high2;

  procedure failure_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, failure_high1, src, line_num, file_name);
    -- pragma translate_on
  end failure_high1;

  procedure failure_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, failure_low1, src, line_num, file_name);
    -- pragma translate_on
  end failure_low1;

  procedure failure_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(logger, msg, failure_low2, src, line_num, file_name);
    -- pragma translate_on
  end failure_low2;

  procedure stop_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, source, false, (1 => handler));
    -- pragma translate_on
  end;

  procedure stop_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, source, false, (1 => handler));
    -- pragma translate_on
  end;

  procedure pass_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, source, true, (1 => handler));
    -- pragma translate_on
  end;

  procedure pass_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, source, true, (1 => handler));
    -- pragma translate_on
  end;

  procedure stop_level (
    variable logger : inout logger_t;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, "", false, (1 => handler));
    -- pragma translate_on
  end;

  procedure stop_level (
    variable logger : inout logger_t;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, "", false, (1 => handler));
    -- pragma translate_on
  end;

  procedure pass_level (
    variable logger : inout logger_t;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, "", true, (1 => handler));
    -- pragma translate_on
  end;

  procedure pass_level (
    variable logger : inout logger_t;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, "", true, (1 => handler));
    -- pragma translate_on
  end;

  procedure stop_source (
    variable logger : inout logger_t;
    constant source : in string;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, null_log_level_vector, source, false, (1 => handler));
    -- pragma translate_on
  end;

  procedure pass_source (
    variable logger : inout logger_t;
    constant source : in string;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, null_log_level_vector, source, true, (1 => handler));
    -- pragma translate_on
  end;

  procedure stop_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, source, false, handler);
    -- pragma translate_on
  end;

  procedure stop_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, source, false, handler);
    -- pragma translate_on
  end;

  procedure pass_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, source, true, handler);
    -- pragma translate_on
  end;

  procedure pass_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, source, true, handler);
    -- pragma translate_on
  end;

  procedure stop_level (
    variable logger : inout logger_t;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, "", false, handler);
    -- pragma translate_on
  end;

  procedure stop_level (
    variable logger : inout logger_t;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, "", false, handler);
    -- pragma translate_on
  end;

  procedure pass_level (
    variable logger : inout logger_t;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, "", true, handler);
    -- pragma translate_on
  end;

  procedure pass_level (
    variable logger : inout logger_t;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, levels, "", true, handler);
    -- pragma translate_on
  end;

  procedure stop_source (
    variable logger : inout logger_t;
    constant source : in string;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, null_log_level_vector, source, false, handler);
    -- pragma translate_on
  end;

  procedure pass_source (
    variable logger : inout logger_t;
    constant source : in string;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(logger, filter, null_log_level_vector, source, true, handler);
    -- pragma translate_on
  end;

  shared variable default_logger : logger_t;

  procedure logger_init (
    constant default_src    : in string       := "";
    constant file_name      : in string       := "log.csv";
    constant display_format : in log_format_t := raw;
    constant file_format    : in log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in character    := ',';
    constant append         : in boolean      := false) is
  begin
    -- pragma translate_off
    logger_init(default_logger,
                default_src,
                file_name,
                display_format,
                file_format,
                stop_level,
                separator,
                append);
    -- pragma translate_on
  end logger_init;

  procedure log(
    constant msg       : in string;
    constant log_level : in log_level_t := info;
    constant src       : in string      := "";
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, log_level, src, line_num, file_name);
    -- pragma translate_on
  end log;

  procedure verbose_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, verbose_high2, src, line_num, file_name);
    -- pragma translate_on
  end verbose_high2;

  procedure verbose_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, verbose_high1, src, line_num, file_name);
    -- pragma translate_on
  end verbose_high1;

  procedure verbose(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, verbose, src, line_num, file_name);
    -- pragma translate_on
  end verbose;

  procedure verbose_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, verbose_low1, src, line_num, file_name);
    -- pragma translate_on
  end verbose_low1;

  procedure verbose_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, verbose_low2, src, line_num, file_name);
    -- pragma translate_on
  end verbose_low2;

  procedure debug_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, debug_high1, src, line_num, file_name);
    -- pragma translate_on
  end debug_high2;

  procedure debug_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, debug_high2, src, line_num, file_name);
    -- pragma translate_on
  end debug_high1;

  procedure debug(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, debug, src, line_num, file_name);
    -- pragma translate_on
  end debug;

  procedure debug_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, debug_low1, src, line_num, file_name);
    -- pragma translate_on
  end debug_low1;

  procedure debug_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, debug_low2, src, line_num, file_name);
    -- pragma translate_on
  end debug_low2;

  procedure info_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, info_high2, src, line_num, file_name);
    -- pragma translate_on
  end info_high2;

  procedure info_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, info_high1, src, line_num, file_name);
    -- pragma translate_on
  end info_high1;

  procedure info(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, info, src, line_num, file_name);
    -- pragma translate_on
  end info;

  procedure info_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, info_low1, src, line_num, file_name);
    -- pragma translate_on
  end info_low1;

  procedure info_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, info_low2, src, line_num, file_name);
    -- pragma translate_on
  end info_low2;

  procedure warning_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, warning_high2, src, line_num, file_name);
    -- pragma translate_on
  end warning_high2;

  procedure warning_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, warning_high1, src, line_num, file_name);
    -- pragma translate_on
  end warning_high1;

  procedure warning(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, warning, src, line_num, file_name);
    -- pragma translate_on
  end warning;

  procedure warning_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, warning_low1, src, line_num, file_name);
    -- pragma translate_on
  end warning_low1;

  procedure warning_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, warning_low2, src, line_num, file_name);
    -- pragma translate_on
  end warning_low2;

  procedure error_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, error_high2, src, line_num, file_name);
    -- pragma translate_on
  end error_high2;

  procedure error_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, error_high1, src, line_num, file_name);
    -- pragma translate_on
  end error_high1;

  procedure error(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, error, src, line_num, file_name);
    -- pragma translate_on
  end error;

  procedure error_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, error_low1, src, line_num, file_name);
    -- pragma translate_on
  end error_low1;

  procedure error_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, error_low2, src, line_num, file_name);
    -- pragma translate_on
  end error_low2;

  procedure failure(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, failure, src, line_num, file_name);
    -- pragma translate_on
  end failure;

  procedure failure_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, failure_high2, src, line_num, file_name);
    -- pragma translate_on
  end failure_high2;

  procedure failure_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, failure_high1, src, line_num, file_name);
    -- pragma translate_on
  end failure_high1;

  procedure failure_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, failure_low1, src, line_num, file_name);
    -- pragma translate_on
  end failure_low1;

  procedure failure_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
  begin
    -- pragma translate_off
    log(default_logger, msg, failure_low2, src, line_num, file_name);
    -- pragma translate_on
  end failure_low2;

  procedure get_logger_cfg (
    variable cfg : inout logger_cfg_t) is
  begin
    -- pragma translate_off
    get_logger_cfg(default_logger, cfg);
    -- pragma translate_on
  end;

  procedure get_logger_cfg (
    variable cfg : inout logger_cfg_export_t) is
  begin
    -- pragma translate_off
    get_logger_cfg(default_logger, cfg);
    -- pragma translate_on
  end;

  procedure stop_source_level (
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, source, false, (1 => handler));
    -- pragma translate_on
  end;

  procedure stop_source_level (
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, source, false, (1 => handler));
    -- pragma translate_on
  end;

  procedure pass_source_level (
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, source, true, (1 => handler));
    -- pragma translate_on
  end;

  procedure pass_source_level (
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, source, true, (1 => handler));
    -- pragma translate_on
  end;

  procedure stop_level (
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, "", false, (1 => handler));
    -- pragma translate_on
  end;

  procedure stop_level (
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, "", false, (1 => handler));
    -- pragma translate_on
  end;

  procedure pass_level (
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, "", true, (1 => handler));
    -- pragma translate_on
  end;

  procedure pass_level (
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, "", true, (1 => handler));
    -- pragma translate_on
  end;

  procedure stop_source (
    constant source : in string;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, null_log_level_vector, source, false, (1 => handler));
    -- pragma translate_on
  end;

  procedure pass_source (
    constant source : in string;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, null_log_level_vector, source, true, (1 => handler));
    -- pragma translate_on
  end;

  procedure stop_source_level (
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, source, false, handler);
    -- pragma translate_on
  end;

  procedure stop_source_level (
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, source, false, handler);
    -- pragma translate_on
  end;

  procedure pass_source_level (
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, source, true, handler);
    -- pragma translate_on
  end;

  procedure pass_source_level (
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, source, true, handler);
    -- pragma translate_on
  end;

  procedure stop_level (
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, "", false, handler);
    -- pragma translate_on
  end;

  procedure stop_level (
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, "", false, handler);
    -- pragma translate_on
  end;

  procedure pass_level (
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
    variable levels : log_level_vector_t(1 to 1) := (1 => level);
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, "", true, handler);
    -- pragma translate_on
  end;

  procedure pass_level (
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, levels, "", true, handler);
    -- pragma translate_on
  end;

  procedure stop_source (
    constant source : in string;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, null_log_level_vector, source, false, handler);
    -- pragma translate_on
  end;

  procedure pass_source (
    constant source : in string;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t) is
  begin
    -- pragma translate_off
    base_add_filter(default_logger, filter, null_log_level_vector, source, true, handler);
    -- pragma translate_on
  end;

  procedure remove_filter (
    constant filter : in log_filter_t) is
  begin
    -- pragma translate_off
    remove_filter(default_logger, filter);
    -- pragma translate_on
  end;

  procedure rename_level (
    constant level  : in    log_level_t;
    constant name   : in    string) is
  begin
    -- pragma translate_off
    rename_level(default_logger, level, name);
    -- pragma translate_on
  end;
end package body log_pkg;

