-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

package body common_log_pkg is
  constant is_original_pkg : boolean := true;

  procedure write_to_log(
    file log_destination : text;
    log_destination_path : string := no_string;
    msg : string := no_string;
    log_time : time := no_time;
    log_level : string := no_string;
    log_source_name : string := no_string;
    log_source_path : string;
    log_format : natural range 0 to 3;
    log_source_line_number : natural;
    log_sequence_number : natural;
    use_color : boolean;
    max_logger_name_length : natural
  ) is

    constant max_time_str : string := time'image(1 sec);
    constant max_time_length : natural := max_time_str'length;

    constant raw_format : integer := 0;
    constant level_format : integer := 1;
    constant verbose_format : integer := 2;
    constant csv_format : integer := 3;

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
      constant level_name : string := get_name(log_level_t'value(log_level));
      variable color : ansi_colors_t;
    begin
      if justify then
        pad(l, max_level_length - level_name'length);
      end if;

      if use_color then
        color := get_color(log_level_t'value(log_level));
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

        for i in log_source_name 'range loop
          if log_source_name(i) = ':' then
            write(l, color_start(fg => lightcyan, style => bright));
            write(l, log_source_name(i));
            write(l, color_start(fg => white, style => bright));
          else
            write(l, log_source_name(i));
          end if;
        end loop;
      else
        write(l, log_source_name);
      end if;

      if use_color then
        write(l, color_end);
      end if;

      if justify then
        pad(l, max_logger_name_length - log_source_name'length);
      end if;

    end;

    procedure write_location(variable l : inout line) is
    begin
      if log_source_path /= "" then
        write(l, " (" & log_source_path & ":" & integer'image(log_source_line_number) & ")");
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

    variable l : line;
  begin
    if log_format = raw_format then
      write_message(l);

    elsif log_format = level_format then
      write_level(l, justify => true);
      write(l, string'(" - "));
      write_message(l, multi_line_align => true);

    elsif log_format = verbose_format then
      write_time(l, justify => true);
      write(l, string'(" - "));
      write_source(l, justify => true);
      write(l, string'(" - "));
      write_level(l, justify => true);
      write(l, string'(" - "));
      write_message(l, multi_line_align => true);

    elsif log_format = csv_format then
      write(l, string'(integer'image(log_sequence_number) & ','));
      write_time(l);
      write(l, ',');
      write_level(l);
      write(l, ',');

      if log_source_line_number = 0 then
        write(l, string'(",,"));
      else
        write(l, log_source_path);
        write(l, ',');
        write(l, integer'image(log_source_line_number));
        write(l, ',');
      end if;

      write_source(l);
      write(l, ',');
      write(l, msg);

    else
      assert false report "Illegal format: " & integer'image(log_format) severity failure;
    end if;
    writeline(log_destination, l);
  end;

end package body;
