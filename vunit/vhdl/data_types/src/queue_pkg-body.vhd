-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

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

  impure function new_queue
  return queue_t is begin
    return (
      p_meta => new_integer_vector_ptr(num_meta),
      data   => new_string_ptr
    );
  end;

  impure function length (
    queue : queue_t
  ) return natural is
    constant head : integer := get(queue.p_meta, head_idx);
    constant tail : integer := get(queue.p_meta, tail_idx);
  begin
    return tail - head;
  end;

  impure function is_empty (
    queue : queue_t
  ) return boolean is begin
    return length(queue) = 0;
  end;

  procedure flush (
    queue : queue_t
  ) is begin
    assert queue /= null_queue report "Flush null queue";
    set(queue.p_meta, head_idx, 0);
    set(queue.p_meta, tail_idx, 0);
  end;

  impure function copy (
    queue : queue_t
  ) return queue_t is
    constant result : queue_t := new_queue;
  begin
    for i in 0 to length(queue) - 1 loop
      unsafe_push(result, get(queue.data, 1 + i));
    end loop;
    return result;
  end;

  function encode (
    data : queue_t
  ) return string is begin
    return encode(data.p_meta) & encode(to_integer(data.data));
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

  procedure unsafe_push (
    queue : queue_t;
    value : character
  ) is
    variable tail : integer;
    variable head : integer;
  begin
    assert queue /= null_queue report "Push to null queue";
    tail := get(queue.p_meta, tail_idx);
    head := get(queue.p_meta, head_idx);
    if length(queue.data) < tail + 1 then
      -- Allocate more new data, double data to avoid
      -- to much copying.
      -- Also normalize the queue by dropping unnused data before head
      resize(queue.data, 2 * length(queue) + 1, drop => head);
      tail := tail - head;
      head := 0;
      set(queue.p_meta, head_idx, head);
    end if;
    set(queue.data, 1 + tail, value);
    set(queue.p_meta, tail_idx, tail + 1);
  end;

  impure function unsafe_pop (
    queue : queue_t
  ) return character is
    variable head : integer;
    variable data : character;
  begin
    assert queue /= null_queue report "Pop from null queue";
    assert length(queue) > 0 report "Pop from empty queue";
    head := get(queue.p_meta, head_idx);
    data := get(queue.data, 1 + head);
    set(queue.p_meta, head_idx, head + 1);
    return data;
  end;

  procedure unsafe_peek (
    queue : queue_t;
    variable value : out character;
    variable offset : inout natural
  ) is
    variable head : integer;
    variable data : character;
  begin
    assert queue /= null_queue report "Peek from null queue";
    assert length(queue) > 0 report "Peek from empty queue";
    head := offset + get(queue.p_meta, head_idx);
    -- The element which indicates the type as not been consumed, hence: queue_element_type_t_code_length
    data := get(queue.data, 1 + head);
    value := data;
    offset := offset + character_code_length;
  end;

  impure function unsafe_peek (
    queue : queue_t
  ) return character is
    variable value : character;
    variable offset : natural := 0;
  begin
    unsafe_peek(queue, value, offset);
    return value;
  end;

  procedure push_type (
    queue        : queue_t;
    element_type : queue_element_type_t
  ) is begin
    unsafe_push(queue, character'val(queue_element_type_t'pos(element_type)));
  end;

  impure function pop_type (
    queue : queue_t
  ) return queue_element_type_t is begin
    return queue_element_type_t'val(character'pos(unsafe_pop(queue)));
  end;

  procedure peek_type (
    queue : queue_t;
    variable value : inout queue_element_type_t;
    variable offset : inout natural
  ) is
    variable peek_value : character;
  begin
    unsafe_peek(queue, peek_value, offset);
    value := queue_element_type_t'val(character'pos(peek_value));
  end;

  impure function peek_type (
    queue : queue_t
  ) return queue_element_type_t is
    variable value : queue_element_type_t;
    variable offset : natural := 0;
  begin
    peek_type(queue, value, offset);
    return value;
  end;

  procedure check_type_pop (
    queue        : queue_t;
    element_type : queue_element_type_t
  ) is
    constant popped_type : queue_element_type_t := pop_type(queue);
  begin
    if popped_type /= element_type then
      report "Got queue element of type " & queue_element_type_t'image(popped_type) &
        ", expected " & queue_element_type_t'image(element_type) & "." severity error;
    end if;
  end;

  procedure check_type_peek (
    queue        : queue_t;
    element_type : queue_element_type_t;
    variable offset : inout natural
  ) is
    variable peeked_type : queue_element_type_t;
  begin
    peek_type(queue, peeked_type, offset);
    if peeked_type /= element_type then
      report "Got queue element of type " & queue_element_type_t'image(peeked_type) &
        ", expected " & queue_element_type_t'image(element_type) & "." severity error;
    end if;
  end;

  procedure push (
    queue : queue_t;
    value : character
  ) is begin
    push_type(queue, vhdl_character);
    unsafe_push(queue, value);
  end;

  impure function pop (
    queue : queue_t
  ) return character is begin
    check_type(queue, vhdl_character);
    return unsafe_pop(queue);
  end;

  procedure peek (
    queue : queue_t;
    variable value : out character;
    variable offset : inout natural
  ) is begin
    check_type_peek(queue, vhdl_character, offset);
    unsafe_peek(queue, value, offset);
  end;

  impure function peek (
    queue : queue_t
  ) return character is
    variable value : character;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push_fix_string (
    queue : queue_t;
    value : string
  ) is begin
    for i in value'range loop
      unsafe_push(queue, value(i));
    end loop;
  end;

  impure function pop_fix_string (
    queue  : queue_t;
    length : natural
  ) return string is
    variable result : string(1 to length);
  begin
    for i in result'range loop
      result(i) := unsafe_pop(queue);
    end loop;

    return result;
  end;

  procedure peek_fix_string (
    queue  : queue_t;
    variable result : out string;
    variable offset : inout natural
  ) is begin
    for i in result'range loop
      unsafe_peek(queue, result(i), offset);
    report "1." & integer'image(i) & "==> " & integer'image(offset);
    end loop;
  end;

  impure function peek_fix_string (
    queue  : queue_t;
    length : natural;
    offset : natural := 0
  ) return string is
    variable offset_v : natural := offset;
    variable result : string(1 to length);
  begin
    peek_fix_string(queue, result, offset_v);
    return result;
  end;

  procedure unsafe_push (
    queue : queue_t;
    value : integer
  ) is begin
    push_fix_string(queue, encode(value));
  end;

  impure function unsafe_pop (
    queue : queue_t
  ) return integer is begin
    return decode(pop_fix_string(queue, integer_code_length));
  end;

  procedure unsafe_peek (
    queue : queue_t;
    variable value : out integer;
    variable offset : inout natural
  ) is
    constant length : natural := integer_code_length;
    variable result : string(1 to length);
  begin
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function unsafe_peek (
    queue : queue_t
  ) return integer is
    variable value : integer;
    variable offset : natural := 0;
  begin
    unsafe_peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    value : integer
  ) is begin
    push_type(queue, vhdl_integer);
    push_fix_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return integer is begin
    check_type(queue, vhdl_integer);
    return decode(pop_fix_string(queue, integer_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out integer;
    variable offset : inout natural
  ) is
    constant length : natural := integer_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_integer, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return integer is
    variable value : integer;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push_byte (
    queue : queue_t;
    value : natural range 0 to 255
  ) is begin
    push_type(queue, vunit_byte);
    unsafe_push(queue, character'val(value));
  end;

  impure function pop_byte (
    queue : queue_t
  ) return integer is begin
    check_type(queue, vunit_byte);
    return character'pos(unsafe_pop(queue));
  end;

  procedure peek_byte (
    queue : queue_t;
    variable value : out integer;
    variable offset : inout natural
  ) is
    variable result : character;
  begin
    check_type_peek(queue, vunit_byte, offset);
    unsafe_peek(queue, result, offset);
    value := character'pos(result);
  end;

  impure function peek_byte (
    queue : queue_t
  ) return integer is
    variable value : integer;
    variable offset : natural := 0;
  begin
    peek_byte(queue, value, offset);
    return value;
  end;

  procedure push_variable_string (
    queue : queue_t;
    value : string
  ) is begin
    unsafe_push(queue, value'length);
    push_fix_string(queue, value);
  end;

  impure function pop_variable_string (
    queue : queue_t
  ) return string is
    constant length : integer := unsafe_pop(queue);
  begin
    return pop_fix_string(queue, length);
  end;

  procedure peek_variable_string (
    queue : queue_t;
    variable value : out string;
    variable offset : inout natural
  ) is
    variable length : integer;
  begin
    unsafe_peek(queue, length, offset);
    report "1.len==> " & integer'image(offset);
    report "  len=" & integer'image(length);
    assert value'length >= length report
      "The expected string is smaller (" & integer'image(value'length) & ") than actual (" & integer'image(length) & ")"
    severity failure;
    assert value'length = length report
      "The expected string is greater (" & integer'image(value'length) & ") than actual (" & integer'image(length) & ")"
    severity warning;
    peek_fix_string(queue, value, offset);
  end;

  impure function peek_variable_string (
    queue : queue_t;
    offset : natural := 0
  ) return string is
    variable offset_v : natural := offset;
    variable length : integer;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    unsafe_peek(queue, length, offset_v);
    return peek_fix_string(queue, length, offset_v);
  end;

  procedure push (
    queue : queue_t;
    value : boolean
  ) is begin
    push_type(queue, vhdl_boolean);
    push_fix_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return boolean is begin
    check_type(queue, vhdl_boolean);
    return decode(pop_fix_string(queue, boolean_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out boolean;
    variable offset : inout natural
  ) is
    constant length : natural := boolean_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_boolean, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return boolean is
    variable value : boolean;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure unsafe_push (
    queue : queue_t;
    value : boolean
  ) is begin
    push_fix_string(queue, encode(value));
  end;

  impure function unsafe_pop (
    queue : queue_t
  ) return boolean is begin
    return decode(pop_fix_string(queue, boolean_code_length));
  end;

  procedure unsafe_peek (
    queue : queue_t;
    variable value : out boolean;
    variable offset : inout natural
  ) is
    constant length : natural := boolean_code_length;
    variable result : string(1 to length);
  begin
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function unsafe_peek (
    queue : queue_t
  ) return boolean is
    variable value : boolean;
    variable offset : natural := 0;
  begin
    unsafe_peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    value : real
  ) is begin
    push_type(queue, vhdl_real);
    push_fix_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return real is begin
    check_type(queue, vhdl_real);
    return decode(pop_fix_string(queue, real_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out real;
    variable offset : inout natural
  ) is
    constant length : natural := real_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_real, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return real is
    variable value : real;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    value : bit
  ) is begin
    push_type(queue, vhdl_bit);
    push_fix_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return bit is begin
    check_type(queue, vhdl_bit);
    return decode(pop_fix_string(queue, bit_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out bit;
    variable offset : inout natural
  ) is
    constant length : natural := bit_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_bit, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return bit is
    variable value : bit;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    value : std_ulogic
  ) is begin
    push_type(queue, ieee_std_ulogic);
    push_fix_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return std_ulogic is begin
    check_type(queue, ieee_std_ulogic);
    return decode(pop_fix_string(queue, std_ulogic_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out std_ulogic;
    variable offset : inout natural
  ) is
    constant length : natural := std_ulogic_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, ieee_std_ulogic, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return std_ulogic is
    variable value : std_ulogic;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    value : severity_level
  ) is begin
    push_type(queue, vhdl_severity_level);
    push_fix_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return severity_level is begin
    check_type(queue, vhdl_severity_level);
    return decode(pop_fix_string(queue, severity_level_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out severity_level;
    variable offset : inout natural
  ) is
    constant length : natural := severity_level_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_severity_level, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return severity_level is
    variable value : severity_level;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    value : file_open_status
  ) is begin
    push_type(queue, vhdl_file_open_status);
    push_fix_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return file_open_status is begin
    check_type(queue, vhdl_file_open_status);
    return decode(pop_fix_string(queue, file_open_status_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out file_open_status;
    variable offset : inout natural
  ) is
    constant length : natural := file_open_status_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_file_open_status, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return file_open_status is
    variable value : file_open_status;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    value : file_open_kind
  ) is begin
    push_type(queue, vhdl_file_open_kind);
    push_fix_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return file_open_kind is begin
    check_type(queue, vhdl_file_open_kind);
    return decode(pop_fix_string(queue, file_open_kind_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out file_open_kind;
    variable offset : inout natural
  ) is
    constant length : natural := file_open_kind_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_file_open_kind, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return file_open_kind is
    variable value : file_open_kind;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    value : bit_vector
  ) is begin
    push_type(queue, vhdl_bit_vector);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return bit_vector is begin
    check_type(queue, vhdl_bit_vector);
    return decode(pop_variable_string(queue));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out bit_vector;
    variable offset : inout natural
  ) is
    constant length : natural := range_length + (value'length + 7)/8; -- TODO repetition of what is inside the codec.vhd
    variable result : string(1 to length);
  begin
    report "1==> " & integer'image(offset);
    check_type_peek(queue, vhdl_bit_vector, offset);
    report "2==> " & integer'image(offset);
    peek_variable_string(queue, result, offset);
    report "3==> " & integer'image(offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return bit_vector is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, vhdl_bit_vector, offset);
    return decode(peek_variable_string(queue, offset));
  end;

  procedure push (
    queue : queue_t;
    value : std_ulogic_vector
  ) is begin
    push_type(queue, vhdl_std_ulogic_vector);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return std_ulogic_vector is begin
    check_type(queue, vhdl_std_ulogic_vector);
    return decode(pop_variable_string(queue));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out std_ulogic_vector;
    variable offset : inout natural
  ) is
    constant length : natural := range_length + (value'length+1)/2; -- TODO repetition of what is inside the codec.vhd
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_std_ulogic_vector, offset);
    peek_variable_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return std_ulogic_vector is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, vhdl_std_ulogic_vector, offset);
    return decode(peek_variable_string(queue, offset));
  end;

  procedure push (
    queue : queue_t;
    value : complex
  ) is begin
    push_type(queue, ieee_complex);
    push_fix_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return complex is begin
    check_type(queue, ieee_complex);
    return decode(pop_fix_string(queue, complex_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out complex;
    variable offset : inout natural
  ) is
    constant length : natural := complex_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, ieee_complex, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return complex is
    variable value : complex;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    value : complex_polar
  ) is begin
    push_type(queue, ieee_complex_polar);
    push_fix_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return complex_polar is begin
    check_type(queue, ieee_complex_polar);
    return decode(pop_fix_string(queue, complex_polar_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out complex_polar;
    variable offset : inout natural
  ) is
    constant length : natural := complex_polar_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, ieee_complex_polar, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return complex_polar is
    variable value : complex_polar;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    value : ieee.numeric_bit.unsigned
  ) is begin
    push_type(queue, ieee_numeric_bit_unsigned);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_bit.unsigned is begin
    check_type(queue, ieee_numeric_bit_unsigned);
    return decode(pop_variable_string(queue));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out ieee.numeric_bit.unsigned;
    variable offset : inout natural
  ) is
    constant length : natural := range_length + (value'length + 7) / 8; -- TODO repetition of what is inside the codec.vhd
    variable result : string(1 to length);
  begin
    check_type_peek(queue, ieee_numeric_bit_unsigned, offset);
    peek_variable_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return ieee.numeric_bit.unsigned is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, ieee_numeric_bit_unsigned, offset);
    return decode(peek_variable_string(queue, offset));
  end;

  procedure push (
    queue : queue_t;
    value : ieee.numeric_bit.signed
  ) is begin
    push_type(queue, ieee_numeric_bit_signed);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_bit.signed is begin
    check_type(queue, ieee_numeric_bit_signed);
    return decode(pop_variable_string(queue));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out ieee.numeric_bit.signed;
    variable offset : inout natural
  ) is
    constant length : natural := range_length + (value'length + 7) / 8; -- TODO repetition of what is inside the codec.vhd
    variable result : string(1 to length);
  begin
    check_type_peek(queue, ieee_numeric_bit_signed, offset);
    peek_variable_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return ieee.numeric_bit.signed is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, ieee_numeric_bit_signed, offset);
    return decode(peek_variable_string(queue, offset));
  end;

  procedure push (
    queue : queue_t;
    value : ieee.numeric_std.unsigned
  ) is begin
    push_type(queue, ieee_numeric_std_unsigned);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_std.unsigned is begin
    check_type(queue, ieee_numeric_std_unsigned);
    return decode(pop_variable_string(queue));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out ieee.numeric_std.unsigned;
    variable offset : inout natural
  ) is
    constant length : natural := range_length + (value'length+1)/2; -- TODO repetition of what is inside the codec.vhd
    variable result : string(1 to length);
  begin
    check_type_peek(queue, ieee_numeric_std_unsigned, offset);
    peek_variable_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return ieee.numeric_std.unsigned is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, ieee_numeric_std_unsigned, offset);
    return decode(peek_variable_string(queue, offset));
  end;

  procedure push (
    queue : queue_t;
    value : ieee.numeric_std.signed
  ) is begin
    push_type(queue, ieee_numeric_std_signed);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return ieee.numeric_std.signed is begin
    check_type(queue, ieee_numeric_std_signed);
    return decode(pop_variable_string(queue));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out ieee.numeric_std.signed;
    variable offset : inout natural
  ) is
    constant length : natural := range_length + (value'length+1)/2; -- TODO repetition of what is inside the codec.vhd
    variable result : string(1 to length);
  begin
    check_type_peek(queue, ieee_numeric_std_signed, offset);
    peek_variable_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return ieee.numeric_std.signed is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, ieee_numeric_std_signed, offset);
    return decode(peek_variable_string(queue, offset));
  end;

  procedure push (
    queue : queue_t;
    value : string
  ) is begin
    push_type(queue, vhdl_string);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return string is begin
    check_type(queue, vhdl_string);
    return decode(pop_variable_string(queue));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out string;
    variable offset : inout natural
  ) is
    constant length : natural := range_length + value'length * character_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_string, offset);
    peek_variable_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return string is
    variable offset : natural := 0;
  begin
    -- cannot use the associated procedure because we would need a variable of type array but we cannot constraint it
    check_type_peek(queue, vhdl_string, offset);
    return decode(peek_variable_string(queue, offset));
  end;

  procedure push (
    queue : queue_t;
    value : time
  ) is begin
    push_type(queue, vhdl_time);
    push_fix_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return time is begin
    check_type(queue, vhdl_time);
    return decode(pop_fix_string(queue, time_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out time;
    variable offset : inout natural
  ) is
    constant length : natural := time_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vhdl_time, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return time is
    variable value : time;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    variable value : inout integer_vector_ptr_t
  ) is begin
    push_type(queue, vunit_integer_vector_ptr_t);
    push_fix_string(queue, encode(value));
    value := null_ptr;
  end;

  impure function pop (
    queue : queue_t
  ) return integer_vector_ptr_t is begin
    check_type(queue, vunit_integer_vector_ptr_t);
    return decode(pop_fix_string(queue, integer_vector_ptr_t_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out integer_vector_ptr_t;
    variable offset : inout natural
  ) is
    constant length : natural := integer_vector_ptr_t_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vunit_integer_vector_ptr_t, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return integer_vector_ptr_t is
    variable value : integer_vector_ptr_t;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure unsafe_push (
    queue : queue_t;
    value : integer_vector_ptr_t
  ) is begin
    push_fix_string(queue, encode(value));
  end;

  impure function unsafe_pop (
    queue : queue_t
  ) return integer_vector_ptr_t is begin
    return decode(pop_fix_string(queue, integer_vector_ptr_t_code_length));
  end;

  procedure unsafe_peek (
    queue : queue_t;
    variable value : out integer_vector_ptr_t;
    variable offset : inout natural
  ) is
    constant length : natural := integer_vector_ptr_t_code_length;
    variable result : string(1 to length);
  begin
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function unsafe_peek (
    queue : queue_t
  ) return integer_vector_ptr_t is
    variable value : integer_vector_ptr_t;
    variable offset : natural := 0;
  begin
    unsafe_peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    variable value : inout string_ptr_t
  ) is begin
    push_type(queue, vunit_string_ptr_t);
    push_fix_string(queue, encode(value));
    value := null_string_ptr;
  end;

  impure function pop (
    queue : queue_t
  ) return string_ptr_t is begin
    check_type(queue, vunit_string_ptr_t);
    return decode(pop_fix_string(queue, string_ptr_t_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out string_ptr_t;
    variable offset : inout natural
  ) is
    constant length : natural := string_ptr_t_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vunit_string_ptr_t, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return string_ptr_t is
    variable value : string_ptr_t;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push (
    queue : queue_t;
    variable value : inout queue_t
  ) is begin
    push_type(queue, vunit_queue_t);
    push_fix_string(queue, encode(value));
    value := null_queue;
  end;

  impure function pop (
    queue : queue_t
  ) return queue_t is begin
    check_type(queue, vunit_queue_t);
    return decode(pop_fix_string(queue, queue_t_code_length));
  end;

  procedure peek (
    queue : queue_t;
    variable value : out queue_t;
    variable offset : inout natural
  ) is
    constant length : natural := queue_t_code_length;
    variable result : string(1 to length);
  begin
    check_type_peek(queue, vunit_queue_t, offset);
    peek_fix_string(queue, result, offset);
    value := decode(result);
  end;

  impure function peek (
    queue : queue_t
  ) return queue_t is
    variable value : queue_t;
    variable offset : natural := 0;
  begin
    peek(queue, value, offset);
    return value;
  end;

  procedure push_ref (
    constant queue : queue_t;
    value : inout integer_array_t
  ) is begin
    push_type(queue, vunit_integer_array_t);
    unsafe_push(queue, value.length);
    unsafe_push(queue, value.width);
    unsafe_push(queue, value.height);
    unsafe_push(queue, value.depth);
    unsafe_push(queue, value.bit_width);
    unsafe_push(queue, value.is_signed);
    unsafe_push(queue, value.lower_limit);
    unsafe_push(queue, value.upper_limit);
    unsafe_push(queue, value.data);
    value := null_integer_array;
  end;

  impure function pop_ref (
    queue : queue_t
  ) return integer_array_t is begin
    check_type(queue, vunit_integer_array_t);
    return (
      length      => unsafe_pop(queue),
      width       => unsafe_pop(queue),
      height      => unsafe_pop(queue),
      depth       => unsafe_pop(queue),
      bit_width   => unsafe_pop(queue),
      is_signed   => unsafe_pop(queue),
      lower_limit => unsafe_pop(queue),
      upper_limit => unsafe_pop(queue),
      data        => unsafe_pop(queue)
    );
  end;

  procedure peek_ref (
    queue : queue_t;
    variable value : out integer_array_t;
    variable offset : inout natural
  ) is
  begin
    check_type_peek(queue, vunit_integer_array_t, offset);
    unsafe_peek(queue, value.length, offset);
    unsafe_peek(queue, value.width, offset);
    unsafe_peek(queue, value.height, offset);
    unsafe_peek(queue, value.depth, offset);
    unsafe_peek(queue, value.bit_width, offset);
    unsafe_peek(queue, value.is_signed, offset);
    unsafe_peek(queue, value.lower_limit, offset);
    unsafe_peek(queue, value.upper_limit, offset);
    unsafe_peek(queue, value.data, offset);
  end;

  impure function peek_ref (
    queue : queue_t
  ) return integer_array_t is
    variable value : integer_array_t;
    variable offset : natural := 0;
  begin
    peek_ref(queue, value, offset);
    return value;
  end;
end package body;
