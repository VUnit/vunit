-- Provides a common API for the check base package
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
use work.check_special_types_pkg.all;
use work.log_types_pkg.all;
use work.log_special_types_pkg.all;
use work.log_pkg.all;

package check_base_pkg is
  procedure base_init (
    variable checker               : inout checker_t;
    constant default_level        : in    log_level_t := error;
    constant default_src          : in    string      := "";
    constant file_name            : in    string      := "error.csv";
    constant display_format : in    log_format_t  := level;
    constant file_format    : in    log_format_t  := off;
    constant stop_level : in log_level_t := failure;
    constant separator            : in    character   := ',';
    constant append               : in    boolean     := false);

  procedure base_check(
    variable checker       : inout checker_t;
    constant expr         : in    boolean;
    constant msg          : in    string := "Check failed!";
    constant level        : in    log_level_t := dflt;
    constant line_num : in natural := 0;
    constant file_name : in string := "");

  procedure base_get_checker_stat (
    variable checker : inout checker_t;
    variable stat : out checker_stat_t);

  procedure base_reset_checker_stat (
    variable checker : inout checker_t);

  procedure base_get_checker_cfg (
    variable checker : inout checker_t;
    variable cfg : inout checker_cfg_t);

  procedure base_get_checker_cfg (
    variable checker : inout checker_t;
    variable cfg : inout checker_cfg_export_t);

  procedure base_get_logger_cfg (
    variable checker : inout checker_t;
    variable cfg : inout logger_cfg_t);

  procedure base_get_logger_cfg (
    variable checker : inout checker_t;
    variable cfg : inout logger_cfg_export_t);

  procedure base_checker_found_errors (
    variable checker : inout checker_t;
    variable result : out   boolean);

end package;
