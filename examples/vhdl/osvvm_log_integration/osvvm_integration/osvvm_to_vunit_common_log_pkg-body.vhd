-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

package body common_log_pkg is
  procedure write_to_log(
    file log_destination : text;
    msg : string := "";
    log_time : time := no_time;
    log_level : string := "";
    log_source_name : string := "";
    str_1, str_2, str_3, str_4, str_5, str_6, str_7, str_8, str_9, str_10 : string := "";
    val_1, val_2, val_3, val_4, val_5, val_6, val_7, val_8, val_9, val_10 : integer := no_val
  ) is
    constant stripped_log_level : string := strip(log_level);

    alias prefix is str_2;
    alias suffix is str_3;

    variable logger : logger_t;
    variable vunit_log_level : log_level_t;
    variable full_msg : line;
  begin
    logger := get_logger(log_source_name);

    if stripped_log_level = "WARNING" then
      vunit_log_level := warning;
    elsif stripped_log_level = "ERROR" then
      vunit_log_level := error;
    elsif stripped_log_level = "FAILURE" then
      vunit_log_level := failure;
    elsif stripped_log_level = "DEBUG" then
      vunit_log_level := debug;
    elsif stripped_log_level = "PASSED" then
      vunit_log_level := pass;
    else
      vunit_log_level := info;
    end if;

    if prefix /= "" then
      write(full_msg, prefix & " ");
    end if;

    write(full_msg, msg);

    if suffix /= "" then
      write(full_msg, " " & suffix);
    end if;

    log(logger, msg, vunit_log_level, path_offset => 4);
  end;

end package body;
