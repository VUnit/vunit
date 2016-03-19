-- Provides a common API for the log base package.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.log_types_pkg.all;
use work.log_special_types_pkg.all;
use work.log_formatting_pkg.all;

package log_base_pkg is
  procedure base_init (
    variable logger         : inout logger_t;
    constant default_src    : in    string       := "";
    constant file_name      : in    string       := "log.csv";
    constant display_format : in    log_format_t := raw;
    constant file_format    : in    log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in    character    := ',';
    constant append         : in    boolean      := false);

  procedure base_log(
    variable logger    : inout logger_t;
    constant msg       : in    string;
    constant log_level : in    log_level_t := info;
    constant src       : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure base_get_logger_cfg (
    variable logger : inout logger_t;
    variable cfg    : inout logger_cfg_t);

  procedure base_get_logger_cfg (
    variable logger : inout logger_t;
    variable cfg    : inout logger_cfg_export_t);

  procedure base_add_filter (
    variable logger : inout logger_t;
    variable filter       : out log_filter_t;
    constant levels : in log_level_vector_t := null_log_level_vector;
    constant src : in string := "";
    constant pass               : in boolean := false;
    constant handlers       : in log_handler_vector_t);

  procedure base_remove_filter (
    variable logger : inout logger_t;
    constant filter : in log_filter_t);

  procedure base_rename_level (
    variable logger : inout logger_t;
    constant level  : in    log_level_t;
    constant name   : in    string);

end package;
