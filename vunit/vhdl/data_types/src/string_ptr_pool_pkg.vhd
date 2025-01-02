-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.string_ptr_pkg.all;
use work.integer_vector_ptr_pkg.all;

package string_ptr_pool_pkg is
  type string_ptr_pool_t is record
    p_data : integer_vector_ptr_t;
  end record;
  constant pool_idx : natural := 0;
  constant length_idx : natural := 1;
  constant max_length_idx : natural := 2;

  constant null_string_ptr_pool : string_ptr_pool_t := (p_data => null_integer_vector_ptr);

  impure function new_string_ptr_pool
  return string_ptr_pool_t;

  impure function new_string_ptr(
    pool : string_ptr_pool_t;
    min_length : natural := 0
  ) return string_ptr_t;

  impure function new_string_ptr(
    pool : string_ptr_pool_t;
    value : string
  ) return string_ptr_t;

  procedure recycle(
    pool : string_ptr_pool_t;
    variable ptr : inout string_ptr_t
  );
end package;

package body string_ptr_pool_pkg is
  constant pool_size_increment : positive := 2 ** 16;

  impure function new_string_ptr_pool
  return string_ptr_pool_t is
    variable pool : string_ptr_pool_t;
  begin
    pool.p_data := new_integer_vector_ptr(3);
    set(pool.p_data, pool_idx, to_integer(new_integer_vector_ptr(pool_size_increment)));
    set(pool.p_data, length_idx, 0);
    set(pool.p_data, max_length_idx, pool_size_increment);

    return pool;
  end;

  impure function new_string_ptr(
    pool : string_ptr_pool_t;
    min_length : natural := 0
  ) return string_ptr_t is
    variable ptr : string_ptr_t;
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
      ptr := new_string_ptr(min_length);
    end if;
    return ptr;
  end;

  impure function new_string_ptr(
    pool : string_ptr_pool_t;
    value : string
  ) return string_ptr_t is
    variable ptr : string_ptr_t;
    constant len : natural := get(pool.p_data, length_idx);
  begin
    if len > 0 then
      -- Reuse
      ptr.ref := get(to_integer_vector_ptr(get(pool.p_data, pool_idx)), len - 1);
      set(pool.p_data, length_idx, len - 1);
      reallocate(ptr, value);
    else
      -- Allocate new
      ptr := new_string_ptr(value);
    end if;
    return ptr;
  end;

  procedure recycle(
    pool : string_ptr_pool_t;
    variable ptr : inout string_ptr_t
  ) is
    constant len : natural := get(pool.p_data, length_idx);
    constant max_len : natural := get(pool.p_data, max_length_idx);
  begin
    if ptr = null_string_ptr then
      return;
    end if;

    if len = max_len then
      resize(to_integer_vector_ptr(get(pool.p_data, pool_idx)), max_len + pool_size_increment);
      set(pool.p_data, max_length_idx, max_len + pool_size_increment);
    end if;

    set(to_integer_vector_ptr(get(pool.p_data, pool_idx)), len, ptr.ref);
    set(pool.p_data, length_idx, len + 1);
    ptr := null_string_ptr;
  end;
end package body;
