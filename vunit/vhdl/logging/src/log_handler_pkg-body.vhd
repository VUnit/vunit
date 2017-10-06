-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

library vunit_lib;
use vunit_lib.string_ptr_pkg.all;
use vunit_lib.integer_vector_ptr_pkg.all;

use work.ansi_pkg.all;
use work.logger_pkg.all;

package body log_handler_pkg is

  constant file_name_idx : natural := 0;
  constant format_idx : natural := 1;
  constant use_color_idx : natural := 2;
  constant file_is_initialized_idx : natural := 3;
  constant log_level_idx : natural := 4;
  constant max_logger_name_idx : natural := 5;
  constant log_handler_length : natural := max_logger_name_idx + 1;

  constant max_time_length : natural := time'image(1 sec)'length;
  constant max_level_length : natural := log_level_t'image(failure)'length;

  impure function new_log_handler(id : natural;
                                  file_name : string;
                                  format : log_format_t;
                                  use_color : boolean) return log_handler_t is
    constant log_handler : log_handler_t := (p_id => id, p_data => allocate(log_handler_length));
  begin
    set(log_handler.p_data, file_name_idx, to_integer(allocate(file_name)));
    set(log_handler.p_data, file_is_initialized_idx, 0);
    set(log_handler.p_data, log_level_idx, to_integer(integer_vector_ptr_t'(allocate)));
    set(log_handler.p_data, max_logger_name_idx, 0);
    set_format(log_handler, format, use_color);
    return log_handler;
  end;

  procedure init_log_handler(log_handler : log_handler_t;
                             format : log_format_t;
                             file_name : string;
                             use_color : boolean := false) is
    variable file_name_ptr : string_ptr_t := to_string_ptr(get(log_handler.p_data, file_name_idx));
  begin
    reallocate(file_name_ptr, file_name);
    set(log_handler.p_data, file_is_initialized_idx, 0);
    set_format(log_handler, format, use_color);
  end;

  procedure set_format(log_handler : log_handler_t;
                       format : log_format_t;
                       use_color : boolean := false) is
  begin
    set(log_handler.p_data, format_idx, log_format_t'pos(format));
    if use_color then
      set(log_handler.p_data, use_color_idx, 1);
    else
      set(log_handler.p_data, use_color_idx, 0);
    end if;
  end;

  impure function upper(str : string) return string is
    variable result : string(str'range);
  begin
    for i in str'range loop
      result(i) := character'val(character'pos(str(i)) + character'pos('A') - character'pos('a'));
    end loop;
    return result;
  end;

  procedure set_max_logger_name_length(log_handler : log_handler_t; value : natural) is
  begin
    set(log_handler.p_data, max_logger_name_idx, value);
  end;


  impure function get_max_logger_name_length(log_handler : log_handler_t) return natural is
  begin
    return get(log_handler.p_data, max_logger_name_idx);
  end;

  impure function get_log_level(log_handler : log_handler_t; logger : logger_t) return log_level_config_t is
    constant log_levels : integer_vector_ptr_t := to_integer_vector_ptr(get(log_handler.p_data, log_level_idx));
    constant logger_id : natural := get_id(logger);
  begin
    assert logger_id < length(log_levels); -- Should never happen
    return log_level_config_t'val(get(log_levels, logger_id));
  end;

  procedure set_log_level(log_handler : log_handler_t;
                          logger : logger_t;
                          level : log_level_config_t) is
    constant log_levels : integer_vector_ptr_t := to_integer_vector_ptr(get(log_handler.p_data, log_level_idx));
    constant logger_id : natural := get_id(logger);
  begin
    if logger_id >= length(log_levels) then
      resize(log_levels, logger_id+1);
    end if;

    set(log_levels, logger_id, log_level_config_t'pos(level));

    for i in 0 to num_children(logger)-1 loop
      set_log_level(log_handler, get_child(logger, i), level);
    end loop;
  end;

  impure function is_enabled(log_handler : log_handler_t;
                             logger : logger_t;
                             level : log_level_t) return boolean is
  begin
    return level >= get_log_level(log_handler, logger);
  end;

  procedure disable_all(log_handler : log_handler_t;
                        logger : logger_t) is

  begin
    set_log_level(log_handler, logger, all_levels);
  end;

  procedure enable_all(log_handler : log_handler_t;
                       logger : logger_t) is

  begin
    set_log_level(log_handler, logger, no_level);
  end;

  procedure log_to_handler(log_handler : log_handler_t;
                           logger : logger_t;
                           msg : string;
                           log_level : log_level_t;
                           log_time : time;
                           line_num : natural := 0;
                           file_name : string := "") is

    constant log_file_name : string := to_string(to_string_ptr(get(log_handler.p_data, file_name_idx)));
    variable l : line;

    procedure log_to_line is
      variable use_color : boolean := get(log_handler.p_data, use_color_idx) = 1;

      procedure write_time(justified : side := right; field : natural := 0) is
      begin
        if use_color then
          write(l, color_start(fg => lightcyan));
        end if;

        write(l, time'image(log_time), justified => justified, field => field);

        if use_color then
          write(l, color_end);
        end if;
      end procedure;

      procedure write_level(justified : side := right; field : natural := 0) is
      begin
        if use_color then
          case log_level is
            when verbose => write(l, color_start(fg => lightblack, style => dim));
            when debug => write(l, color_start(style => normal));
            when info => write(l, color_start(style => bright));
            when warning => write(l, color_start(fg => yellow));
            when error => write(l, color_start(fg => red, style => bright));
            when failure => write(l, color_start(fg => white, bg => red, style => bright));
          end case;
        end if;

        write(l, upper(log_level_t'image(log_level)), justified => justified, field => field);

        if use_color then
          write(l, color_end);
        end if;
      end;

      procedure write_source(justified : side := right; field : natural := 0) is
      begin
        if use_color then
          write(l, color_start(fg => white, style => bright));
        end if;

        write(l, get_full_name(logger), justified => justified, field => field);

        if use_color then
          write(l, color_end);
        end if;
      end;

      procedure write_location is
      begin
        if file_name /= "" then
          write(l, " (" & file_name & ":" & integer'image(line_num) & ")");
        end if;
      end;

      procedure write_message(multi_line_align : boolean := false) is
        variable prefix_len : natural;
        variable location_written : boolean := false;
      begin
        if not multi_line_align then
          write(l, msg);
        else
          prefix_len := length_without_color(l.all);
          for i in msg'range loop

            if msg(i) = LF and not location_written then
              location_written := true;
              write_location;
            end if;

            write(l, msg(i));

            if msg(i) = LF then
              write(l, string'(1 to prefix_len => ' '));
            end if;
          end loop;
        end if;

        if not location_written then
          write_location;
        end if;

      end procedure;

      constant format : log_format_t := log_format_t'val(get(log_handler.p_data, format_idx));
    begin
      case format is
        when raw =>
          write_message;

        when csv =>
          write_time;
          write(l, ',');
          write_source;
          write(l, ',');
          write_level;
          write(l, ',');
          write_message;

        when level =>
          write_level(field => max_level_length);
          write(l, string'(" - "));
          write_message(multi_line_align => true);

        when verbose =>
          write_time(field => max_time_length);
          write(l, string'(" - "));
          write_source(justified => left, field => get_max_logger_name_length(log_handler));
          write(l, string'(" - "));
          write_level(field => max_level_length);
          write(l, string'(" - "));
          write_message(multi_line_align => true);
      end case;
    end;

    procedure log_to_file is
      variable file_is_initialized : boolean := get(log_handler.p_data, file_is_initialized_idx) = 1;
      file fptr : text;
      variable status : file_open_status;
    begin
      if not file_is_initialized then
        file_open(status, fptr, log_file_name, write_mode);
        set(log_handler.p_data, file_is_initialized_idx, 1);
      else
        file_open(status, fptr, log_file_name, append_mode);
      end if;

      if status /= open_ok then
        report "Failed to open file " & log_file_name & " - " & file_open_status'image(status) severity failure;
      end if;

      writeline(fptr, l);

      file_close(fptr);
    end;

  begin
    if log_file_name = null_file_name then
      null;
    elsif log_file_name = stdout_file_name then
      log_to_line;
      writeline(OUTPUT, l);
    else
      log_to_line;
      log_to_file;
    end if;
  end;

end package body;
