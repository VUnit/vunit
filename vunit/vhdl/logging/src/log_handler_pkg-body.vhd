-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body log_handler_pkg is
  -- Questa will issue warnings if the code contains time units lower than
  -- the resolution even if that code isn't executed. To avoid that is most
  -- cases a number of replacement constants are defined as fractions of us.
  constant femtosecond : time := us / 1000000000;
  constant picosecond : time := us / 1000000;
  constant nanosecond : time := us / 1000;

  function resolution_limit return delay_length is
    constant t : string := time'image(time'high);
    constant signature : character := t(t'length - 1);
  begin
    case signature is
      when 'f' => return femtosecond;
      when 'p' => return picosecond;
      when 'n' => return nanosecond;
      when 'u' => return us;
      when 'm' => return ms;
      when others =>
        report "Only resolution limits in the fs to ms range are supported. " &
        "Only native simulation time formatting is supported" severity warning;
        return picosecond;
    end case;
  end;

  constant display_handler_id_number : natural := 0;
  constant next_log_handler_id_number : integer_vector_ptr_t := new_integer_vector_ptr(1, value => display_handler_id_number+1);
  constant native_time_unit : time := 0 * time'low;
  constant auto_time_unit : time := -resolution_limit;
  constant full_time_resolution : integer := p_full_resolution;

  constant id_number_idx : natural := 0;
  constant file_name_idx : natural := 1;
  constant format_idx : natural := 2;
  constant use_color_idx : natural := 3;
  constant log_time_unit_idx : natural := 4;
  constant n_log_time_decimals_idx : natural := 5;
  constant file_id_idx : natural := 6;
  constant max_logger_name_idx : natural := 7;
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
                                  use_color : boolean;
                                  log_time_unit : time;
                                  n_log_time_decimals : integer
                                ) return log_handler_t is
    constant log_handler : log_handler_t := (p_data => new_integer_vector_ptr(log_handler_length));
  begin
    set(log_handler.p_data, id_number_idx, id_number);
    set(log_handler.p_data, file_name_idx, to_integer(new_string_ptr(file_name)));
    set(log_handler.p_data, file_id_idx, to_integer(null_file_id));
    init_log_file(log_handler, file_name);
    set(log_handler.p_data, max_logger_name_idx, 0);
    set_format(log_handler, format, use_color, log_time_unit, n_log_time_decimals);
    return log_handler;
  end;

  impure function new_log_handler(file_name : string;
                                  format : log_format_t := verbose;
                                  use_color : boolean := false;
                                  log_time_unit : time := native_time_unit;
                                  n_log_time_decimals : integer :=  0) return log_handler_t is
    constant id_number : natural := get(next_log_handler_id_number, 0);
  begin
    set(next_log_handler_id_number, 0, id_number + 1);
    return new_log_handler(id_number, file_name, format, use_color, log_time_unit, n_log_time_decimals);
  end;

  -- Display handler; Write to stdout
  constant p_display_handler : log_handler_t := new_log_handler(display_handler_id_number,
                                                                stdout_file_name,
                                                                format => verbose,
                                                                use_color => true,
                                                                log_time_unit => native_time_unit,
                                                                n_log_time_decimals => 0
                                                              );

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
                             use_color : boolean := false;
                             log_time_unit : time := native_time_unit;
                             n_log_time_decimals : integer :=  0) is
    variable file_name_ptr : string_ptr_t := to_string_ptr(get(log_handler.p_data, file_name_idx));
  begin
    assert log_handler /= null_log_handler;
    reallocate(file_name_ptr, file_name);
    init_log_file(log_handler, file_name);
    set_format(log_handler, format, use_color, log_time_unit, n_log_time_decimals);
  end;

  procedure set_format(log_handler : log_handler_t;
                       format : log_format_t := verbose;
                       use_color : boolean := false;
                       log_time_unit : time := native_time_unit;
                       n_log_time_decimals : integer :=  0) is
  begin
    set(log_handler.p_data, format_idx, log_format_t'pos(format));
    if use_color then
      set(log_handler.p_data, use_color_idx, 1);
    else
      set(log_handler.p_data, use_color_idx, 0);
    end if;
    if log_time_unit = native_time_unit then
      set(log_handler.p_data, log_time_unit_idx, p_native_unit);
    elsif log_time_unit = auto_time_unit then
      set(log_handler.p_data, log_time_unit_idx, p_auto_unit);
    elsif log_time_unit = sec then
      set(log_handler.p_data, log_time_unit_idx, 0);
    elsif log_time_unit = ms then
      set(log_handler.p_data, log_time_unit_idx, -3);
    elsif log_time_unit = us then
      set(log_handler.p_data, log_time_unit_idx, -6);
    elsif log_time_unit = nanosecond then
      set(log_handler.p_data, log_time_unit_idx, -9);
    elsif log_time_unit = picosecond then
      set(log_handler.p_data, log_time_unit_idx, -12);
    elsif log_time_unit = femtosecond then
      set(log_handler.p_data, log_time_unit_idx, -15);
    else
      report "Illegal log_time_unit: " & time'image(log_time_unit) severity failure;
    end if;
    set(log_handler.p_data, n_log_time_decimals_idx, n_log_time_decimals);
  end;

  procedure get_format(constant log_handler : in log_handler_t;
                       variable format : out log_format_t;
                       variable use_color : out boolean;
                       variable log_time_unit : out time;
                       variable n_log_time_decimals : out integer) is
  begin
    format := log_format_t'val(get(log_handler.p_data, format_idx));
    use_color := get(log_handler.p_data, use_color_idx) =  1;
    case get(log_handler.p_data, log_time_unit_idx) is
      when p_native_unit => log_time_unit := native_time_unit;
      when p_auto_unit => log_time_unit := auto_time_unit;
      when 0 => log_time_unit := sec;
      when -3 => log_time_unit := ms;
      when -6 => log_time_unit := us;
      when -9 => log_time_unit := nanosecond;
      when -12 => log_time_unit := picosecond;
      when -15 => log_time_unit := femtosecond;
      when others =>
        report "Illegal internal log_time_unit representation: " &
        integer'image(get(log_handler.p_data, log_time_unit_idx)) severity failure;
    end case;
    n_log_time_decimals := get(log_handler.p_data, n_log_time_decimals_idx);
  end;

  procedure get_format(constant log_handler : in log_handler_t;
                       variable format : out log_format_t;
                       variable use_color : out boolean) is
    variable not_used_log_time_unit : time;
    variable not_used_n_log_time_decimals : integer;
  begin
    get_format(log_handler, format, use_color, not_used_log_time_unit, not_used_n_log_time_decimals);
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
        log_time_unit => get(log_handler.p_data, log_time_unit_idx),
        n_log_time_decimals => get(log_handler.p_data, n_log_time_decimals_idx),
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
        log_time_unit => get(log_handler.p_data, log_time_unit_idx),
        n_log_time_decimals => get(log_handler.p_data, n_log_time_decimals_idx),
        max_logger_name_length => get_max_logger_name_length(log_handler));
    end if;
  end;

end package body;
