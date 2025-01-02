-- This package provides fundamental types used by the check package.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com


package body checker_pkg is

  constant logger_idx            : natural := 0;
  constant default_log_level_idx : natural := 1;
  constant stat_checks_idx       : natural := 2;
  constant stat_failed_idx       : natural := 3;
  constant stat_passed_idx       : natural := 4;
  constant unhandled_checks_idx  : natural := 5;
  constant checker_length        : natural := unhandled_checks_idx + 1;

  constant unhandled_checks : integer_vector_ptr_t := new_integer_vector_ptr;
  constant string_pool : string_ptr_pool_t := new_string_ptr_pool;

  impure function new_checker(logger_name : string;
                              default_log_level : log_level_t := error) return checker_t is
  begin
    return new_checker(get_logger(logger_name), default_log_level);
  end;

  impure function new_checker(logger            : logger_t;
                              default_log_level : log_level_t := error) return checker_t is
    variable checker : checker_t;
    constant unhandled_checker_checks : integer := to_integer(new_integer_vector_ptr);
    constant unhandled_checks_length : natural := length(unhandled_checks);
  begin
    checker := (p_data => new_integer_vector_ptr(checker_length));
    set(checker.p_data, logger_idx, to_integer(logger.p_data));
    set(checker.p_data, default_log_level_idx, log_level_t'pos(default_log_level));
    resize(unhandled_checks, unhandled_checks_length + 1);
    set(unhandled_checks, unhandled_checks_length, unhandled_checker_checks);
    set(checker.p_data, unhandled_checks_idx, unhandled_checker_checks);
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

  function p_std_msg (
    constant check_result : string;
    constant msg          : string;
    constant ctx          : string)
    return string is

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
    if not is_decorated(msg) then
      return append_context(msg, ctx);
    else
      return append_context(check_result & undecorate(msg), ctx);
    end if;
  end function p_std_msg;

  impure function p_register_unhandled_check(checker : checker_t) return unhandled_check_id_t is
    constant unhandled_checker_checks : integer_vector_ptr_t := to_integer_vector_ptr(get(checker.p_data, unhandled_checks_idx));
    constant unhandled_checker_checks_length : natural := length(unhandled_checker_checks);
  begin
    resize(unhandled_checker_checks, unhandled_checker_checks_length + 1);
    set(unhandled_checker_checks, unhandled_checker_checks_length, 1);

    return unhandled_checker_checks_length;
  end;

  procedure p_handle(check_result : check_result_t) is
  begin
    set(to_integer_vector_ptr(get(check_result.p_checker.p_data, unhandled_checks_idx)), check_result.p_unhandled_check_id, 0);
  end;

  impure function p_has_unhandled_checks return boolean is
    variable unhandled_checker_checks : integer_vector_ptr_t;
  begin
    for checker_idx in 0 to length(unhandled_checks) - 1 loop
      unhandled_checker_checks := to_integer_vector_ptr(get(unhandled_checks, checker_idx));
      for check_idx in 0 to length(unhandled_checker_checks) - 1 loop
        if get(unhandled_checker_checks, check_idx) /= 0 then
          return true;
        end if;
      end loop;
    end loop;

    return false;
  end;

  impure function p_build_result(
    constant checker      : in checker_t;
    constant is_pass      : in boolean;
    constant msg     : in string;
    constant std_pass_msg : in string;
    constant std_fail_msg : in string;
    constant std_pass_ctx : in string;
    constant std_fail_ctx : in string;
    constant level        : in log_level_t;
    constant path_offset  : in natural;
    constant line_num     : in natural;
    constant file_name    : in string)
    return check_result_t is
    variable check_result : check_result_t;
    variable location : location_t := get_location(path_offset + 1, line_num, file_name);
  begin
    check_result.p_is_pass := is_pass;
    check_result.p_checker := checker;
    if is_pass then
      check_result.p_level := pass;
    elsif level = null_log_level then
      check_result.p_level := get_default_log_level(checker);
    else
      check_result.p_level := level;
    end if;
    check_result.p_line_num := location.line_num;
    check_result.p_file_name := new_string_ptr(string_pool, location.file_name.all);

    update_checker_stat(checker, is_pass);
    if is_pass then
      check_result.p_unhandled_check_id := null_unhandled_check_id;
      if is_pass_visible(checker) then
        check_result.p_msg := new_string_ptr(p_std_msg(std_pass_msg, msg, std_pass_ctx));
      else
        check_result.p_msg := null_string_ptr;
      end if;
    else
      check_result.p_unhandled_check_id := p_register_unhandled_check(checker);
      check_result.p_msg := new_string_ptr(string_pool, p_std_msg(std_fail_msg, msg, std_fail_ctx));
    end if;

    deallocate(location);
    return check_result;
  end;

  procedure p_recycle_check_result(check_result : check_result_t) is
    variable file_name : string_ptr_t := check_result.p_file_name;
    variable msg : string_ptr_t := check_result.p_msg;
  begin
    recycle(string_pool, file_name);
    recycle(string_pool, msg);
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

  procedure update_checker_stat(
    checker : checker_t;
    is_pass : boolean
  ) is
  begin
    set(checker.p_data, stat_checks_idx, get(checker.p_data, stat_checks_idx) + 1);
    if is_pass then
      set(checker.p_data, stat_passed_idx, get(checker.p_data, stat_passed_idx) + 1);
    else
      set(checker.p_data, stat_failed_idx, get(checker.p_data, stat_failed_idx) + 1);
    end if;
  end;

  procedure log_passing_check(checker : checker_t) is
    constant logger : logger_t := get_logger(checker);
  begin
    log(logger, "", pass); -- invisible log
  end;

  procedure passing_check(checker : checker_t) is
  begin
    update_checker_stat(checker, is_pass => true);
    log_passing_check(checker);
  end;

  procedure log_passing_check(
    checker     : checker_t;
    msg         : string;
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string  := "") is
    constant logger : logger_t := get_logger(checker);
  begin
    -- pragma translate_off
    if is_visible(logger, pass) then
      log(logger, msg, pass, path_offset + 1, line_num, file_name);
    else
      log(logger, "", pass); -- invisible log
    end if;
    -- pragma translate_on
  end;

  procedure passing_check(
    checker     : checker_t;
    msg         : string;
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string  := "") is
  begin
    -- pragma translate_off
    update_checker_stat(checker, is_pass => true);
    log_passing_check(checker, msg, path_offset + 1, line_num, file_name);
    -- pragma translate_on
  end;

  procedure log_failing_check(
    checker     : checker_t;
    msg         : string;
    level       : log_level_t := null_log_level;
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string := "") is
  begin
    -- pragma translate_off
    if level = null_log_level then
      log(get_logger(checker), msg, get_default_log_level(checker), path_offset + 1, line_num, file_name);
    else
      log(get_logger(checker), msg, level, path_offset + 1, line_num, file_name);
    end if;
  -- pragma translate_on
  end;

  procedure failing_check(
    checker     : checker_t;
    msg         : string;
    level       : log_level_t := null_log_level;
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string := "") is
  begin
    -- pragma translate_off
    update_checker_stat(checker, is_pass => false);
    log_failing_check(checker, msg, level, path_offset + 1, line_num, file_name);
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

  impure function to_integer(checker : checker_t) return integer is
  begin
    return to_integer(checker.p_data);
  end;

  impure function to_checker(value : integer) return checker_t is
  begin
    return (p_data => to_integer_vector_ptr(value));
  end;

end package body;
