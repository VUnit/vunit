-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2023, Lars Asplund lars.anders.asplund@gmail.com

use work.ansi_pkg.all;
use work.log_levels_pkg.all;
use work.string_ops.upper;

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

    alias file_name is str_1;

    alias format is val_1;
    alias line_num is val_2;
    alias sequence_number is val_3;
    alias use_color is val_4;
    alias get_max_logger_name_length is val_5;

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

      if use_color = 1 then
        write(l, color_start(fg => lightcyan));
      end if;

      write(l, time_string);

      if use_color = 1 then
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

      if use_color = 1 then
        color := get_color(log_level_t'value(log_level));
        write(l, color_start(fg => color.fg, bg => color.bg, style => color.style));
      end if;

      write(l, upper(level_name));

      if use_color = 1 then
        write(l, color_end);
      end if;
    end;

    procedure write_source(variable l : inout line; justify : boolean := false) is
    begin
      if use_color = 1 then
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

      if use_color = 1 then
        write(l, color_end);
      end if;

      if justify then
        pad(l, get_max_logger_name_length - log_source_name'length);
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

    variable l : line;
  begin
    if format = raw_format then
      write_message(l);

    elsif format = level_format then
      write_level(l, justify => true);
      write(l, string'(" - "));
      write_message(l, multi_line_align => true);

    elsif format = verbose_format then
      write_time(l, justify => true);
      write(l, string'(" - "));
      write_source(l, justify => true);
      write(l, string'(" - "));
      write_level(l, justify => true);
      write(l, string'(" - "));
      write_message(l, multi_line_align => true);

    elsif format = csv_format then
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

    else
      assert false report "Illegal format: " & integer'image(format) severity failure;
    end if;
    writeline(log_destination, l);
  end;

end package body;
