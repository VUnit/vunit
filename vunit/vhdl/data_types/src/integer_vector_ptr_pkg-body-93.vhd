-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

package body integer_vector_ptr_pkg is

  -- Pointer storage
  shared variable storage : vava_t := new vav_t'(0 to 2**16 - 1 => null);
  shared variable storage_index : natural := 0;

  -- Stack of unused storage indices
  shared variable stack : integer_vector_access_t := new integer_vector_t'(0 to 2**16 - 1 => -1);
  shared variable stack_index : natural := 0;

  procedure reallocate_storage (
    length : positive
  ) is
    variable old_storage : vava_t;
  begin
    old_storage := storage;
    storage := new vav_t'(0 to length - 1 => null);
    for i in old_storage'range loop
      storage(i) := old_storage(i);
    end loop;
    deallocate(old_storage);
  end;

  procedure reallocate_stack (
    length : positive
  ) is
    variable old_stack : integer_vector_access_t;
  begin
    old_stack := stack;
    stack := new integer_vector_t'(0 to length - 1 => -1);
    for i in old_stack'range loop
      stack(i) := old_stack(i);
    end loop;
    deallocate(old_stack);
  end;

  impure function new_integer_vector_ptr (
    length : natural := 0;
    value  : val_t   := 0
  ) return ptr_t is
    variable ref : index_t;
  begin
    if stack_index > 0 then
      stack_index := stack_index - 1;
      ref := stack(stack_index);
    else
      if storage_index >= storage'length then
        reallocate_storage(storage'length + 2**16);
      end if;
      ref := storage_index;
      storage_index := storage_index + 1;
    end if;
    storage(ref) := new vec_t'(0 to length - 1 => value);
    return (ref => ref);
  end;

  procedure deallocate (
    ptr : ptr_t
  ) is begin
    if stack_index >= stack'length then
      reallocate_stack(stack'length + 2**16);
    end if;
    stack(stack_index) := ptr.ref;
    stack_index := stack_index + 1;
    deallocate(storage(ptr.ref));
    storage(ptr.ref) := null;
  end;

  impure function length (
    ptr : ptr_t
  ) return integer is begin
    return storage(ptr.ref)'length;
  end;

  procedure set (
    ptr   : ptr_t;
    index : natural;
    value : val_t
  ) is begin
    storage(ptr.ref)(index) := value;
  end;

  impure function get (
    ptr   : ptr_t;
    index : natural
  ) return val_t is begin
    return storage(ptr.ref)(index);
  end;

  procedure reallocate (
    ptr    : ptr_t;
    length : natural;
    value  : val_t := 0
  ) is begin
    deallocate(storage(ptr.ref));
    storage(ptr.ref) := new vec_t'(0 to length - 1 => value);
  end;

  procedure resize (
    ptr    : ptr_t;
    length : natural;
    rotate : natural := 0;
    value  : val_t := 0
  ) is
    variable old_ptr : va_t := storage(ptr.ref);
    variable new_ptr : va_t := new vec_t'(0 to length - 1 => value);
    variable min_length : natural := old_ptr'length;
  begin
    if length < old_ptr'length then
      min_length := length;
    end if;
    for i in 0 to min_length - 1 loop
      new_ptr(i) := old_ptr((rotate + i) mod old_ptr'length);
    end loop;
    storage(ptr.ref) := new_ptr;
    deallocate(old_ptr);
  end;

  function to_integer (
    value : ptr_t
  ) return integer is begin
    return value.ref;
  end;

  impure function to_integer_vector_ptr (
    value : val_t
  ) return ptr_t is begin
    -- @TODO maybe assert that the ref is valid
    return (ref => value);
  end;

  function encode (
    data : ptr_t
  ) return string is begin
    return encode(data.ref);
  end;

  function decode (
    code : string
  ) return ptr_t is
    variable ret_val : ptr_t;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);
    return ret_val;
  end;

  procedure decode (
    constant code   : string;
    variable index  : inout positive;
    variable result : out ptr_t
  ) is begin
    decode(code, index, result.ref);
  end;

end package body;

