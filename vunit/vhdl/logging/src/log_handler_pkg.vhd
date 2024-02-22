-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

use work.ansi_pkg.all;
use work.common_log_pkg.all;
use work.file_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.log_levels_pkg.all;
use work.string_ops.upper;
use work.string_ptr_pkg.all;

package log_handler_pkg is
  type deprecated_log_format_t is (
    -- The raw log format contains just the message without any other information
    raw,

    -- The level log format contains the level and message
    level,

    -- The verbose log format contains all information
    verbose,

    -- The csv format contains all information in machine readable format
    csv,

    -- Deprecated value not supported by new interfaces but kept for backward
    -- compatibility reasons. NOT for new designs
    off);

  subtype log_format_t is deprecated_log_format_t range raw to csv;

  -- Log handler record, all fields are private
  type log_handler_t is record
    p_data : integer_vector_ptr_t;
  end record;
  constant null_log_handler : log_handler_t := (p_data => null_ptr);
  type log_handler_vec_t is array (natural range <>) of log_handler_t;

  -- Display handler; Write to stdout
  impure function display_handler return log_handler_t;

  -- Get the name of the file used by the handler
  impure function get_file_name (log_handler : log_handler_t) return string;

  -- File name used by the display handler
  constant stdout_file_name : string := ">1";

  constant null_file_name : string := "";

  -- Set the format to be used by the log handler
  procedure set_format(log_handler : log_handler_t;
                       format : log_format_t;
                       use_color : boolean := false);

  -- Get the format used by the log handler
  procedure get_format(constant log_handler : in log_handler_t;
                       variable format : out log_format_t;
                       variable use_color : out boolean);

  impure function new_log_handler(file_name : string;
                                  format : log_format_t := verbose;
                                  use_color : boolean := false) return log_handler_t;

  ---------------------------------------------
  -- Private parts not intended for public use
  ---------------------------------------------
  impure function get_id_number(log_handler : log_handler_t) return natural;
  procedure update_max_logger_name_length(log_handler : log_handler_t; value : natural);
  impure function get_max_logger_name_length(log_handler : log_handler_t) return natural;

  procedure log_to_handler(log_handler : log_handler_t;
                           logger_name : string;
                           msg : string;
                           log_level : log_level_t;
                           log_time : time;
                           sequence_number : natural;
                           line_num : natural := 0;
                           file_name : string := "");

  procedure init_log_handler(log_handler : log_handler_t;
                             format : log_format_t;
                             file_name : string;
                             use_color : boolean := false);
end package;
