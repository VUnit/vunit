-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

library vunit_lib;
use vunit_lib.string_ptr_pkg.all;
use vunit_lib.integer_vector_ptr_pkg.all;

use work.ansi_pkg.all;
use work.string_ops.upper;
use work.file_pkg.all;

package body log_handler_pkg is

  constant display_handler_id_number : natural := 0;
  constant next_log_handler_id_number : integer_vector_ptr_t := new_integer_vector_ptr(1, value => display_handler_id_number+1);

  constant id_number_idx : natural := 0;
  constant file_name_idx : natural := 1;
  constant format_idx : natural := 2;
  constant use_color_idx : natural := 3;
  constant file_id_idx : natural := 4;
  constant max_logger_name_idx : natural := 5;
  constant log_handler_length : natural := max_logger_name_idx + 1;

  constant max_time_str : string := time'image(1 sec);
  constant max_time_length : natural := max_time_str'length;

  procedure assert_status(status : file_open_status; file_name : string) is
  begin
    assert status = open_ok
      report "Failed to open file " & file_name & " - " & file_open_status'image(status) severity failure;
  end procedure;

  procedure init_log_file(log_handler : log_handler_t; file_name : string) is
    variable file_id : file_id_t := to_file_id(get(log_handler.p_data, file_id_idx));
  begin
    if (file_name /= null_file_name) and (file_name /= stdout_file_name) then
      file_open_for_write(file_id, file_name);
    end if;
    set(log_handler.p_data, file_id_idx, to_integer(file_id));
  end procedure;

  impure function new_log_handler(id_number : natural;
                                  file_name : string;
                                  format : log_format_t;
                                  use_color : boolean) return log_handler_t is
    constant log_handler : log_handler_t := (p_data => new_integer_vector_ptr(log_handler_length));
  begin
    set(log_handler.p_data, id_number_idx, id_number);
    set(log_handler.p_data, file_name_idx, to_integer(new_string_ptr(file_name)));
    set(log_handler.p_data, file_id_idx, to_integer(null_file_id));
    init_log_file(log_handler, file_name);
    set(log_handler.p_data, max_logger_name_idx, 0);
    set_format(log_handler, format, use_color);
    return log_handler;
  end;

  impure function new_log_handler(file_name : string;
                                  format : log_format_t := verbose;
                                  use_color : boolean := false) return log_handler_t is
    constant id_number : natural := get(next_log_handler_id_number, 0);
  begin
    set(next_log_handler_id_number, 0, id_number + 1);
    return new_log_handler(id_number, file_name, format, use_color);
  end;

  -- Display handler; Write to stdout
  constant p_display_handler : log_handler_t := new_log_handler(display_handler_id_number,
                                                                stdout_file_name,
                                                                format => verbose,
                                                                use_color => true);

  impure function display_handler return log_handler_t is
  begin
    return p_display_handler;
  end function;

  impure function get_id_number(log_handler : log_handler_t) return natural is
  begin
    return get(log_handler.p_data, id_number_idx);
  end;

  impure function get_file_name (log_handler : log_handler_t) return string is
  begin
    return to_string(to_string_ptr(get(log_handler.p_data, file_name_idx)));
  end;

  procedure init_log_handler(log_handler : log_handler_t;
                             format : log_format_t;
                             file_name : string;
                             use_color : boolean := false) is
    variable file_name_ptr : string_ptr_t := to_string_ptr(get(log_handler.p_data, file_name_idx));
  begin
    assert log_handler /= null_log_handler;
    reallocate(file_name_ptr, file_name);
    init_log_file(log_handler, file_name);
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

  procedure get_format(constant log_handler : in log_handler_t;
                       variable format : out log_format_t;
                       variable use_color : out boolean) is
  begin
    format := log_format_t'val(get(log_handler.p_data, format_idx));
    use_color := get(log_handler.p_data, use_color_idx) =  1;
  end;

  procedure set_max_logger_name_length(log_handler : log_handler_t; value : natural) is
  begin
    set(log_handler.p_data, max_logger_name_idx, value);
  end;


  impure function get_max_logger_name_length(log_handler : log_handler_t) return natural is
  begin
    return get(log_handler.p_data, max_logger_name_idx);
  end;

  procedure update_max_logger_name_length(log_handler : log_handler_t; value : natural) is
  begin
    if get_max_logger_name_length(log_handler) < value then
      set_max_logger_name_length(log_handler, value);
    end if;
  end;

  procedure log_to_handler(log_handler : log_handler_t;
                           logger_name : string;
                           msg : string;
                           log_level : log_level_t;
                           log_time : time;
                           sequence_number : natural;
                           line_num : natural := 0;
                           file_name : string := "") is

    variable l : line;
    constant log_file_name : string := get_file_name(log_handler);

    procedure log_to_line(variable l : inout line) is
      variable use_color : boolean := get(log_handler.p_data, use_color_idx) = 1;

      procedure pad(variable l : inout line; len : integer) is
      begin
        if len > 0 then
          write(l, string'(1 to len => ' '));
        end if;
      end;

      procedure write_time(variable l : inout line; justify : boolean := false) is
        constant time_string : string := time'image(log_time);
      begin
        if justify then
          pad(l, max_time_length - time_string'length);
        end if;

        if use_color then
          write(l, color_start(fg => lightcyan));
        end if;

        write(l, time_string);

        if use_color then
          write(l, color_end);
        end if;
      end procedure;

      procedure write_level(variable l : inout line; justify : boolean := false) is
        constant level_name : string := get_name(log_level);
        variable color : ansi_colors_t;
      begin
        if justify then
          pad(l, max_level_length - level_name'length);
        end if;

        if use_color then
          color := get_color(log_level);
          write(l, color_start(fg => color.fg, bg => color.bg, style => color.style));
        end if;

        write(l, upper(level_name));

        if use_color then
          write(l, color_end);
        end if;
      end;

      procedure write_source(variable l : inout line; justify : boolean := false) is
      begin
        if use_color then
          write(l, color_start(fg => white, style => bright));

          for i in logger_name 'range loop
            if logger_name(i) = ':' then
              write(l, color_start(fg => lightcyan, style => bright));
              write(l, logger_name(i));
              write(l, color_start(fg => white, style => bright));
            else
              write(l, logger_name(i));
            end if;
          end loop;
        else
          write(l, logger_name);
        end if;

        if use_color then
          write(l, color_end);
        end if;

        if justify then
          pad(l, get_max_logger_name_length(log_handler) - logger_name'length);
        end if;

      end;

      procedure write_location(variable l : inout line) is
      begin
        if file_name /= "" then
          write(l, " (" & file_name & ":" & integer'image(line_num) & ")");
        end if;
      end;

      procedure write_message(variable l : inout line; multi_line_align : boolean := false) is
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
              write_location(l);
            end if;

            write(l, msg(i));

            if msg(i) = LF then
              write(l, string'(1 to prefix_len => ' '));
            end if;
          end loop;
        end if;

        if not location_written then
          write_location(l);
        end if;

      end procedure;

      constant format : log_format_t := log_format_t'val(get(log_handler.p_data, format_idx));
    begin
      case format is
        when raw =>
          write_message(l);

        when csv =>
          write(l, string'(integer'image(sequence_number) & ','));
          write_time(l);
          write(l, ',');
          write_level(l);
          write(l, ',');

          if line_num = 0 then
            write(l, string'(",,"));
          else
            write(l, file_name);
            write(l, ',');
            write(l, integer'image(line_num));
            write(l, ',');
          end if;

          write_source(l);
          write(l, ',');
          write(l, msg);

        when level =>
          write_level(l, justify => true);
          write(l, string'(" - "));
          write_message(l, multi_line_align => true);

        when verbose =>
          write_time(l, justify => true);
          write(l, string'(" - "));
          write_source(l, justify => true);
          write(l, string'(" - "));
          write_level(l, justify => true);
          write(l, string'(" - "));
          write_message(l, multi_line_align => true);
      end case;
    end;

    procedure log_to_file(variable l : inout line) is
      file fptr : text;
      variable status : file_open_status;
    begin
      file_open(status, fptr, log_file_name, append_mode);
      assert_status(status, log_file_name);
      writeline(fptr, l);
      file_close(fptr);
    end;

  begin
    if log_file_name = null_file_name then
      null;
    elsif log_file_name = stdout_file_name then
      log_to_line(l);
      writeline(OUTPUT, l);
    else
      log_to_line(l);
      writeline(to_file_id(get(log_handler.p_data, file_id_idx)), l);
    end if;
  end;

end package body;
