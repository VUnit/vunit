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

    procedure check_valid (
      ref : index_t
    );

    procedure deallocate (
      ref : index_t
    );

    procedure reallocate_storage (
      length : positive
    );

    procedure reallocate_stack (
      length : positive
    );

    impure function length (
      ref : index_t
    ) return natural;

    procedure set (
      ref   : index_t;
      index : positive;
      value : val_t
    );

    impure function get (
      ref   : index_t;
      index : positive
    ) return val_t;

    procedure reallocate (
      ref    : index_t;
      length : natural
    );

    procedure reallocate (
      ref   : index_t;
      value : vec_t
    );

    procedure resize (
      ref    : index_t;
      length : natural;
      drop   : natural := 0;
      rotate : natural := 0
    );

    impure function to_string (
      ref : index_t
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

    procedure check_valid (
      ref : index_t
    ) is begin
      assert 0 <= ref and ref < storage_index report "invalid pointer";
      assert storage(ref) /= null report "unallocated pointer";
    end;

    procedure deallocate (
      ref : index_t
    ) is begin
      if ref >= 0 then
        check_valid(ref);
        if stack_index >= stack'length then
          reallocate_stack(stack'length + 2**16);
        end if;
        stack(stack_index) := ref;
        stack_index := stack_index + 1;
        deallocate(storage(ref));
        storage(ref) := null;
      end if;
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
      ref : index_t
    ) return natural is begin
      check_valid(ref);
      return storage(ref)'length;
    end;

    procedure set (
      ref   : index_t;
      index : positive;
      value : val_t
    ) is begin
      check_valid(ref);
      storage(ref)(index) := value;
    end;

    impure function get (
      ref   : index_t;
      index : positive
    ) return val_t is begin
      check_valid(ref);
      return storage(ref)(index);
    end;

    procedure reallocate (
      ref    : index_t;
      length : natural
    ) is
      variable value : vec_t(1 to length) := (others => val_t'low);
    begin
      reallocate(ref, value);
    end;

    procedure reallocate (
      ref   : index_t;
      value : vec_t
    ) is begin
      check_valid(ref);
      deallocate(storage(ref));
      storage(ref) := new vec_t'(value);
    end;

    procedure resize (
      ref    : index_t;
      length : natural;
      drop   : natural := 0;
      rotate : natural := 0
    ) is
      variable old_ptr : va_t;
      variable new_ptr : va_t := new vec_t'(1 to length => val_t'low);
      variable min_length : natural;
      variable index : natural;
    begin
      check_valid(ref);
      assert drop = 0 or rotate = 0 report "can't combine drop and rotate";
      old_ptr := storage(ref);
      min_length := old_ptr'length - drop;
      if length < min_length then
        min_length := length;
      end if;
      for i in 0 to min_length - 1 loop
        index := (drop + rotate + i) mod old_ptr'length;
        new_ptr(i + 1) := old_ptr(index + 1);
      end loop;
      storage(ref) := new_ptr;
      deallocate(old_ptr);
    end;

    impure function to_string (
      ref : index_t
    ) return string is begin
      check_valid(ref);
      return storage(ref).all;
    end;

  end protected body;

  shared variable ptr_storage : string_ptr_storage_t;

  function to_integer (
    value : ptr_t
  ) return index_t is begin
    return value.ref;
  end;

  impure function to_string_ptr (
    value : index_t
  ) return ptr_t is begin
    if value >= 0 then
      ptr_storage.check_valid(value);
    end if;
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
  ) return natural is begin
    return ptr_storage.length(ptr.ref);
  end;

  procedure set (
    ptr   : ptr_t;
    index : positive;
    value : val_t
  ) is begin
    ptr_storage.set(ptr.ref, index, value);
  end;

  impure function get (
    ptr   : ptr_t;
    index : positive
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
    length : natural;
    drop   : natural := 0;
    rotate : natural := 0
  ) is begin
    ptr_storage.resize(ptr.ref, length, drop, rotate);
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

