-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

package body string_ptr_pkg is
  type string_access_t is access string;
  type string_access_vector_t is array (natural range <>) of string_access_t;
  type string_access_vector_access_t is access string_access_vector_t;

  shared variable current_index : integer := 0;
  shared variable ptrs : vava_t := null;

  impure function
  new_string_ptr(
    length : natural := 0
  ) return ptr_t is
    variable old_ptrs : vava_t;
    variable retval : ptr_t := (index => current_index);
  begin
    if ptrs = null then
      ptrs := new vav_t'(0 => null);
    elsif ptrs'length <= current_index then
      -- Reallocate ptr pointers to larger ptr
      -- Use more size to trade size for speed
      old_ptrs := ptrs;
      ptrs := new vav_t'(0 to ptrs'length + 2**16 => null);
      for i in old_ptrs'range loop
        ptrs(i) := old_ptrs(i);
      end loop;
      deallocate(old_ptrs);
    end if;
    ptrs(current_index) := new string'(1 to length => val_t'low);
    current_index := current_index + 1;
    return retval;
  end;

  procedure
  deallocate(
    ptr : ptr_t
  ) is begin
    deallocate(ptrs(ptr.index));
    ptrs(ptr.index) := null;
  end;

  impure function
  length(
    ptr : ptr_t
  ) return integer is begin
    return ptrs(ptr.index)'length;
  end;

  procedure
  set(
    ptr   : ptr_t;
    index : integer;
    value : val_t
  ) is begin
    ptrs(ptr.index)(index) := value;
  end;

  impure function
  get(
    ptr   : ptr_t;
    index : integer
  ) return val_t is begin
    return ptrs(ptr.index)(index);
  end;

  procedure
  reallocate(
    ptr    : ptr_t;
    length : natural
  ) is
    variable old_ptr, new_ptr : string_access_t;
  begin
    deallocate(ptrs(ptr.index));
    ptrs(ptr.index) := new string'(1 to length => val_t'low);
  end;

  procedure
  reallocate(
    ptr   : ptr_t;
    value : string
  ) is
    variable old_ptr, new_ptr : string_access_t;
    variable n_value : string(1 to value'length) := value;
  begin
    deallocate(ptrs(ptr.index));
    ptrs(ptr.index) := new string'(n_value);
  end;

  procedure
  resize(
    ptr    : ptr_t;
    length : natural;
    drop   : natural := 0
  ) is
    variable old_ptr, new_ptr : string_access_t;
    variable min_length : natural := length;
  begin
    new_ptr := new string'(1 to length => val_t'low);
    old_ptr := ptrs(ptr.index);

    if min_length > old_ptr'length - drop then
      min_length := old_ptr'length - drop;
    end if;

    for i in 1 to min_length loop
      new_ptr(i) := old_ptr(drop + i);
    end loop;

    ptrs(ptr.index) := new_ptr;
    deallocate(old_ptr);
  end;

  impure function
  to_string(
    ptr : ptr_t
  ) return string is begin
    return ptrs(ptr.index).all;
  end;

  function
  to_integer(
    value : ptr_t
  ) return integer is begin
    return value.index;
  end;

  impure function
  to_string_ptr(
    value : integer
  ) return ptr_t is begin
    -- @TODO maybe assert that the index is valid
    return (index => value);
  end;

  impure function
  new_string_ptr(
    value : string
  ) return ptr_t is
    variable result : ptr_t := new_string_ptr(value'length);
    variable n_value : string(1 to value'length) := value;
  begin
    for i in 1 to n_value'length loop
      set(result, i, n_value(i));
    end loop;
    return result;
  end;

  function
  encode(
    data : ptr_t
  ) return string is begin
    return encode(data.index);
  end;

  function
  decode(
    code : string
  ) return ptr_t is
    variable ret_val : ptr_t;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);
    return ret_val;
  end;

  procedure
  decode(
    constant code   : string;
    variable index  : inout positive;
    variable result : out ptr_t
  ) is begin
    decode(code, index, result.index);
  end;

end package body;
