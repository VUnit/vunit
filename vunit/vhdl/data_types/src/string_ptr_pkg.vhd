-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

--
-- The purpose of this package is to provide an string access type (pointer)
-- that can itself be used in arrays and returned from functions unlike a
-- real access type. This is achieved by letting the actual value be a handle
-- into a singleton datastructure of string access types.
--
package string_ptr_pkg is
  subtype index_t is integer range -1 to integer'high;
  type string_ptr_t is record
    index : index_t;
  end record;
  constant null_string_ptr : string_ptr_t := (index => -1);

  function to_integer(value : string_ptr_t) return integer;
  impure function to_string_ptr(value : integer) return string_ptr_t;
  impure function allocate(length : natural := 0) return string_ptr_t;
  impure function allocate(value : string) return string_ptr_t;
  procedure deallocate(ptr : string_ptr_t);
  impure function length(ptr : string_ptr_t) return integer;
  procedure set(ptr : string_ptr_t; index : integer; value : character);
  impure function get(ptr : string_ptr_t; index : integer) return character;
  procedure reallocate(ptr : string_ptr_t; length : natural);
  procedure resize(ptr : string_ptr_t; length : natural; drop : natural := 0);
  impure function to_string(ptr : string_ptr_t) return string;
end package;

package body string_ptr_pkg is
  type string_access_t is access string;
  type string_access_vector_t is array (natural range <>) of string_access_t;
  type string_access_vector_access_t is access string_access_vector_t;

  type string_ptr_storage_t is protected
    impure function allocate(length : natural) return string_ptr_t;
    procedure deallocate(ptr : string_ptr_t);
    impure function length(ptr : string_ptr_t) return integer;
    procedure set(ptr : string_ptr_t; index : integer; value : character);
    impure function get(ptr : string_ptr_t; index : integer) return character;
    procedure reallocate(ptr : string_ptr_t; length : natural);
    procedure resize(ptr : string_ptr_t; length : natural; drop : natural := 0);
    impure function to_string(ptr : string_ptr_t) return string;
  end protected;

  type string_ptr_storage_t is protected body
    variable current_index : integer := 0;
    variable ptrs : string_access_vector_access_t := null;

    impure function allocate(length : natural) return string_ptr_t is
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

    procedure resize(ptr : string_ptr_t; length : natural; drop : natural := 0) is
      variable old_ptr, new_ptr : string_access_t;
    begin
      new_ptr := new string'(1 to length => character'low);
      old_ptr := ptrs(ptr.index);
      for i in 1+drop to old_ptr'length loop
        new_ptr(i-drop) := old_ptr(i);
      end loop;
      ptrs(ptr.index) := new_ptr;
      deallocate(old_ptr);
    end procedure;

    impure function to_string(ptr : string_ptr_t) return string is
    begin
      return ptrs(ptr.index).all;
    end;

  end protected body;

  shared variable string_ptr_storage : string_ptr_storage_t;

  function to_integer(value : string_ptr_t) return integer is
  begin
    return value.index;
  end function;

  impure function to_string_ptr(value : integer) return string_ptr_t is
  begin
    -- @TODO maybe assert that the index is valid
    return (index => value);
  end function;

  impure function allocate(length : natural := 0) return string_ptr_t is
  begin
    return string_ptr_storage.allocate(length);
  end function;

  impure function allocate(value : string) return string_ptr_t is
    variable result : string_ptr_t := allocate(value'length);
  begin
    for i in 1 to value'length loop
      set(result, i, value(i));
    end loop;
    return result;
  end function;

  procedure deallocate(ptr : string_ptr_t) is
  begin
    string_ptr_storage.deallocate(ptr);
  end procedure;

  impure function length(ptr : string_ptr_t) return integer is
  begin
    return string_ptr_storage.length(ptr);
  end function;

  procedure set(ptr : string_ptr_t; index : integer; value : character) is
  begin
    string_ptr_storage.set(ptr, index, value);
  end procedure;

  impure function get(ptr : string_ptr_t; index : integer) return character is
  begin
    return string_ptr_storage.get(ptr, index);
  end function;

  procedure reallocate(ptr : string_ptr_t; length : natural) is
  begin
    string_ptr_storage.reallocate(ptr, length);
  end procedure;

  procedure resize(ptr : string_ptr_t; length : natural; drop : natural := 0) is
  begin
    string_ptr_storage.resize(ptr, length, drop);
  end procedure;

  impure function to_string(ptr : string_ptr_t) return string is
  begin
    return string_ptr_storage.to_string(ptr);
  end;

end package body;
