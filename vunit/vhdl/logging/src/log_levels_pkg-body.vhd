-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body log_levels_pkg is

  type levels_t is record
    names : integer_vector_ptr_t;
    colors : integer_vector_ptr_t;
    max_level_length : integer_vector_ptr_t;
  end record;

  procedure add_level(
    levels : levels_t;
    name : string;
    log_level : log_level_t;
    fg, bg : ansi_color_t := no_color;
    style : ansi_style_t := normal) is

    constant log_level_idx : natural := log_level_t'pos(log_level);
  begin
    if get(levels.max_level_length, 0) < name'length then
      set(levels.max_level_length, 0, name'length);
    end if;

    set(levels.names, log_level_idx, to_integer(new_string_ptr(name)));

    set(levels.colors, log_level_idx,
        to_integer(integer_vector_ptr_t'(new_integer_vector_ptr(3))));
    set(to_integer_vector_ptr(get(levels.colors, log_level_idx)), 0,
        ansi_color_t'pos(fg));
    set(to_integer_vector_ptr(get(levels.colors, log_level_idx)), 1,
        ansi_color_t'pos(bg));
    set(to_integer_vector_ptr(get(levels.colors, log_level_idx)), 2,
        ansi_style_t'pos(style));

  end;

  impure function create_levels return levels_t is
    variable result : levels_t;

    procedure add_level(log_level : log_level_t; fg, bg : ansi_color_t := no_color; style : ansi_style_t := normal) is
    begin
      add_level(result, log_level_t'image(log_level), log_level, fg, bg, style);
    end;
  begin
    result := (names => new_integer_vector_ptr(log_level_t'pos(log_level_t'high)+1,
                                 value => to_integer(null_string_ptr)),
               colors => new_integer_vector_ptr(log_level_t'pos(log_level_t'high)+1,
                                 value => to_integer(null_ptr)),
               max_level_length => new_integer_vector_ptr(1, value => 0));

    add_level(trace, fg => magenta, style => bright);
    add_level(debug, fg => cyan, style => bright);
    add_level(pass, fg => green, style => bright);
    add_level(info, fg => white, style => bright);
    add_level(warning, fg => yellow, style => bright);
    add_level(error, fg => red, style => bright);
    add_level(failure, fg => white, bg => red, style => bright);

    return result;
  end;

  constant levels : levels_t := create_levels;

  impure function new_log_level(name : string;
                                fg : ansi_color_t := no_color;
                                bg : ansi_color_t := no_color;
                                style : ansi_style_t := normal) return log_level_t is
    variable log_level : log_level_t := null_log_level;
  begin

    -- Take first free log level
    for level in legal_log_level_t'low to legal_log_level_t'high loop
      if not is_valid(level) then
        log_level := level;
        exit;
      end if;
    end loop;

    if log_level = null_log_level then
      core_failure("Cannot create custom log level " & name &
                   " already used all " & integer'image(max_num_custom_log_levels) &
                   " custom log levels");
      return null_log_level;
    end if;

    add_level(levels, name, log_level, fg, bg, style);

    return log_level;
  end;

  impure function is_valid(log_level : log_level_t) return boolean is
    variable name_ptr : string_ptr_t := to_string_ptr(get(levels.names, log_level_t'pos(log_level)));
  begin
    return name_ptr /= null_string_ptr;
  end;

  impure function get_color(log_level : log_level_t) return ansi_colors_t is
    variable color_ptr : integer_vector_ptr_t := to_integer_vector_ptr(get(levels.colors, log_level_t'pos(log_level)));
  begin
    if color_ptr = null_ptr then
      return no_colors;
    end if;
    return (fg => ansi_color_t'val(get(color_ptr, 0)),
            bg => ansi_color_t'val(get(color_ptr, 1)),
            style => ansi_style_t'val(get(color_ptr, 2)));
  end;

  impure function get_name(log_level : log_level_t) return string is
    variable name_ptr : string_ptr_t := to_string_ptr(get(levels.names, log_level_t'pos(log_level)));
  begin
    if name_ptr = null_string_ptr then
      core_failure("Use of undefined level " & log_level_t'image(log_level) & ".");
      return log_level_t'image(log_level);
    end if;
    return to_string(name_ptr);
  end;

  impure function max_level_length return natural is
  begin
    return get(levels.max_level_length, 0);
  end;
end package body;
