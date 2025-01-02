-- This package contains support functions for debug codec building
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

use work.string_ops.all;

package com_debug_codec_builder_pkg is
  -----------------------------------------------------------------------------
  -- Encoding support
  -----------------------------------------------------------------------------
  procedure open_group (
    variable l : inout line);
  procedure append_group (
    variable l       : inout line;
    constant element : in    string);
  procedure close_group (
    variable l      : inout line;
    variable code   : out   string;
    variable length : out   natural);
  function create_group (
    constant num_of_elements : natural range 0 to 10;
    constant element1        : string := "";
    constant element2        : string := "";
    constant element3        : string := "";
    constant element4        : string := "";
    constant element5        : string := "";
    constant element6        : string := "";
    constant element7        : string := "";
    constant element8        : string := "";
    constant element9        : string := "";
    constant element10       : string := "")
    return string;
  function create_array_group (
    constant arr           : string;
    constant range_left1   : string;
    constant range_right1  : string;
    constant is_ascending1 : boolean;
    constant range_left2   : string  := "";
    constant range_right2  : string  := "";
    constant is_ascending2 : boolean := true)
    return string;
  function escape_special_characters (
    constant data : string)
    return string;

  -----------------------------------------------------------------------------
  -- Decoding support
  -----------------------------------------------------------------------------
  procedure split_group (
    constant grp                 : in    string;
    variable elements            : inout lines_t;
    constant max_num_of_elements : in    natural;
    variable length              : inout natural);
  function get_element (
    constant grp      : in string;
    constant position : in natural)
    return string;
  function get_first_element (
    constant grp : string)
    return string;
  procedure deallocate_elements (
    variable elements : inout lines_t);
  function unescape_special_characters (
    constant code : string)
    return string;
end package com_debug_codec_builder_pkg;

package body com_debug_codec_builder_pkg is
  -----------------------------------------------------------------------------
  -- Encoding support
  -----------------------------------------------------------------------------
  procedure open_group (
    variable l : inout line) is
  begin
    deallocate(l);
    write(l, '(');
  end procedure open_group;

  procedure append_group (
    variable l       : inout line;
    constant element : in    string) is
  begin
    write(l, element & ",");
  end procedure append_group;

  procedure close_group (
    variable l      : inout line;
    variable code   : out   string;
    variable length : out   natural) is
    variable final : line;
    variable line_length : integer;
  begin
    if l.all /= "(" then
      line_length := l.all'length;
      write(final, l.all(1 to line_length - 1));
      deallocate(l);
    else
      final := l;
    end if;
    write(final, ')');
    length            := final.all'length;
    code(1 to length) := final.all;
    deallocate(final);
  end procedure close_group;

  function create_group (
    constant num_of_elements : natural range 0 to 10;
    constant element1        : string := "";
    constant element2        : string := "";
    constant element3        : string := "";
    constant element4        : string := "";
    constant element5        : string := "";
    constant element6        : string := "";
    constant element7        : string := "";
    constant element8        : string := "";
    constant element9        : string := "";
    constant element10       : string := "")
    return string is
  begin
    if num_of_elements = 4 then
      return "(" & element1 & "," & element2 & "," & element3 & "," & element4 & ")";
    elsif num_of_elements = 3 then
      return "(" & element1 & "," & element2 & "," & element3 & ")";
    elsif num_of_elements = 5 then
      return "(" & element1 & "," & element2 & "," & element3 & "," & element4 & "," & element5 & ")";
    elsif num_of_elements = 2 then
      return "(" & element1 & "," & element2 & ")";
    elsif num_of_elements = 7 then
      return "(" & element1 & "," & element2 & "," & element3 & "," & element4 & "," & element5 & "," & element6 & "," & element7 & ")";
    elsif num_of_elements = 1 then
      return "(" & element1 & ")";
    elsif num_of_elements = 6 then
      return "(" & element1 & "," & element2 & "," & element3 & "," & element4 & "," & element5 & "," & element6 & ")";
    elsif num_of_elements = 8 then
      return "(" & element1 & "," & element2 & "," & element3 & "," & element4 & "," & element5 & "," & element6 & "," & element7 & "," & element8 & ")";
    elsif num_of_elements = 9 then
      return "(" & element1 & "," & element2 & "," & element3 & "," & element4 & "," & element5 & "," & element6 & "," & element7 & "," & element8 & "," & element9 & ")";
    elsif num_of_elements = 10 then
      return "(" & element1 & "," & element2 & "," & element3 & "," & element4 & "," & element5 & "," & element6 & "," & element7 & "," & element8 & "," & element9 & "," & element10 & ")";
    else
      return "()";
    end if;
  end function create_group;

  function create_array_group (
    constant arr           : string;
    constant range_left1   : string;
    constant range_right1  : string;
    constant is_ascending1 : boolean;
    constant range_left2   : string  := "";
    constant range_right2  : string  := "";
    constant is_ascending2 : boolean := true)
    return string is
    variable ret_val : string(1 to 18 + arr'length + range_left1'length + range_right1'length +
                              range_left2'length + range_right2'length);
    variable l      : line;
    variable length : natural;
  begin
    open_group(l);
    append_group(l, arr);
    append_group(l, range_left1);
    append_group(l, range_right1);
    append_group(l, to_string(is_ascending1));
    if range_left2 /= "" then
      append_group(l, range_left2);
      append_group(l, range_right2);
      append_group(l, to_string(is_ascending2));
    end if;
    close_group(l, ret_val, length);

    return ret_val(1 to length);
  end;

  function escape_special_characters (
    constant data : string)
    return string is
  begin
    return replace(replace(replace(data, ')', "\rp"), '(', "\lp"), ',', "\comma");
  end function escape_special_characters;

  -----------------------------------------------------------------------------
  -- Decoding support
  -----------------------------------------------------------------------------
  procedure split_group (
    constant grp                 : in    string;
    variable elements            : inout lines_t;
    constant max_num_of_elements : in    natural;
    variable length              : inout natural) is
    variable element_start       : positive;
    variable level               : natural   := 0;
  begin
    deallocate_elements(elements);
    length := 0;

    if (grp = "()") or                  -- Empty group
       (grp(grp'left) /= '(') or        -- Not a valid group
       (grp(grp'right) /= ')') then     -- Not a valid group
      return;
    end if;

    elements      := new work.string_ops.line_vector(0 to max_num_of_elements - 1);
    element_start := grp'left + 1;
    for i in grp'left + 1 to grp'right loop
      if length = max_num_of_elements then
        return;
      elsif grp(i) = '(' then
        level := level + 1;
      elsif ((grp(i) = ',') or (i = grp'right)) and (level = 0) then
        if grp(i) = ',' then
          write(elements.all(length), grp(element_start to i - 1));
        else
          write(elements.all(length), grp(element_start to i - 1));
        end if;

        length        := length + 1;
        element_start := i + 1;
      elsif grp(i) = ')' then
        level := level - 1;
      end if;
    end loop;

    if level /= 0 then  -- Not a valid group
      deallocate_elements(elements);
      length := 0;
    end if;

  end procedure split_group;

  function get_element (
    constant grp      : in string;
    constant position : in natural)
    return string is
    variable elements : lines_t;
    variable length   : natural;
    variable ret_val  : string(1 to grp'length);
  begin
    if grp = "" then
      return "";
    end if;

    if grp(grp'left) /= '(' then
      if position = 0 then
        return grp;
      else
        return "";
      end if;
    end if;

    split_group(grp, elements, position + 1, length);
    if length < position + 1 then
      return "";
    else
      length               := elements.all(position).all'length;
      ret_val(1 to length) := elements.all(position).all;
      deallocate_elements(elements);
      return ret_val(1 to length);
    end if;
  end function get_element;

  function get_first_element (
    constant grp : string)
    return string is
  begin
    return get_element(grp, 0);
  end function get_first_element;

  procedure deallocate_elements (
    variable elements : inout lines_t) is
  begin
    if elements = null then
      return;
    end if;

    for i in elements.all'range loop
      deallocate(elements.all(i));
    end loop;
    deallocate(elements);
  end procedure deallocate_elements;

  function unescape_special_characters (
    constant code : string)
    return string is
  begin
    return replace(replace(replace(code, "\rp", ')'), "\lp", '('), "\comma", ',');
  end function unescape_special_characters;

end package body com_debug_codec_builder_pkg;
