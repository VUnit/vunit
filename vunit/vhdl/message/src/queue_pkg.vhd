-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.integer_vector_ptr_pkg.all;
use work.integer_vector_ptr_pool_pkg.all;

package queue_pkg is

  type queue_t is record
    head : integer_vector_ptr_t;
    tail : integer_vector_ptr_t;
    data : integer_vector_ptr_t;
  end record;
  constant num_words_per_queue : natural := 3;

  constant null_queue : queue_t := (head => null_ptr, tail => null_ptr, data => null_ptr);

  impure function allocate return queue_t;
  impure function length(queue : queue_t) return integer;
  procedure flush(queue : queue_t);

  procedure push(queue : queue_t; value : integer);
  impure function pop(queue : queue_t) return integer;

  procedure push_boolean(queue : queue_t; value : boolean);
  impure function pop_boolean(queue : queue_t) return boolean;

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

  impure function allocate return queue_t is
  begin
    return (head => allocate(1),
            tail => allocate(1),
            data => allocate);
  end;

  impure function length(queue : queue_t) return integer is
    variable head : integer := get(queue.head, 0);
    variable tail : integer := get(queue.tail, 0);
  begin
    return tail - head;
  end;

  procedure flush(queue : queue_t) is
  begin
    assert queue /= null_queue report "Flush null queue";
    set(queue.head, 0, 0);
    set(queue.tail, 0, 0);
  end;

  procedure push(queue : queue_t; value : integer) is
    variable tail : integer;
  begin
    assert queue /= null_queue report "Push to null queue";
    tail := get(queue.tail, 0);
    if length(queue.data) < tail+1 then
      -- Allocate more new data to avoid linear copy
      resize(queue.data, length(queue.data)+tail+1);
    end if;
    set(queue.data, tail, value);
    set(queue.tail, 0, tail+1);
  end;

  impure function pop(queue : queue_t) return integer is
    variable head : integer;
    variable data : integer;
  begin
    assert queue /= null_queue report "Pop from null queue";
    assert length(queue) > 0 report "Pop from empty queue";
    head := get(queue.head, 0);
    data := get(queue.data, head);
    set(queue.head, 0, head+1);
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
    push_integer_vector_ptr_ref(queue, value.head);
    push_integer_vector_ptr_ref(queue, value.tail);
    push_integer_vector_ptr_ref(queue, value.data);
  end;

  -- Pop a queue reference from the queue
  impure function pop_queue_ref(queue : queue_t) return queue_t is
    variable result : queue_t;
  begin
    result.head := pop_integer_vector_ptr_ref(queue);
    result.tail := pop_integer_vector_ptr_ref(queue);
    result.data := pop_integer_vector_ptr_ref(queue);
    return result;
  end;
end package body;
