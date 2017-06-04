-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
use work.integer_vector_ptr_pkg.all;

package integer_vector_ptr_pool_pkg is

  type integer_vector_ptr_pool_t is record
    num_ptrs : integer_vector_ptr_t;
    ptrs : integer_vector_ptr_t;
  end record;
  constant null_integer_vector_ptr_pool : integer_vector_ptr_pool_t := (others => null_ptr);

  impure function allocate return integer_vector_ptr_pool_t;
  impure function allocate(pool : integer_vector_ptr_pool_t; min_length : natural := 0) return integer_vector_ptr_t;
  procedure recycle(pool : integer_vector_ptr_pool_t; variable ptr : inout integer_vector_ptr_t);

end package;

package body integer_vector_ptr_pool_pkg is

  impure function allocate return integer_vector_ptr_pool_t is
    variable result : integer_vector_ptr_pool_t;
  begin
    result.num_ptrs := allocate(1);
    set(result.num_ptrs, 0, 0);
    result.ptrs := allocate(0);
    return result;
  end;

  impure function allocate(pool : integer_vector_ptr_pool_t; min_length : natural := 0) return integer_vector_ptr_t is
    constant num_ptrs : integer := get(pool.num_ptrs, 0);
    variable ptr : integer_vector_ptr_t;
  begin
    if num_ptrs > 0 then
      -- Reuse
      ptr := to_integer_vector_ptr(get(pool.ptrs, num_ptrs-1));
      set(pool.num_ptrs, 0, num_ptrs-1);
      if length(ptr) < min_length then
        reallocate(ptr, min_length);
      end if;
    else
      -- Allocate new
      ptr := allocate(min_length);
    end if;
    return ptr;
  end;

  procedure recycle(pool : integer_vector_ptr_pool_t; variable ptr : inout integer_vector_ptr_t) is
    constant num_ptrs : integer := get(pool.num_ptrs, 0);
  begin
    if ptr = null_ptr then
      return;
    end if;
    set(pool.num_ptrs, 0, num_ptrs+1);
    if length(pool.ptrs) < num_ptrs+1 then
      resize(pool.ptrs, num_ptrs+1);
    end if;
    set(pool.ptrs, num_ptrs, to_integer(ptr));

    -- @TODO check that this is set to null ptr
    ptr := null_ptr;
  end procedure;


end package body;
