-- The check package provides the primary checking functionality.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body check_pkg is
  type boolean_vector is array (natural range <>) of boolean;

  function result(str : string := "") return string is
  begin
    return decorate(str);
  end;

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

  function to_ordinal_number (num : unsigned) return string is
    constant num_str      : string := to_integer_string(num);
    variable ordinal_unit : string(1 to 2);
  begin
    case num_str(num_str'right) is
      when '1'    => ordinal_unit := "st";
      when '2'    => ordinal_unit := "nd";
      when '3'    => ordinal_unit := "rd";
      when others => ordinal_unit := "th";
    end case;

    if num_str'length > 1 then
      if num_str(num_str'right - 1) = '1' then
        ordinal_unit := "th";
      end if;
    end if;

    return num_str & ordinal_unit;
  end function to_ordinal_number;

  procedure log(check_result : check_result_t) is
  begin
    -- pragma translate_off
    if check_result.p_is_pass then
      if is_pass_visible(check_result.p_checker) and (check_result.p_msg /= null_string_ptr) then
        log_passing_check(check_result.p_checker, to_string(check_result.p_msg), 0, check_result.p_line_num, to_string(check_result.p_file_name));
      else
        log_passing_check(check_result.p_checker);
      end if;
    else
      p_handle(check_result);
      log_failing_check(check_result.p_checker, to_string(check_result.p_msg), check_result.p_level, 0, check_result.p_line_num, to_string(check_result.p_file_name));
    end if;

    p_recycle_check_result(check_result);
    -- pragma translate_on
  end;

  procedure notify_if_fail(check_result : check_result_t; signal event : inout any_event_t) is
  begin
    if not check_result.p_is_pass then
      notify(event);
    end if;
    log(check_result);
  end;

  -----------------------------------------------------------------------------
  -- check
  -----------------------------------------------------------------------------
  procedure check(
    constant checker           : in checker_t;
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag & ".";
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check(checker, to_x01(expr) = '1', msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check(
    constant checker     : in  checker_t;
    variable pass        : out boolean;
    constant expr        : in  boolean;
    constant msg         : in  string      := check_result_tag & ".";
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    if expr then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(checker, p_std_msg("Check passed", msg, ""), path_offset, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(checker, p_std_msg("Check failed", msg, ""), level, path_offset, line_num, file_name);
    end if;
  -- pragma translate_on
  end;

  procedure check(
    constant checker     : in checker_t;
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check(checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check(
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check(
    variable pass        : out boolean;
    constant expr        : in  boolean;
    constant msg         : in  string      := check_result_tag & ".";
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check(
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check(
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    return check(default_checker, expr, msg, level, path_offset, line_num, file_name);
  end;

  procedure check(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag & ".";
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check(default_checker, clock, en, expr, msg, level, active_clock_edge, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check(
    constant checker     : in checker_t;
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check(checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check(
    constant checker     : in checker_t;
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => expr,
      msg => msg,
      std_pass_msg => "Check passed",
      std_fail_msg => "Check failed",
      std_pass_ctx => "",
      std_fail_ctx => "",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  -----------------------------------------------------------------------------
  -- check_passed
  -----------------------------------------------------------------------------
  procedure check_passed(
    constant checker     : in checker_t;
    constant msg         : in string  := check_result_tag & ".";
    constant path_offset : in natural := 0;
    constant line_num    : in natural := 0;
    constant file_name   : in string  := "") is
  begin
    -- pragma translate_off
    if is_pass_visible(checker) then
      passing_check(checker, p_std_msg("Unconditional check passed", msg, ""), path_offset, line_num, file_name);
    else
      passing_check(checker);
    end if;
  -- pragma translate_on
  end;

  procedure check_passed(
    constant msg         : in string  := check_result_tag & ".";
    constant path_offset : in natural := 0;
    constant line_num    : in natural := 0;
    constant file_name   : in string  := "") is
  begin
    -- pragma translate_off
    check_passed(default_checker, msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_failed
  -----------------------------------------------------------------------------
  procedure check_failed(
    constant checker     : in checker_t;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    failing_check(checker, p_std_msg("Unconditional check failed", msg, ""), level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_failed(
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    failing_check(default_checker, p_std_msg("Unconditional check failed", msg, ""), level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_true
  -----------------------------------------------------------------------------
  procedure check_true(
    constant checker           : in checker_t;
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag & ".";
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_true(checker, to_x01(expr) = '1', msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_true(
    constant checker     : in  checker_t;
    variable pass        : out boolean;
    constant expr        : in  boolean;
    constant msg         : in  string      := check_result_tag & ".";
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    if expr then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(checker, p_std_msg("True check passed", msg, ""), path_offset, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(checker, p_std_msg("True check failed", msg, ""), level, path_offset, line_num, file_name);
    end if;
  -- pragma translate_on
  end;

  procedure check_true(
    constant checker     : in checker_t;
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_true(checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_true(
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_true(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_true(
    variable pass        : out boolean;
    constant expr        : in  boolean;
    constant msg         : in  string      := check_result_tag & ".";
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check_true(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_true(
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_true(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_true(
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    return check_true(default_checker, expr, msg, level, path_offset, line_num, file_name);
  end;

  procedure check_true(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag & ".";
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_true(default_checker, clock, en, expr, msg, level, active_clock_edge, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_true(
    constant checker     : in checker_t;
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_true(checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_true(
    constant checker     : in checker_t;
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => expr,
      msg => msg,
      std_pass_msg => "True check passed",
      std_fail_msg => "True check failed",
      std_pass_ctx => "",
      std_fail_ctx => "",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;
  -----------------------------------------------------------------------------
  -- check_false
  -----------------------------------------------------------------------------
  procedure check_false(
    constant checker           : in checker_t;
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag & ".";
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_false(checker, to_x01(expr) /= '0', msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_false(
    constant checker     : in  checker_t;
    variable pass        : out boolean;
    constant expr        : in  boolean;
    constant msg         : in  string      := check_result_tag & ".";
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    if not expr then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(checker, p_std_msg("False check passed", msg, ""), path_offset, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(checker, p_std_msg("False check failed", msg, ""), level, path_offset, line_num, file_name);
    end if;
  -- pragma translate_on
  end;

  procedure check_false(
    constant checker     : in checker_t;
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_false(checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_false(
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_false(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_false(
    variable pass        : out boolean;
    constant expr        : in  boolean;
    constant msg         : in  string      := check_result_tag & ".";
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check_false(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_false(
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_false(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_false(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag & ".";
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_false(default_checker, clock, en, expr, msg, level, active_clock_edge, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_false(
    constant checker     : in checker_t;
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag & ".";
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_false(checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  -----------------------------------------------------------------------------
  -- check_implication
  -----------------------------------------------------------------------------
  procedure check_implication(
    constant checker           : in checker_t;
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal antecedent_expr     : in std_logic;
    signal consequent_expr     : in std_logic;
    constant msg               : in string      := check_result_tag & ".";
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_implication(checker, pass, to_x01(antecedent_expr) /= '0',
                      to_x01(consequent_expr) = '1', msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_implication(
    constant checker         : in  checker_t;
    variable pass            : out boolean;
    constant antecedent_expr : in  boolean;
    constant consequent_expr : in  boolean;
    constant msg             : in  string      := check_result_tag & ".";
    constant level           : in  log_level_t := null_log_level;
    constant path_offset     : in  natural     := 0;
    constant line_num        : in  natural     := 0;
    constant file_name       : in  string      := "") is
  begin
    -- pragma translate_off
    if (not antecedent_expr) or consequent_expr then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Implication check passed", msg,
            "Got " & boolean'image(antecedent_expr) & " -> " & boolean'image(consequent_expr) & "."),
          path_offset, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(checker, p_std_msg("Implication check failed", msg, ""), level, path_offset, line_num, file_name);
    end if;
  -- pragma translate_on
  end;

  procedure check_implication(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal antecedent_expr     : in std_logic;
    signal consequent_expr     : in std_logic;
    constant msg               : in string      := check_result_tag & ".";
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_implication(default_checker, clock, en, antecedent_expr, consequent_expr, msg, level, active_clock_edge, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_implication(
    constant checker         : in checker_t;
    constant antecedent_expr : in boolean;
    constant consequent_expr : in boolean;
    constant msg             : in string      := check_result_tag & ".";
    constant level           : in log_level_t := null_log_level;
    constant path_offset     : in natural     := 0;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_implication(checker, pass, antecedent_expr, consequent_expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_implication(
    constant antecedent_expr : in boolean;
    constant consequent_expr : in boolean;
    constant msg             : in string      := check_result_tag & ".";
    constant level           : in log_level_t := null_log_level;
    constant path_offset     : in natural     := 0;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_implication(default_checker, pass, antecedent_expr, consequent_expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_implication(
    variable pass            : out boolean;
    constant antecedent_expr : in  boolean;
    constant consequent_expr : in  boolean;
    constant msg             : in  string      := check_result_tag & ".";
    constant level           : in  log_level_t := null_log_level;
    constant path_offset     : in  natural     := 0;
    constant line_num        : in  natural     := 0;
    constant file_name       : in  string      := "") is
  begin
    -- pragma translate_off
    check_implication(default_checker, pass, antecedent_expr, consequent_expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_implication(
    constant antecedent_expr : in boolean;
    constant consequent_expr : in boolean;
    constant msg             : in string      := check_result_tag & ".";
    constant level           : in log_level_t := null_log_level;
    constant path_offset     : in natural     := 0;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_implication(default_checker, pass, antecedent_expr, consequent_expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_implication(
    constant checker         : in checker_t;
    constant antecedent_expr : in boolean;
    constant consequent_expr : in boolean;
    constant msg             : in string      := check_result_tag & ".";
    constant level           : in log_level_t := null_log_level;
    constant path_offset     : in natural     := 0;
    constant line_num        : in natural     := 0;
    constant file_name       : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_implication(checker, pass, antecedent_expr, consequent_expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  -----------------------------------------------------------------------------
  -- check_stable
  -----------------------------------------------------------------------------
  type check_stable_fsm_state_t is (idle, active_window);

  procedure run_stability_check (
    constant checker              : in checker_t;
    constant start_event          : in std_logic;
    constant end_event            : in std_logic;
    constant expr                 : in std_logic_vector;
    constant msg                  : in string;
    constant level                : in log_level_t;
    constant active_clock_edge    : in edge_t;
    constant allow_restart        : in boolean;
    constant path_offset          : in natural;
    constant line_num             : in natural;
    constant file_name            : in string;
    variable state                : inout check_stable_fsm_state_t;
    variable ref                  : inout std_logic_vector;
    variable clock_edge_counter   : inout unsigned(63 downto 0);
    variable is_stable            : inout boolean;
    variable exit_stability_check : out   boolean) is

    function format (expr : std_logic) return character is
    begin
      return std_logic'image(expr)(2);
    end;

    function format (expr : std_logic_vector) return string is
    begin
      if expr'length = 1 then
        return (1 => format(expr(expr'left)));
      else
        return to_nibble_string(expr) & " (" & to_integer_string(expr) & ")";
      end if;

    end;

    procedure open_window (variable open_ok   : out boolean) is
    begin
      clock_edge_counter := x"0000000000000001";
      ref                := to_x01(expr);
      open_ok            := true;
      if is_x(start_event) then
        open_ok := false;
        failing_check(checker,
                      p_std_msg("Stability check failed", msg,
                              "Start event is " & format(start_event) & "."),
                      level, path_offset, line_num, file_name);
      elsif is_x(expr) then
        open_ok := false;
        failing_check(checker,
                      p_std_msg("Stability check failed", msg,
                              "Got " & format(expr) &
                              " at 1st active and enabled clock edge."),
                      level, path_offset, line_num, file_name);
      end if;
    end procedure;

    procedure close_window(cycle : unsigned; is_ok : boolean) is
      variable close_ok    : boolean := is_ok;
    begin
      if is_x(end_event) then
        close_ok := false;
        failing_check(checker,
                      p_std_msg("Stability check failed", msg,
                              "End event is " & format(end_event) & "."),
                      level, path_offset, line_num, file_name);
      end if;

      if close_ok then
        if is_pass_visible(checker) then
          passing_check(checker,
                        p_std_msg("Stability check passed", msg,
                                "Got " & format(ref) &
                                " for " & to_integer_string(cycle) &
                                " active and enabled clock edges."),
                        path_offset, line_num, file_name);
        else
          passing_check(checker);
        end if;
      end if;
    end procedure close_window;

    variable open_ok : boolean;
  begin
    exit_stability_check := false;
    case state is

      when idle =>
        if to_x01(start_event) /= '0' then
          open_window(open_ok);
          if not open_ok then
            exit_stability_check := true;
            return;
          elsif to_x01(end_event) /= '0' then
            close_window(clock_edge_counter, is_ok => true);
            exit_stability_check := true;
            return;
          else
            state := active_window;
          end if;
        end if;

      when active_window =>
        clock_edge_counter := clock_edge_counter + 1;

        if to_x01(start_event) /= '0' and allow_restart then
          close_window(cycle => clock_edge_counter - 1, is_ok => true);
          open_window(open_ok);
          if not open_ok then
            exit_stability_check := true;
            return;
          end if;

        elsif ref /= to_x01(expr) then
          is_stable := false;
          failing_check(checker,
                        p_std_msg("Stability check failed", msg,
                                "Got " & format(expr) &
                                " at " & to_ordinal_number(clock_edge_counter) &
                                " active and enabled clock edge. Expected " &
                                format(ref) & "."), level, path_offset, line_num, file_name);
        end if;

        if to_x01(end_event) /= '0' then
          close_window(clock_edge_counter, is_ok => is_stable);
          exit_stability_check := true;
          return;
        end if;

    end case;

  end procedure run_stability_check;

  procedure check_stable(
    constant checker           : in checker_t;
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal start_event         : in std_logic;
    signal end_event           : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant allow_restart     : in boolean     := false;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is

    variable state                : check_stable_fsm_state_t := idle;
    variable ref                   : std_logic_vector(expr'range);
    variable clock_edge_counter   : unsigned(63 downto 0);
    variable is_stable            : boolean                  := true;
    variable exit_stability_check : boolean;
  begin
    -- pragma translate_off
    stability_check : loop
      wait_on_edge(clock, en, active_clock_edge);

      run_stability_check(checker, start_event, end_event, expr, msg, level, active_clock_edge,
                          allow_restart, path_offset, line_num, file_name, state, ref, clock_edge_counter,
                          is_stable, exit_stability_check);
      exit when exit_stability_check;
    end loop;
  -- pragma translate_on
  end;

  procedure check_stable(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal start_event         : in std_logic;
    signal end_event           : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant allow_restart     : in boolean     := false;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_stable(default_checker, clock, en, start_event, end_event, expr, msg, level, active_clock_edge,
                 allow_restart, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_stable(
    constant checker           : in checker_t;
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal start_event         : in std_logic;
    signal end_event           : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant allow_restart     : in boolean     := false;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is

    variable state                : check_stable_fsm_state_t := idle;
    variable ref                  : std_logic_vector(0 to 0);
    variable clock_edge_counter   : unsigned(63 downto 0);
    variable is_stable            : boolean                  := true;
    variable exit_stability_check : boolean;
  begin
    -- pragma translate_off
    stability_check : loop
      wait_on_edge(clock, en, active_clock_edge);

      run_stability_check(checker, start_event, end_event, (0 => expr), msg, level, active_clock_edge,
                          allow_restart, path_offset, line_num, file_name, state, ref, clock_edge_counter,
                          is_stable, exit_stability_check);
      exit when exit_stability_check;
    end loop;
  -- pragma translate_on
  end;

  procedure check_stable(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal start_event         : in std_logic;
    signal end_event           : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant allow_restart     : in boolean     := false;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_stable(default_checker, clock, en, start_event, end_event, expr, msg, level, active_clock_edge,
                 allow_restart, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_not_unknown
  -----------------------------------------------------------------------------
  procedure check_not_unknown(
    constant checker           : in checker_t;
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_not_unknown(checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    constant checker     : in  checker_t;
    variable pass        : out boolean;
    constant expr        : in  std_logic_vector;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    if not is_x(expr) then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(checker,
                      p_std_msg("Not unknown check passed",
                              msg,
                              "Got " & to_nibble_string(expr) & " (" & to_integer_string(expr) & ")" & "."),
                      path_offset, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(checker,
                    p_std_msg("Not unknown check failed",
                            msg,
                            "Got " & to_nibble_string(expr) & "."),
                    level, path_offset, line_num, file_name);
    end if;
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, clock, en, expr, msg, level, active_clock_edge, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    constant checker     : in checker_t;
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    variable pass        : out boolean;
    constant expr        : in  std_logic_vector;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_not_unknown(
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_not_unknown(
    constant checker     : in checker_t;
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_not_unknown(
    constant checker           : in checker_t;
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_not_unknown(checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    constant checker     : in  checker_t;
    variable pass        : out boolean;
    constant expr        : in  std_logic;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    if not is_x(expr) then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(checker,
                      p_std_msg("Not unknown check passed",
                              msg,
                              "Got " & std_logic'image(expr)(2) & "."),
                      path_offset, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(checker,
                    p_std_msg("Not unknown check failed",
                            msg,
                            "Got " & std_logic'image(expr)(2) & "."),
                    level, path_offset, line_num, file_name);
    end if;
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, clock, en, expr, msg, level, active_clock_edge, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    constant checker     : in checker_t;
    constant expr        : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    constant expr        : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_not_unknown(
    variable pass        : out boolean;
    constant expr        : in  std_logic;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_not_unknown(
    constant expr        : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_not_unknown(
    constant checker     : in checker_t;
    constant expr        : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_not_unknown(checker, pass, expr, msg, level, path_offset, line_num, file_name);
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
    constant checker           : in checker_t;
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_zero_one_hot(checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_zero_one_hot(
    constant checker     : in  checker_t;
    variable pass        : out boolean;
    constant expr        : in  std_logic_vector;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    if n_hot_in_valid_range(expr, 0, 1) then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(checker,
                      p_std_msg("Zero one-hot check passed", msg,
                              "Got " & to_nibble_string(expr) & "."),
                      path_offset, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(checker,
                    p_std_msg("Zero one-hot check failed", msg,
                            "Got " & to_nibble_string(expr) & "."),
                    level, path_offset, line_num, file_name);
    end if;
  -- pragma translate_on
  end;

  procedure check_zero_one_hot(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_zero_one_hot(default_checker, clock, en, expr, msg, level, active_clock_edge, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_zero_one_hot(
    variable pass        : out boolean;
    constant expr        : in  std_logic_vector;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check_zero_one_hot(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_zero_one_hot(
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_zero_one_hot(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_zero_one_hot(
    constant checker     : in checker_t;
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_zero_one_hot(checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_zero_one_hot(
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_zero_one_hot(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_zero_one_hot(
    constant checker     : in checker_t;
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_zero_one_hot(checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  -----------------------------------------------------------------------------
  -- check_one_hot
  -----------------------------------------------------------------------------
  procedure check_one_hot(
    constant checker           : in checker_t;
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    wait_on_edge(clock, en, active_clock_edge);
    check_one_hot(checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_one_hot(
    constant checker     : in  checker_t;
    variable pass        : out boolean;
    constant expr        : in  std_logic_vector;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    if n_hot_in_valid_range(expr, 1, 1) then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(checker,
                      p_std_msg("One-hot check passed", msg,
                              "Got " & to_nibble_string(expr) & "."),
                      path_offset, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(checker,
                    p_std_msg("One-hot check failed", msg,
                            "Got " & to_nibble_string(expr) & "."),
                    level, path_offset, line_num, file_name);
    end if;
  -- pragma translate_on
  end;

  procedure check_one_hot(
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal expr                : in std_logic_vector;
    constant msg               : in string      := check_result_tag;
    constant level             : in log_level_t := null_log_level;
    constant active_clock_edge : in edge_t      := rising_edge;
    constant path_offset       : in natural     := 0;
    constant line_num          : in natural     := 0;
    constant file_name         : in string      := "") is
  begin
    -- pragma translate_off
    check_one_hot(default_checker, clock, en, expr, msg, level, active_clock_edge, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_one_hot(
    variable pass        : out boolean;
    constant expr        : in  std_logic_vector;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check_one_hot(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_one_hot(
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_one_hot(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_one_hot(
    constant checker     : in checker_t;
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_one_hot(checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_one_hot(
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_one_hot(default_checker, pass, expr, msg, level, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_one_hot(
    constant checker     : in checker_t;
    constant expr        : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_one_hot(checker, pass, expr, msg, level, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  -----------------------------------------------------------------------------
  -- check_next
  -----------------------------------------------------------------------------
  procedure check_next(
    constant checker             : in checker_t;
    signal clock                 : in std_logic;
    signal en                    : in std_logic;
    signal start_event           : in std_logic;
    signal expr                  : in std_logic;
    constant msg                 : in string      := check_result_tag;
    constant num_cks             : in natural     := 1;
    constant allow_overlapping   : in boolean     := true;
    constant allow_missing_start : in boolean     := true;
    constant level               : in log_level_t := null_log_level;
    constant active_clock_edge   : in edge_t      := rising_edge;
    constant path_offset         : in natural     := 0;
    constant line_num            : in natural     := 0;
    constant file_name           : in string      := "") is

    variable schedule                       : boolean_vector(0 to num_cks) := (others => false);
    variable clock_cycles_after_start_event : natural;

    function check_is_scheduled(
      constant schedule   : in boolean_vector)
      return boolean is
    begin
      return schedule(0);
    end function check_is_scheduled;

    procedure schedule_check(
      variable schedule : inout boolean_vector;
      constant num_cks    : in    natural) is
    begin
      schedule(num_cks) := true;
    end procedure schedule_check;

    procedure update_remaining_times_to_scheduled_checks(
      variable schedule : inout boolean_vector;
      constant num_cks    : in    natural) is
    begin
      schedule(0 to num_cks - 1) := schedule(1 to num_cks);
      schedule(num_cks)          := false;
    end procedure update_remaining_times_to_scheduled_checks;

    function pending_check (
      constant schedule : boolean_vector)
      return boolean is
      constant no_pending_checks : boolean_vector(1 to schedule'right) := (others => false);
    begin
      return schedule(1 to schedule'right) /= no_pending_checks;
    end function pending_check;

    procedure check_expr is
    begin
      if to_x01(expr) = '1' then
        if is_pass_visible(checker) then
          passing_check(checker, p_std_msg("Next check passed", msg, ""), path_offset, line_num, file_name);
        else
          passing_check(checker);
        end if;
      else
        failing_check(checker,
                      p_std_msg("Next check failed", msg,
                              "Got " & std_logic'image(expr)(2) &
                              " at the " & to_ordinal_number(to_unsigned(num_cks, 32)) &
                              " active and enabled clock edge."),
                      level, path_offset, line_num, file_name);
      end if;
    end procedure check_expr;

  begin
    -- pragma translate_off
    while true loop
      wait_on_edge(clock, en, active_clock_edge);
      clock_cycles_after_start_event := clock_cycles_after_start_event + 1;

      if to_x01(start_event) = '1' then
        if pending_check(schedule) and not allow_overlapping then
          failing_check(checker,
                        p_std_msg("Next check failed", msg,
                                "Got overlapping start event at the " &
                                to_ordinal_number(to_unsigned(clock_cycles_after_start_event, 32)) &
                                " active and enabled clock edge."),
                        level, path_offset, line_num, file_name);
        else
          schedule_check(schedule, num_cks);
          clock_cycles_after_start_event := 0;
        end if;
      elsif to_x01(start_event) = 'X' then
        failing_check(checker,
                      p_std_msg("Next check failed", msg,
                              "Start event is " & std_logic'image(start_event)(2) & "."),
                      level, path_offset, line_num, file_name);
      end if;

      if check_is_scheduled(schedule) then
        check_expr;
      elsif (to_x01(expr) = '1') and not allow_missing_start then
        failing_check(checker,
                      p_std_msg("Next check failed", msg,
                              "Missing start event for true expression."),
                      level, path_offset, line_num, file_name);
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
    constant msg                 : in string      := check_result_tag;
    constant num_cks             : in natural     := 1;
    constant allow_overlapping   : in boolean     := true;
    constant allow_missing_start : in boolean     := true;
    constant level               : in log_level_t := null_log_level;
    constant active_clock_edge   : in edge_t      := rising_edge;
    constant path_offset         : in natural     := 0;
    constant line_num            : in natural     := 0;
    constant file_name           : in string      := "") is
  begin
    -- pragma translate_off
    check_next(default_checker, clock, en, start_event, expr, msg, num_cks, allow_overlapping,
               allow_missing_start, level, active_clock_edge, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_sequence
  -----------------------------------------------------------------------------
  procedure check_sequence(
    constant checker           : in checker_t;
    signal clock               : in std_logic;
    signal en                  : in std_logic;
    signal event_sequence      : in std_logic_vector;
    constant msg               : in string          := check_result_tag;
    constant trigger_event     : in trigger_event_t := penultimate;
    constant level             : in log_level_t     := null_log_level;
    constant active_clock_edge : in edge_t          := rising_edge;
    constant path_offset       : in natural         := 0;
    constant line_num          : in natural         := 0;
    constant file_name         : in string          := "") is

    variable expected_events : boolean_vector(0 to event_sequence'length - 1) := (others => false);
    variable tracks          : boolean_vector(0 to event_sequence'length - 1) := (others => false);

    procedure find_new_and_update_existing_tracks (
      variable tracks         : inout boolean_vector;
      constant event_sequence   : in    std_logic_vector) is

      constant seq                       : std_logic_vector(0 to event_sequence'length - 1) := event_sequence;
      variable unknown_event_in_sequence : boolean                                          := false;

      function active_tracks (
        constant tracks   : in boolean_vector)
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
        failing_check(checker,
                      p_std_msg("Sequence check failed", msg,
                              "Got " & to_nibble_string(seq) & "."),
                      level, path_offset, line_num, file_name);
      end if;
    end find_new_and_update_existing_tracks;

    procedure update_expectations_on_events_in_next_cycle (
      constant tracks            : in    boolean_vector;
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
      constant expected_events   : in boolean_vector;
      constant event_sequence    : in std_logic_vector) is
      constant seq : std_logic_vector(0 to event_sequence'length - 1) := event_sequence;
    begin
      for i in 1 to seq'right loop
        if expected_events(i) then
          if to_x01(seq(i)) /= '1' then
            failing_check(checker,
                          p_std_msg("Sequence check failed", msg,
                                  "Missing required event at " &
                                  to_ordinal_number(to_unsigned(i, 32)) &
                                  " active and enabled clock edge."),
                          level, path_offset, line_num, file_name);
          elsif i = seq'right then
            if is_pass_visible(checker) then
              passing_check(checker, p_std_msg("Sequence check passed", msg, ""), path_offset, line_num, file_name);
            else
              passing_check(checker);
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
      failing_check(checker,
                    p_std_msg("Sequence check failed", msg,
                            "Event sequence length must be at least 2. Got " &
                            natural'image(event_sequence'length) & "."),
                    level, path_offset, line_num, file_name);
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
    constant msg               : in string          := check_result_tag;
    constant trigger_event     : in trigger_event_t := penultimate;
    constant level             : in log_level_t     := null_log_level;
    constant active_clock_edge : in edge_t          := rising_edge;
    constant path_offset       : in natural         := 0;
    constant line_num          : in natural         := 0;
    constant file_name         : in string          := "") is
  begin
    -- pragma translate_off
    check_sequence(default_checker, clock, en, event_sequence, msg, trigger_event, level, active_clock_edge,
                   path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_relation
  -----------------------------------------------------------------------------
  procedure check_relation(
    constant checker     : in checker_t;
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(checker, pass, expr, msg, level, context_msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    constant checker     : in  checker_t;
    variable pass        : out boolean;
    constant expr        : in  boolean;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant context_msg : in  string      := "";
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    if expr then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(checker, p_std_msg("Relation check passed", msg, context_msg), path_offset, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(checker, p_std_msg("Relation check failed", msg, context_msg), level, path_offset, line_num, file_name);
    end if;
  -- pragma translate_on
  end;

  procedure check_relation(
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, expr, msg, level, context_msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    variable pass        : out boolean;
    constant expr        : in  boolean;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant context_msg : in  string      := "";
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, expr, msg, level, context_msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_relation(
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, expr, msg, level, context_msg, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_relation(
    constant checker     : in checker_t;
    constant expr        : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(checker, pass, expr, msg, level, context_msg, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_relation(
    constant checker     : in checker_t;
    constant expr        : in std_ulogic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    constant checker     : in  checker_t;
    variable pass        : out boolean;
    constant expr        : in  std_ulogic;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant context_msg : in  string      := "";
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check_relation(checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    constant expr        : in std_ulogic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    variable pass        : out boolean;
    constant expr        : in  std_ulogic;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant context_msg : in  string      := "";
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_relation(
    constant expr        : in std_ulogic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_relation(
    constant checker     : in checker_t;
    constant expr        : in std_ulogic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_relation(
    constant checker     : in checker_t;
    constant expr        : in bit;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    constant checker     : in  checker_t;
    variable pass        : out boolean;
    constant expr        : in  bit;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant context_msg : in  string      := "";
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check_relation(checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    constant expr        : in bit;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  procedure check_relation(
    variable pass        : out boolean;
    constant expr        : in  bit;
    constant msg         : in  string      := check_result_tag;
    constant level       : in  log_level_t := null_log_level;
    constant context_msg : in  string      := "";
    constant path_offset : in  natural     := 0;
    constant line_num    : in  natural     := 0;
    constant file_name   : in  string      := "") is
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
  -- pragma translate_on
  end;

  impure function check_relation(
    constant expr        : in bit;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(default_checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_relation(
    constant checker     : in checker_t;
    constant expr        : in bit;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant context_msg : in string      := "";
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_relation(checker, pass, (expr = '1'), msg, level, context_msg, path_offset, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

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
    constant left  : std_logic_vector;
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

  function to_string (
    constant data : character)
    return string is
    constant full_string : string := character'image(data);
  begin
    if (full_string(full_string'left) = ''') and (full_string(full_string'right) = ''') then
      return full_string(full_string'left + 1 to full_string'right - 1);
    else
      return full_string;
    end if;
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

  -----------------------------------------------------------------------------
  -- check_(almost)_equal for real
  -----------------------------------------------------------------------------

  procedure check_equal(
    constant got         : in real;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant max_diff    : in real        := 0.0;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, got, expected, msg, max_diff, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in real;
    constant expected    : in real;
    constant msg         : in string      := check_result_tag;
    constant max_diff    : in real        := 0.0;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if abs (got - expected) <= max_diff then
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got abs (" & real'image(got) & " - " & real'image(expected) & ") <= " & real'image(max_diff) & "."),
          path_offset, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got abs (" & real'image(got) & " - " & real'image(expected) & ") > " & real'image(max_diff) & "."),
        level, path_offset, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  -----------------------------------------------------------------------------
  -- check_equal
  -----------------------------------------------------------------------------
  procedure check_equal(
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ".",
      std_fail_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in unsigned;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in unsigned;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in unsigned;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_string(expected) & " (" & to_nibble_string(to_sufficient_unsigned(expected, got'length)) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in unsigned;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in unsigned;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in unsigned;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in unsigned;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ".",
      std_fail_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". Expected " & to_string(expected) & " (" & to_nibble_string(to_sufficient_unsigned(expected, got'length)) & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in unsigned;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in natural;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in natural;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in natural;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in natural;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in natural;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in natural;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in natural;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & ".",
      std_fail_ctx => "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & ". Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in natural;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in unsigned;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in unsigned;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in unsigned;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in unsigned;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in unsigned;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in unsigned;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in unsigned;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ".",
      std_fail_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in unsigned;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in std_logic_vector;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in std_logic_vector;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in std_logic_vector;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic_vector;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in std_logic_vector;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic_vector;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic_vector;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ".",
      std_fail_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in std_logic_vector;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ".",
      std_fail_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in std_logic_vector;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in std_logic_vector;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in std_logic_vector;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_string(expected) & " (" & to_nibble_string(to_sufficient_unsigned(expected, got'length)) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic_vector;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in std_logic_vector;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic_vector;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic_vector;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ".",
      std_fail_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". Expected " & to_string(expected) & " (" & to_nibble_string(to_sufficient_unsigned(expected, got'length)) & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in std_logic_vector;
    constant expected    : in natural;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in natural;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in natural;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in natural;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in natural;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in natural;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in natural;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in natural;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & ".",
      std_fail_ctx => "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_unsigned(got, expected'length)) & ")" & ". Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in natural;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ".",
      std_fail_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in signed;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in signed;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in signed;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_string(expected) & " (" & to_nibble_string(to_sufficient_signed(expected, got'length)) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in signed;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in signed;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in signed;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in signed;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ".",
      std_fail_ctx => "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". Expected " & to_string(expected) & " (" & to_nibble_string(to_sufficient_signed(expected, got'length)) & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in signed;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in integer;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in integer;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in integer;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_signed(got, expected'length)) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_signed(got, expected'length)) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in integer;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in integer;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in integer;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in integer;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_signed(got, expected'length)) & ")" & ".",
      std_fail_ctx => "Got " & to_string(got) & " (" & to_nibble_string(to_sufficient_signed(got, expected'length)) & ")" & ". Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in integer;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in integer;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in integer;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in integer;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in integer;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in integer;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in integer;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in integer;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_string(got) & ".",
      std_fail_ctx => "Got " & to_string(got) & ". Expected " & to_string(expected) & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in integer;
    constant expected    : in integer;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_string(got) & ".",
      std_fail_ctx => "Got " & to_string(got) & ". Expected " & to_string(expected) & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in std_logic;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in std_logic;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in std_logic;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in std_logic;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in std_logic;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_string(got) & ".",
      std_fail_ctx => "Got " & to_string(got) & ". Expected " & to_string(expected) & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in std_logic;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in boolean;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in boolean;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in boolean;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in boolean;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in boolean;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in boolean;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in boolean;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_string(got) & ".",
      std_fail_ctx => "Got " & to_string(got) & ". Expected " & to_string(expected) & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in boolean;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in boolean;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in boolean;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in boolean;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in boolean;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in boolean;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in boolean;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in boolean;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_string(got) & ".",
      std_fail_ctx => "Got " & to_string(got) & ". Expected " & to_string(expected) & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in boolean;
    constant expected    : in boolean;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in string;
    constant expected    : in string;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in string;
    constant expected    : in string;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in string;
    constant expected    : in string;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in string;
    constant expected    : in string;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in string;
    constant expected    : in string;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in string;
    constant expected    : in string;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in string;
    constant expected    : in string;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_string(got) & ".",
      std_fail_ctx => "Got " & to_string(got) & ". Expected " & to_string(expected) & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in string;
    constant expected    : in string;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in character;
    constant expected    : in character;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in character;
    constant expected    : in character;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in character;
    constant expected    : in character;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in character;
    constant expected    : in character;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in character;
    constant expected    : in character;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in character;
    constant expected    : in character;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in character;
    constant expected    : in character;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_string(got) & ".",
      std_fail_ctx => "Got " & to_string(got) & ". Expected " & to_string(expected) & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in character;
    constant expected    : in character;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  procedure check_equal(
    constant got         : in time;
    constant expected    : in time;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    variable pass        : out boolean;
    constant got         : in time;
    constant expected    : in time;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in time;
    constant expected    : in time;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if got = expected then
      pass := true;
      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Equality check passed", msg,
            "Got " & to_string(got) & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Equality check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_equal(
    constant checker     : in checker_t;
    constant got         : in time;
    constant expected    : in time;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_equal(
    constant got         : in time;
    constant expected    : in time;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in time;
    constant expected    : in time;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_equal(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_equal(
    constant checker     : in checker_t;
    constant got         : in time;
    constant expected    : in time;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
    variable check_result : check_result_t;
  begin
    -- pragma translate_off
    check_result := p_build_result(
      checker => checker,
      is_pass => got = expected,
      msg => msg,
      std_pass_msg => "Equality check passed",
      std_fail_msg => "Equality check failed",
      std_pass_ctx => "Got " & to_string(got) & ".",
      std_fail_ctx => "Got " & to_string(got) & ". Expected " & to_string(expected) & ".",
      level => level,
      path_offset => path_offset + 1,
      line_num => line_num,
      file_name => file_name
    );
    -- pragma translate_on

    return check_result;
  end;

  impure function check_equal(
    constant got         : in time;
    constant expected    : in time;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return check_result_t is
  begin
    -- pragma translate_off
    return check_equal(default_checker, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;


  -----------------------------------------------------------------------------
  -- check_match
  -----------------------------------------------------------------------------
  procedure check_match(
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable pass        : out boolean;
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if std_match(got, expected) then
      pass := true;

      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Match check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
            "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Match check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_match(
    constant checker     : in checker_t;
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_match(
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_match(
    constant checker     : in checker_t;
    constant got         : in unsigned;
    constant expected    : in unsigned;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_match(
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable pass        : out boolean;
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if std_match(got, expected) then
      pass := true;

      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Match check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
            "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Match check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_match(
    constant checker     : in checker_t;
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_match(
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_match(
    constant checker     : in checker_t;
    constant got         : in std_logic_vector;
    constant expected    : in std_logic_vector;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_match(
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable pass        : out boolean;
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if std_match(got, expected) then
      pass := true;

      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Match check passed", msg,
            "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
            "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Match check failed", msg,
          "Got " & to_nibble_string(got) & " (" & to_integer_string(got) & ")" & ". " &
          "Expected " & to_nibble_string(expected) & " (" & to_integer_string(expected) & ")" & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_match(
    constant checker     : in checker_t;
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_match(
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_match(
    constant checker     : in checker_t;
    constant got         : in signed;
    constant expected    : in signed;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  procedure check_match(
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    variable pass        : out boolean;
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure check_match(
    constant checker     : in checker_t;
    variable pass        : out boolean;
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
  begin
    -- pragma translate_off
    if std_match(got, expected) then
      pass := true;

      if is_pass_visible(checker) then
        passing_check(
          checker,
          p_std_msg(
            "Match check passed", msg,
            "Got " & to_string(got) & ". " &
            "Expected " & to_string(expected) & "."),
          path_offset + 1, line_num, file_name);
      else
        passing_check(checker);
      end if;
    else
      pass := false;
      failing_check(
        checker,
        p_std_msg(
          "Match check failed", msg,
          "Got " & to_string(got) & ". " &
          "Expected " & to_string(expected) & "."),
        level, path_offset + 1, line_num, file_name);
    end if;
    -- pragma translate_on
  end;

  procedure check_match(
    constant checker     : in checker_t;
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "") is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  impure function check_match(
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(default_checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  impure function check_match(
    constant checker     : in checker_t;
    constant got         : in std_logic;
    constant expected    : in std_logic;
    constant msg         : in string      := check_result_tag;
    constant level       : in log_level_t := null_log_level;
    constant path_offset : in natural     := 0;
    constant line_num    : in natural     := 0;
    constant file_name   : in string      := "")
    return boolean is
    variable pass : boolean;
  begin
    -- pragma translate_off
    check_match(checker, pass, got, expected, msg, level, path_offset + 1, line_num, file_name);
    -- pragma translate_on
    return pass;
  end;

  -----------------------------------------------------------------------------

end package body check_pkg;
