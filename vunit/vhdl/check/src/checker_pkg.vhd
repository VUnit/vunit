-- This package provides fundamental types used by the check package.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.location_pkg.all;
use work.string_ops.all;
use work.string_ptr_pool_pkg.all;

package checker_pkg is
  type checker_t is record
    p_data : integer_vector_ptr_t;
  end record;
  constant null_checker : checker_t := (p_data => null_ptr);

  subtype unhandled_check_id_t is integer range -1 to integer'high;
  constant null_unhandled_check_id : unhandled_check_id_t := -1;

  type check_result_t  is record
    p_is_pass : boolean;
    p_checker : checker_t;
    p_msg : string_ptr_t;
    p_level : log_level_t;
    p_unhandled_check_id : unhandled_check_id_t;
    p_line_num : natural;
    p_file_name : string_ptr_t;
  end record;

  impure function new_checker(logger_name : string;
                              default_log_level : log_level_t := error) return checker_t;
  impure function new_checker(logger            : logger_t;
                              default_log_level : log_level_t := error) return checker_t;

  impure function get_logger(checker            : checker_t) return logger_t;
  impure function get_default_log_level(checker : checker_t) return log_level_t;
  procedure set_default_log_level(checker : checker_t; default_log_level : log_level_t);

  impure function is_pass_visible(checker : checker_t) return boolean;

  procedure passing_check(checker : checker_t);

  procedure passing_check(
    checker     : checker_t;
    msg         : string;
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string  := "");

  procedure failing_check(
    checker     : checker_t;
    msg         : string;
    level       : log_level_t := null_log_level;
    path_offset : natural := 0;
    line_num    : natural                := 0;
    file_name   : string                 := "");

  procedure update_checker_stat(
      checker : checker_t;
      is_pass : boolean
    );

  procedure log_passing_check(checker : checker_t);

  procedure log_passing_check(
    checker     : checker_t;
    msg         : string;
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string  := "");

  procedure log_failing_check(
    checker     : checker_t;
    msg         : string;
    level       : log_level_t := null_log_level;
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string := "");

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

  impure function get_checker_stat(checker : checker_t) return checker_stat_t;
  procedure reset_checker_stat(checker     : checker_t);
  procedure get_checker_stat(checker       :     checker_t;
                             variable stat : out checker_stat_t);

  impure function to_integer(checker : checker_t) return integer;
  impure function to_checker(value : integer) return checker_t;

  -- Private
  impure function p_has_unhandled_checks return boolean;
  impure function p_register_unhandled_check(checker : checker_t) return unhandled_check_id_t;
  procedure p_handle(check_result : check_result_t);
  impure function p_build_result(
    constant checker : in checker_t;
    constant is_pass : in boolean;
    constant msg : in string;
    constant std_pass_msg : in string;
    constant std_fail_msg : in string;
    constant std_pass_ctx : in string;
    constant std_fail_ctx : in string;
    constant level : in log_level_t;
    constant path_offset : in natural;
    constant line_num : in natural;
    constant file_name : in string)
  return check_result_t;

  procedure p_recycle_check_result(check_result : check_result_t);

  function p_std_msg(
    constant check_result : string;
    constant msg : string;
    constant ctx : string)
  return string;
end package;
