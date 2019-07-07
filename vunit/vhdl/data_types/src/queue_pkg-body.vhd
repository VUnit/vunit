-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

use work.codec_pkg.all;

package body queue_pkg is

  constant tail_idx : natural := 0;
  constant head_idx : natural := 1;
  constant wrap_idx : natural := 2;
  constant num_meta : natural := wrap_idx + 1;

  impure function new_queue
    return queue_t is
  begin
    return (p_meta => new_integer_vector_ptr(length => num_meta),
            data   => new_integer_vector_ptr(length => 256, value => -1));
  end;

  impure function length (
    queue : queue_t
  ) return natural is
    constant head : integer := get(queue.p_meta, head_idx);
    constant tail : integer := get(queue.p_meta, tail_idx);
    constant wrap : integer := get(queue.p_meta, wrap_idx);
  begin
    if wrap = 0 then
      return head - tail;
    else
      return length(queue.data) - (head - tail);
    end if;
  end;

  impure function is_empty (
    queue : queue_t
  ) return boolean is begin
    return length(queue) = 0;
  end;

  impure function is_full (
    queue : queue_t
  ) return boolean is begin
    return length(queue) = length(queue.data);
  end;

  procedure flush (
    queue : queue_t
  ) is
    variable ref : integer;
  begin
    assert queue /= null_queue report "Flush null queue";
    set(queue.p_meta, head_idx, 0);
    set(queue.p_meta, tail_idx, 0);
    set(queue.p_meta, wrap_idx, 0);
    for i in 0 to length(queue.data) - 1 loop
      ref := get(queue.data, i);
      if ref > -1 then
        deallocate(to_string_ptr(ref));
      end if;
    end loop;
  end;

  procedure unsafe_push (
    queue : queue_t;
    value : string_ptr_t
  ) is
    variable head : integer  := get(queue.p_meta, head_idx);
    variable tail : integer  := get(queue.p_meta, tail_idx);
    variable wrap : integer  := get(queue.p_meta, wrap_idx);
    variable size : positive := length(queue.data);
  begin
    assert queue /= null_queue report "Push to null queue";
    if is_full(queue) then
      resize(queue.data, 2 * size, rotate => tail);
      tail := 0;
      head := size;
      wrap := 0;
      size := 2 * size;
      set(queue.p_meta, tail_idx, tail);
      set(queue.p_meta, wrap_idx, wrap);
    end if;
    set(queue.data, head, to_integer(value));
    head := head + 1;
    if head >= size then
      head := head mod size;
      if wrap = 0 then
        wrap := 1;
      else
        wrap := 0;
      end if;
      set(queue.p_meta, wrap_idx, wrap);
    end if;
    set(queue.p_meta, head_idx, head);
  end;

  impure function unsafe_pop (
    queue : queue_t
  ) return string_ptr_t is
    constant size : positive := length(queue.data);
    variable tail : integer  := get(queue.p_meta, tail_idx);
    variable wrap : integer  := get(queue.p_meta, wrap_idx);
    variable data : string_ptr_t;
  begin
    assert queue /= null_queue report "Pop from null queue";
    assert length(queue) > 0 report "Pop from empty queue";
    data := to_string_ptr(get(queue.data, tail));
    tail := tail + 1;
    if tail >= size then
      tail := tail mod size;
      if wrap = 0 then
        wrap := 1;
      else
        wrap := 0;
      end if;
      set(queue.p_meta, wrap_idx, wrap);
    end if;
    set(queue.p_meta, tail_idx, tail);
    return data;
  end;

  impure function copy (
    queue : queue_t
  ) return queue_t is
    constant tail   : positive := get(queue.p_meta, tail_idx);
    constant size   : positive := length(queue.data);
    constant result : queue_t := new_queue;
    variable idx    : natural;
    variable ptr    : string_ptr_t;
  begin
    for i in 0 to length(queue) - 1 loop
      idx := (tail + i) mod size;
      ptr := to_string_ptr(get(queue.data, idx));
      unsafe_push(result, new_string_ptr(to_string(ptr)));
    end loop;
    return result;
  end;

  function encode (
    data : queue_t
  ) return string is begin
    return encode(data.p_meta) & encode(data.data);
  end;

  procedure decode (
    constant code   : string;
    variable index  : inout positive;
    variable result : out queue_t
  ) is begin
    decode(code, index, result.p_meta);
    decode(code, index, result.data);
  end;

  function decode (
    code : string
  ) return queue_t is
    variable ret_val : queue_t;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);
    return ret_val;
  end;

  function encode (
    item_type : queue_item_type_t
  ) return character is
  begin
    return character'val(queue_item_type_t'pos(item_type));
  end;

  function decode (
    char : character
  ) return queue_item_type_t is
  begin
    return queue_item_type_t'val(character'pos(char));
  end;

  procedure check_type (
    got      : queue_item_type_t;
    expected : queue_item_type_t
  ) is
  begin
    if got /= expected then
      report "Got queue item of type " & queue_item_type_t'image(got) &
        ", expected " & queue_item_type_t'image(expected) & "." severity error;
    end if;
  end;

  procedure push_item (
    queue : queue_t;
    value : string
  ) is
  begin
    unsafe_push(queue, new_string_ptr(value));
  end;

  impure function pop_item (
    queue : queue_t
  ) return string is
    constant ptr : string_ptr_t := unsafe_pop(queue);
    constant str : string       := to_string(ptr);
  begin
    deallocate(ptr);
    return str;
  end;

  procedure push (
    queue : queue_t;
    value : character
  ) is begin
    push_item(queue, encode(vhdl_character) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return character is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vhdl_character);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : integer
  ) is begin
    push_item(queue, encode(vhdl_integer) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return integer is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vhdl_integer);
    return decode(str(2 to str'right));
  end;

  procedure push_byte (
    queue : queue_t;
    value : natural range 0 to 255
  ) is begin
    push_item(queue, encode(vunit_byte) & encode(character'val(value)));
  end;

  impure function pop_byte (
    queue : queue_t
  ) return integer is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vunit_byte);
    return character'pos(decode(str(2 to str'right)));
  end;

  procedure push (
    queue : queue_t;
    value : boolean
  ) is begin
    push_item(queue, encode(vhdl_boolean) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return boolean is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vhdl_boolean);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : real
  ) is begin
    push_item(queue, encode(vhdl_real) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return real is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vhdl_real);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : bit
  ) is begin
    push_item(queue, encode(vhdl_bit) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return bit is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vhdl_bit);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : std_ulogic
  ) is begin
    push_item(queue, encode(ieee_std_ulogic) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return std_ulogic is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, ieee_std_ulogic);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : severity_level
  ) is begin
    push_item(queue, encode(vhdl_severity_level) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return severity_level is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vhdl_severity_level);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : file_open_status
  ) is begin
    push_item(queue, encode(vhdl_file_open_status) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return file_open_status is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vhdl_file_open_status);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : file_open_kind
  ) is begin
    push_item(queue, encode(vhdl_file_open_kind) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return file_open_kind is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vhdl_file_open_kind);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : bit_vector
  ) is begin
    push_item(queue, encode(vhdl_bit_vector) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return bit_vector is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vhdl_bit_vector);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : std_ulogic_vector
  ) is begin
    push_item(queue, encode(ieee_std_ulogic_vector) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return std_ulogic_vector is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, ieee_std_ulogic_vector);
    report str;
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : complex
  ) is begin
    push_item(queue, encode(ieee_complex) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return complex is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, ieee_complex);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : complex_polar
  ) is begin
    push_item(queue, encode(ieee_complex_polar) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return complex_polar is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, ieee_complex_polar);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : ieee.numeric_bit.unsigned
  ) is begin
    push_item(queue, encode(ieee_numeric_bit_unsigned) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_bit.unsigned is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, ieee_numeric_bit_unsigned);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : ieee.numeric_bit.signed
  ) is begin
    push_item(queue, encode(ieee_numeric_bit_signed) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_bit.signed is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, ieee_numeric_bit_signed);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : ieee.numeric_std.unsigned
  ) is begin
    push_item(queue, encode(ieee_numeric_std_unsigned) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_std.unsigned is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, ieee_numeric_std_unsigned);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : ieee.numeric_std.signed
  ) is begin
    push_item(queue, encode(ieee_numeric_std_signed) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_std.signed is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, ieee_numeric_std_signed);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : string
  ) is begin
    push_item(queue, encode(vhdl_string) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return string is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vhdl_string);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    value : time
  ) is begin
    push_item(queue, encode(vhdl_time) & encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return time is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vhdl_time);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    variable value : inout integer_vector_ptr_t
  ) is begin
    push_item(queue, encode(vunit_integer_vector_ptr) & encode(value));
    value := null_integer_vector_ptr;
  end;

  impure function pop (
    queue : queue_t
  ) return integer_vector_ptr_t is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vunit_integer_vector_ptr);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    variable value : inout string_ptr_t
  ) is begin
    push_item(queue, encode(vunit_string_ptr) & encode(value));
    value := null_string_ptr;
  end;

  impure function pop (
    queue : queue_t
  ) return string_ptr_t is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vunit_string_ptr);
    return decode(str(2 to str'right));
  end;

  procedure push (
    queue : queue_t;
    variable value : inout queue_t
  ) is begin
    push_item(queue, encode(vunit_queue) & encode(value));
    value := null_queue;
  end;

  impure function pop (
    queue : queue_t
  ) return queue_t is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vunit_queue);
    return decode(str(2 to str'right));
  end;

  procedure push (
    constant queue : queue_t;
    value : inout integer_array_t
  ) is begin
    push_item(queue, encode(vunit_integer_array) & encode(value));
    value := null_integer_array;
  end;

  impure function pop (
    queue : queue_t
  ) return integer_array_t is
    constant str : string := pop_item(queue);
    constant typ : queue_item_type_t := decode(str(1));
  begin
    check_type(typ, vunit_integer_array);
    return decode(str(2 to str'right));
  end;

end package body;

