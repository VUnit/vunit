-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.integer_vector_ptr_pkg.all;
use work.queue_pkg.all;

package integer_vector_ptr_pool_pkg is
  type integer_vector_ptr_pool_t is record
    ptrs : queue_t;
  end record;
  constant null_integer_vector_ptr_pool : integer_vector_ptr_pool_t := (others => null_queue);

  impure function new_integer_vector_ptr_pool
  return integer_vector_ptr_pool_t;

  impure function new_integer_vector_ptr (
    pool       : integer_vector_ptr_pool_t;
    min_length : natural := 0
  ) return integer_vector_ptr_t;

  procedure recycle (
    pool         : integer_vector_ptr_pool_t;
    variable ptr : inout integer_vector_ptr_t
  );
end package;

package body integer_vector_ptr_pool_pkg is
  impure function new_integer_vector_ptr_pool
  return integer_vector_ptr_pool_t is begin
    return (ptrs => new_queue);
  end;

  impure function new_integer_vector_ptr (
    pool       : integer_vector_ptr_pool_t;
    min_length : natural := 0
  ) return integer_vector_ptr_t is
    variable ptr : integer_vector_ptr_t;
  begin
    if length(pool.ptrs) > 0 then
      -- Reuse
      ptr := pop_integer_vector_ptr_ref(pool.ptrs);
      if length(ptr) < min_length then
        reallocate(ptr, min_length);
      end if;
    else
      -- Allocate new
      ptr := new_integer_vector_ptr(min_length);
    end if;
    return ptr;
  end;

  procedure recycle (
    pool         : integer_vector_ptr_pool_t;
    variable ptr : inout integer_vector_ptr_t
  ) is begin
    if ptr = null_ptr then
      return;
    end if;
    push_integer_vector_ptr_ref(pool.ptrs, ptr);
    ptr := null_ptr;
  end;

end package body;
