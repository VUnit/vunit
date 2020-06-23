-- This package provides fundamental types used by the check package.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.integer_vector_ptr_pkg.all;

package checker_pkg is
  type checker_t is record
    p_data : integer_vector_ptr_t;
  end record;
  constant null_checker : checker_t := (p_data => null_ptr);

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

end package;
