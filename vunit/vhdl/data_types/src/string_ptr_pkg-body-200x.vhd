-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

use work.integer_vector_pkg.all;

package body string_ptr_pkg is

  type string_ptr_storage_t is protected

    impure function new_ptr (
      length : natural := 0
    ) return natural;

    impure function new_ptr (
      value : vec_t
    ) return natural;

    procedure deallocate (
      ref : natural
    );

    procedure reallocate_storage (
      length : positive
    );

    procedure reallocate_stack (
      length : positive
    );

    impure function length (
      ref : natural
    ) return integer;

    procedure set (
      ref   : natural;
      index : natural;
      value : val_t
    );

    impure function get (
      ref   : natural;
      index : natural
    ) return val_t;

    procedure reallocate (
      ref    : natural;
      length : natural
    );

    procedure reallocate (
      ref   : natural;
      value : vec_t
    );

    procedure resize (
      ref    : natural;
      length : natural
    );

    impure function to_string (
      ref : natural
    ) return string;

  end protected;

  type string_ptr_storage_t is protected body

    -- Pointer storage
    variable storage : vava_t := new vav_t'(0 to 2**16 - 1 => null);
    variable storage_index : natural := 0;

    -- Stack of unused storage indices
    variable stack : integer_vector_access_t := new integer_vector_t'(0 to 2**16 - 1 => -1);
    variable stack_index : natural := 0;

    impure function new_ptr (
      length : natural := 0
    ) return natural is
      constant value : vec_t(1 to length) := (others => val_t'low);
    begin
      return new_ptr(value);
    end;

    impure function new_ptr (
      value : vec_t
    ) return natural is
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
      storage(ref) := new vec_t'(value);
      return ref;
    end;

    procedure deallocate (
      ref : natural
    ) is begin
      if stack_index >= stack'length then
        reallocate_stack(stack'length + 2**16);
      end if;
      stack(stack_index) := ref;
      stack_index := stack_index + 1;
      deallocate(storage(ref));
      storage(ref) := null;
    end;

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

    impure function length (
      ref : natural
    ) return integer is begin
      return storage(ref)'length;
    end;

    procedure set (
      ref   : natural;
      index : natural;
      value : val_t
    ) is begin
      storage(ref)(index) := value;
    end;

    impure function get (
      ref   : natural;
      index : natural
    ) return val_t is begin
      return storage(ref)(index);
    end;

    procedure reallocate (
      ref    : natural;
      length : natural
    ) is
      variable value : vec_t(1 to length) := (others => val_t'low);
    begin
      reallocate(ref, value);
    end;

    procedure reallocate (
      ref   : natural;
      value : vec_t
    ) is begin
      deallocate(storage(ref));
      storage(ref) := new vec_t'(value);
    end;

    procedure resize (
      ref    : natural;
      length : natural
    ) is
      variable old_ptr : va_t := storage(ref);
      variable new_ptr : va_t := new vec_t'(1 to length => val_t'low);
      variable min_length : natural := old_ptr'length;
    begin
      if length < old_ptr'length then
        min_length := length;
      end if;
      for i in 1 to min_length loop
        new_ptr(i) := old_ptr(i);
      end loop;
      storage(ref) := new_ptr;
      deallocate(old_ptr);
    end;

    impure function to_string (
      ref : natural
    ) return string is begin
      return storage(ref).all;
    end;

  end protected body;

  shared variable ptr_storage : string_ptr_storage_t;

  function to_integer (
    value : ptr_t
  ) return integer is begin
    return value.ref;
  end;

  impure function to_string_ptr (
    value : integer
  ) return ptr_t is begin
    -- @TODO maybe assert that the ref is valid
    return (ref => value);
  end;

  impure function new_string_ptr (
    length : natural := 0
  ) return ptr_t is begin
    return (ref => ptr_storage.new_ptr(length));
  end;

  impure function new_string_ptr (
    value : vec_t
  ) return ptr_t is begin
    return (ref => ptr_storage.new_ptr(value));
  end;

  procedure deallocate (
    ptr : ptr_t
  ) is begin
    ptr_storage.deallocate(ptr.ref);
  end;

  impure function length (
    ptr : ptr_t
  ) return integer is begin
    return ptr_storage.length(ptr.ref);
  end;

  procedure set (
    ptr   : ptr_t;
    index : natural;
    value : val_t
  ) is begin
    ptr_storage.set(ptr.ref, index, value);
  end;

  impure function get (
    ptr   : ptr_t;
    index : natural
  ) return val_t is begin
    return ptr_storage.get(ptr.ref, index);
  end;

  procedure reallocate (
    ptr    : ptr_t;
    length : natural
  ) is begin
    ptr_storage.reallocate(ptr.ref, length);
  end;

  procedure reallocate (
    ptr   : ptr_t;
    value : vec_t
  ) is begin
    ptr_storage.reallocate(ptr.ref, value);
  end;

  procedure resize (
    ptr    : ptr_t;
    length : natural
  ) is begin
    ptr_storage.resize(ptr.ref, length);
  end;

  impure function to_string (
    ptr : ptr_t
  ) return string is begin
    return ptr_storage.to_string(ptr.ref);
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

