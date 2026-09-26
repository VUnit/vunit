-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body queue_pkg is
  constant tail_idx : natural := 0;
  constant head_idx : natural := 1;
  constant num_meta : natural := head_idx + 1;
  constant queue_t_code_length : positive := integer_vector_ptr_t_code_length + string_ptr_t_code_length;

  impure function new_queue
  return queue_t is begin
    return (p_meta => new_integer_vector_ptr(num_meta),
            data   => new_string_ptr);
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

  procedure push_type (
    queue        : queue_t;
    element_type : data_type_t
  ) is begin
    unsafe_push(queue, character'val(data_type_t'pos(element_type)));
  end;

  impure function pop_type (
    queue : queue_t
  ) return data_type_t is begin
    return data_type_t'val(character'pos(unsafe_pop(queue)));
  end;

  procedure check_type (
    queue        : queue_t;
    element_type : data_type_t
  ) is
    constant popped_type : data_type_t := pop_type(queue);
  begin
    if popped_type /= element_type then
      report "Got queue element of type " & to_string(popped_type) &
        ", expected " & to_string(element_type) & "." severity error;
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

  procedure push (
    queue : queue_t;
    value : std_ulogic_vector
  ) is begin
    push_type(queue, ieee_std_ulogic_vector);
    push_variable_string(queue, encode(value));
  end;

  impure function pop (
    queue : queue_t
  ) return std_ulogic_vector is begin
    check_type(queue, ieee_std_ulogic_vector);
    return decode(pop_variable_string(queue));
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
    ) return integer_array_t is
    variable length, width, height, depth, bit_width : natural;
    variable is_signed : boolean;
    variable lower_limit, upper_limit : integer;
    variable data : integer_vector_ptr_t;

  begin
    check_type(queue, vunit_integer_array_t);

    -- Assigning values to temporary varibles solves
    -- a Questa bug.
    length      := unsafe_pop(queue);
    width       := unsafe_pop(queue);
    height      := unsafe_pop(queue);
    depth       := unsafe_pop(queue);
    bit_width   := unsafe_pop(queue);
    is_signed   := unsafe_pop(queue);
    lower_limit := unsafe_pop(queue);
    upper_limit := unsafe_pop(queue);
    data        := unsafe_pop(queue);

    return (
      length      => length,
      width       => width,
      height      => height,
      depth       => depth,
      bit_width   => bit_width,
      is_signed   => is_signed,
      lower_limit => lower_limit,
      upper_limit => upper_limit,
      data        => data
    );
  end;

end package body;
