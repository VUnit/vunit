-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.codec_pkg.all;
use work.codec_builder_pkg.all;

package queue_pkg is

  type queue_t is record
    p_meta : integer_vector_ptr_t;
    data : string_ptr_t;
  end record;
  constant num_words_per_queue : natural := 2;

  constant null_queue : queue_t := (p_meta => null_ptr, data => null_string_ptr);

  impure function allocate return queue_t;
  impure function length(queue : queue_t) return integer;
  procedure flush(queue : queue_t);
  impure function copy(queue : queue_t) return queue_t;

  procedure push(queue : queue_t; value : integer);
  impure function pop(queue : queue_t) return integer;
  alias push_integer is push[queue_t, integer];
  alias pop_integer is pop[queue_t return integer];

  procedure push_byte(queue : queue_t; value : natural range 0 to 255);
  impure function pop_byte(queue : queue_t) return integer;

  procedure push(queue : queue_t; value : character);
  impure function pop(queue : queue_t) return character;
  alias push_character is push[queue_t, character];
  alias pop_character is pop[queue_t return character];

  procedure push(queue : queue_t; value : boolean);
  impure function pop(queue : queue_t) return boolean;
  alias push_boolean is push[queue_t, boolean];
  alias pop_boolean is pop[queue_t return boolean];

  procedure push(queue : queue_t; value : real);
  impure function pop(queue : queue_t) return real;
  alias push_real is push[queue_t, real];
  alias pop_real is pop[queue_t return real];

  procedure push(queue : queue_t; value : std_ulogic);
  impure function pop(queue : queue_t) return std_ulogic;
  alias push_std_ulogic is push[queue_t, std_ulogic];
  alias pop_std_ulogic is pop[queue_t return std_ulogic];

  procedure push(queue : queue_t; value : std_ulogic_vector);
  impure function pop(queue : queue_t) return std_ulogic_vector;
  alias push_std_ulogic_vector is push[queue_t, std_ulogic_vector];
  alias pop_std_ulogic_vector is pop[queue_t return std_ulogic_vector];

  procedure push(queue : queue_t; value : string);
  impure function pop(queue : queue_t) return string;
  alias push_string is push[queue_t, string];
  alias pop_string is pop[queue_t return string];

  procedure push(queue : queue_t; value : time);
  impure function pop(queue : queue_t) return time;
  alias push_time is push[queue_t, time];
  alias pop_time is pop[queue_t return time];

  procedure push(queue : queue_t; value : integer_vector_ptr_t);
  impure function pop(queue : queue_t) return integer_vector_ptr_t;
  alias push_integer_vector_ptr_ref is push[queue_t, integer_vector_ptr_t];
  alias pop_integer_vector_ptr_ref is pop[queue_t return integer_vector_ptr_t];

  procedure push(queue : queue_t; value : string_ptr_t);
  impure function pop(queue : queue_t) return string_ptr_t;
  alias push_string_ptr_ref is push[queue_t, string_ptr_t];
  alias pop_string_ptr_ref is pop[queue_t return string_ptr_t];

  procedure push(queue : queue_t; value : queue_t);
  impure function pop(queue : queue_t) return queue_t;
  alias push_queue_ref is push[queue_t, queue_t];
  alias pop_queue_ref is pop[queue_t return queue_t];

  constant queue_t_code_length : positive := integer_vector_ptr_t_code_length + string_ptr_t_code_length;
  function encode(data : queue_t) return string;
  function decode(code : string) return queue_t;
  procedure decode (constant code : string; variable index : inout positive; variable result : out queue_t);
  alias encode_queue_t is encode[queue_t return string];
  alias decode_queue_t is decode[string return queue_t];
end package;

package body queue_pkg is

  constant tail_idx : natural := 0;
  constant head_idx : natural := 1;
  constant num_meta : natural := head_idx + 1;

  impure function allocate return queue_t is
  begin
    return (p_meta => allocate(num_meta),
            data => allocate);
  end;

  impure function length(queue : queue_t) return integer is
    variable head : integer := get(queue.p_meta, head_idx);
    variable tail : integer := get(queue.p_meta, tail_idx);
  begin
    return tail - head;
  end;

  procedure flush(queue : queue_t) is
  begin
    assert queue /= null_queue report "Flush null queue";
    set(queue.p_meta, head_idx, 0);
    set(queue.p_meta, tail_idx, 0);
  end;

  impure function copy(queue : queue_t) return queue_t is
    variable result : queue_t := allocate;
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

  function decode(code : string) return queue_t is
    variable ret_val : queue_t;
    variable index : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  procedure decode (constant code : string; variable index : inout positive; variable result : out queue_t) is
  begin
    decode(code, index, result.p_meta);
    decode(code, index, result.data);
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

  procedure push(queue : queue_t; value : std_ulogic) is
  begin
    push_fix_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return std_ulogic is
  begin
    return decode(pop_fix_string(queue, std_ulogic_code_length));
  end;

  procedure push(queue : queue_t; value : std_ulogic_vector) is
  begin
    push_variable_string(queue, encode(value));
  end;

  impure function pop(queue : queue_t) return std_ulogic_vector is
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
end package body;
