-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
use work.string_ptr_pkg.all;
use work.queue_pkg.all;

package string_ptr_pool_pkg is

  type string_ptr_pool_t is record
    ptrs : queue_t;
  end record;
  constant null_string_ptr_pool : string_ptr_pool_t := (others => null_queue);

  impure function allocate return string_ptr_pool_t;
  impure function allocate(pool : string_ptr_pool_t; min_length : natural := 0) return string_ptr_t;
  procedure recycle(pool : string_ptr_pool_t; variable ptr : inout string_ptr_t);

end package;

package body string_ptr_pool_pkg is

  impure function allocate return string_ptr_pool_t is
  begin
    return (ptrs => allocate);
  end;

  impure function allocate(pool : string_ptr_pool_t; min_length : natural := 0) return string_ptr_t is
    variable ptr : string_ptr_t;
  begin
    if length(pool.ptrs) > 0 then
      -- Reuse
      ptr := to_string_ptr(pop(pool.ptrs));

      if length(ptr) < min_length then
        reallocate(ptr, min_length);
      end if;
    else

      -- Allocate new
      ptr := allocate(min_length);
    end if;
    return ptr;
  end;

  procedure recycle(pool : string_ptr_pool_t; variable ptr : inout string_ptr_t) is
  begin
    if ptr = null_string_ptr then
      return;
    end if;

    push(pool.ptrs, to_integer(ptr));
    ptr := null_string_ptr;
  end procedure;

end package body;
