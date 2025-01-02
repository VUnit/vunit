-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.integer_vector_ptr_pkg.all;

package integer_vector_ptr_pool_pkg is
  type integer_vector_ptr_pool_t is record
    p_data : integer_vector_ptr_t;
  end record;
  constant pool_idx : natural := 0;
  constant length_idx : natural := 1;
  constant max_length_idx : natural := 2;

  constant null_integer_vector_ptr_pool : integer_vector_ptr_pool_t := (p_data => null_integer_vector_ptr);

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
  constant pool_size_increment : positive := 2 ** 16;

  impure function new_integer_vector_ptr_pool
  return integer_vector_ptr_pool_t is
    variable pool : integer_vector_ptr_pool_t;
  begin
    pool.p_data := new_integer_vector_ptr(3);
    set(pool.p_data, pool_idx, to_integer(new_integer_vector_ptr(pool_size_increment)));
    set(pool.p_data, length_idx, 0);
    set(pool.p_data, max_length_idx, pool_size_increment);

    return pool;
  end;

  impure function new_integer_vector_ptr (
    pool       : integer_vector_ptr_pool_t;
    min_length : natural := 0
  ) return integer_vector_ptr_t is
    variable ptr : integer_vector_ptr_t;
    constant len : natural := get(pool.p_data, length_idx);
  begin
    if len > 0 then
      -- Reuse
      ptr.ref := get(to_integer_vector_ptr(get(pool.p_data, pool_idx)), len - 1);
      set(pool.p_data, length_idx, len - 1);
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
  ) is
    constant len : natural := get(pool.p_data, length_idx);
    constant max_len : natural := get(pool.p_data, max_length_idx);
  begin
    if ptr = null_ptr then
      return;
    end if;

    if len = max_len then
      resize(to_integer_vector_ptr(get(pool.p_data, pool_idx)), max_len + pool_size_increment);
      set(pool.p_data, max_length_idx, max_len + pool_size_increment);
    end if;

    set(to_integer_vector_ptr(get(pool.p_data, pool_idx)), len, ptr.ref);
    set(pool.p_data, length_idx, len + 1);
    ptr := null_ptr;
  end;

end package body;
