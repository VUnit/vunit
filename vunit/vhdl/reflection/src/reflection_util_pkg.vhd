-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
--
-- Internal helpers shared by the packages built on VHDL-2019 reflection.

library ieee;
use ieee.std_logic_1164.all;

use std.reflection.all;
use std.textio.all;

use work.string_ops.lower;
use work.string_ops.upper;

package reflection_util_pkg is
  -- Simulators differ in the case of simple_name. Riviera-PRO rejects chained mirror calls, so these
  -- helpers go through a variable.
  impure function get_type_name(variable value : inout value_mirror) return string;
  impure function get_pos(variable value : inout value_mirror) return integer;

  -- Element offset positions from the left
  impure function get_element(variable value : inout array_value_mirror; offset : natural) return value_mirror;

  -- The elements of an array of std_ulogic or character, from the left, ranged 0 to 'length - 1 and
  -- 1 to 'length
  impure function to_std_ulogic_vector(variable value : inout array_value_mirror) return std_ulogic_vector;
  impure function to_string(variable value : inout array_value_mirror) return string;

  -- Appends a row "  <path>: got <x>, expected <y>", starting with LF, to diff for every leaf where got
  -- and expected differ. Record elements add ".<name>" to the path and array elements "(<index>)".
  procedure p_diff(
    variable got      : inout value_mirror;
    variable expected : inout value_mirror;
    constant path     : in string;
    variable diff     : inout line);
end package;

package body reflection_util_pkg is
  impure function get_type_name(variable value : inout value_mirror) return string is
    variable subtype_mirror : subtype_mirror := value.get_subtype_mirror;
  begin
    return upper(subtype_mirror.simple_name);
  end;

  impure function get_pos(variable value : inout value_mirror) return integer is
    variable enumeration : enumeration_value_mirror := value.to_enumeration;
  begin
    return enumeration.pos;
  end;

  -- NVC indexes from 'left upwards whatever the direction
  impure function get_element(variable value : inout array_value_mirror; offset : natural) return value_mirror is
    variable subtype_mirror : array_subtype_mirror := value.get_subtype_mirror;
  begin
`if TOOL_NAME = "nvc" then
    return value.get(subtype_mirror.left + index(offset));
`else
    if subtype_mirror.ascending then
      return value.get(subtype_mirror.left + index(offset));
    end if;
    return value.get(subtype_mirror.left - index(offset));
`end if
  end;

  impure function to_std_ulogic_vector(variable value : inout array_value_mirror) return std_ulogic_vector is
    variable subtype_mirror : array_subtype_mirror := value.get_subtype_mirror;
    variable element : value_mirror;
    variable result : std_ulogic_vector(0 to integer(subtype_mirror.length) - 1);
  begin
    for idx in result'range loop
      element := get_element(value, idx);
      result(idx) := std_ulogic'val(get_pos(element));
    end loop;
    return result;
  end;

  impure function to_string(variable value : inout array_value_mirror) return string is
    variable subtype_mirror : array_subtype_mirror := value.get_subtype_mirror;
    variable element : value_mirror;
    variable result : string(1 to integer(subtype_mirror.length));
  begin
    for idx in result'range loop
      element := get_element(value, idx - 1);
      result(idx) := character'val(get_pos(element));
    end loop;
    return result;
  end;

  -- The declared index of the element at offset
  impure function get_index(variable value : inout array_value_mirror; offset : natural) return index is
    variable subtype_mirror : array_subtype_mirror := value.get_subtype_mirror;
  begin
    if subtype_mirror.ascending then
      return subtype_mirror.left + index(offset);
    end if;
    return subtype_mirror.left - index(offset);
  end;

  procedure add(variable diff : inout line; path, text : string) is
  begin
    write(diff, LF & "  ");
    if path /= "" then
      write(diff, path & ": ");
    end if;
    write(diff, text);
  end;

  impure function get_image(variable value : inout value_mirror) return string is
    constant type_name : string := get_type_name(value);
    variable integer_value : integer_value_mirror;
    variable floating_value : floating_value_mirror;
    variable physical_value : physical_value_mirror;
    variable enumeration : enumeration_value_mirror;
  begin
    case value.get_value_class is
      when class_integer =>
        integer_value := value.to_integer;
        return integer_value.image;
      when class_floating =>
        floating_value := value.to_floating;
        return floating_value.image;
      when class_physical =>
        physical_value := value.to_physical;
        if type_name = "TIME" then
          -- The value is in units of the resolution limit on Riviera-PRO, fs on NVC
          return time'image(physical_value.value * std.env.resolution_limit);
        end if;
        return physical_value.image;
      when others =>
        enumeration := value.to_enumeration;
        return lower(enumeration.image);
    end case;
  end;

  procedure p_diff(
    variable got      : inout value_mirror;
    variable expected : inout value_mirror;
    constant path     : in string;
    variable diff     : inout line) is
    variable got_record, expected_record : record_value_mirror;
    variable record_subtype : record_subtype_mirror;
    variable got_array, expected_array : array_value_mirror;
    variable got_array_subtype, expected_array_subtype : array_subtype_mirror;
    variable got_element, expected_element : value_mirror;
  begin
    case got.get_value_class is
      when class_integer | class_floating | class_physical | class_enumeration =>
        if get_image(got) /= get_image(expected) then
          add(diff, path, "got " & get_image(got) & ", expected " & get_image(expected));
        end if;

      when class_record =>
        got_record := got.to_record;
        expected_record := expected.to_record;
        record_subtype := got_record.get_subtype_mirror;
        for idx in 0 to record_subtype.length - 1 loop
          got_element := got_record.get(idx);
          expected_element := expected_record.get(idx);
          if path = "" then
            p_diff(got_element, expected_element, lower(record_subtype.element_name(idx)), diff);
          else
            p_diff(got_element, expected_element, path & "." & lower(record_subtype.element_name(idx)), diff);
          end if;
        end loop;

      when class_array =>
        got_array := got.to_array;
        expected_array := expected.to_array;
        got_array_subtype := got_array.get_subtype_mirror;
        expected_array_subtype := expected_array.get_subtype_mirror;
        if got_array_subtype.dimensions /= 1 then
          add(diff, path, "values differ");
        elsif got_array_subtype.length /= expected_array_subtype.length then
          add(diff, path & "'length",
              "got " & index'image(got_array_subtype.length) & ", expected " &
              index'image(expected_array_subtype.length));
        else
          for offset in 0 to integer(got_array_subtype.length) - 1 loop
            got_element := get_element(got_array, offset);
            expected_element := get_element(expected_array, offset);
            p_diff(got_element, expected_element, path & "(" & index'image(get_index(got_array, offset)) & ")",
                   diff);
          end loop;
        end if;

      when others =>
        add(diff, path, "values differ");
    end case;
  end;
end package body;
