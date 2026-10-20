-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
--
-- reflection_queue_pkg pushes a value of any type onto a queue_t, using VHDL-2019 reflection. The
-- elements are pushed one by one with the queue_pkg push of their type, in declaration order, so that
-- they can be popped with pop_integer, pop_std_ulogic_vector and so on.
--
-- The push is one-way: reflection can read a value but can't create one, so there is no pop that
-- returns the value.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.reflection.all;

use work.logger_pkg.all;
use work.queue_pkg.all;
use work.reflection_util_pkg.all;
use work.string_ops.lower;

package reflection_queue_pkg is
  constant reflection_queue_logger : logger_t := get_logger("vunit_lib:reflection_queue_pkg");

  -- Instantiate once per type, then call with the value:
  --
  --   procedure push is new vunit_lib.reflection_queue_pkg.push generic map (t => packet_t);
  --   ...
  --   push(queue, packet);
  --   addr := pop_integer(queue);
  --   data := pop_std_ulogic_vector(queue);
  --
  -- The selected name keeps the instantiation unambiguous with the push procedures of queue_pkg, which
  -- Riviera-PRO otherwise reports as ambiguous.
  procedure push generic (type t) parameter (queue : queue_t; value : t);
end package;

package body reflection_queue_pkg is
  -- The name of the element in error messages
  function element_label(name : string) return string is
  begin
    if name = "" then
      return "value";
    end if;
    return name;
  end;

  procedure push_mirror(queue : queue_t; name : string; variable value : inout value_mirror) is
    constant type_name : string := get_type_name(value);
    variable integer_value : integer_value_mirror;
    variable floating_value : floating_value_mirror;
    variable physical_value : physical_value_mirror;
    variable enumeration : enumeration_value_mirror;
    variable record_value : record_value_mirror;
    variable record_subtype : record_subtype_mirror;
    variable array_value : array_value_mirror;
    variable element : value_mirror;
  begin
    case value.get_value_class is
      when class_integer =>
        integer_value := value.to_integer;
        push_integer(queue, integer_value.value);

      when class_floating =>
        floating_value := value.to_floating;
        push_real(queue, floating_value.value);

      when class_physical =>
        if type_name = "TIME" then
          -- The value is in units of the resolution limit on Riviera-PRO, fs on NVC
          physical_value := value.to_physical;
          push_time(queue, physical_value.value * std.env.resolution_limit);
        else
          failure(reflection_queue_logger, element_label(name) & ": physical type " & type_name & " is not supported.");
        end if;

      when class_enumeration =>
        enumeration := value.to_enumeration;
        if type_name = "BOOLEAN" then
          push_boolean(queue, boolean'val(enumeration.pos));
        elsif type_name = "BIT" then
          push_bit(queue, bit'val(enumeration.pos));
        elsif type_name = "STD_ULOGIC" or type_name = "STD_LOGIC" then
          push_std_ulogic(queue, std_ulogic'val(enumeration.pos));
        elsif type_name = "CHARACTER" then
          push_character(queue, character'val(enumeration.pos));
        else
          -- Popped with pop_string, and back with my_enum_t'value
          push_string(queue, enumeration.image);
        end if;

      when class_array =>
        array_value := value.to_array;
        if type_name = "STRING" then
          push_string(queue, to_string(array_value));
        elsif type_name = "UNSIGNED" or type_name = "UNRESOLVED_UNSIGNED" then
          push_numeric_std_unsigned(queue, unsigned(to_std_ulogic_vector(array_value)));
        elsif type_name = "SIGNED" or type_name = "UNRESOLVED_SIGNED" then
          push_numeric_std_signed(queue, signed(to_std_ulogic_vector(array_value)));
        elsif type_name = "STD_ULOGIC_VECTOR" or type_name = "STD_LOGIC_VECTOR" then
          push_std_ulogic_vector(queue, to_std_ulogic_vector(array_value));
        else
          failure(reflection_queue_logger, element_label(name) & ": array type " & type_name & " is not supported.");
        end if;

      when class_record =>
        record_value := value.to_record;
        record_subtype := record_value.get_subtype_mirror;
        for idx in 0 to record_subtype.length - 1 loop
          element := record_value.get(idx);
          if name = "" then
            push_mirror(queue, lower(record_subtype.element_name(idx)), element);
          else
            push_mirror(queue, name & "." & lower(record_subtype.element_name(idx)), element);
          end if;
        end loop;

      when others =>
        failure(reflection_queue_logger, element_label(name) & ": type " & type_name & " is not supported.");
    end case;
  end;

  procedure push generic (type t) parameter (queue : queue_t; value : t) is
    variable mirror : value_mirror := value'reflect;
  begin
    push_mirror(queue, "", mirror);
  end;
end package body;
