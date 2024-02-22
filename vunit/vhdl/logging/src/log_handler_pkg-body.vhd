-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

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

    constant log_file_name : string := get_file_name(log_handler);

  begin
    if log_file_name = null_file_name then
      null;
    elsif log_file_name = stdout_file_name then
      write_to_log(
        log_destination => OUTPUT,
        log_destination_path => "",
        msg => msg,
        log_time => log_time,
        log_level => log_level_t'image(log_level),
        log_source_name => logger_name,
        log_source_path => file_name,
        log_format => get(log_handler.p_data, format_idx),
        log_source_line_number => line_num,
        log_sequence_number => sequence_number,
        use_color => get(log_handler.p_data, use_color_idx) = 1,
        max_logger_name_length => get_max_logger_name_length(log_handler));
    else
      write_to_log(
        file_id => to_file_id(get(log_handler.p_data, file_id_idx)),
        msg => msg,
        log_time => log_time,
        log_level => log_level_t'image(log_level),
        log_source_name => logger_name,
        log_source_path => file_name,
        log_format => get(log_handler.p_data, format_idx),
        log_source_line_number => line_num,
        log_sequence_number => sequence_number,
        use_color => get(log_handler.p_data, use_color_idx) = 1,
        max_logger_name_length => get_max_logger_name_length(log_handler));
    end if;
  end;

end package body;
