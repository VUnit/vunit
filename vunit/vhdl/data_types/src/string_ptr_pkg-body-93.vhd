-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.codec_pkg.all;
use work.codec_builder_pkg.all;

package body string_ptr_pkg is
  type string_access_t is access string;
  type string_access_vector_t is array (natural range <>) of string_access_t;
  type string_access_vector_access_t is access string_access_vector_t;

  shared variable current_index : integer := 0;
  shared variable ptrs : string_access_vector_access_t := null;

  impure function allocate(length : natural := 0) return string_ptr_t is
    variable old_ptrs : string_access_vector_access_t;
    variable retval : string_ptr_t := (index => current_index);
  begin

    if ptrs = null then
      ptrs := new string_access_vector_t'(0 => null);
    elsif ptrs'length <= current_index then
      -- Reallocate ptr pointers to larger ptr
      -- Use more size to trade size for speed
      old_ptrs := ptrs;
      ptrs := new string_access_vector_t'(0 to ptrs'length + 2**16 => null);
      for i in old_ptrs'range loop
        ptrs(i) := old_ptrs(i);
      end loop;
      deallocate(old_ptrs);
    end if;

    ptrs(current_index) := new string'(1 to length => character'low);
    current_index := current_index + 1;
    return retval;
  end function;

  procedure deallocate(ptr : string_ptr_t) is
  begin
    deallocate(ptrs(ptr.index));
    ptrs(ptr.index) := null;
  end procedure;

  impure function length(ptr : string_ptr_t) return integer is
  begin
    return ptrs(ptr.index)'length;
  end function;

  procedure set(ptr : string_ptr_t; index : integer; value : character) is
  begin
    ptrs(ptr.index)(index) := value;
  end procedure;

  impure function get(ptr : string_ptr_t; index : integer) return character is
  begin
    return ptrs(ptr.index)(index);
  end function;

  procedure reallocate(ptr : string_ptr_t; length : natural) is
    variable old_ptr, new_ptr : string_access_t;
  begin
    deallocate(ptrs(ptr.index));
    ptrs(ptr.index) := new string'(1 to length => character'low);
  end procedure;

  procedure reallocate(ptr : string_ptr_t; value : string) is
    variable old_ptr, new_ptr : string_access_t;
  begin
    deallocate(ptrs(ptr.index));
    ptrs(ptr.index) := new string'(value);
  end procedure;

  procedure resize(ptr : string_ptr_t; length : natural; drop : natural := 0) is
    variable old_ptr, new_ptr : string_access_t;
    variable min_length : natural := length;
  begin
    new_ptr := new string'(1 to length => character'low);
    old_ptr := ptrs(ptr.index);

    if min_length > old_ptr'length - drop then
      min_length := old_ptr'length - drop;
    end if;

    for i in 1 to min_length loop
      new_ptr(i) := old_ptr(drop + i);
    end loop;

    ptrs(ptr.index) := new_ptr;
    deallocate(old_ptr);
  end procedure;

  impure function to_string(ptr : string_ptr_t) return string is
  begin
    return ptrs(ptr.index).all;
  end;

  function to_integer(value : string_ptr_t) return integer is
  begin
    return value.index;
  end function;

  impure function to_string_ptr(value : integer) return string_ptr_t is
  begin
    -- @TODO maybe assert that the index is valid
    return (index => value);
  end function;

  impure function allocate(value : string) return string_ptr_t is
    variable result : string_ptr_t := allocate(value'length);
  begin
    for i in 1 to value'length loop
      set(result, i, value(i));
    end loop;
    return result;
  end function;

  function encode(data : string_ptr_t) return string is
  begin
    return encode(data.index);
  end;

  function decode(code : string) return string_ptr_t is
    variable ret_val : string_ptr_t;
    variable index : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  procedure decode (constant code : string; variable index : inout positive; variable result : out string_ptr_t) is
  begin
    decode(code, index, result.index);
  end;

end package body;
