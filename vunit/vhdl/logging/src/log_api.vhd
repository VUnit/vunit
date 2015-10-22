-- Log API package provides the common user API for all
-- implementations of the logging functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use work.log_types_pkg.all;
use work.log_special_types_pkg.all;
use work.log_base_pkg.all;
use work.log_formatting_pkg.all;

package log_pkg is
  alias logger_init is base_init[logger_t, string, string, log_format_t, log_format_t, log_level_t, character, boolean];
  alias log is base_log[logger_t, string, log_level_t, string, natural, string];

  procedure verbose_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure verbose_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure verbose(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure verbose_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure verbose_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure debug_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure debug_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure debug(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure debug_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure debug_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure info_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure info_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure info(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure info_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure info_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure warning_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure warning_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure warning(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure warning_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure warning_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure error_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure error_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure error(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure error_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure error_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure failure_high2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure failure_high1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure failure(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure failure_low1(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure failure_low2(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  alias get_logger_cfg is base_get_logger_cfg[logger_t, logger_cfg_t];
  alias get_logger_cfg is base_get_logger_cfg[logger_t, logger_cfg_export_t];

  procedure stop_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure stop_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure pass_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure pass_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure stop_level (
    variable logger : inout logger_t;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure stop_level (
    variable logger : inout logger_t;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure pass_level (
    variable logger : inout logger_t;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure pass_level (
    variable logger : inout logger_t;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure stop_source (
    variable logger : inout logger_t;
    constant source : in string;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure pass_source (
    variable logger : inout logger_t;
    constant source : in string;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure stop_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure stop_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure pass_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure pass_source_level (
    variable logger : inout logger_t;
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure stop_level (
    variable logger : inout logger_t;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure stop_level (
    variable logger : inout logger_t;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure pass_level (
    variable logger : inout logger_t;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure pass_level (
    variable logger : inout logger_t;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure stop_source (
    variable logger : inout logger_t;
    constant source : in string;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure pass_source (
    variable logger : inout logger_t;
    constant source : in string;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  alias remove_filter is base_remove_filter[logger_t, log_filter_t];
  alias rename_level is base_rename_level[logger_t, log_level_t, string];

  procedure logger_init (
    constant default_src    : in string       := "";
    constant file_name      : in string       := "log.csv";
    constant display_format : in log_format_t := raw;
    constant file_format    : in log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in character    := ',';
    constant append         : in boolean      := false);

  procedure log(
    constant msg       : in string;
    constant log_level : in log_level_t := info;
    constant src       : in string      := "";
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  procedure verbose_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure verbose_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure verbose(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure verbose_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure verbose_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure debug_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure debug_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure debug(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure debug_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure debug_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure info_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure info_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure info(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure info_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure info_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure warning_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure warning_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure warning(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure warning_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure warning_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure error_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure error_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure error(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure error_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure error_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure failure_high2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure failure_high1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure failure(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure failure_low1(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure failure_low2(
    constant msg       : in    string;
    constant src       : in    string  := "";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "");

  procedure get_logger_cfg (
    variable cfg : inout logger_cfg_t);

  procedure get_logger_cfg (
    variable cfg : inout logger_cfg_export_t);

  procedure stop_source_level (
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure stop_source_level (
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure pass_source_level (
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure pass_source_level (
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure stop_level (
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure stop_level (
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure pass_level (
    constant level : in log_level_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure pass_level (
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure stop_source (
    constant source : in string;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure pass_source (
    constant source : in string;
    constant handler       : in log_handler_t;
    variable filter       : out log_filter_t);

  procedure stop_source_level (
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure stop_source_level (
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure pass_source_level (
    constant source : in string;
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure pass_source_level (
    constant source : in string;
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure stop_level (
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure stop_level (
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure pass_level (
    constant level : in log_level_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure pass_level (
    constant levels : in log_level_vector_t;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure stop_source (
    constant source : in string;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure pass_source (
    constant source : in string;
    constant handler       : in log_handler_vector_t;
    variable filter       : out log_filter_t);

  procedure remove_filter (
    constant filter : in log_filter_t);

  procedure rename_level (
    constant level  : in    log_level_t;
    constant name   : in    string);

end package;
