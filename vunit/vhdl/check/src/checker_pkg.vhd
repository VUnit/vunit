-- This package provides fundamental types used by the check package.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;

package checker_pkg is
  type edge_t is (rising_edge, falling_edge, both_edges);
  type trigger_event_t is (first_pipe, first_no_pipe, penultimate);

  type checker_stat_t is record
    n_checks : natural;
    n_failed : natural;
    n_passed : natural;
  end record;

  function "+" (
    stat1 : checker_stat_t;
    stat2 : checker_stat_t)
    return checker_stat_t;

  function "-" (
    stat1 : checker_stat_t;
    stat2 : checker_stat_t)
    return checker_stat_t;

  function to_string(stat : checker_stat_t) return string;

  type checker_t is record
    p_data : integer_vector_ptr_t;
  end record;

  impure function num_checkers return natural;
  impure function get_checker(id : natural) return checker_t;

  impure function new_checker(name              : string;
                              logger            : logger_t;
                              default_log_level : log_level_t := error) return checker_t;
  impure function new_checker(name              : string;
                              default_log_level : log_level_t := error) return checker_t;

  impure function get_logger(checker            : checker_t) return logger_t;
  impure function get_default_log_level(checker : checker_t) return log_level_t;
  procedure set_default_log_level(checker : checker_t; default_log_level : log_level_t);

  impure function get_stat(checker : checker_t) return checker_stat_t;
  impure function get_name(checker : checker_t) return string;
  procedure reset_stat(checker     : checker_t);
  procedure get_stat(checker       :     checker_t;
                     variable stat : out checker_stat_t);

  -- Legacy aliases
  alias get_checker_stat is get_stat[checker_t return checker_stat_t];
  alias get_checker_stat is get_stat[checker_t, checker_stat_t];
  alias reset_checker_stat is reset_stat[checker_t];

  constant null_checker : checker_t := (p_data => null_ptr);

  impure function is_passing_check_msg_enabled(checker : checker_t) return boolean;

  procedure passing_check(checker : checker_t);

  procedure passing_check(
    checker   : checker_t;
    msg       : string;
    line_num  : natural := 0;
    file_name : string  := "");

  procedure failing_check(
    checker   : checker_t;
    msg       : string;
    level     : log_level_t := null_log_level;
    line_num  : natural                := 0;
    file_name : string                 := "");

end package;

package body checker_pkg is

  constant logger_idx            : natural := 0;
  constant id_idx                : natural := 1;
  constant name_idx              : natural := 2;
  constant default_log_level_idx : natural := 3;
  constant stat_checks_idx       : natural := 4;
  constant stat_failed_idx       : natural := 5;
  constant stat_passed_idx       : natural := 6;
  constant checker_length        : natural := stat_passed_idx + 1;

  constant checkers : integer_vector_ptr_t := allocate;

  impure function num_checkers return natural is
  begin
    return length(checkers);
  end;

  impure function get_checker(id : natural) return checker_t is
  begin
    return (p_data => to_integer_vector_ptr(get(checkers, id)));
  end;

  impure function new_checker(name              : string;
                              default_log_level : log_level_t := error) return checker_t is
    variable logger : logger_t;
  begin

    if name = "" then
      -- Default checker
      logger := get_logger("check");
    else
      logger := get_logger(name, parent => get_logger("check"));
    end if;

    return new_checker(name, logger, default_log_level);
  end;

  impure function new_checker(name              : string;
                              logger            : logger_t;
                              default_log_level : log_level_t := error) return checker_t is
    variable checker : checker_t;
    variable id      : natural;
  begin
    for i in 0 to num_checkers-1 loop
      if get_name(get_checker(i)) = name then
        failure("Checker with name """ & name & """ already exists.");
        return null_checker;
      end if;
    end loop;

    checker := (p_data => allocate(checker_length));
    id      := length(checkers);
    resize(checkers, length(checkers)+1);
    set(checkers, id, to_integer(checker.p_data));

    set(checker.p_data, id_idx, id);
    set(checker.p_data, name_idx, to_integer(allocate(name)));
    set(checker.p_data, logger_idx, to_integer(logger.p_data));
    set(checker.p_data, default_log_level_idx, log_level_t'pos(default_log_level));
    reset_stat(checker);
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

  procedure reset_stat(checker : checker_t) is
  begin
    set(checker.p_data, stat_checks_idx, 0);
    set(checker.p_data, stat_failed_idx, 0);
    set(checker.p_data, stat_passed_idx, 0);
  end;

  impure function get_stat(checker : checker_t) return checker_stat_t is
  begin
    return (n_checks => get(checker.p_data, stat_checks_idx),
            n_failed => get(checker.p_data, stat_failed_idx),
            n_passed => get(checker.p_data, stat_passed_idx));

  end;

  procedure get_stat(checker       :     checker_t;
                     variable stat : out checker_stat_t) is
  begin
    stat := get_stat(checker);
  end;

  impure function get_name(checker : checker_t) return string is
  begin
    return to_string(to_string_ptr(get(checker.p_data, name_idx)));
  end;

  impure function is_passing_check_msg_enabled(checker : checker_t) return boolean is
  begin
    return is_enabled(get_logger(checker), verbose);
  end;

  procedure passing_check(checker : checker_t) is
  begin
    set(checker.p_data, stat_checks_idx, get(checker.p_data, stat_checks_idx) + 1);
    set(checker.p_data, stat_passed_idx, get(checker.p_data, stat_passed_idx) + 1);
  end;

  procedure passing_check(
    checker   : checker_t;
    msg       : string;
    line_num  : natural := 0;
    file_name : string  := "") is
    constant logger : logger_t := get_logger(checker);
  begin
    -- pragma translate_off
    passing_check(checker);

    if is_enabled(logger, verbose) then
      log(logger, msg, verbose, line_num, file_name);
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
