-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.ansi_pkg.all;
use work.core_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;

package log_levels_pkg is

  type log_level_t is (
    null_log_level,

    trace,
    debug,
    pass,
    info,
    warning,
    error,
    failure,

    custom_level1,
    custom_level2,
    custom_level3,
    custom_level4,
    custom_level5,
    custom_level6,
    custom_level7,
    custom_level8);

  type log_level_vec_t is array (natural range <>) of log_level_t;
  constant null_vec : log_level_vec_t(1 to 0) := (others => info);

  subtype alert_log_level_t is log_level_t range warning to failure;
  subtype legal_log_level_t is log_level_t range log_level_t'succ(null_log_level) to log_level_t'high;

  constant max_num_custom_log_levels : natural := (
    1 + log_level_t'pos(log_level_t'high) - log_level_t'pos(custom_level1));

  impure function new_log_level(name : string;
                                fg : ansi_color_t := no_color;
                                bg : ansi_color_t := no_color;
                                style : ansi_style_t := normal) return log_level_t;
  impure function is_valid(log_level : log_level_t) return boolean;

  impure function get_name(log_level : log_level_t) return string;
  impure function get_color(log_level : log_level_t) return ansi_colors_t;
  impure function max_level_length return natural;
end package;
