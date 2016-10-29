-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

--
-- The purpose of this package is to provide an integer vector access type (pointer)
-- that can itself be used in arrays and returned from functions unlike a
-- real access type. This is achieved by letting the actual value be a handle
-- into a singleton datastructure of integer vector access types.
--
package integer_vector_ptr_pkg is
  type integer_vector_ptr_t is record
    index : integer;
  end record;
  constant null_ptr : integer_vector_ptr_t := (index => -1);

  impure function allocate(length : natural := 0) return integer_vector_ptr_t;
  procedure deallocate(ptr : integer_vector_ptr_t);
  impure function length(ptr : integer_vector_ptr_t) return integer;
  procedure set(ptr : integer_vector_ptr_t; index : integer; value : integer);
  impure function get(ptr : integer_vector_ptr_t; index : integer) return integer;
  procedure resize(ptr : integer_vector_ptr_t; length : natural);
end package;

package body integer_vector_ptr_pkg is
  type integer_vector_access_t is access integer_vector;
  type integer_vector_access_vector_t is array (natural range <>) of integer_vector_access_t;
  type integer_vector_access_vector_access_t is access integer_vector_access_vector_t;

  type integer_vector_ptr_storage_t is protected
    impure function allocate(length : natural) return integer_vector_ptr_t;
    procedure deallocate(ptr : integer_vector_ptr_t);
    impure function length(ptr : integer_vector_ptr_t) return integer;
    procedure set(ptr : integer_vector_ptr_t; index : integer; value : integer);
    impure function get(ptr : integer_vector_ptr_t; index : integer) return integer;
    procedure resize(ptr : integer_vector_ptr_t; length : natural);
  end protected;

  type integer_vector_ptr_storage_t is protected body
    variable ptrs : integer_vector_access_vector_access_t;

    impure function allocate(length : natural) return integer_vector_ptr_t is
      variable old_ptrs : integer_vector_access_vector_access_t;
    begin

      if ptrs = null then
        ptrs := new integer_vector_access_vector_t'(0 => null);
      else
        -- Reallocate ptr pointers to larger ptr
        old_ptrs := ptrs;
        ptrs := new integer_vector_access_vector_t'(0 to old_ptrs'length => null);
        for i in old_ptrs'range loop
          ptrs(i) := old_ptrs(i);
        end loop;
        deallocate(old_ptrs);
      end if;
      ptrs(ptrs'length-1) := new integer_vector'(0 to length-1 => 0);
      return (index => ptrs'length-1);
    end function;

    procedure deallocate(ptr : integer_vector_ptr_t) is
    begin
      deallocate(ptrs(ptr.index));
      ptrs(ptr.index) := null;
    end procedure;

    impure function length(ptr : integer_vector_ptr_t) return integer is
    begin
      return ptrs(ptr.index)'length;
    end function;

    procedure set(ptr : integer_vector_ptr_t; index : integer; value : integer) is
    begin
      ptrs(ptr.index)(index) := value;
    end procedure;

    impure function get(ptr : integer_vector_ptr_t; index : integer) return integer is
    begin
      return ptrs(ptr.index)(index);
    end function;

    procedure resize(ptr : integer_vector_ptr_t; length : natural) is
      variable old_ptr, new_ptr : integer_vector_access_t;
    begin
      new_ptr := new integer_vector'(0 to length - 1 => 0);
      old_ptr := ptrs(ptr.index);
      for i in old_ptr'range loop
        new_ptr(i) := old_ptr(i);
      end loop;
      ptrs(ptr.index) := new_ptr;
      deallocate(old_ptr);
    end procedure;

  end protected body;

  shared variable integer_vector_ptr_storage : integer_vector_ptr_storage_t;

  impure function allocate(length : natural := 0) return integer_vector_ptr_t is
  begin
    return integer_vector_ptr_storage.allocate(length);
  end function;

  procedure deallocate(ptr : integer_vector_ptr_t) is
  begin
    integer_vector_ptr_storage.deallocate(ptr);
  end procedure;

  impure function length(ptr : integer_vector_ptr_t) return integer is
  begin
    return integer_vector_ptr_storage.length(ptr);
  end function;

  procedure set(ptr : integer_vector_ptr_t; index : integer; value : integer) is
  begin
    integer_vector_ptr_storage.set(ptr, index, value);
  end procedure;

  impure function get(ptr : integer_vector_ptr_t; index : integer) return integer is
  begin
    return integer_vector_ptr_storage.get(ptr, index);
  end function;

  procedure resize(ptr : integer_vector_ptr_t; length : natural) is
  begin
    integer_vector_ptr_storage.resize(ptr, length);
  end procedure;
end package body;
