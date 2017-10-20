-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ptr_pkg.all;
use work.ansi_pkg.all;

package log_levels_pkg is

  type log_level_t is (
    below_all_log_levels,

    custom_level1,
    custom_level2,
    custom_level3,
    custom_level4,
    custom_level5,
    custom_level6,
    custom_level7,
    custom_level8,
    custom_level9,
    custom_level10,
    custom_level11,
    custom_level12,
    custom_level13,
    custom_level14,

    verbose,

    custom_level16,
    custom_level17,
    custom_level18,
    custom_level19,
    custom_level20,
    custom_level21,
    custom_level22,
    custom_level23,
    custom_level24,
    custom_level25,
    custom_level26,
    custom_level27,
    custom_level28,
    custom_level29,

    debug,

    custom_level31,
    custom_level32,
    custom_level33,
    custom_level34,
    custom_level35,
    custom_level36,
    custom_level37,
    custom_level38,
    custom_level39,
    custom_level40,
    custom_level41,
    custom_level42,
    custom_level43,
    custom_level44,

    info,

    custom_level46,
    custom_level47,
    custom_level48,
    custom_level49,
    custom_level50,
    custom_level51,
    custom_level52,
    custom_level53,
    custom_level54,
    custom_level55,
    custom_level56,
    custom_level57,
    custom_level58,
    custom_level59,

    warning,

    custom_level61,
    custom_level62,
    custom_level63,
    custom_level64,
    custom_level65,
    custom_level66,
    custom_level67,
    custom_level68,
    custom_level69,
    custom_level70,
    custom_level71,
    custom_level72,
    custom_level73,
    custom_level74,

    error,

    custom_level76,
    custom_level77,
    custom_level78,
    custom_level79,
    custom_level80,
    custom_level81,
    custom_level82,
    custom_level83,
    custom_level84,
    custom_level85,
    custom_level86,
    custom_level87,
    custom_level88,
    custom_level89,

    failure,

    custom_level91,
    custom_level92,
    custom_level93,
    custom_level94,
    custom_level95,
    custom_level96,
    custom_level97,
    custom_level98,
    custom_level99,
    custom_level100,

    above_all_log_levels,

    null_log_level
    );
  type log_level_vec_t is array (natural range <>) of log_level_t;

  subtype user_log_level_t is log_level_t range custom_level1 to custom_level100;
  type user_log_level_vec_t is array (natural range <>) of user_log_level_t;
  constant null_vec : user_log_level_vec_t(1 to 0) := (others => info);

  subtype numeric_log_level_t is integer range 1 to 100;

  impure function "+" (reference_level : log_level_t; offset : numeric_log_level_t) return numeric_log_level_t;
  impure function "-" (reference_level : log_level_t; offset : numeric_log_level_t) return numeric_log_level_t;
  impure function new_log_level(name : string;
                                log_level : numeric_log_level_t;
                                fg : ansi_color_t := no_color;
                                bg : ansi_color_t := no_color;
                                style : ansi_style_t := normal) return log_level_t;
  impure function is_valid(log_level : log_level_t) return boolean;
  impure function get_name(log_level : log_level_t) return string;
  impure function get_color(log_level : log_level_t) return ansi_colors_t;
  impure function max_level_length return natural;
end package;
