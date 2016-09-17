-- This package provides fundamental types used by the log package.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.lang.all;
use work.string_ops.all;

package log_types_pkg is
  type log_format_t is (dflt, off, raw, verbose_csv, level, verbose);
  type log_level_t is (dflt, highest_level,
                       failure_high2, failure_high1, failure, failure_low1, failure_low2,
                       error_high2, error_high1, error, error_low1, error_low2,
                       warning_high2, warning_high1, warning, warning_low1, warning_low2,
                       info_high2, info_high1, info, info_low1, info_low2,
                       debug_high2, debug_high1, debug, debug_low1, debug_low2,
                       verbose_high2, verbose_high1, verbose, verbose_low1, verbose_low2);
  type log_level_vector_t is array (natural range <>) of log_level_t;
  constant null_log_level_vector : log_level_vector_t(1 to 0) := (others => dflt);
  type log_handler_t is (display_handler, file_handler, d, f);
  type log_handler_vector_t is array (natural range <>) of log_handler_t;
  type log_filter_t is record
    id : natural;
    pass_filter : boolean;
    handlers : log_handler_vector_t(1 to 2);
    n_handlers : natural;
    levels      : log_level_vector_t(1 to 30);
    n_levels    : natural;
    src      : string(1 to 256);
    src_length : natural;
  end record;

  type logger_cfg_t is record
    log_default_src          : line;
    log_file_name            : line;
    log_display_format       : log_format_t;
    log_file_format          : log_format_t;
    log_file_is_initialized  : boolean;
    log_stop_level          : log_level_t;
    log_separator            : character;
  end record;

  type logger_cfg_export_t is record
    log_default_src          : string(1 to 512);
    log_default_src_length   : natural;
    log_file_name            : string(1 to 512);
    log_file_name_length     : natural;
    log_display_format       : log_format_t;
    log_file_format          : log_format_t;
    log_file_is_initialized  : boolean;
    log_stop_level          : log_level_t;
    log_separator            : character;
  end record;

end package;
