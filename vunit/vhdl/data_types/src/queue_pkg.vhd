-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.float_pkg.all;

use work.integer_vector_ptr_pkg.all;

package queue_pkg is

  type queue_t is record
    p_meta : integer_vector_ptr_t;
    data : integer_vector_ptr_t;
  end record;
  constant num_words_per_queue : natural := 2;

  constant null_queue : queue_t := (p_meta => null_ptr, data => null_ptr);

  impure function allocate return queue_t;
  impure function length(queue : queue_t) return integer;
  procedure flush(queue : queue_t);

  procedure push(queue : queue_t; value : integer);
  impure function pop(queue : queue_t) return integer;

  procedure push_boolean(queue : queue_t; value : boolean);
  impure function pop_boolean(queue : queue_t) return boolean;

  procedure push_real(queue : queue_t; value : real);
  impure function pop_real(queue : queue_t) return real;

  procedure push_std_ulogic(queue : queue_t; value : std_ulogic);
  impure function pop_std_ulogic(queue : queue_t) return std_ulogic;

  procedure push_std_ulogic_vector(queue : queue_t; value : std_ulogic_vector);
  impure function pop_std_ulogic_vector(queue : queue_t) return std_ulogic_vector;

  procedure push_string(queue : queue_t; value : string);
  impure function pop_string(queue : queue_t) return string;

  procedure push_integer_vector_ptr_ref(queue : queue_t; value : integer_vector_ptr_t);
  impure function pop_integer_vector_ptr_ref(queue : queue_t) return integer_vector_ptr_t;

  procedure push_queue_ref(queue : queue_t; value : queue_t);
  impure function pop_queue_ref(queue : queue_t) return queue_t;

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

  procedure push(queue : queue_t; value : integer) is
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

    set(queue.data, tail, value);
    set(queue.p_meta, tail_idx, tail+1);
  end;

  impure function pop(queue : queue_t) return integer is
    variable head : integer;
    variable data : integer;
  begin
    assert queue /= null_queue report "Pop from null queue";
    assert length(queue) > 0 report "Pop from empty queue";
    head := get(queue.p_meta, head_idx);
    data := get(queue.data, head);
    set(queue.p_meta, head_idx, head+1);
    return data;
  end;

  procedure push_boolean(queue : queue_t; value : boolean) is
  begin
    if value then
      push(queue, 1);
    else
      push(queue, 0);
    end if;
  end;

  impure function pop_boolean(queue : queue_t) return boolean is
  begin
    return pop(queue) = 1;
  end;

  procedure push_real(queue : queue_t; value : real) is
    variable f64 : float64;
  begin
    f64 := to_float(value, f64);
    push_std_ulogic_vector(queue, to_slv(f64));
  end;

  impure function pop_real(queue : queue_t) return real is
    variable f64 : float64;
  begin
    f64 := to_float(pop_std_ulogic_vector(queue), f64);
    return to_real(f64);
  end;

  procedure push_std_ulogic(queue : queue_t; value : std_ulogic) is
  begin
    push(queue, std_ulogic'pos(value));
  end;

  impure function pop_std_ulogic(queue : queue_t) return std_ulogic is
  begin
    return std_ulogic'val(pop(queue));
  end;

  procedure push_std_ulogic_vector(queue : queue_t; value : std_ulogic_vector) is
  begin
    push_boolean(queue, value'ascending);
    push(queue, value'left);
    push(queue, value'right);
    for i in value'range loop
      push_std_ulogic(queue, value(i));
    end loop;
  end;

  impure function pop_std_ulogic_vector(queue : queue_t) return std_ulogic_vector is
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
    left_idx := pop(queue);
    right_idx := pop(queue);

    if is_ascending then
      return ascending_std_ulogic_vector;
    else
      return descending_std_ulogic_vector;
    end if;
  end;

  procedure push_string(queue : queue_t; value : string) is
  begin
    push_boolean(queue, value'ascending);
    push(queue, value'left);
    push(queue, value'right);
    for i in value'range loop
      push(queue, character'pos(value(i)));
    end loop;
  end procedure;

  impure function pop_string(queue : queue_t) return string is
    variable is_ascending : boolean;
    variable left_idx, right_idx : integer;

    impure function ascending_string return string is
      variable result : string(left_idx to right_idx);
    begin
      for i in left_idx to right_idx loop
        result(i) := character'val(pop(queue));
      end loop;
      return result;
    end;

    impure function descending_string return string is
      variable result : string(left_idx downto right_idx);
    begin
      for i in left_idx downto right_idx loop
        result(i) := character'val(pop(queue));
      end loop;
      return result;
    end;

  begin
    is_ascending := pop_boolean(queue);
    left_idx := pop(queue);
    right_idx := pop(queue);

    if is_ascending then
      return ascending_string;
    else
      return descending_string;
    end if;
  end;

  procedure push_integer_vector_ptr_ref(queue : queue_t; value : integer_vector_ptr_t) is
  begin
    push(queue, to_integer(value));
  end;

  impure function pop_integer_vector_ptr_ref(queue : queue_t) return integer_vector_ptr_t is
  begin
    return to_integer_vector_ptr(pop(queue));
  end;

  procedure push_queue_ref(queue : queue_t; value : queue_t) is
  begin
    push_integer_vector_ptr_ref(queue, value.p_meta);
    push_integer_vector_ptr_ref(queue, value.data);
  end;

  -- Pop a queue reference from the queue
  impure function pop_queue_ref(queue : queue_t) return queue_t is
    variable result : queue_t;
  begin
    result.p_meta := pop_integer_vector_ptr_ref(queue);
    result.data := pop_integer_vector_ptr_ref(queue);
    return result;
  end;
end package body;
