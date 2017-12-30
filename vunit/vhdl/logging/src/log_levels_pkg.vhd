-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ptr_pkg.all;
use work.ansi_pkg.all;

package log_levels_pkg is

  type log_level_t is (
    null_log_level,

    verbose,
    debug,
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

  subtype standard_log_level_t is log_level_t range verbose to failure;
  subtype legal_log_level_t is log_level_t range log_level_t'succ(null_log_level) to log_level_t'high;

  constant num_standard_log_levels : natural := (standard_log_level_t'pos(standard_log_level_t'high) -
                                                 standard_log_level_t'pos(standard_log_level_t'low) + 1);

  constant num_legal_log_levels : natural := (legal_log_level_t'pos(legal_log_level_t'high) -
                                              legal_log_level_t'pos(legal_log_level_t'low) + 1);

  constant max_num_custom_log_levels : natural := num_legal_log_levels - num_standard_log_levels;

  impure function new_log_level(name : string;
                                fg : ansi_color_t := no_color;
                                bg : ansi_color_t := no_color;
                                style : ansi_style_t := normal) return log_level_t;
  impure function is_valid(log_level : log_level_t) return boolean;

  -- Returns true if the log_level is not a custom level
  impure function is_standard(log_level : log_level_t) return boolean;

  impure function get_name(log_level : log_level_t) return string;
  impure function get_color(log_level : log_level_t) return ansi_colors_t;
  impure function max_level_length return natural;
end package;
