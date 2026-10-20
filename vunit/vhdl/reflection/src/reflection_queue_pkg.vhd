-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com
--
-- reflection_queue_pkg pushes values of any type onto a queue_t and pops them back.
--
-- Instantiate once per type in an architecture or package, then push and pop like the queue_pkg types:
--
--   package packet_queue is new vunit_lib.reflection_queue_pkg generic map (t => packet_t);
--   use packet_queue.all;
--   ...
--   push(queue, packet);
--   packet := pop(queue);
--
-- A value can't be rebuilt from its parts in VHDL, so push keeps a copy of the value in a store owned by
-- the instance and pushes a handle to it. pop takes the value back out of the store. The queue therefore
-- holds a handle rather than the data: encoding or copying the queue doesn't copy the values, and a
-- value that is never popped stays in the store.

use work.integer_vector_ptr_pkg.all;
use work.logger_pkg.all;
use work.queue_pkg.all;

package reflection_queue_pkg is
  generic (type t);

  -- Errors go to the logger "vunit_lib:reflection_queue_pkg", shared by all instances

  procedure push(queue : queue_t; value : t);
  impure function pop(queue : queue_t) return t;
end package;

package body reflection_queue_pkg is
  constant logger : logger_t := get_logger("vunit_lib:reflection_queue_pkg");

  type value_ptr_t is access t;
  type value_ptr_vec_t is array (natural range <>) of value_ptr_t;
  type value_ptr_vec_ptr_t is access value_ptr_vec_t;

  type store_t is protected
    impure function add(value : t) return natural;
    impure function get(handle : natural) return t;
    procedure remove(handle : natural);
  end protected;

  type store_t is protected body
    variable values : value_ptr_vec_ptr_t := new value_ptr_vec_t(0 to 15);
    -- Handles of removed values, reused before the store grows
    variable free_handles : integer_vector(0 to 15);
    variable n_free : natural := 0;
    variable n_used : natural := 0;

    impure function add(value : t) return natural is
      variable handle : natural;
      variable grown : value_ptr_vec_ptr_t;
    begin
      if n_free > 0 then
        n_free := n_free - 1;
        handle := free_handles(n_free);
      else
        if n_used > values'high then
          grown := new value_ptr_vec_t(0 to 2 * values'length - 1);
          grown(values'range) := values.all;
          deallocate(values);
          values := grown;
        end if;
        handle := n_used;
        n_used := n_used + 1;
      end if;
      values(handle) := new t'(value);
      return handle;
    end;

    impure function get(handle : natural) return t is
    begin
      return values(handle).all;
    end;

    procedure remove(handle : natural) is
    begin
      deallocate(values(handle));
      if n_free <= free_handles'high then
        free_handles(n_free) := handle;
        n_free := n_free + 1;
      end if;
    end;
  end protected body;

  shared variable store : store_t;

  -- Identifies the values of this instance on a queue. Each instance allocates its own pointer, so the
  -- pointers differ. 'path_name of store doesn't, since NVC leaves out the package instance.
  constant instance_id : integer := to_integer(new_integer_vector_ptr);

  procedure push(queue : queue_t; value : t) is
  begin
    push_integer(queue, instance_id);
    push_integer(queue, store.add(value));
  end;

  impure function take(handle : natural) return t is
    constant value : t := store.get(handle);
  begin
    store.remove(handle);
    return value;
  end;

  impure function pop(queue : queue_t) return t is
    constant item_instance_id : integer := pop_integer(queue);
    constant handle : integer := pop_integer(queue);
  begin
    if item_instance_id /= instance_id then
      -- path_offset 1 gives the location of the pop call
      failure(logger, "The next item on the queue was not pushed by this instance.", 1);
    end if;
    return take(handle);
  end;
end package body;
