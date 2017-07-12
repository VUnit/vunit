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

  procedure push(queue : queue_t; value : integer) is
    variable val, byte : integer;
  begin
    val := value;
    for i in 0 to 3 loop
      byte := val mod 256;
      val := (val - byte)/256;
      push_byte(queue, byte);
    end loop;
  end;

  impure function pop(queue : queue_t) return integer is
    variable value, byte : integer;
  begin
    value := pop_byte(queue);

    byte := pop_byte(queue);
    value := value + byte*256;

    byte := pop_byte(queue);
    value := value + byte*(256**2);

    byte := pop_byte(queue);
    if byte < 128 then
      value := value + byte * 256**3;
    else
      value := value + (byte - 256) * 256**3;
    end if;

    return value;
  end;

  procedure push_byte(queue : queue_t; value : natural range 0 to 255) is
  begin
    push_character(queue, character'val(value));
  end;

  impure function pop_byte(queue : queue_t) return integer is
  begin
    return character'pos(pop_character(queue));
  end;

  procedure push(queue : queue_t; value : boolean) is
  begin
    if value then
      push_character(queue, '1');
    else
      push_character(queue, '0');
    end if;
  end;

  impure function pop(queue : queue_t) return boolean is
  begin
    return pop_character(queue) = '1';
  end;

  function log2 (a : real) return integer is
    variable y : real;
    variable n : integer := 0;
  begin
    if (a = 1.0 or a = 0.0) then
      return 0;
    end if;
    y := a;
    if(a > 1.0) then
      while y >= 2.0 loop
        y := y / 2.0;
        n := n + 1;
      end loop;
      return n;
    end if;
    -- o < y < 1
    while y < 1.0 loop
      y := y * 2.0;
      n := n - 1;
    end loop;
    return n;
  end function;

  procedure push(queue : queue_t; value : real) is
    constant is_signed : boolean := value < 0.0;
    variable val : real := value;
    variable exp : integer;
    variable low : integer;
    variable high : integer;
  begin
    if is_signed then
      val := -val;
    end if;

    exp := log2(val);
    -- Assume 53 mantissa bits
    val := val * 2.0 ** (-exp + 53);
    high := integer(floor(val * 2.0 ** (-31)));
    low := integer(val - real(high) * 2.0 ** 31);
    push_boolean(queue, is_signed);
    push_integer(queue, exp);
    push_integer(queue, low);
    push_integer(queue, high);
  end;

  impure function pop(queue : queue_t) return real is
    constant is_signed : boolean := pop_boolean(queue);
    variable exp : integer := pop_integer(queue);
    variable low : integer := pop_integer(queue);
    variable high : integer := pop_integer(queue);
    variable val : real := (real(low) + real(high) * 2.0**31) * 2.0 ** (exp - 53);
  begin
    if is_signed then
      val := -val;
    end if;
    return val;
  end;

  procedure push(queue : queue_t; value : std_ulogic) is
  begin
    push_byte(queue, std_ulogic'pos(value));
  end;

  impure function pop(queue : queue_t) return std_ulogic is
  begin
    return std_ulogic'val(pop_byte(queue));
  end;

  procedure push(queue : queue_t; value : std_ulogic_vector) is
  begin
    push_boolean(queue, value'ascending);
    push_integer(queue, value'left);
    push_integer(queue, value'right);
    for i in value'range loop
      push_std_ulogic(queue, value(i));
    end loop;
  end;

  impure function pop(queue : queue_t) return std_ulogic_vector is
    variable is_ascending : boolean;
    variable left_idx, right_idx : integer;

    impure function ascending_std_ulogic_vector return std_ulogic_vector is
      variable result : std_ulogic_vector(left_idx to right_idx);
    begin
      for i in left_idx to right_idx loop
        result(i) := pop_std_ulogic(queue);
      end loop;
      return result;
    end;

    impure function descending_std_ulogic_vector return std_ulogic_vector is
      variable result : std_ulogic_vector(left_idx downto right_idx);
    begin
      for i in left_idx downto right_idx loop
        result(i) := pop_std_ulogic(queue);
      end loop;
      return result;
    end;

  begin
    is_ascending := pop_boolean(queue);
    left_idx := pop_integer(queue);
    right_idx := pop_integer(queue);

    if is_ascending then
      return ascending_std_ulogic_vector;
    else
      return descending_std_ulogic_vector;
    end if;
  end;

  procedure push(queue : queue_t; value : string) is
  begin
    push_boolean(queue, value'ascending);
    push_integer(queue, value'left);
    push_integer(queue, value'right);

    for i in value'range loop
      push_character(queue, value(i));
    end loop;
  end procedure;

  impure function pop(queue : queue_t) return string is
    variable is_ascending : boolean;
    variable left_idx, right_idx : integer;

    impure function ascending_string return string is
      variable result : string(left_idx to right_idx);
    begin
      for i in left_idx to right_idx loop
        result(i) := pop_character(queue);
      end loop;
      return result;
    end;

    impure function descending_string return string is
      variable result : string(left_idx downto right_idx);
    begin
      for i in left_idx downto right_idx loop
        result(i) := pop_character(queue);
      end loop;
      return result;
    end;

  begin
    is_ascending := pop_boolean(queue);
    left_idx := pop_integer(queue);
    right_idx := pop_integer(queue);

    if is_ascending then
      return ascending_string;
    else
      return descending_string;
    end if;
  end;

  procedure push(queue : queue_t; value : time) is
    constant time_str : string := time'image(value);
  begin
    push_string(queue, time_str);
  end;

  impure function pop(queue : queue_t) return time is
    constant time_str : string := pop_string(queue);
  begin
    return time'value(time_str);
  end;

  procedure push(queue : queue_t; value : integer_vector_ptr_t) is
  begin
    push_integer(queue, to_integer(value));
  end;

  impure function pop(queue : queue_t) return integer_vector_ptr_t is
  begin
    return to_integer_vector_ptr(pop_integer(queue));
  end;

  procedure push(queue : queue_t; value : string_ptr_t) is
  begin
    push_integer(queue, to_integer(value));
  end;

  impure function pop(queue : queue_t) return string_ptr_t is
  begin
    return to_string_ptr(pop_integer(queue));
  end;

  procedure push(queue : queue_t; value : queue_t) is
  begin
    push_integer_vector_ptr_ref(queue, value.p_meta);
    push_string_ptr_ref(queue, value.data);
  end;

  -- Pop a queue reference from the queue
  impure function pop(queue : queue_t) return queue_t is
    variable result : queue_t;
  begin
    result.p_meta := pop_integer_vector_ptr_ref(queue);
    result.data := pop_string_ptr_ref(queue);
    return result;
  end;

end package body;
