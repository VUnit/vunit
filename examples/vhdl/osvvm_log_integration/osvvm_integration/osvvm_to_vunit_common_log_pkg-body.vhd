-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

package body common_log_pkg is
  constant is_original_pkg : boolean := false;
  -- Create a namespace for OSVVM to avoid name collisions between OSVVM alert/log ID names
  -- and VUnit logger names. The file handler handling the OSVVM transcript file is also
  -- attached to this logger.
  constant osvvm : logger_t := get_logger("OSVVM");

  constant has_file_handler : integer_vector_ptr_t := new_integer_vector_ptr(1);

  procedure write_to_log(
    file log_destination : text;
    log_destination_path : string := no_string;
    msg : string := no_string;
    log_time : time := no_time;
    log_level : string := no_string;
    log_source_name : string := no_string
  ) is

    constant stripped_log_level : string := strip(log_level);
    variable file_log_handler : log_handler_t;

    variable logger : logger_t;
    variable vunit_log_level : log_level_t;
    variable reenable_display_handler : boolean := false;

    impure function remove_parent_path(full_path : string) return string is
      variable parts : lines_t :=  split(full_path, "/");
    begin
      return parts(parts'right).all;
    end;
  begin
    logger := get_logger(log_source_name, parent => osvvm);

    -- Here we do the simplified assumption that when the transcript is opened it stays
    -- on and is always mirrored. Allowing arbitrary use of transcript and mirroring
    -- requires additional code. The transcript file is moved to the VUnit output path
    -- to avoid access from multiple threads when running parallel simulations.
    if (log_destination_path /= no_string) then
      if (get(has_file_handler, 0) = 0) then
        file_log_handler := new_log_handler(join(get_string(run_db, "output_path"), remove_parent_path(log_destination_path)));
        -- The message has already been logged to display so temporarily disable it
        set_log_handlers(osvvm, (0 => file_log_handler));
        show_all(logger, file_log_handler);
        reenable_display_handler := true;
        set(has_file_handler, 0, 1);
      else
        return;
      end if;
    end if;

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

    log(logger, msg, vunit_log_level, path_offset => 4, line_num => 0, file_name => "");

    if reenable_display_handler then
      set_log_handlers(osvvm, (display_handler, file_log_handler));
    end if;
  end;

end package body;
