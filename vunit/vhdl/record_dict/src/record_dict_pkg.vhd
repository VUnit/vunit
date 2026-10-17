-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
--
-- record_dict_pkg converts a value of any record type to a dict_t, using VHDL-2019
-- reflection. Element names become lower case keys, a nested record becomes a nested
-- dict_t.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.reflection.all;

use work.dict_pkg.all;
use work.logger_pkg.all;
use work.string_ops.lower;

package record_dict_pkg is
  constant record_dict_logger : logger_t := get_logger("vunit_lib:record_dict_pkg");

  -- Instantiate once per record type, then call with the record:
  --
  --   function to_dict is new to_dict generic map (record_t => packet_t);
  --   ...
  --   dict := to_dict(packet);
  --
  -- The generic type is needed since a mirror is an access type, which a parameter can only take as a
  -- variable, so my_record'reflect can't be passed to a subprogram. The function reflects its own
  -- parameter instead.
  impure function to_dict generic (type record_t) parameter (value : record_t) return dict_t;
end package;

package body record_dict_pkg is
  impure function mirror_to_dict(variable value : inout value_mirror) return dict_t;

  impure function to_std_ulogic_vector(variable value : inout array_value_mirror) return std_ulogic_vector is
    variable subtype_mirror : array_subtype_mirror := value.get_subtype_mirror;
    variable element : value_mirror;
    variable result : std_ulogic_vector(0 to integer(subtype_mirror.length) - 1);
  begin
    for idx in result'range loop
      element := value.get(subtype_mirror.left + index(idx));
      result(idx) := std_ulogic'val(element.to_enumeration.pos);
    end loop;
    return result;
  end;

  impure function to_string(variable value : inout array_value_mirror) return string is
    variable subtype_mirror : array_subtype_mirror := value.get_subtype_mirror;
    variable element : value_mirror;
    variable result : string(1 to integer(subtype_mirror.length));
  begin
    for idx in result'range loop
      element := value.get(subtype_mirror.left + index(idx - 1));
      result(idx) := character'val(element.to_enumeration.pos);
    end loop;
    return result;
  end;

  procedure set(dict : dict_t; key : string; variable value : inout value_mirror) is
    constant type_name : string := value.get_subtype_mirror.simple_name;
    variable enumeration : enumeration_value_mirror;
    variable array_value : array_value_mirror;
    variable nested : dict_t;
  begin
    case value.get_value_class is
      when class_integer =>
        set_integer(dict, key, value.to_integer.value);

      when class_floating =>
        set_real(dict, key, value.to_floating.value);

      when class_physical =>
        if type_name = "TIME" then
          set_time(dict, key, value.to_physical.value * 1 fs);
        else
          failure(record_dict_logger, key & ": physical type " & type_name & " is not supported.");
        end if;

      when class_enumeration =>
        enumeration := value.to_enumeration;
        if type_name = "BOOLEAN" then
          set_boolean(dict, key, boolean'val(enumeration.pos));
        elsif type_name = "BIT" then
          set_bit(dict, key, bit'val(enumeration.pos));
        elsif type_name = "STD_ULOGIC" or type_name = "STD_LOGIC" then
          set_std_ulogic(dict, key, std_ulogic'val(enumeration.pos));
        elsif type_name = "CHARACTER" then
          set_character(dict, key, character'val(enumeration.pos));
        else
          set_string(dict, key, enumeration.image);
        end if;

      when class_array =>
        array_value := value.to_array;
        if type_name = "STRING" then
          set_string(dict, key, to_string(array_value));
        elsif type_name = "UNSIGNED" or type_name = "UNRESOLVED_UNSIGNED" then
          set_numeric_std_unsigned(dict, key, unsigned(to_std_ulogic_vector(array_value)));
        elsif type_name = "SIGNED" or type_name = "UNRESOLVED_SIGNED" then
          set_numeric_std_signed(dict, key, signed(to_std_ulogic_vector(array_value)));
        elsif type_name = "STD_ULOGIC_VECTOR" or type_name = "STD_LOGIC_VECTOR" then
          set_std_ulogic_vector(dict, key, to_std_ulogic_vector(array_value));
        else
          failure(record_dict_logger, key & ": array type " & type_name & " is not supported.");
        end if;

      when class_record =>
        -- NVC rejects mirror_to_dict(value) as an actual of set_dict_t_ref
        nested := mirror_to_dict(value);
        set_dict_t_ref(dict, key, nested);

      when others =>
        failure(record_dict_logger, key & ": type " & type_name & " is not supported.");
    end case;
  end;

  impure function mirror_to_dict(variable value : inout value_mirror) return dict_t is
    variable record_value : record_value_mirror;
    variable subtype_mirror : record_subtype_mirror;
    variable element : value_mirror;
    constant dict : dict_t := new_dict;
  begin
    if value.get_value_class /= class_record then
      failure(record_dict_logger, "to_dict expects a record, got " & value.get_subtype_mirror.simple_name & ".");
      return dict;
    end if;

    record_value := value.to_record;
    subtype_mirror := record_value.get_subtype_mirror;
    for idx in 0 to subtype_mirror.length - 1 loop
      element := record_value.get(idx);
      set(dict, lower(subtype_mirror.element_name(idx)), element);
    end loop;
    return dict;
  end;

  impure function to_dict generic (type record_t) parameter (value : record_t) return dict_t is
    variable mirror : value_mirror := value'reflect;
  begin
    return mirror_to_dict(mirror);
  end;
end package body;
