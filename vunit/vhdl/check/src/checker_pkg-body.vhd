-- This package provides fundamental types used by the check package.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com


package body checker_pkg is

  constant logger_idx            : natural := 0;
  constant default_log_level_idx : natural := 1;
  constant stat_checks_idx       : natural := 2;
  constant stat_failed_idx       : natural := 3;
  constant stat_passed_idx       : natural := 4;
  constant checker_length        : natural := stat_passed_idx + 1;

  impure function new_checker(logger_name : string;
                              default_log_level : log_level_t := error) return checker_t is
  begin
    return new_checker(get_logger(logger_name), default_log_level);
  end;

  impure function new_checker(logger            : logger_t;
                              default_log_level : log_level_t := error) return checker_t is
    variable checker : checker_t;
    variable id      : natural;
  begin
    checker := (p_data => new_integer_vector_ptr(checker_length));
    set(checker.p_data, logger_idx, to_integer(logger.p_data));
    set(checker.p_data, default_log_level_idx, log_level_t'pos(default_log_level));
    reset_checker_stat(checker);
    return checker;
  end;

  impure function get_logger(checker : checker_t) return logger_t is
  begin
    return (p_data => to_integer_vector_ptr(get(checker.p_data, logger_idx)));
  end;

  impure function get_default_log_level(checker : checker_t) return log_level_t is
  begin
    return log_level_t'val(get(checker.p_data, default_log_level_idx));
  end;

  procedure set_default_log_level(checker : checker_t; default_log_level : log_level_t) is
  begin
    set(checker.p_data, default_log_level_idx, log_level_t'pos(default_log_level));
  end;

  procedure reset_checker_stat(checker : checker_t) is
  begin
    set(checker.p_data, stat_checks_idx, 0);
    set(checker.p_data, stat_failed_idx, 0);
    set(checker.p_data, stat_passed_idx, 0);
  end;

  impure function get_checker_stat(checker : checker_t) return checker_stat_t is
  begin
    return (n_checks => get(checker.p_data, stat_checks_idx),
            n_failed => get(checker.p_data, stat_failed_idx),
            n_passed => get(checker.p_data, stat_passed_idx));

  end;

  procedure get_checker_stat(checker       :     checker_t;
                             variable stat : out checker_stat_t) is
  begin
    stat := get_checker_stat(checker);
  end;

  impure function is_pass_visible(checker : checker_t) return boolean is
  begin
    return is_visible(get_logger(checker), pass);
  end;

  procedure passing_check(checker : checker_t) is
    constant logger : logger_t := get_logger(checker);
  begin
    set(checker.p_data, stat_checks_idx, get(checker.p_data, stat_checks_idx) + 1);
    set(checker.p_data, stat_passed_idx, get(checker.p_data, stat_passed_idx) + 1);

    log(logger, "", pass); -- invisible log
  end;

  procedure passing_check(
    checker   : checker_t;
    msg       : string;
    line_num  : natural := 0;
    file_name : string  := "") is
    constant logger : logger_t := get_logger(checker);
  begin
    -- pragma translate_off
    set(checker.p_data, stat_checks_idx, get(checker.p_data, stat_checks_idx) + 1);
    set(checker.p_data, stat_passed_idx, get(checker.p_data, stat_passed_idx) + 1);

    if is_visible(logger, pass) then
      log(logger, msg, pass, line_num, file_name);
    else
      log(logger, "", pass); -- invisible log
    end if;

  -- pragma translate_on
  end;

  procedure failing_check(
    checker   : checker_t;
    msg       : string;
    level     : log_level_t := null_log_level;
    line_num  : natural                := 0;
    file_name : string                 := "") is
  begin
    -- pragma translate_off
    set(checker.p_data, stat_checks_idx, get(checker.p_data, stat_checks_idx) + 1);
    set(checker.p_data, stat_failed_idx, get(checker.p_data, stat_failed_idx) + 1);

    if level = null_log_level then
      log(get_logger(checker), msg, get_default_log_level(checker), line_num, file_name);
    else
      log(get_logger(checker), msg, level, line_num, file_name);
    end if;
  -- pragma translate_on
  end;

  function "+" (
    stat1 : checker_stat_t;
    stat2 : checker_stat_t)
    return checker_stat_t is
    variable sum : checker_stat_t;
  begin
    sum.n_checks := stat1.n_checks + stat2.n_checks;
    sum.n_passed := stat1.n_passed + stat2.n_passed;
    sum.n_failed := stat1.n_failed + stat2.n_failed;

    return sum;
  end function "+";

  function "-" (
    stat1 : checker_stat_t;
    stat2 : checker_stat_t)
    return checker_stat_t is
    variable diff : checker_stat_t;
  begin
    diff.n_checks := stat1.n_checks - stat2.n_checks;
    diff.n_passed := stat1.n_passed - stat2.n_passed;
    diff.n_failed := stat1.n_failed - stat2.n_failed;

    return diff;
  end function "-";

  function to_string(stat : checker_stat_t) return string is
  begin
    return ("checker_stat'("&
            "n_checks => " & integer'image(stat.n_checks) & ", " &
            "n_failed => " & integer'image(stat.n_failed) & ", " &
            "n_passed => " & integer'image(stat.n_passed) &
            ")");
  end function;

end package body;
