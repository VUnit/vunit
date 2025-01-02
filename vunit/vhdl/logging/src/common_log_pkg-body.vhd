-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.math_real.all;

use std.textio.all;

package body common_log_pkg is
  constant is_original_pkg : boolean := true;

  function get_resolution_limit_as_log10_of_sec return integer is
    constant t : string := time'image(time'high);
    constant signature : character := t(t'length - 1);
  begin
    case signature is
      when 'f' => return -15;
      when 'p' => return -12;
      when 'n' => return -9;
      when 'u' => return -6;
      when 'm' => return -3;
      when others =>
        report "Only resolution limits in the fs to ms range are supported. " &
        "Only native simulation time formatting is supported" severity warning;
        return -12;
    end case;
  end;

  constant p_resolution_limit_as_log10_of_sec : integer := get_resolution_limit_as_log10_of_sec;

  function p_to_string(
    value : time;
    unit : integer := p_native_unit;
    n_decimals : integer := 0
  ) return string is
    -- The typical simulator can handle time ranges wider than the integer range it can handle.
    -- For example, 9876543210 fs i a valid time but 9876543210 is not a valid integer.
    -- For that reason we cannot extract the integer part and then use normal arithmetic. Instead, the solution
    -- is based on manipulating the string representation. This has two implications:
    -- 1. When limiting the number of decimals, the value is truncated rather than rounded. However, when limiting
    --    the number of decimals, the exact value is of no interest.
    -- 2. Only units between fs and sec are supported. These are separated by powers of 10 and conversion
    -- can be perfomed by moving the radix point. However, this approach of division is exact which a floating point
    -- division may not be

    constant value_str : string := time'image(value);

    function unit_to_log10_of_sec(position_of_last_digit : positive) return integer is
    begin
      if unit = p_auto_unit then
        return ((position_of_last_digit - 1) / 3) * 3 + p_resolution_limit_as_log10_of_sec;
      elsif unit = p_native_unit then
        return p_resolution_limit_as_log10_of_sec;
      else
        return unit;
      end if;
    end;

    function max(a, b : integer) return integer is
    begin
      if a >= b then
        return a;
      end if;

      return b;
    end;

    function min(a, b : integer) return integer is
    begin
      if a <= b then
        return a;
      end if;

      return b;
    end;

    variable position_of_last_digit : positive;
    variable unit_as_log10_of_sec : integer;
    variable n_decimals_to_use : integer;
    variable n_decimals_for_full_resolution : integer;
    variable point_position : integer;
    variable result : line;
    variable position_of_last_decimal_to_use : integer;
    variable position_of_first_decimal_to_use : integer;
    variable n_added_decimals : natural;
    variable n_decimals_to_add : integer;
  begin
    -- Shortcut for limiting performance impact on default behavior
    if (unit = p_native_unit) and (n_decimals = 0) then
      return value_str;
    end if;

    -- We assume that time is presented with a unit in the fs to ms range (space + 2 characters)
    position_of_last_digit := value_str'length - 3;
    unit_as_log10_of_sec := unit_to_log10_of_sec(position_of_last_digit);

    -- Assuming that value_str is given in resolution_limit units
    n_decimals_for_full_resolution := unit_as_log10_of_sec - p_resolution_limit_as_log10_of_sec;

    -- digits before the point position are the integer part. The digits at the point position and after
    -- are the decimal part
    point_position := position_of_last_digit - n_decimals_for_full_resolution + 1;

    if n_decimals = p_full_resolution then
      n_decimals_to_use := n_decimals_for_full_resolution;
    else
      n_decimals_to_use := n_decimals;
    end if;

    -- Add integer part
    if point_position > 1 then
      write(result, value_str(1 to point_position - 1));
    else
      write(result, string'("0"));
    end if;

    -- Add decimal part
    if (n_decimals_to_use > 0) then
      write(result, string'("."));
      n_added_decimals := 0;

      -- Add leading zeros, for example 123 fs = 0.000123 ns
      if -point_position + 1 > 0 then
        n_added_decimals := min(n_decimals_to_use, -point_position + 1);
        write(result, string'((1 to n_added_decimals => '0')));
      end if;

      -- Add digits from the value input
      if n_added_decimals < n_decimals_to_use then
        position_of_first_decimal_to_use := max(point_position, 1);
  	    position_of_last_decimal_to_use := min(
  	      position_of_first_decimal_to_use + n_decimals_to_use - n_added_decimals - 1,
  	      position_of_last_digit
  	    );
        n_decimals_to_add := position_of_last_decimal_to_use - position_of_first_decimal_to_use + 1;
        if n_decimals_to_add > 0 then
          write(result, value_str(position_of_first_decimal_to_use to position_of_last_decimal_to_use));
          n_added_decimals := n_added_decimals + n_decimals_to_add;
        end if;
      end if;

      -- Add trailing zeros to get total number of decimals, for example 123 fs = 123.00 fs with 2 decimals
      if n_added_decimals < n_decimals_to_use then
        write(result, string'((1 to n_decimals_to_use - n_added_decimals => '0')));
      end if;
    end if;

    -- Add unit
    case unit_as_log10_of_sec is
      when -15 => write(result, string'(" fs"));
      when -12 => write(result, string'(" ps"));
      when -9 => write(result, string'(" ns"));
      when -6 => write(result, string'(" us"));
      when -3 => write(result, string'(" ms"));
      when 0 => write(result, string'(" sec"));
      when others =>
        report "Time unit not supported: " & integer'image(unit_as_log10_of_sec) severity failure;
    end case;

    return result.all;
  end;

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
    log_time_unit : integer;
    n_log_time_decimals : integer;
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
      constant time_string : string := p_to_string(log_time, log_time_unit, n_log_time_decimals);
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
