-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

use work.codec_pkg.all;
use work.codec_builder_pkg.all;

package body integer_vector_ptr_pkg is
  type integer_vector is array (natural range <>) of integer;
  type integer_vector_access_t is access integer_vector;
  type integer_vector_access_vector_t is array (natural range <>) of integer_vector_access_t;
  type integer_vector_access_vector_access_t is access integer_vector_access_vector_t;

 type integer_vector_ptr_storage_t is protected
    impure function allocate(length : natural := 0; value : integer := 0) return integer_vector_ptr_t;
    procedure deallocate(ptr : integer_vector_ptr_t);
    impure function length(ptr : integer_vector_ptr_t) return integer;
    procedure set(ptr : integer_vector_ptr_t; index : integer; value : integer);
    impure function get(ptr : integer_vector_ptr_t; index : integer) return integer;
    procedure reallocate(ptr : integer_vector_ptr_t; length : natural; value : integer := 0);
    procedure resize(ptr : integer_vector_ptr_t; length : natural; drop : natural := 0; value : integer := 0);
  end protected;

  type integer_vector_ptr_storage_t is protected body
    variable current_index : integer := 0;
    variable ptrs : integer_vector_access_vector_access_t := null;

    impure function allocate(length : natural := 0; value : integer := 0) return integer_vector_ptr_t is
      variable old_ptrs : integer_vector_access_vector_access_t;
      variable retval : integer_vector_ptr_t := (index => current_index);
    begin

      if ptrs = null then
        ptrs := new integer_vector_access_vector_t'(0 => null);
      elsif ptrs'length <= current_index then
        -- Reallocate ptr pointers to larger ptr
        -- Use more size to trade size for speed
        old_ptrs := ptrs;
        ptrs := new integer_vector_access_vector_t'(0 to ptrs'length + 2**16 => null);
        for i in old_ptrs'range loop
          ptrs(i) := old_ptrs(i);
        end loop;
        deallocate(old_ptrs);
      end if;

      ptrs(current_index) := new integer_vector'(0 to length-1 => value);
      current_index := current_index + 1;
      return retval;
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

    procedure reallocate(ptr : integer_vector_ptr_t; length : natural; value : integer := 0) is
      variable old_ptr, new_ptr : integer_vector_access_t;
    begin
      deallocate(ptrs(ptr.index));
      ptrs(ptr.index) := new integer_vector'(0 to length - 1 => value);
    end procedure;

    procedure resize(ptr : integer_vector_ptr_t; length : natural; drop : natural := 0; value : integer := 0) is
      variable old_ptr, new_ptr : integer_vector_access_t;
      variable min_length : natural := length;
    begin
      new_ptr := new integer_vector'(0 to length - 1 => value);
      old_ptr := ptrs(ptr.index);

      if min_length > old_ptr'length - drop then
        min_length := old_ptr'length - drop;
      end if;

      for i in 0 to min_length-1 loop
        new_ptr(i) := old_ptr(drop + i);
      end loop;
      ptrs(ptr.index) := new_ptr;
      deallocate(old_ptr);
    end procedure;

  end protected body;

  shared variable integer_vector_ptr_storage : integer_vector_ptr_storage_t;

  function to_integer(value : integer_vector_ptr_t) return integer is
  begin
    return value.index;
  end function;

  impure function to_integer_vector_ptr(value : integer) return integer_vector_ptr_t is
  begin
    -- @TODO maybe assert that the index is valid
    return (index => value);
  end function;

  impure function allocate(length : natural := 0; value : integer := 0) return integer_vector_ptr_t is
  begin
    return integer_vector_ptr_storage.allocate(length, value);
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

  procedure reallocate(ptr : integer_vector_ptr_t; length : natural; value : integer := 0) is
  begin
    integer_vector_ptr_storage.reallocate(ptr, length, value);
  end procedure;

  procedure resize(ptr : integer_vector_ptr_t; length : natural; drop : natural := 0; value : integer := 0) is
  begin
    integer_vector_ptr_storage.resize(ptr, length, drop, value);
  end procedure;

  function encode(data : integer_vector_ptr_t) return string is
  begin
    return encode(data.index);
  end;

  function decode(code : string) return integer_vector_ptr_t is
    variable ret_val : integer_vector_ptr_t;
    variable index : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  procedure decode (
    constant code : string;
    variable index : inout positive;
    variable result : out integer_vector_ptr_t) is
  begin
    decode(code, index, result.index);
  end;

end package body;
