-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

use work.log_levels_pkg.all;
use work.log_handler_pkg.all;
use work.integer_vector_ptr_pkg.all;

package logger_pkg is

  type logger_t is record
    p_data : integer_vector_ptr_t;
  end record;

  constant null_logger : logger_t := (p_data => null_ptr);

  procedure info(msg : string;
                 line_num : natural := 0;
                 file_name : string := "");

  impure function is_visible(logger : logger_t;
                             log_level : log_level_t) return boolean;

  procedure log(logger : logger_t;
                msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "");

  procedure log(msg : string;
                log_level : log_level_t := info;
                path_offset : natural := 0;
                line_num : natural := 0;
                file_name : string := "");

  procedure debug(logger : logger_t;
                  msg : string;
                  path_offset : natural := 0;
                  line_num : natural := 0;
                  file_name : string := "");

  procedure failure(logger : logger_t;
                    msg : string;
                    path_offset : natural := 0;
                    line_num : natural := 0;
                    file_name : string := "");

  impure function get_logger(name : string;
                             parent : logger_t := null_logger) return logger_t;

end package;
