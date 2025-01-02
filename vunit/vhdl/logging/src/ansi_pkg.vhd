-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;
use work.string_ptr_pkg.all;

package ansi_pkg is

  type ansi_color_t is (
    no_color,

    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,

    -- Non standard foregrounds
    lightblack,
    lightred,
    lightgreen,
    lightyellow,
    lightblue,
    lightmagenta,
    lightcyan,
    lightwhite
    );

  type ansi_style_t is (
    dim,
    normal,
    bright
    );

  type ansi_colors_t is record
    fg : ansi_color_t;
    bg : ansi_color_t;
    style : ansi_style_t;
  end record;
  constant no_colors : ansi_colors_t := (fg => no_color, bg => no_color, style => normal);

  impure function colorize(msg : string;
                           colors : ansi_colors_t := no_colors) return string;

  impure function colorize(msg : string;
                           fg : ansi_color_t := no_color;
                           bg : ansi_color_t := no_color;
                           style : ansi_style_t := normal) return string;

  impure function strip_color(msg : string) return string;
  impure function length_without_color(msg : string) return natural;

  impure function color_start(fg : ansi_color_t := no_color;
                              bg : ansi_color_t := no_color;
                              style : ansi_style_t := normal) return string;

  impure function color_start(colors : ansi_colors_t := no_colors) return string;

  impure function color_end return string;

  procedure disable_colors;
  procedure enable_colors;

  procedure ansi_color_demo;
end package;

package body ansi_pkg is
  constant colors_enabled : string_ptr_t := new_string_ptr("0");

  impure function colors_are_enabled return boolean is
  begin
    return get(colors_enabled, 1) = '1';
  end;

  type color_to_code_t is array (ansi_color_t range <>) of integer;
  type style_to_code_t is array (ansi_style_t range <>) of integer;

  constant color_to_code : color_to_code_t := (
    no_color => 39,
    black => 30,
    red => 31,
    green => 32,
    yellow => 33,
    blue => 34,
    magenta => 35,
    cyan => 36,
    white => 37,

    -- Non standard foregrounds
    lightblack => 90,
    lightred => 91,
    lightgreen => 92,
    lightyellow => 93,
    lightblue => 94,
    lightmagenta => 95,
    lightcyan => 96,
    lightwhite => 97);

  constant style_to_code : style_to_code_t := (
    bright => 1,
    dim => 2,
    normal => 22);

  impure function colorize(msg : string;
                    colors : ansi_colors_t := no_colors) return string is
  begin
    return colorize(msg, fg => colors.fg, bg => colors.bg, style => colors.style);
  end;

  impure function length_without_color(msg : string) return natural is
    variable idx : natural := msg'low;
    variable len : natural := 0;
  begin
    while idx <= msg'high loop
      if msg(idx) = character'val(27) then
        idx := idx + 1;

        while idx <= msg'high and msg(idx) /= 'm' loop
          idx := idx + 1;
        end loop;

        idx := idx + 1;
      else
        idx := idx + 1;
        len := len + 1;
      end if;
    end loop;

    return len;
  end;

  impure function drop_color(msg : string) return string is
  begin
    for i in msg'low to msg'high loop
      if msg(i) = 'm' then
        return strip_color(msg(i+1 to msg'high));
      end if;
    end loop;

    assert false report "incomplete color escape did not end with 'm'";
    return msg;
  end;

  impure function strip_color(msg : string) return string is
  begin
    for i in msg'low to msg'high loop
      if msg(i) = character'val(27) then
        return msg(msg'low to i-1) & drop_color(msg(i+1 to msg'high));
      end if;
    end loop;

    return msg;
  end;

  impure function colorize(msg : string;
                    fg : ansi_color_t := no_color;
                    bg : ansi_color_t := no_color;
                    style : ansi_style_t := normal) return string is
  begin
    if fg = no_color and bg = no_color and style = normal then
      return msg;
    else
      return color_start(fg, bg, style) & msg & color_end;
    end if;
  end;

  impure function color_start(colors : ansi_colors_t := no_colors) return string is
  begin
    return color_start(fg => colors.fg, bg => colors.bg, style => colors.style);
  end;

  impure function color_start(fg : ansi_color_t := no_color;
                              bg : ansi_color_t := no_color;
                              style : ansi_style_t := normal) return string is
  begin
    if colors_are_enabled then
      return (character'val(27) & '[' &
              integer'image(style_to_code(style)) & ';' &
              integer'image(color_to_code(fg)) & ';' &
              integer'image(color_to_code(bg)+10) & 'm');
    else
      return "";
    end if;
  end;

  impure function color_end return string is
  begin
    if colors_are_enabled then
      return character'val(27) & '[' & integer'image(0) & 'm';
    else
      return "";
    end if;
  end function;

  procedure ansi_color_demo is
    variable l : line;
  begin
    for bg in ansi_color_t'low to ansi_color_t'high loop
      write(l, colorize("bg=" & ansi_color_t'image(bg), bg => bg));
      writeline(output, l);
    end loop;

    for style in ansi_style_t'low to ansi_style_t'high loop
      for fg in ansi_color_t'low to ansi_color_t'high loop
        write(l, colorize(
          "fg=" & ansi_color_t'image(fg) & ", " &
          "style=" & ansi_style_t'image(style),
          fg => fg, style => style));
        writeline(output, l);
      end loop;
    end loop;

  end procedure;

  procedure disable_colors is
  begin
    set(colors_enabled, 1, '0');
  end;

  procedure enable_colors is
  begin
    set(colors_enabled, 1, '1');
  end;

end package body;
