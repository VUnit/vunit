-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.math_real.all;
use ieee.math_complex.all;
use work.codec_pkg.all;
use work.codec_builder_pkg.all;

package body queue_pkg is

  constant tail_idx : natural := 0;
  constant head_idx : natural := 1;
  constant num_meta : natural := head_idx + 1;

  constant queue_t_code_length : positive := integer_vector_ptr_t_code_length + string_ptr_t_code_length;

  impure function new_queue return queue_t is
  begin
    return (p_meta => new_integer_vector_ptr(num_meta),
            data => new_string_ptr);
  end;

  impure function length(queue : queue_t) return natural is
    variable head : integer := get(queue.p_meta, head_idx);
    variable tail : integer := get(queue.p_meta, tail_idx);
  begin
    return tail - head;
  end;

  impure function is_empty(queue : queue_t) return boolean is
  begin
    return length(queue) = 0;
  end;

  procedure flush(queue : queue_t) is
  begin
    assert queue /= null_queue report "Flush null queue";
    set(queue.p_meta, head_idx, 0);
    set(queue.p_meta, tail_idx, 0);
  end;

  impure function copy(queue : queue_t) return queue_t is
    variable result : queue_t := new_queue;
  begin
    for i in 0 to length(queue) - 1 loop
      push(result, get(queue.data, 1+i));
    end loop;

    return result;
  end;

  function encode(data : queue_t) return string is
  begin
    return encode(data.p_meta) & encode(to_integer(data.data));
  end;


  procedure decode (constant code : string; variable index : inout positive; variable result : out queue_t) is
  begin
    decode(code, index, result.p_meta);
    decode(code, index, result.data);
  end;

  function decode(code : string) return queue_t is
    variable ret_val : queue_t;
    variable index : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  procedure push(queue : queue_t; value : character) is
    variable tail : integer;
    variable head : integer;
  begin
    assert queue /= null_queue report "Push to null queue";
    tail := get(queue.p_meta, tail_idx);
    head := get(queue.p_meta, head_idx);

    if length(queue.data) < tail+1 then
      -- Allocate more new data, double data to avoid
      -- to much copying.
      -- Also normalize the queue by dropping unnused data before head
      resize(queue.data, 2*length(queue)+1, drop => head);
      tail := tail - head;
      head := 0;
      set(queue.p_meta, head_idx, head);
    end if;

    set(queue.data, 1+tail, value);
    set(queue.p_meta, tail_idx, tail+1);
  end;

  impure function pop(queue : queue_t) return character is
    variable head : integer;
    variable data : character;
  begin
    assert queue /= null_queue report "Pop from null queue";
    assert length(queue) > 0 report "Pop from empty queue";
    head := get(queue.p_meta, head_idx);
    data := get(queue.data, 1+head);
    set(queue.p_meta, head_idx, head+1);
    return data;
  end;

  procedure push_fix_string(queue : queue_t; value : string) is
  begin
    for i in value'range loop
      push_character(queue, value(i));
    end loop;
  end procedure;

  impure function pop_fix_string(queue : queue_t; length : natural) return string is
    variable result : string(1 to length);
  begin
    for i in result'range loop
      result(i) := pop_character(queue);
    end loop;

    return result;
  end;

  procedure push(queue : queue_t; value : integer) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return integer is
  begin
    return decode(pop_fix_string(queue, integer_code_length));
  end;

  procedure push_byte(queue : queue_t; value : natural range 0 to 255) is
  begin
    push_character(queue, character'val(value));
  end;

  impure function pop_byte(queue : queue_t) return integer is
  begin
    return character'pos(pop_character(queue));
  end;

  procedure push_variable_string(queue : queue_t; value : string) is
  begin
    push_integer(queue, value'length);
    push_fix_string(queue, value);
  end procedure;

  impure function pop_variable_string(queue : queue_t) return string is
    constant length : integer := pop_integer(queue);
  begin
    return pop_fix_string(queue, length);
  end;

  procedure push(queue : queue_t; value : boolean) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return boolean is
  begin
    return decode(pop_fix_string(queue, boolean_code_length));
  end;

  procedure push(queue : queue_t; value : real) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return real is
  begin
    return decode(pop_fix_string(queue, real_code_length));
  end;

  procedure push(queue : queue_t; value : bit) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return bit is
  begin
    return decode(pop_fix_string(queue, bit_code_length));
  end;

  procedure push(queue : queue_t; value : std_ulogic) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return std_ulogic is
  begin
    return decode(pop_fix_string(queue, std_ulogic_code_length));
  end;

  procedure push(queue : queue_t; value : severity_level) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return severity_level is
  begin
    return decode(pop_fix_string(queue, severity_level_code_length));
  end;

  procedure push(queue : queue_t; value : file_open_status) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return file_open_status is
  begin
    return decode(pop_fix_string(queue, file_open_status_code_length));
  end;

  procedure push(queue : queue_t; value : file_open_kind) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return file_open_kind is
  begin
    return decode(pop_fix_string(queue, file_open_kind_code_length));
  end;

  procedure push(queue : queue_t; value : bit_vector) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return bit_vector is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(queue : queue_t; value : std_ulogic_vector) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return std_ulogic_vector is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(queue : queue_t; value : complex) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return complex is
  begin
    return decode(pop_fix_string(queue, complex_code_length));
  end;

  procedure push(queue : queue_t; value : complex_polar) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return complex_polar is
  begin
    return decode(pop_fix_string(queue, complex_polar_code_length));
  end;

  procedure push(queue : queue_t; value : ieee.numeric_bit.unsigned) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return ieee.numeric_bit.unsigned is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(queue : queue_t; value : ieee.numeric_bit.signed) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return ieee.numeric_bit.signed is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(queue : queue_t; value : ieee.numeric_std.unsigned) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return ieee.numeric_std.unsigned is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(queue : queue_t; value : ieee.numeric_std.signed) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return ieee.numeric_std.signed is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(queue : queue_t; value : string) is
  begin
    push_variable_string(queue, encode(value));
  end procedure;

  impure function pop(queue : queue_t) return string is
  begin
    return decode(pop_variable_string(queue));
  end;

  procedure push(queue : queue_t; value : time) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return time is
  begin
    return decode(pop_fix_string(queue, time_code_length));
  end;

  procedure push(queue : queue_t; value : integer_vector_ptr_t) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return integer_vector_ptr_t is
  begin
    return decode(pop_fix_string(queue, integer_vector_ptr_t_code_length));
  end;

  procedure push(queue : queue_t; value : string_ptr_t) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return string_ptr_t is
  begin
    return decode(pop_fix_string(queue, string_ptr_t_code_length));
  end;

  procedure push(queue : queue_t; value : queue_t) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return queue_t is
  begin
    return decode(pop_fix_string(queue, queue_t_code_length));
  end;

  procedure push_ref(constant queue : queue_t; value : inout integer_array_t) is
  begin
    push(queue, value.length);
    push(queue, value.width);
    push(queue, value.height);
    push(queue, value.depth);
    push(queue, value.bit_width);
    push(queue, value.is_signed);
    push(queue, value.lower_limit);
    push(queue, value.upper_limit);
    push(queue, value.data);
    value.data := null_ptr;
  end;

  impure function pop_ref(queue : queue_t) return integer_array_t is
    variable result : integer_array_t;
  begin
    result.length := pop(queue);
    result.width := pop(queue);
    result.height := pop(queue);
    result.depth := pop(queue);
    result.bit_width := pop(queue);
    result.is_signed := pop(queue);
    result.lower_limit := pop(queue);
    result.upper_limit := pop(queue);
    result.data := pop(queue);

    return result;
  end;

end package body;
