-- This file contains the API for the check package. The API is
-- common to all implementations of the check functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.check_types_pkg.all;
use work.check_special_types_pkg.all;
use work.check_base_pkg.all;
use work.log_types_pkg.all;
use work.log_special_types_pkg.all;
use work.log_pkg.all;

package check_pkg is
  shared variable default_checker : checker_t;
  signal check_enabled : std_logic := '1';

  alias checker_init is base_init[checker_t, log_level_t, string, string, log_format_t, log_format_t, log_level_t, character, boolean];

  procedure checker_init (
    constant default_level  : in log_level_t  := error;
    constant default_src    : in string       := "";
    constant file_name      : in string       := "error.csv";
    constant display_format : in log_format_t := level;
    constant file_format    : in log_format_t := off;
    constant stop_level : in log_level_t := failure;
    constant separator      : in character    := ',';
    constant append         : in boolean      := false);

  procedure checker_init (
    variable checker       : inout checker_t;
    constant default_level : in    log_level_t := error;
    variable logger        : inout logger_t);

  procedure checker_init (
    constant default_level : in    log_level_t := error;
    variable logger        : inout logger_t);

  alias check is base_check[checker_t, boolean, string, log_level_t, natural, string];

  procedure check(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    boolean;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check(
    constant expr      : in boolean;
    constant msg       : in string      := "Check failed!";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  procedure check(
    variable pass      : out boolean;
    constant expr      : in  boolean;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "");

  impure function check(
    constant expr      : in  boolean;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "")
    return boolean;

  procedure get_checker_stat (
    variable stat : out checker_stat_t);
  alias get_checker_stat is base_get_checker_stat[checker_t, checker_stat_t];
  impure function get_checker_stat
    return checker_stat_t;

  procedure reset_checker_stat;
  alias reset_checker_stat is base_reset_checker_stat[checker_t];

  procedure get_checker_cfg (
    variable cfg : inout checker_cfg_t);
  alias get_checker_cfg is base_get_checker_cfg[checker_t, checker_cfg_t];

  procedure get_checker_cfg (
    variable cfg : inout checker_cfg_export_t);
  alias get_checker_cfg is base_get_checker_cfg[checker_t, checker_cfg_export_t];

  procedure get_logger_cfg (
    variable cfg : inout logger_cfg_t);
  alias get_logger_cfg is base_get_logger_cfg[checker_t, logger_cfg_t];

  procedure get_logger_cfg (
    variable cfg : inout logger_cfg_export_t);
  alias get_logger_cfg is base_get_logger_cfg[checker_t, logger_cfg_export_t];

  procedure checker_found_errors (
    variable result : out boolean);
  alias checker_found_errors is base_checker_found_errors[checker_t, boolean];
  impure function checker_found_errors
    return boolean;

  function "+" (
    constant stat1 : checker_stat_t;
    constant stat2 : checker_stat_t)
    return checker_stat_t;

  function "-" (
    constant stat1 : checker_stat_t;
    constant stat2 : checker_stat_t)
    return checker_stat_t;

  -- pragma translate_off
  function to_string (
    constant stat : checker_stat_t)
    return string;
  -- pragma translate_on

  -----------------------------------------------------------------------------
  -- check_passed
  -----------------------------------------------------------------------------
  procedure check_passed(
    variable checker   : inout checker_t);

  procedure check_passed;

  -----------------------------------------------------------------------------
  -- check_failed
  -----------------------------------------------------------------------------
  procedure check_failed(
    variable checker   : inout checker_t;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_failed(
    constant msg       : in string      := "Check failed!";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  -----------------------------------------------------------------------------
  -- check_true
  -----------------------------------------------------------------------------
  procedure check_true(
    variable checker   : inout checker_t;
    constant expr      : in    boolean;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_true(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    boolean;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_true(
    variable checker    : inout checker_t;
    signal clock        : in    std_logic;
    signal en           : in    std_logic;
    signal expr         : in    std_logic;
    constant msg        : in    string           := "Check failed!";
    constant level      : in    log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in    natural          := 0;
    constant file_name  : in    string           := "");

  procedure check_true(
    constant expr      : in boolean;
    constant msg       : in string      := "Check failed!";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  procedure check_true(
    variable pass      : out boolean;
    constant expr      : in  boolean;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "");

  impure function check_true(
    constant expr      : in  boolean;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "")
    return boolean;

  procedure check_true(
    signal clock        : in std_logic;
    signal en           : in std_logic;
    signal expr         : in std_logic;
    constant msg        : in string           := "Check failed!";
    constant level      : in log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in natural          := 0;
    constant file_name  : in string           := "");

  -----------------------------------------------------------------------------
  -- check_false
  -----------------------------------------------------------------------------
  procedure check_false(
    variable checker   : inout checker_t;
    constant expr      : in    boolean;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_false(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    boolean;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_false(
    variable checker    : inout checker_t;
    signal clock        : in    std_logic;
    signal en           : in    std_logic;
    signal expr         : in    std_logic;
    constant msg        : in    string           := "Check failed!";
    constant level      : in    log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in    natural          := 0;
    constant file_name  : in    string           := "");

  procedure check_false(
    constant expr      : in boolean;
    constant msg       : in string      := "Check failed!";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  procedure check_false(
    variable pass      : out boolean;
    constant expr      : in  boolean;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "");

  impure function check_false(
    constant expr      : in  boolean;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "")
    return boolean;

  procedure check_false(
    signal clock        : in std_logic;
    signal en           : in std_logic;
    signal expr         : in std_logic;
    constant msg        : in string           := "Check failed!";
    constant level      : in log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in natural          := 0;
    constant file_name  : in string           := "");

  -----------------------------------------------------------------------------
  -- check_implication
  -----------------------------------------------------------------------------
  procedure check_implication(
    variable checker       : inout checker_t;
    signal clock           : in    std_logic;
    signal en              : in    std_logic;
    signal antecedent_expr : in    std_logic;
    signal consequent_expr : in    std_logic;
    constant msg           : in    string           := "Check failed!";
    constant level         : in    log_level_t      := dflt;
    constant active_clock_edge    : in edge_t := rising_edge;
    constant line_num      : in    natural          := 0;
    constant file_name     : in    string           := "");

  procedure check_implication(
    signal clock           : in std_logic;
    signal en              : in std_logic;
    signal antecedent_expr : in std_logic;
    signal consequent_expr : in std_logic;
    constant msg           : in string           := "Check failed!";
    constant level         : in log_level_t      := dflt;
    constant active_clock_edge    : in edge_t := rising_edge;
    constant line_num      : in natural          := 0;
    constant file_name     : in string           := "");

  procedure check_implication(
    variable checker         : inout checker_t;
    constant antecedent_expr : in    boolean;
    constant consequent_expr : in    boolean;
    constant msg             : in    string      := "Check failed!";
    constant level           : in    log_level_t := dflt;
    constant line_num        : in    natural     := 0;
    constant file_name       : in    string      := "");

  procedure check_implication(
    variable checker         : inout checker_t;
    variable pass            : out   boolean;
    constant antecedent_expr : in    boolean;
    constant consequent_expr : in    boolean;
    constant msg             : in    string      := "Check failed!";
    constant level           : in    log_level_t := dflt;
    constant line_num        : in    natural     := 0;
    constant file_name       : in    string      := "");

  procedure check_implication(
    constant antecedent_expr : in boolean;
    constant consequent_expr : in boolean;
    constant msg             : in string      := "Check failed!";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_implication(
    variable pass            : out boolean;
    constant antecedent_expr : in  boolean;
    constant consequent_expr : in  boolean;
    constant msg             : in  string      := "Check failed!";
    constant level           : in  log_level_t := dflt;
    constant line_num        : in  natural     := 0;
    constant file_name       : in  string      := "");

  impure function check_implication(
    constant antecedent_expr : in  boolean;
    constant consequent_expr : in  boolean;
    constant msg             : in  string      := "Check failed!";
    constant level           : in  log_level_t := dflt;
    constant line_num        : in  natural     := 0;
    constant file_name       : in  string      := "")
    return boolean;

  -----------------------------------------------------------------------------
  -- check_stable
  -----------------------------------------------------------------------------
  procedure check_stable(
    variable checker    : inout checker_t;
    signal clock        : in    std_logic;
    signal en           : in    std_logic;
    signal start_event  : in    std_logic;
    signal end_event    : in    std_logic;
    signal expr         : in    std_logic_vector;
    constant msg        : in    string           := "Check failed!";
    constant level      : in    log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in    natural          := 0;
    constant file_name  : in    string           := "");

  procedure check_stable(
    signal clock        : in std_logic;
    signal en           : in std_logic;
    signal start_event  : in std_logic;
    signal end_event    : in std_logic;
    signal expr         : in std_logic_vector;
    constant msg        : in string           := "Check failed!";
    constant level      : in log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in natural          := 0;
    constant file_name  : in string           := "");

  procedure check_stable(
    variable checker    : inout checker_t;
    signal clock        : in    std_logic;
    signal en           : in    std_logic;
    signal start_event  : in    std_logic;
    signal end_event    : in    std_logic;
    signal expr         : in    std_logic;
    constant msg        : in    string           := "Check failed!";
    constant level      : in    log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in    natural          := 0;
    constant file_name  : in    string           := "");

  procedure check_stable(
    signal clock        : in std_logic;
    signal en           : in std_logic;
    signal start_event  : in std_logic;
    signal end_event    : in std_logic;
    signal expr         : in std_logic;
    constant msg        : in string           := "Check failed!";
    constant level      : in log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in natural          := 0;
    constant file_name  : in string           := "");

  -------------------------------------------------------------------------------
  -- check_not_unknown
  -------------------------------------------------------------------------------
  procedure check_not_unknown(
    variable checker    : inout checker_t;
    signal clock        : in    std_logic;
    signal en           : in    std_logic;
    signal expr         : in    std_logic_vector;
    constant msg        : in    string           := "Check failed!";
    constant level      : in    log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in    natural          := 0;
    constant file_name  : in    string           := "");

  procedure check_not_unknown(
    signal clock        : in std_logic;
    signal en           : in std_logic;
    signal expr         : in std_logic_vector;
    constant msg        : in string           := "Check failed!";
    constant level      : in log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in natural          := 0;
    constant file_name  : in string           := "");

  procedure check_not_unknown(
    variable checker   : inout checker_t;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_not_unknown(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_not_unknown(
    constant expr      : in std_logic_vector;
    constant msg       : in string      := "Check failed!";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  procedure check_not_unknown(
    variable pass      : out boolean;
    constant expr      : in  std_logic_vector;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "");

  impure function check_not_unknown(
    constant expr      : in  std_logic_vector;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "")
    return boolean;

  procedure check_not_unknown(
    variable checker    : inout checker_t;
    signal clock        : in    std_logic;
    signal en           : in    std_logic;
    signal expr         : in    std_logic;
    constant msg        : in    string           := "Check failed!";
    constant level      : in    log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in    natural          := 0;
    constant file_name  : in    string           := "");

  procedure check_not_unknown(
    signal clock        : in std_logic;
    signal en           : in std_logic;
    signal expr         : in std_logic;
    constant msg        : in string           := "Check failed!";
    constant level      : in log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in natural          := 0;
    constant file_name  : in string           := "");

  procedure check_not_unknown(
    variable checker   : inout checker_t;
    constant expr      : in    std_logic;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_not_unknown(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    std_logic;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_not_unknown(
    constant expr      : in std_logic;
    constant msg       : in string      := "Check failed!";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  procedure check_not_unknown(
    variable pass      : out boolean;
    constant expr      : in  std_logic;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "");

  impure function check_not_unknown(
    constant expr      : in  std_logic;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "")
    return boolean;

  -----------------------------------------------------------------------------
  -- check_zero_one_hot
  -----------------------------------------------------------------------------
  procedure check_zero_one_hot(
    variable checker    : inout checker_t;
    signal clock        : in    std_logic;
    signal en           : in    std_logic;
    signal expr         : in    std_logic_vector;
    constant msg        : in    string           := "Check failed!";
    constant level      : in    log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in    natural          := 0;
    constant file_name  : in    string           := "");

  procedure check_zero_one_hot(
    signal clock        : in std_logic;
    signal en           : in std_logic;
    signal expr         : in std_logic_vector;
    constant msg        : in string           := "Check failed!";
    constant level      : in log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in natural          := 0;
    constant file_name  : in string           := "");

  procedure check_zero_one_hot(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_zero_one_hot(
    variable pass      : out boolean;
    constant expr      : in  std_logic_vector;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "");

  impure function check_zero_one_hot(
    constant expr      : in  std_logic_vector;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "")
    return boolean;

  procedure check_zero_one_hot(
    variable checker   : inout checker_t;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_zero_one_hot(
    constant expr      : in std_logic_vector;
    constant msg       : in string      := "Check failed!";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  -----------------------------------------------------------------------------
  -- check_one_hot
  -----------------------------------------------------------------------------
  procedure check_one_hot(
    variable checker    : inout checker_t;
    signal clock        : in    std_logic;
    signal en           : in    std_logic;
    signal expr         : in    std_logic_vector;
    constant msg        : in    string           := "Check failed!";
    constant level      : in    log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in    natural          := 0;
    constant file_name  : in    string           := "");

  procedure check_one_hot(
    signal clock        : in std_logic;
    signal en           : in std_logic;
    signal expr         : in std_logic_vector;
    constant msg        : in string           := "Check failed!";
    constant level      : in log_level_t      := dflt;
    constant active_clock_edge : in edge_t := rising_edge;
    constant line_num   : in natural          := 0;
    constant file_name  : in string           := "");

  procedure check_one_hot(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_one_hot(
    variable pass      : out boolean;
    constant expr      : in  std_logic_vector;
    constant msg       : in  string      := "Check failed!";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "");

  impure function check_one_hot(
    constant expr      : in  std_logic_vector;
    constant msg       : in  string      := "Check failed!";
    constant level     :  in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "")
    return boolean;

  procedure check_one_hot(
    variable checker   : inout checker_t;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := "Check failed!";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_one_hot(
    constant expr      : in std_logic_vector;
    constant msg       : in string      := "Check failed!";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  -----------------------------------------------------------------------------
  -- check_next
  -----------------------------------------------------------------------------
  procedure check_next(
    variable checker             : inout checker_t;
    signal clock                 : in    std_logic;
    signal en                    : in    std_logic;
    signal start_event           : in    std_logic;
    signal expr                  : in    std_logic;
    constant msg                 : in    string           := "Check failed!";
    constant num_cks             : in    positive         := 1;
    constant allow_overlapping   : in    boolean          := true;
    constant allow_missing_start : in    boolean          := true;
    constant level               : in    log_level_t      := dflt;
    constant active_clock_edge          : in edge_t := rising_edge;
    constant line_num            : in    natural          := 0;
    constant file_name           : in    string           := "");

  procedure check_next(
    signal clock                 : in std_logic;
    signal en                    : in std_logic;
    signal start_event           : in std_logic;
    signal expr                  : in std_logic;
    constant msg                 : in string           := "Check failed!";
    constant num_cks             : in positive         := 1;
    constant allow_overlapping   : in boolean          := true;
    constant allow_missing_start : in boolean          := true;
    constant level               : in log_level_t      := dflt;
    constant active_clock_edge          : in edge_t := rising_edge;
    constant line_num            : in natural          := 0;
    constant file_name           : in string           := "");

  -----------------------------------------------------------------------------
  -- check_sequence
  -----------------------------------------------------------------------------
  procedure check_sequence(
    variable checker             : inout checker_t;
    signal clock                 : in    std_logic;
    signal en                    : in    std_logic;
    signal event_sequence        : in    std_logic_vector;
    constant msg                 : in    string                  := "Check failed!";
    constant trigger_event : in    trigger_event_t := penultimate;
    constant level               : in    log_level_t             := dflt;
    constant active_clock_edge          : in edge_t := rising_edge;
    constant line_num            : in    natural                 := 0;
    constant file_name           : in    string                  := "");

  procedure check_sequence(
    signal clock                 : in std_logic;
    signal en                    : in std_logic;
    signal event_sequence        : in std_logic_vector;
    constant msg                 : in string                  := "Check failed!";
    constant trigger_event : in    trigger_event_t := penultimate;
    constant level               : in log_level_t             := dflt;
    constant active_clock_edge          : in edge_t := rising_edge;
    constant line_num            : in natural                 := 0;
    constant file_name           : in string                  := "");

  -----------------------------------------------------------------------------
  -- check_relation
  -----------------------------------------------------------------------------
  procedure check_relation(
    variable checker   : inout checker_t;
    constant expr      : in    boolean;
    constant msg       : in    string      := "";
    constant level     : in    log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_relation(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    boolean;
    constant msg       : in    string      := "";
    constant level     : in    log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_relation(
    constant expr      : in boolean;
    constant msg       : in string      := "";
    constant level     : in log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  procedure check_relation(
    variable pass      : out boolean;
    constant expr      : in  boolean;
    constant msg       : in  string      := "";
    constant level     : in  log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "");

  impure function check_relation(
    constant expr      : in  boolean;
    constant msg       : in  string      := "";
    constant level     : in  log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "")
    return boolean;

  procedure check_relation(
    variable checker   : inout checker_t;
    constant expr      : in    std_ulogic;
    constant msg       : in    string      := "";
    constant level     : in    log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_relation(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    std_ulogic;
    constant msg       : in    string      := "";
    constant level     : in    log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_relation(
    constant expr      : in std_ulogic;
    constant msg       : in string      := "";
    constant level     : in log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  procedure check_relation(
    variable pass      : out boolean;
    constant expr      : in  std_ulogic;
    constant msg       : in  string      := "";
    constant level     : in  log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "");

  impure function check_relation(
    constant expr      : in  std_ulogic;
    constant msg       : in  string      := "";
    constant level     : in  log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "")
    return boolean;

  procedure check_relation(
    variable checker   : inout checker_t;
    constant expr      : in    bit;
    constant msg       : in    string      := "";
    constant level     : in    log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_relation(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    bit;
    constant msg       : in    string      := "";
    constant level     : in    log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "");

  procedure check_relation(
    constant expr      : in bit;
    constant msg       : in string      := "";
    constant level     : in log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "");

  procedure check_relation(
    variable pass      : out boolean;
    constant expr      : in  bit;
    constant msg       : in  string      := "";
    constant level     : in  log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "");

  impure function check_relation(
    constant expr      : in  bit;
    constant msg       : in  string      := "";
    constant level     : in  log_level_t := dflt;
    constant auto_msg  : in    string      := "";
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "")
    return boolean;

  -----------------------------------------------------------------------------
  -- Manually generated check_equals
  -----------------------------------------------------------------------------

  procedure check_equal(
    constant got             : in time;
    constant expected        : in time;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in time;
    constant expected        : in time;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in time;
    constant expected        : in time;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in time;
    constant expected        : in time;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in time;
    constant expected        : in time;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in string;
    constant expected        : in string;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in string;
    constant expected        : in string;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in string;
    constant expected        : in string;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in string;
    constant expected        : in string;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in string;
    constant expected        : in string;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;
  -----------------------------------------------------------------------------
  -- check_equal
  -----------------------------------------------------------------------------

  procedure check_equal(
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in unsigned;
    constant expected        : in natural;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in natural;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in natural;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in unsigned;
    constant expected        : in natural;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in unsigned;
    constant expected        : in natural;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in natural;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in natural;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in natural;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in natural;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in natural;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in unsigned;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in unsigned;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in unsigned;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in std_logic_vector;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in std_logic_vector;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in std_logic_vector;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in signed;
    constant expected        : in integer;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in integer;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in integer;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in signed;
    constant expected        : in integer;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in signed;
    constant expected        : in integer;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in integer;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in integer;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in integer;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in integer;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in integer;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in integer;
    constant expected        : in integer;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in integer;
    constant expected        : in integer;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in integer;
    constant expected        : in integer;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in integer;
    constant expected        : in integer;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in integer;
    constant expected        : in integer;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in std_logic;
    constant expected        : in boolean;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in boolean;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in boolean;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in std_logic;
    constant expected        : in boolean;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in std_logic;
    constant expected        : in boolean;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in boolean;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in boolean;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in boolean;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in boolean;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in boolean;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_equal(
    constant got             : in boolean;
    constant expected        : in boolean;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in boolean;
    constant expected        : in boolean;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in boolean;
    constant expected        : in boolean;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in boolean;
    constant expected        : in boolean;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_equal(
    constant got             : in boolean;
    constant expected        : in boolean;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  -----------------------------------------------------------------------------
  -- check_match
  -----------------------------------------------------------------------------

  procedure check_match(
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable checker         : inout checker_t;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_match(
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_match(
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable checker         : inout checker_t;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_match(
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_match(
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable checker         : inout checker_t;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_match(
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;

  procedure check_match(
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  procedure check_match(
    variable checker         : inout checker_t;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "");

  impure function check_match(
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := "";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean;
end package;
