-- The check package provides the primary checking functionality.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.check_types_pkg.all;
use work.check_base_pkg.all;
use work.log_base_pkg.all;
use work.log_pkg.all;
use work.string_ops.all;

package body check_pkg is
  type boolean_vector is array (natural range <>) of boolean;
  function logical_right_shift (
    constant arg   : boolean_vector;
    constant count : natural)
    return boolean_vector is
    variable ret_val : boolean_vector(0 to arg'length - 1) := (others => false);
    constant temp    : boolean_vector(0 to arg'length - 1) := arg;
  begin
    ret_val(count to ret_val'right) := temp(0 to ret_val'right - count);

    return ret_val;
  end function logical_right_shift;
  constant max_supported_num_of_bits_in_integer_implementation : natural := 256;

  function std_msg (
    constant check_result : string;
    constant msg    : string;
    constant ctx    : string)
    return string is
    constant msg_i : string(1 to msg'length) := msg;

    function replace_result_tag (msg, check_result : string) return string is
    begin
      if msg'length < check_result_tag_c'length then
        return msg;
      elsif msg(1 to check_result_tag_c'length) = check_result_tag_c then
        return check_result & msg(check_result_tag_c'length + 1 to msg'right);
      else
        return msg;
      end if;
    end function replace_result_tag;

    function append_context (msg, ctx : string) return string is
    begin
      if msg = "" then
        return ctx;
      elsif ctx = "" then
        return msg;
      else
        return msg & " - " & ctx;
      end if;
    end function append_context;
  begin
    return append_context(replace_result_tag(msg_i, check_result), ctx);
  end function std_msg;

  procedure checker_init (
    constant default_level  : in log_level_t  := error;
    constant default_src    : in string       := "";
    constant file_name      : in string       := "error.csv";
    constant display_format : in log_format_t := level;
    constant file_format    : in log_format_t := off;
    constant stop_level     : in log_level_t  := failure;
    constant separator      : in character    := ',';
    constant append         : in boolean      := false) is
  begin
    -- pragma translate_off
    base_init(default_checker,
              default_level,
              default_src,
              file_name,
              display_format,
              file_format,
              stop_level,
              separator,
              append);
  -- pragma translate_on
  end checker_init;

  procedure enable_pass_msg is
  begin
    enable_pass_msg(display_handler);
    enable_pass_msg(file_handler);
  end;

  procedure enable_pass_msg (
    constant handler : in log_handler_t) is
  begin
    base_enable_pass_msg(default_checker, handler);
  end;

  procedure disable_pass_msg is
  begin
    disable_pass_msg(display_handler);
    disable_pass_msg(file_handler);
  end;

  procedure disable_pass_msg (
    constant handler : in log_handler_t) is
  begin
    base_disable_pass_msg(default_checker, handler);
  end;

  procedure enable_pass_msg (
    variable checker : inout checker_t) is
  begin
    base_enable_pass_msg(checker, display_handler);
    base_enable_pass_msg(checker, file_handler);
  end;

  procedure disable_pass_msg (
    variable checker : inout checker_t) is
  begin
    base_disable_pass_msg(checker, display_handler);
    base_disable_pass_msg(checker, file_handler);
  end;

  procedure checker_init (
    variable checker       : inout checker_t;
    constant default_level : in    log_level_t := error;
    variable logger        : inout logger_t) is
    variable cfg : logger_cfg_t;
  begin
    -- pragma translate_off
    get_logger_cfg(logger, cfg);
    checker_init(checker,
                 default_level,
                 cfg.log_default_src.all,
                 cfg.log_file_name.all,
                 cfg.log_display_format,
                 cfg.log_file_format,
                 cfg.log_stop_level,
                 cfg.log_separator,
                 true);
  -- pragma translate_on
  end;

  procedure checker_init (
    constant default_level : in    log_level_t := error;
    variable logger        : inout logger_t) is
  begin
    -- pragma translate_off
    checker_init(default_checker,
                 default_level,
                 logger);
  -- pragma translate_on
  end checker_init;

  procedure get_checker_stat (
    variable stat : out checker_stat_t) is
  begin
    get_checker_stat(default_checker, stat);
  end;

  impure function get_checker_stat
    return checker_stat_t is
    variable stat : checker_stat_t;
  begin
    get_checker_stat(default_checker, stat);
    return stat;
  end function get_checker_stat;

  procedure reset_checker_stat is
  begin
    reset_checker_stat(default_checker);
  end reset_checker_stat;

  function "+" (
    constant stat1 : checker_stat_t;
    constant stat2 : checker_stat_t)
    return checker_stat_t is
    variable sum : checker_stat_t;
  begin
    sum.n_checks := stat1.n_checks + stat2.n_checks;
    sum.n_passed := stat1.n_passed + stat2.n_passed;
    sum.n_failed := stat1.n_failed + stat2.n_failed;

    return sum;
  end function "+";

  function "-" (
    constant stat1 : checker_stat_t;
    constant stat2 : checker_stat_t)
    return checker_stat_t is
    variable diff : checker_stat_t;
  begin
    diff.n_checks := stat1.n_checks - stat2.n_checks;
    diff.n_passed := stat1.n_passed - stat2.n_passed;
    diff.n_failed := stat1.n_failed - stat2.n_failed;

    return diff;
  end function "-";

  -- pragma translate_off
  function to_string (
    constant stat : checker_stat_t)
    return string is
    variable result : line;
  begin
    write(result, "Checks: " & natural'image(stat.n_checks) & LF & "Passed: ");
    write(result, stat.n_passed, right, natural'image(stat.n_checks)'length);
    write(result, LF & "Failed: ");
    write(result, stat.n_failed, right, natural'image(stat.n_checks)'length);

    return result.all;
  end function to_string;
  -- pragma translate_on

  procedure get_checker_cfg (
    variable cfg : inout checker_cfg_t) is
  begin
    get_checker_cfg(default_checker, cfg);
  end;

  procedure get_checker_cfg (
    variable cfg : inout checker_cfg_export_t) is
  begin
    get_checker_cfg(default_checker, cfg);
  end;

  procedure get_logger_cfg (
    variable cfg : inout logger_cfg_t) is
  begin
    get_logger_cfg(default_checker, cfg);
  end;

  procedure get_logger_cfg (
    variable cfg : inout logger_cfg_export_t) is
  begin
    get_logger_cfg(default_checker, cfg);
  end;

  procedure checker_found_errors (
    variable result : out boolean) is
  begin
    checker_found_errors(default_checker, result);
  end;

  impure function checker_found_errors
    return boolean is
    variable result : boolean;
  begin
    checker_found_errors(default_checker, result);
    return result;
  end function checker_found_errors;

  procedure wait_on_edge (
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    constant active_clock_edge : in edge_t;
    constant n_edges           : in positive := 1) is
  begin
    for i in 1 to n_edges loop
      if active_clock_edge = rising_edge then
        wait until rising_edge(clock) and (to_x01(en) = '1');
      elsif active_clock_edge = falling_edge then
        wait until falling_edge(clock) and (to_x01(en) = '1');
      elsif active_clock_edge = both_edges then
        wait until (falling_edge(clock) or rising_edge(clock)) and (to_x01(en) = '1');
      else
        wait;
      end if;
    end loop;
  end wait_on_edge;

  function start_condition (
    signal clock               : std_logic;
    constant active_clock_edge : edge_t;
    signal start_event         : std_logic;
    signal en                  : std_logic)
    return boolean is
  begin
    if (to_x01(start_event) = '0') or (to_x01(en) /= '1') then
      return false;
    elsif active_clock_edge = rising_edge then
      return rising_edge(clock);
    elsif active_clock_edge = falling_edge then
      return falling_edge(clock);
    elsif active_clock_edge = both_edges then
      return falling_edge(clock) or rising_edge(clock);
    else
      return false;
    end if;
  end start_condition;

  function result (msg : string := "") return string is
  begin
    if msg = "" then
      return check_result_tag_c;
    elsif msg(msg'left) = '.' or msg(msg'left) = ',' or msg(msg'left) = ':' or
          msg(msg'left) = ';' or msg(msg'left) = '?' or msg(msg'left) = '!' then
      return check_result_tag_c & msg;
    else
      return check_result_tag_c & " " & msg;
    end if;
  end;

  function to_ordinal_number (num : natural) return string is
    constant num_str : string := natural'image(num);
    variable ordinal_unit : string(1 to 2);
  begin
    case num_str(num_str'right) is
      when '1' => ordinal_unit := "st";
      when '2' => ordinal_unit := "nd";
      when '3' => ordinal_unit := "rd";
      when others => ordinal_unit := "th";
    end case;

    if num_str'length > 1 then
      if num_str(num_str'right - 1) = '1' then
        ordinal_unit := "th";
      end if;
    end if;

    return num_str & ordinal_unit;
  end function to_ordinal_number;

  -----------------------------------------------------------------------------
  -- check
  -----------------------------------------------------------------------------
  procedure check(
    variable checker           : inout checker_t;
    signal clock               : in    std_logic;
    signal en                  : in    std_logic;
    signal expr                : in    std_logic;
    constant msg               : in    string      := check_result_tag_c & ".";
    constant level             : in    log_level_t := dflt;
    constant active_clock_edge : in    edge_t      := rising_edge;
    constant line_num          : in    natural     := 0;
    constant file_name         : in    string      := "") is
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check(checker, to_x01(expr) = '1', msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    boolean;
    constant msg       : in    string      := check_result_tag_c & ".";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if expr then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(checker, std_msg("Check passed", msg, ""), line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(checker, std_msg("Check failed", msg, ""), level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check(
    variable checker   : inout checker_t;
    constant expr      : in    boolean;
    constant msg       : in    string      := check_result_tag_c & ".";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check(checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check(
    constant expr      : in boolean;
    constant msg       : in string      := check_result_tag_c & ".";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check(
    variable pass      : out boolean;
    constant expr      : in  boolean;
    constant msg       : in  string      := check_result_tag_c & ".";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "") is
  begin
    -- pragma translate_off
    check(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check(
    constant expr      : in boolean;
    constant msg       : in string      := check_result_tag_c & ".";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag_c & ".";
    constant level             : in log_level_t := dflt;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check(default_checker, clock, en, expr, msg, level, active_clock_edge, line_num, file_name);
    -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_passed
  -----------------------------------------------------------------------------
  procedure check_passed(
    variable checker   : inout checker_t;
    constant msg       : in    string  := check_result_tag_c & ".";
    constant line_num  : in    natural := 0;
    constant file_name : in    string  := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    base_pass_msg_enabled(checker, en);
    if en then
      base_check_true(checker, std_msg("Unconditional check passed", msg, ""), line_num, file_name);
    else
      base_check_true(checker);
    end if;
    -- pragma translate_on
  end;

  procedure check_passed(
    constant msg       : in string  := check_result_tag_c & ".";
    constant line_num  : in natural := 0;
    constant file_name : in string  := "") is
  begin
    -- pragma translate_off
    check_passed(default_checker, msg, line_num, file_name);
    -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_failed
  -----------------------------------------------------------------------------
  procedure check_failed(
    variable checker   : inout checker_t;
    constant msg       : in    string      := check_result_tag_c & ".";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
  begin
    -- pragma translate_off
    base_check_false(checker, std_msg("Unconditional check failed", msg, ""), level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_failed(
    constant msg       : in string      := check_result_tag_c & ".";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
  begin
    -- pragma translate_off
    base_check_false(default_checker, std_msg("Unconditional check failed", msg, ""), level, line_num, file_name);
    -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_true
  -----------------------------------------------------------------------------
  procedure check_true(
    variable checker           : inout checker_t;
    signal clock               : in    std_logic;
    signal en                  : in    std_logic;
    signal expr                : in    std_logic;
    constant msg               : in    string      := check_result_tag_c & ".";
    constant level             : in    log_level_t := dflt;
    constant active_clock_edge : in    edge_t      := rising_edge;
    constant line_num          : in    natural     := 0;
    constant file_name         : in    string      := "") is
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_true(checker, to_x01(expr) = '1', msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_true(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    boolean;
    constant msg       : in    string      := check_result_tag_c & ".";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if expr then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(checker, std_msg("True check passed", msg, ""), line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(checker, std_msg("True check failed", msg, ""), level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_true(
    variable checker   : inout checker_t;
    constant expr      : in    boolean;
    constant msg       : in    string      := check_result_tag_c & ".";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_true(checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_true(
    constant expr      : in boolean;
    constant msg       : in string      := check_result_tag_c & ".";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_true(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_true(
    variable pass      : out boolean;
    constant expr      : in  boolean;
    constant msg       : in  string      := check_result_tag_c & ".";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "") is
  begin
    -- pragma translate_off
    check_true(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_true(
    constant expr      : in boolean;
    constant msg       : in string      := check_result_tag_c & ".";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_true(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_true(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag_c & ".";
    constant level             : in log_level_t := dflt;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_true(default_checker, clock, en, expr, msg, level, active_clock_edge, line_num, file_name);
    -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_false
  -----------------------------------------------------------------------------
  procedure check_false(
    variable checker           : inout checker_t;
    signal clock               : in    std_logic;
    signal en                  : in    std_logic;
    signal expr                : in    std_logic;
    constant msg               : in    string      := check_result_tag_c & ".";
    constant level             : in    log_level_t := dflt;
    constant active_clock_edge : in    edge_t      := rising_edge;
    constant line_num          : in    natural     := 0;
    constant file_name         : in    string      := "") is
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_false(checker, to_x01(expr) /= '0', msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_false(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    boolean;
    constant msg       : in    string      := check_result_tag_c & ".";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if not expr then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(checker, std_msg("False check passed", msg, ""), line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(checker, std_msg("False check failed", msg, ""), level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_false(
    variable checker   : inout checker_t;
    constant expr      : in    boolean;
    constant msg       : in    string      := check_result_tag_c & ".";
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_false(checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_false(
    constant expr      : in boolean;
    constant msg       : in string      := check_result_tag_c & ".";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_false(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_false(
    variable pass      : out boolean;
    constant expr      : in  boolean;
    constant msg       : in  string      := check_result_tag_c & ".";
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "") is
  begin
    -- pragma translate_off
    check_false(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_false(
    constant expr      : in boolean;
    constant msg       : in string      := check_result_tag_c & ".";
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_false(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_false(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag_c & ".";
    constant level             : in log_level_t := dflt;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_false(default_checker, clock, en, expr, msg, level, active_clock_edge, line_num, file_name);
    -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_implication
  -----------------------------------------------------------------------------
  procedure check_implication(
    variable checker           : inout checker_t;
    signal clock               : in    std_logic;
    signal en                  : in    std_logic;
    signal antecedent_expr     : in    std_logic;
    signal consequent_expr     : in    std_logic;
    constant msg               : in    string      := check_result_tag_c & ".";
    constant level             : in    log_level_t := dflt;
    constant active_clock_edge : in    edge_t      := rising_edge;
    constant line_num          : in    natural     := 0;
    constant file_name         : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_implication(checker, pass, to_x01(antecedent_expr) /= '0',
                      to_x01(consequent_expr) = '1', msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_implication(
    variable checker         : inout checker_t;
    variable pass            : out   boolean;
    constant antecedent_expr : in    boolean;
    constant consequent_expr : in    boolean;
    constant msg             : in    string      := check_result_tag_c & ".";
    constant level           : in    log_level_t := dflt;
    constant line_num        : in    natural     := 0;
    constant file_name       : in    string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if (not antecedent_expr) or consequent_expr then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Implication check passed", msg,
            "Got " & boolean'image(antecedent_expr) & " -> " & boolean'image(consequent_expr) & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(checker, std_msg("Implication check failed", msg, ""), level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_implication(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal antecedent_expr     : in std_logic;
    signal consequent_expr     : in std_logic;
    constant msg               : in string      := check_result_tag_c & ".";
    constant level             : in log_level_t := dflt;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_implication(default_checker, clock, en, antecedent_expr, consequent_expr, msg, level, active_clock_edge, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_implication(
    variable checker         : inout checker_t;
    constant antecedent_expr : in    boolean;
    constant consequent_expr : in    boolean;
    constant msg             : in    string      := check_result_tag_c & ".";
    constant level           : in    log_level_t := dflt;
    constant line_num        : in    natural     := 0;
    constant file_name       : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_implication(checker, pass, antecedent_expr, consequent_expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_implication(
    constant antecedent_expr : in boolean;
    constant consequent_expr : in boolean;
    constant msg             : in string      := check_result_tag_c & ".";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_implication(default_checker, pass, antecedent_expr, consequent_expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_implication(
    variable pass            : out boolean;
    constant antecedent_expr : in  boolean;
    constant consequent_expr : in  boolean;
    constant msg             : in  string      := check_result_tag_c & ".";
    constant level           : in  log_level_t := dflt;
    constant line_num        : in  natural     := 0;
    constant file_name       : in  string      := "") is
  begin
    -- pragma translate_off
    check_implication(default_checker, pass, antecedent_expr, consequent_expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_implication(
    constant antecedent_expr : in boolean;
    constant consequent_expr : in boolean;
    constant msg             : in string      := check_result_tag_c & ".";
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_implication(default_checker, pass, antecedent_expr, consequent_expr, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  -----------------------------------------------------------------------------
  -- check_stable
  -----------------------------------------------------------------------------
  procedure check_start_end_event (
    variable checker   : inout checker_t;
    signal event       : in    std_logic;
    constant start_end : in    string;
    constant msg       : in    string;
    constant level     : in    log_level_t;
    constant line_num  : in    natural;
    constant file_name : in    string;
    variable pass      : inout boolean) is
  begin
    if is_x(event) then
      pass := false;
      base_check_false(checker,
                       std_msg("Stability check failed", msg,
                               start_end & " event is " & std_logic'image(event)(2) & "."),
                       level, line_num, file_name);
    end if;
  end procedure check_start_end_event;

  procedure check_stable(
    variable checker           : inout checker_t;
    signal clock               : in    std_logic;
    signal en                  : in    std_logic;
    signal start_event         : in    std_logic;
    signal end_event           : in    std_logic;
    signal expr                : in    std_logic_vector;
    constant msg               : in    string      := check_result_tag_c;
    constant level             : in    log_level_t := dflt;
    constant active_clock_edge : in    edge_t      := rising_edge;
    constant line_num          : in    natural     := 0;
    constant file_name         : in    string      := "") is
    variable ref  : std_logic_vector(expr'range);
    variable pass : boolean := true;
    variable clock_edge_counter : positive;
    variable pass_msg_en : boolean;
    procedure check_unknown_expr is
    begin
      if is_x(expr) then
        pass := false;
        base_check_false(checker,
                         std_msg("Stability check failed", msg,
                                 "Got " & to_nibble_string(expr) &
                                 " at " & to_ordinal_number(clock_edge_counter) &
                                 " active and enabled clock edge."),
                         level, line_num, file_name);
      end if;
    end procedure check_unknown_expr;

  begin
    -- pragma translate_off
    wait on clock until start_condition(clock, active_clock_edge, start_event, en);
    clock_edge_counter := 1;
    check_start_end_event(checker, start_event, "Start", msg, level, line_num, file_name, pass);

    if pass then
      ref := to_x01(expr);
      check_unknown_expr;

      while (to_x01(end_event) = '0') or (to_x01(en) /= '1') loop
        wait_on_edge(clock, en, active_clock_edge);
        clock_edge_counter := clock_edge_counter + 1;
        check_unknown_expr;

        if ref /= to_x01(expr) then
          pass := false;
          base_check_false(checker,
                           std_msg("Stability check failed", msg,
                                   "Got " & to_nibble_string(expr) & " (" & to_integer_string(expr) &
                                   ") at " & to_ordinal_number(clock_edge_counter) &
                                   " active and enabled clock edge. Expected " &
                                   to_nibble_string(ref) & " (" & to_integer_string(ref) & ")."),
                           level, line_num, file_name);
        end if;
      end loop;
      check_start_end_event(checker, end_event, "End", msg, level, line_num, file_name, pass);

      if pass then
        base_pass_msg_enabled(checker, pass_msg_en);
        if pass_msg_en then
          base_check_true(checker,
                          std_msg("Stability check passed", msg,
                                  "Got " & to_nibble_string(expr) & " (" & to_integer_string(expr) &
                                  ") for " & positive'image(clock_edge_counter) &
                                  " active and enabled clock edges."),
                          line_num, file_name);
        else
          base_check_true(checker);
        end if;
      end if;
    end if;
    -- pragma translate_on
  end;

  procedure check_stable(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal start_event         : in std_logic;
    signal end_event           : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag_c;
    constant level             : in log_level_t := dflt;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_stable(default_checker, clock, en, start_event, end_event, expr, msg, level, active_clock_edge,
                 line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_stable(
    variable checker           : inout checker_t;
    signal clock               : in    std_logic;
    signal en                  : in    std_logic;
    signal start_event         : in    std_logic;
    signal end_event           : in    std_logic;
    signal expr                : in    std_logic;
    constant msg               : in    string      := check_result_tag_c;
    constant level             : in    log_level_t := dflt;
    constant active_clock_edge : in    edge_t      := rising_edge;
    constant line_num          : in    natural     := 0;
    constant file_name         : in    string      := "") is
    variable ref  : std_logic;
    variable pass : boolean := true;
    variable clock_edge_counter : positive;
    variable pass_msg_en : boolean;
    procedure check_unknown_expr is
    begin
      if is_x(expr) then
        pass := false;
        base_check_false(checker,
                         std_msg("Stability check failed", msg,
                                 "Got " & std_logic'image(expr)(2) &
                                 " at " & to_ordinal_number(clock_edge_counter) &
                                 " active and enabled clock edge."),
                         level, line_num, file_name);
      end if;
    end procedure check_unknown_expr;
  begin
    -- pragma translate_off
    wait on clock until start_condition(clock, active_clock_edge, start_event, en);
    clock_edge_counter := 1;
    check_start_end_event(checker, start_event, "Start", msg, level, line_num, file_name, pass);

    if pass then
      ref := to_x01(expr);
      check_unknown_expr;

      while (to_x01(end_event) = '0') or (to_x01(en) /= '1') loop
        wait_on_edge(clock, en, active_clock_edge);
        clock_edge_counter := clock_edge_counter + 1;
        check_unknown_expr;

        if ref /= to_x01(expr) then
          pass := false;
          base_check_false(checker,
                           std_msg("Stability check failed", msg,
                                   "Got " & std_logic'image(expr)(2) &
                                   " at " & to_ordinal_number(clock_edge_counter) &
                                   " active and enabled clock edge. Expected " &
                                   std_logic'image(ref)(2) & "."),
                           level, line_num, file_name);
        end if;
      end loop;
      check_start_end_event(checker, end_event, "End", msg, level, line_num, file_name, pass);

      if pass then
        base_pass_msg_enabled(checker, pass_msg_en);
        if pass_msg_en then
          base_check_true(checker,
                          std_msg("Stability check passed", msg,
                                  "Got " & std_logic'image(expr)(2) &
                                  " for " & positive'image(clock_edge_counter) &
                                  " active and enabled clock edges."),
                          line_num, file_name);
        else
          base_check_true(checker);
        end if;
      end if;
    end if;

    -- pragma translate_on
  end;

  procedure check_stable(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal start_event         : in std_logic;
    signal end_event           : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag_c;
    constant level             : in log_level_t := dflt;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_stable(default_checker, clock, en, start_event, end_event, expr, msg, level, active_clock_edge,
                 line_num, file_name);
  -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_not_unknown
  -----------------------------------------------------------------------------
  procedure check_not_unknown(
    variable checker           : inout checker_t;
    signal clock               : in    std_logic;
    signal en                  : in    std_logic;
    signal expr                : in    std_logic_vector;
    constant msg               : in    string      := check_result_tag_c;
    constant level             : in    log_level_t := dflt;
    constant active_clock_edge : in    edge_t      := rising_edge;
    constant line_num          : in    natural     := 0;
    constant file_name         : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_not_unknown(checker, pass, expr, msg, level, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if not is_x(expr) then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(checker,
                        std_msg("Not unknown check passed",
                                msg,
                                "Got " & to_nibble_string(expr) & " (" & to_integer_string(expr) & ")" & "."),
                        line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(checker,
                       std_msg("Not unknown check failed",
                               msg,
                               "Got " & to_nibble_string(expr) & "."),
                       level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_not_unknown(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag_c;
    constant level             : in log_level_t := dflt;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, clock, en, expr, msg, level, active_clock_edge, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    variable checker   : inout checker_t;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(checker, pass, expr, msg, level, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    constant expr      : in std_logic_vector;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    variable pass      : out boolean;
    constant expr      : in  std_logic_vector;
    constant msg       : in  string      := check_result_tag_c;
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "") is
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_not_unknown(
    constant expr      : in std_logic_vector;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_not_unknown(
    variable checker           : inout checker_t;
    signal clock               : in    std_logic;
    signal en                  : in    std_logic;
    signal expr                : in    std_logic;
    constant msg               : in    string      := check_result_tag_c;
    constant level             : in    log_level_t := dflt;
    constant active_clock_edge : in    edge_t      := rising_edge;
    constant line_num          : in    natural     := 0;
    constant file_name         : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_not_unknown(checker, pass, expr, msg, level, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    std_logic;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if not is_x(expr) then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(checker,
                        std_msg("Not unknown check passed",
                                msg,
                                "Got " & std_logic'image(expr)(2) & "."),
                        line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(checker,
                       std_msg("Not unknown check failed",
                               msg,
                               "Got " & std_logic'image(expr)(2) & "."),
                       level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_not_unknown(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag_c;
    constant level             : in log_level_t := dflt;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, clock, en, expr, msg, level, active_clock_edge, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    variable checker   : inout checker_t;
    constant expr      : in    std_logic;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(checker, pass, expr, msg, level, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    constant expr      : in std_logic;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    variable pass      : out boolean;
    constant expr      : in  std_logic;
    constant msg       : in  string      := check_result_tag_c;
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "") is
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_not_unknown(
    constant expr      : in std_logic;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  -----------------------------------------------------------------------------
  -- check_zero_one_hot
  -----------------------------------------------------------------------------
  function n_hot_in_valid_range (
    constant expr        :    std_logic_vector;
    constant lower_bound : in natural;
    constant upper_bound : in natural)
    return boolean is
    variable n : natural := 0;
  begin
    if is_x(expr) then
      return false;
    end if;
    for i in expr'range loop
      if to_x01(expr(i)) = '1' then
        n := n + 1;
      end if;
    end loop;

    return (n >= lower_bound) and (n <= upper_bound);
  end function n_hot_in_valid_range;

  procedure check_zero_one_hot(
    variable checker           : inout checker_t;
    signal clock               : in    std_logic;
    signal en                  : in    std_logic;
    signal expr                : in    std_logic_vector;
    constant msg               : in    string      := check_result_tag_c;
    constant level             : in    log_level_t := dflt;
    constant active_clock_edge : in    edge_t      := rising_edge;
    constant line_num          : in    natural     := 0;
    constant file_name         : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_zero_one_hot(checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_zero_one_hot(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if n_hot_in_valid_range(expr, 0, 1) then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(checker,
                        std_msg("Zero one-hot check passed", msg,
                                "Got " & to_nibble_string(expr) & "."),
                        line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(checker,
                       std_msg("Zero one-hot check failed", msg,
                               "Got " & to_nibble_string(expr) & "."),
                       level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_zero_one_hot(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag_c;
    constant level             : in log_level_t := dflt;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_zero_one_hot(default_checker, clock, en, expr, msg, level, active_clock_edge, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_zero_one_hot(
    variable pass      : out boolean;
    constant expr      : in  std_logic_vector;
    constant msg       : in  string      := check_result_tag_c;
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "") is
  begin
    -- pragma translate_off
    check_zero_one_hot(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_zero_one_hot(
    constant expr      : in std_logic_vector;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_zero_one_hot(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_zero_one_hot(
    variable checker   : inout checker_t;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_zero_one_hot(checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_zero_one_hot(
    constant expr      : in std_logic_vector;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_zero_one_hot(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_one_hot
  -----------------------------------------------------------------------------
  procedure check_one_hot(
    variable checker           : inout checker_t;
    signal clock               : in    std_logic;
    signal en                  : in    std_logic;
    signal expr                : in    std_logic_vector;
    constant msg               : in    string      := check_result_tag_c;
    constant level             : in    log_level_t := dflt;
    constant active_clock_edge : in    edge_t      := rising_edge;
    constant line_num          : in    natural     := 0;
    constant file_name         : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_one_hot(checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_one_hot(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if n_hot_in_valid_range(expr, 1, 1) then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(checker,
                        std_msg("One-hot check passed", msg,
                                "Got " & to_nibble_string(expr) & "."),
                        line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(checker,
                       std_msg("One-hot check failed", msg,
                               "Got " & to_nibble_string(expr) & "."),
                       level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_one_hot(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag_c;
    constant level             : in log_level_t := dflt;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_one_hot(default_checker, clock, en, expr, msg, level, active_clock_edge, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_one_hot(
    variable pass      : out boolean;
    constant expr      : in  std_logic_vector;
    constant msg       : in  string      := check_result_tag_c;
    constant level     : in  log_level_t := dflt;
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "") is
  begin
    -- pragma translate_off
    check_one_hot(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_one_hot(
    constant expr      : in std_logic_vector;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_one_hot(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_one_hot(
    variable checker   : inout checker_t;
    constant expr      : in    std_logic_vector;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_one_hot(checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_one_hot(
    constant expr      : in std_logic_vector;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_one_hot(default_checker, pass, expr, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_next
  -----------------------------------------------------------------------------
  procedure check_next(
    variable checker             : inout checker_t;
    signal clock                 : in    std_logic;
    signal en                    : in    std_logic;
    signal start_event           : in    std_logic;
    signal expr                  : in    std_logic;
    constant msg                 : in    string      := check_result_tag_c;
    constant num_cks             : in    positive    := 1;
    constant allow_overlapping   : in    boolean     := true;
    constant allow_missing_start : in    boolean     := true;
    constant level               : in    log_level_t := dflt;
    constant active_clock_edge   : in    edge_t      := rising_edge;
    constant line_num            : in    natural     := 0;
    constant file_name           : in    string      := "") is

    variable schedule : boolean_vector(0 to num_cks) := (others => false);
    variable clock_cycles_after_start_event : natural;
    variable pass_msg_en : boolean;

    function check_is_scheduled(
      constant schedule : in boolean_vector)
      return boolean is
    begin
      return schedule(0);
    end function check_is_scheduled;

    procedure schedule_check(
      variable schedule : inout boolean_vector;
      constant num_cks  : in    natural) is
    begin
      schedule(num_cks) := true;
    end procedure schedule_check;

    procedure update_remaining_times_to_scheduled_checks(
      variable schedule : inout boolean_vector;
      constant num_cks  : in    natural) is
    begin
      schedule(0 to num_cks - 1) := schedule(1 to num_cks);
      schedule(num_cks)          := false;
    end procedure update_remaining_times_to_scheduled_checks;

    function pending_check (
      constant schedule : boolean_vector)
      return boolean is
      constant no_pending_checks : boolean_vector(1 to schedule'right) := (others => false);
    begin
      if schedule(1 to schedule'right) = no_pending_checks then
        return false;
      else
        return true;
      end if;
    end function pending_check;

  begin
    -- pragma translate_off
    while true loop
      wait_on_edge(clock, en, active_clock_edge);
      clock_cycles_after_start_event := clock_cycles_after_start_event + 1;

      if check_is_scheduled(schedule) then
        if to_x01(expr) = '1' then
          base_pass_msg_enabled(checker, pass_msg_en);
          if pass_msg_en then
            base_check_true(checker, std_msg("Next check passed", msg, ""), line_num, file_name);
          else
            base_check_true(checker);
          end if;
        else
          base_check_false(checker,
                           std_msg("Next check failed", msg,
                                   "Got " & std_logic'image(expr)(2) &
                                   " at the " & to_ordinal_number(num_cks) &
                                   " active and enabled clock edge."),
                           level, line_num, file_name);
        end if;
      elsif (to_x01(expr) = '1') and not allow_missing_start then
        base_check_false(checker,
                         std_msg("Next check failed", msg,
                                 "Missing start event for true expression."),
                         level, line_num, file_name);
      end if;

      if to_x01(start_event) = '1' then
        if pending_check(schedule) and not allow_overlapping then
          base_check_false(checker,
                           std_msg("Next check failed", msg,
                                   "Got overlapping start event at the " &
                                   to_ordinal_number(clock_cycles_after_start_event) &
                                   " active and enabled clock edge."),
                           level, line_num, file_name);
        else
          schedule_check(schedule, num_cks);
          clock_cycles_after_start_event := 0;
        end if;
      elsif to_x01(start_event) = 'X' then
        base_check_false(checker,
                         std_msg("Next check failed", msg,
                                 "Start event is " & std_logic'image(start_event)(2) & "."),
                         level, line_num, file_name);
      end if;

      update_remaining_times_to_scheduled_checks(schedule, num_cks);
    end loop;
  -- pragma translate_on
  end;

  procedure check_next(
    signal clock                 : in std_logic;
    signal en                    : in std_logic;
    signal start_event           : in std_logic;
    signal expr                  : in std_logic;
    constant msg                 : in string      := check_result_tag_c;
    constant num_cks             : in positive    := 1;
    constant allow_overlapping   : in boolean     := true;
    constant allow_missing_start : in boolean     := true;
    constant level               : in log_level_t := dflt;
    constant active_clock_edge   : in edge_t      := rising_edge;
    constant line_num            : in natural     := 0;
    constant file_name           : in string      := "") is
  begin
    -- pragma translate_off
    check_next(default_checker, clock, en, start_event, expr, msg, num_cks, allow_overlapping,
               allow_missing_start, level, active_clock_edge, line_num, file_name);
  -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_sequence
  -----------------------------------------------------------------------------
  procedure check_sequence(
    variable checker           : inout checker_t;
    signal clock               : in    std_logic;
    signal en                  : in    std_logic;
    signal event_sequence      : in    std_logic_vector;
    constant msg               : in    string          := check_result_tag_c;
    constant trigger_event     : in    trigger_event_t := penultimate;
    constant level             : in    log_level_t     := dflt;
    constant active_clock_edge : in    edge_t          := rising_edge;
    constant line_num          : in    natural         := 0;
    constant file_name         : in    string          := "") is

    variable expected_events : boolean_vector(0 to event_sequence'length - 1) := (others => false);
    variable tracks          : boolean_vector(0 to event_sequence'length - 1) := (others => false);

    procedure find_new_and_update_existing_tracks (
      variable tracks         : inout boolean_vector;
      constant event_sequence : in    std_logic_vector) is

      constant seq                       : std_logic_vector(0 to event_sequence'length - 1) := event_sequence;
      variable unknown_event_in_sequence : boolean                                          := false;

      function active_tracks (
        constant tracks : in boolean_vector)
        return boolean is
      begin
        for i in tracks'range loop
          if tracks(i) then
            return true;
          end if;
        end loop;
        return false;
      end function active_tracks;
    begin
      for i in tracks'reverse_range loop
        if to_x01(seq(i)) = 'X' then
          -- FIXME: check moved out of loop to work with GHDL 0.33.
          unknown_event_in_sequence := true;
        end if;

        if i = 0 then
          if (trigger_event = first_no_pipe) and active_tracks(tracks) then
            tracks(0) := false;
          else
            tracks(0) := (to_x01(seq(seq'left)) = '1');
          end if;
        else
          tracks(i) := (tracks(i - 1) and (to_x01(seq(i)) = '1'));
        end if;
      end loop;

      -- FIXME: check moved out of loop to work with GHDL 0.33.
      if unknown_event_in_sequence then
        base_check_false(checker,
                         std_msg("Sequence check failed", msg,
                                 "Got " & to_nibble_string(seq) & "."),
                         level, line_num, file_name);
      end if;
    end find_new_and_update_existing_tracks;

    procedure update_expectations_on_events_in_next_cycle (
      constant tracks          : in    boolean_vector;
      variable expected_events : inout boolean_vector) is
    begin
      if trigger_event = penultimate then
        expected_events(expected_events'right - 1) := tracks(tracks'right - 1);
      else
        expected_events(expected_events'range) := tracks(expected_events'range);
      end if;
      expected_events := logical_right_shift(expected_events, 1);
    end procedure update_expectations_on_events_in_next_cycle;

    procedure verify_expected_events (
      constant expected_events : in boolean_vector;
      constant event_sequence  : in std_logic_vector) is
      constant seq : std_logic_vector(0 to event_sequence'length - 1) := event_sequence;
      variable pass_msg_en : boolean;
    begin
      for i in 1 to seq'right loop
        if expected_events(i) then
          if to_x01(seq(i)) /= '1' then
            base_check_false(checker,
                             std_msg("Sequence check failed", msg,
                                     "Missing required event at " &
                                     to_ordinal_number(i) &
                                     " active and enabled clock edge."),
                             level, line_num, file_name);
          elsif i = seq'right then
            base_pass_msg_enabled(checker, pass_msg_en);
            if pass_msg_en then
              base_check_true(checker, std_msg("Sequence check passed", msg, ""), line_num, file_name);
            else
              base_check_true(checker);
            end if;
          end if;
        end if;
      end loop;
    end procedure verify_expected_events;

    variable valid_event_sequence_length : boolean;
  begin
    -- pragma translate_off
    valid_event_sequence_length := event_sequence'length >= 2;
    if not valid_event_sequence_length then
      base_check_false(checker,
                       std_msg("Sequence check failed", msg,
                               "Event sequence length must be at least 2. Got " &
                               natural'image(event_sequence'length) & "."),
                       level, line_num, file_name);
    end if;

    wait_on_edge(clock, en, active_clock_edge);
    while valid_event_sequence_length loop
      find_new_and_update_existing_tracks(tracks, event_sequence);
      update_expectations_on_events_in_next_cycle(tracks, expected_events);
      wait_on_edge(clock, en, active_clock_edge);
      verify_expected_events(expected_events, event_sequence);
    end loop;

    wait;
  -- pragma translate_on
  end;

  procedure check_sequence(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal event_sequence      : in std_logic_vector;
    constant msg               : in string          := check_result_tag_c;
    constant trigger_event     : in trigger_event_t := penultimate;
    constant level             : in log_level_t     := dflt;
    constant active_clock_edge : in edge_t          := rising_edge;
    constant line_num          : in natural         := 0;
    constant file_name         : in string          := "") is
  begin
    -- pragma translate_off
    check_sequence(default_checker, clock, en, event_sequence, msg, trigger_event, level, active_clock_edge,
                   line_num, file_name);
  -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_relation
  -----------------------------------------------------------------------------
  procedure check_relation(
    variable checker   : inout checker_t;
    constant expr      : in    boolean;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant context_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(checker, pass, expr, msg, level, context_msg, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    boolean;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant context_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if expr then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(checker, std_msg("Relation check passed", msg, context_msg), line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(checker, std_msg("Relation check failed", msg, context_msg), level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_relation(
    constant expr      : in boolean;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant context_msg  : in string      := "";
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, expr, msg, level, context_msg, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    variable pass      : out boolean;
    constant expr      : in  boolean;
    constant msg       : in  string      := check_result_tag_c;
    constant level     : in  log_level_t := dflt;
    constant context_msg  : in  string      := "";
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "") is
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, expr, msg, level, context_msg, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_relation(
    constant expr      : in boolean;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant context_msg  : in string      := "";
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, expr, msg, level, context_msg, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_relation(
    variable checker   : inout checker_t;
    constant expr      : in    std_ulogic;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant context_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(checker, pass, (expr = '1'), msg, level, context_msg, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    std_ulogic;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant context_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
  begin
    -- pragma translate_off
    check_relation(checker, pass, (expr = '1'), msg, level, context_msg, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    constant expr      : in std_ulogic;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant context_msg  : in string      := "";
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    variable pass      : out boolean;
    constant expr      : in  std_ulogic;
    constant msg       : in  string      := check_result_tag_c;
    constant level     : in  log_level_t := dflt;
    constant context_msg  : in  string      := "";
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "") is
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_relation(
    constant expr      : in std_ulogic;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant context_msg  : in string      := "";
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_relation(
    variable checker   : inout checker_t;
    constant expr      : in    bit;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant context_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(checker, pass, (expr = '1'), msg, level, context_msg, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    variable checker   : inout checker_t;
    variable pass      : out   boolean;
    constant expr      : in    bit;
    constant msg       : in    string      := check_result_tag_c;
    constant level     : in    log_level_t := dflt;
    constant context_msg  : in    string      := "";
    constant line_num  : in    natural     := 0;
    constant file_name : in    string      := "") is
  begin
    -- pragma translate_off
    check_relation(checker, pass, (expr = '1'), msg, level, context_msg, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    constant expr      : in bit;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant context_msg  : in string      := "";
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    variable pass      : out boolean;
    constant expr      : in  bit;
    constant msg       : in  string      := check_result_tag_c;
    constant level     : in  log_level_t := dflt;
    constant context_msg  : in  string      := "";
    constant line_num  : in  natural     := 0;
    constant file_name : in  string      := "") is
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_relation(
    constant expr      : in bit;
    constant msg       : in string      := check_result_tag_c;
    constant level     : in log_level_t := dflt;
    constant context_msg  : in string      := "";
    constant line_num  : in natural     := 0;
    constant file_name : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  -----------------------------------------------------------------------------
  -- check_equal
  -----------------------------------------------------------------------------
  function "=" (
    constant left  : unsigned;
    constant right : std_logic_vector)
    return boolean is
  begin
    return left = unsigned(right);
  end function "=";

  function "=" (
    constant left  : std_logic_vector;
    constant right : unsigned)
    return boolean is
  begin
    return unsigned(left) = right;
  end function "=";

  function "=" (
    constant left  : natural;
    constant right : std_logic_vector)
    return boolean is
  begin
    return left = unsigned(right);
  end function "=";

  function "=" (
    constant left : std_logic_vector;
    constant right : natural)
    return boolean is
  begin
    return unsigned(left) = right;
  end function "=";

  function "=" (
    constant left  : boolean;
    constant right : std_logic)
    return boolean is
  begin
    return left = (right = '1');
  end function "=";

  function "=" (
    constant left  : std_logic;
    constant right : boolean)
    return boolean is
  begin
    return (left = '1') = right;
  end function "=";

  function to_char (
    constant bit : std_logic)
    return character is
    constant chars : string(1 to 9) := "UX01ZWLH-";
  begin
    return chars(std_logic'pos(bit) + 1);
  end function to_char;

  function to_string (
    constant data : std_logic)
    return string is
    variable ret_val : string(1 to 1);
  begin
    ret_val(1) := to_char(data);
    return ret_val;
  end function to_string;

  function to_string (
    constant data : boolean)
    return string is
  begin
    if data then
      return "true";
    else
      return "false";
    end if;
  end function to_string;

  function to_string (
    constant data : integer)
    return string is
  begin
    return integer'image(data);
  end function to_string;

  function to_string (
    constant data : string)
    return string is
  begin
    return data;
  end function to_string;

  function to_string (
    constant data : time)
    return string is
  begin
    return time'image(data);
  end function to_string;

  function max (
    constant value_1 : integer;
    constant value_2 : integer)
    return integer is
  begin
    if value_1 > value_2 then
      return value_1;
    else
      return value_2;
    end if;
  end max;

  function required_num_of_unsigned_bits (
    constant value : natural)
    return natural is
    variable max_value       : natural := 0;
    variable required_length : natural := 1;
  begin
    for i in 0 to max_supported_num_of_bits_in_integer_implementation - 2 loop
      max_value       := max_value + 2 ** i;
      exit when max_value >= value;
      required_length := required_length + 1;
    end loop;

    return required_length;
  end required_num_of_unsigned_bits;

  function to_sufficient_unsigned (
    constant value      : natural;
    constant min_length : natural)
    return unsigned is
  begin
    return to_unsigned(value, max(min_length, required_num_of_unsigned_bits(value)));
  end to_sufficient_unsigned;

  function to_sufficient_signed (
    constant value      : integer;
    constant min_length : natural)
    return signed is
    variable min_value       : integer := -1;
    variable required_length : natural := 1;
  begin
    if value < 0 then
      for i in 0 to max_supported_num_of_bits_in_integer_implementation - 1 loop
        exit when min_value <= value;
        min_value           := min_value * 2;
        required_length     := required_length + 1;
      end loop;

      return to_signed(value, max(min_length, required_length));
    else
      return signed(to_unsigned(natural(value), max(min_length, required_num_of_unsigned_bits(natural(value)) + 1)));
    end if;
  end to_sufficient_signed;

  procedure check_equal(
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in unsigned;
    constant expected        : in natural;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in natural;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in natural;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_string(expected) & " (" & to_nibble_string(to_sufficient_unsigned(expected, got'length)) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in unsigned;
    constant expected        : in natural;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in unsigned;
    constant expected        : in natural;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in natural;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in natural;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in natural;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in natural;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in natural;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in unsigned;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in unsigned;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in unsigned;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in std_logic_vector;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in std_logic_vector;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in std_logic_vector;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in std_logic_vector;
    constant expected        : in natural;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in natural;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in natural;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_string(expected) & " (" & to_nibble_string(to_sufficient_unsigned(expected, got'length)) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in std_logic_vector;
    constant expected        : in natural;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in std_logic_vector;
    constant expected        : in natural;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in natural;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in natural;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in natural;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in natural;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in natural;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in signed;
    constant expected        : in integer;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in integer;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in integer;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_string(expected) & " (" & to_nibble_string(to_sufficient_signed(expected, got'length)) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in signed;
    constant expected        : in integer;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in signed;
    constant expected        : in integer;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in integer;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in integer;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in integer;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_signed(got, expected'length)) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_signed(got, expected'length)) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in integer;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in integer;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in integer;
    constant expected        : in integer;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in integer;
    constant expected        : in integer;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in integer;
    constant expected        : in integer;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in integer;
    constant expected        : in integer;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in integer;
    constant expected        : in integer;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in std_logic;
    constant expected        : in boolean;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in boolean;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in boolean;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in std_logic;
    constant expected        : in boolean;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in std_logic;
    constant expected        : in boolean;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in boolean;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in boolean;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in boolean;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in boolean;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in boolean;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in boolean;
    constant expected        : in boolean;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in boolean;
    constant expected        : in boolean;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in boolean;
    constant expected        : in boolean;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in boolean;
    constant expected        : in boolean;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in boolean;
    constant expected        : in boolean;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in string;
    constant expected        : in string;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in string;
    constant expected        : in string;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in string;
    constant expected        : in string;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in string;
    constant expected        : in string;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in string;
    constant expected        : in string;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_equal(
    constant got             : in time;
    constant expected        : in time;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass            : out boolean;
    constant got             : in time;
    constant expected        : in time;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in time;
    constant expected        : in time;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    variable checker         : inout checker_t;
    constant got             : in time;
    constant expected        : in time;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got             : in time;
    constant expected        : in time;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  -----------------------------------------------------------------------------
  -- check_match
  -----------------------------------------------------------------------------
  procedure check_match(
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if std_match(got, expected) then
      pass := true;

      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Match check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
            "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Match check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_match(
    variable checker         : inout checker_t;
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_match(
    constant got             : in unsigned;
    constant expected        : in unsigned;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_match(
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if std_match(got, expected) then
      pass := true;

      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Match check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
            "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Match check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_match(
    variable checker         : inout checker_t;
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_match(
    constant got             : in std_logic_vector;
    constant expected        : in std_logic_vector;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_match(
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if std_match(got, expected) then
      pass := true;

      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Match check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
            "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Match check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_match(
    variable checker         : inout checker_t;
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_match(
    constant got             : in signed;
    constant expected        : in signed;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_match(
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable checker         : inout checker_t;
    variable pass            : out boolean;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable en : boolean;
  begin
    -- pragma translate_off
    if std_match(got, expected) then
      pass := true;

      base_pass_msg_enabled(checker, en);
      if en then
        base_check_true(
          checker,
          std_msg(
            "Match check passed", msg,
            "Got " & to_string(got) & ". " &
            "Expected " & to_string(expected) & "."),
          line_num, file_name);
      else
        base_check_true(checker);
      end if;
    else
      pass := false;
      base_check_false(
        checker,
        std_msg(
          "Match check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_match(
    variable checker         : inout checker_t;
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_match(
    constant got             : in std_logic;
    constant expected        : in std_logic;
    constant msg             : in string := check_result_tag_c;
    constant level           : in log_level_t := dflt;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

end package body check_pkg;
