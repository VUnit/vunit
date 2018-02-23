-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2018, Lars Asplund lars.anders.asplund@gmail.com

package generic_dynamic_array_pkg is
  generic (
    type value_t
    );

  --------------------------------------------------------
  -- Basic array  pointer type
  --------------------------------------------------------
  type array_t is array (natural range <>) of value_t;

  subtype index_t is integer range -1 to integer'high;
  type array_ptr_t is record
    index : index_t;
  end record;
  constant null_array_ptr : array_ptr_t := (index => -1);

  function to_integer(value : array_ptr_t) return integer;
  impure function to_array_ptr(value : integer) return array_ptr_t;
  impure function new_array_ptr(length : natural := 0) return array_ptr_t;
  impure function new_array_ptr(length : natural; value : value_t) return array_ptr_t;
  procedure deallocate(ptr : array_ptr_t);
  impure function length(ptr : array_ptr_t) return integer;
  procedure set(ptr : array_ptr_t; index : integer; value : value_t);
  impure function get(ptr : array_ptr_t; index : integer) return value_t;
  procedure reallocate(ptr : array_ptr_t; length : natural);
  procedure reallocate(ptr : array_ptr_t; length : natural; value : value_t);
  procedure resize(ptr : array_ptr_t; length : natural; drop : natural := 0);
  procedure resize(ptr : array_ptr_t; length : natural; value : value_t; drop : natural := 0);

  --------------------------------------------------------
  -- Enhanced array type
  --------------------------------------------------------
  type dynamic_array_t is record
    -- All fields are considered private, use functions to access these
    length : natural;
    width : natural;
    height : natural;
    depth : natural;
    data : array_ptr_t;
  end record;

  -- Ensure null_integer_array is the default VHDL value of the record
  constant null_dynamic_array : dynamic_array_t := (
    length => 0,
    width => 0,
    height => 0,
    depth => 0,
    data => null_array_ptr
    );

  type array_vec_t is array (natural range <>) of dynamic_array_t;

  impure function new_1d(length : integer := 0) return dynamic_array_t;

  impure function new_2d(width : integer := 0;
                         height : integer := 0) return dynamic_array_t;

  impure function new_3d(width : integer := 0;
                         height : integer := 0;
                         depth : integer := 0) return dynamic_array_t;

  impure function copy(arr : dynamic_array_t) return dynamic_array_t;

  procedure deallocate(variable arr : inout dynamic_array_t);
  impure function is_null(arr : dynamic_array_t) return boolean;

  impure function length(arr : dynamic_array_t) return integer;
  impure function width(arr : dynamic_array_t) return integer;
  impure function height(arr : dynamic_array_t) return integer;
  impure function depth(arr : dynamic_array_t) return integer;

  impure function get(arr : dynamic_array_t; idx : integer) return value_t;
  impure function get(arr : dynamic_array_t; x,y : integer) return value_t;
  impure function get(arr : dynamic_array_t; x,y,z : integer) return value_t;

  procedure set(arr : dynamic_array_t; idx : integer; value : value_t);
  procedure set(arr : dynamic_array_t; x,y : integer; value : value_t);
  procedure set(arr : dynamic_array_t; x,y,z : integer; value : value_t);

  procedure append(variable arr : inout dynamic_array_t; value : value_t);
  procedure reshape(variable arr : inout dynamic_array_t; length : integer);
  procedure reshape(variable arr : inout dynamic_array_t; width, height : integer);
  procedure reshape(variable arr : inout dynamic_array_t; width, height, depth : integer);

end package;


package body generic_dynamic_array_pkg is
  type array_access_t is access array_t;
  type array_access_array_t is array (natural range <>) of array_access_t;
  type array_access_array_access_t is access array_access_array_t;

  type ptr_storage_t is protected
    impure function new_array_ptr(length : natural; value : value_t) return array_ptr_t;
    procedure deallocate(ptr : array_ptr_t);
    impure function length(ptr : array_ptr_t) return integer;
    procedure set(ptr : array_ptr_t; index : integer; value : value_t);
    impure function get(ptr : array_ptr_t; index : integer) return value_t;
    procedure reallocate(ptr : array_ptr_t; length : natural; value : value_t);
    procedure resize(ptr : array_ptr_t; length : natural; value : value_t; drop : natural);
  end protected;

  type ptr_storage_t is protected body
    variable current_index : integer := 0;
    variable ptrs : array_access_array_access_t := null;

    impure function new_array_ptr(length : natural; value : value_t) return array_ptr_t is
      variable old_ptrs : array_access_array_access_t;
      variable retval : array_ptr_t := (index => current_index);
    begin

      if ptrs = null then
        ptrs := new array_access_array_t'(0 => null);
      elsif ptrs'length <= current_index then
        -- Reallocate ptr pointers to larger ptr
        -- Use more size to trade size for speed
        old_ptrs := ptrs;
        ptrs := new array_access_array_t'(0 to ptrs'length + 2**16 => null);
        for i in old_ptrs'range loop
          ptrs(i) := old_ptrs(i);
        end loop;
        deallocate(old_ptrs);
      end if;

      ptrs(current_index) := new array_t'(0 to length-1 => value);
      current_index := current_index + 1;
      return retval;
    end function;

    procedure deallocate(ptr : array_ptr_t) is
    begin
      deallocate(ptrs(ptr.index));
      ptrs(ptr.index) := null;
    end procedure;

    impure function length(ptr : array_ptr_t) return integer is
    begin
      return ptrs(ptr.index)'length;
    end function;

    procedure set(ptr : array_ptr_t; index : integer; value : value_t) is
    begin
      ptrs(ptr.index)(index) := value;
    end procedure;

    impure function get(ptr : array_ptr_t; index : integer) return value_t is
    begin
      return ptrs(ptr.index)(index);
    end function;

    procedure reallocate(ptr : array_ptr_t; length : natural; value : value_t) is
      variable old_ptr, new_array_ptr : array_access_t;
    begin
      deallocate(ptrs(ptr.index));
      ptrs(ptr.index) := new array_t'(0 to length - 1 => value);
    end procedure;

    procedure resize(ptr : array_ptr_t; length : natural; value : value_t; drop : natural) is
      variable old_ptr, new_array_ptr : array_access_t;
      variable min_length : natural := length;
    begin
      new_array_ptr := new array_t'(0 to length - 1 => value);
      old_ptr := ptrs(ptr.index);

      if min_length > old_ptr'length - drop then
        min_length := old_ptr'length - drop;
      end if;

      for i in 0 to min_length-1 loop
        new_array_ptr(i) := old_ptr(drop + i);
      end loop;
      ptrs(ptr.index) := new_array_ptr;
      deallocate(old_ptr);
    end procedure;

  end protected body;

  shared variable ptr_storage : ptr_storage_t;

  function get_default_value return value_t is
    variable value : value_t;
  begin
    return value;
  end;

  function to_integer(value : array_ptr_t) return integer is
  begin
    return value.index;
  end function;

  impure function to_array_ptr(value : integer) return array_ptr_t is
  begin
    -- @TODO maybe assert that the index is valid
    return (index => value);
  end function;

  impure function new_array_ptr(length : natural; value : value_t) return array_ptr_t is
  begin
    return ptr_storage.new_array_ptr(length, value);
  end function;

  impure function new_array_ptr(length : natural := 0) return array_ptr_t is
    variable value : value_t;
  begin
    return ptr_storage.new_array_ptr(length, value);
  end function;

  procedure deallocate(ptr : array_ptr_t) is
  begin
    ptr_storage.deallocate(ptr);
  end procedure;

  impure function length(ptr : array_ptr_t) return integer is
  begin
    return ptr_storage.length(ptr);
  end function;

  procedure set(ptr : array_ptr_t; index : integer; value : value_t) is
  begin
    ptr_storage.set(ptr, index, value);
  end procedure;

  impure function get(ptr : array_ptr_t; index : integer) return value_t is
  begin
    return ptr_storage.get(ptr, index);
  end function;

  procedure reallocate(ptr : array_ptr_t; length : natural; value : value_t) is
  begin
    ptr_storage.reallocate(ptr, length, value);
  end procedure;

  procedure reallocate(ptr : array_ptr_t; length : natural) is
    variable value : value_t;
  begin
    ptr_storage.reallocate(ptr, length, value);
  end procedure;

  procedure resize(ptr : array_ptr_t; length : natural; drop : natural := 0) is
    variable value : value_t;
  begin
    ptr_storage.resize(ptr, length, value, drop);
  end procedure;

  procedure resize(ptr : array_ptr_t; length : natural; value : value_t; drop : natural := 0) is
  begin
    ptr_storage.resize(ptr, length, value, drop);
  end procedure;

  --------------------------------------------------------
  -- Array functions
  --------------------------------------------------------

  impure function length(arr : dynamic_array_t) return integer is
  begin
    return arr.length;
  end function;

  impure function width(arr : dynamic_array_t) return integer is
  begin
    return arr.width;
  end function;

  impure function height(arr : dynamic_array_t) return integer is
  begin
    return arr.height;
  end function;

  impure function depth(arr : dynamic_array_t) return integer is
  begin
    return arr.depth;
  end function;

  procedure validate_data(arr : dynamic_array_t) is
  begin
    assert arr.data /= null_array_ptr report "Data is not allocated";
  end procedure;

  procedure validate_bounds(name : string; val, bound : integer) is
  begin
    assert 0 <= val and val < bound
                report (name & "=" & integer'image(val) & " " &
                        "is out of bounds " &
                        "0 <= " & name  &" < " & integer'image(bound));
  end procedure;

  procedure realloc(variable arr : inout dynamic_array_t; new_length : integer) is
  begin
    if arr.data = null_array_ptr then
      -- Array was empty
      arr.data := new_array_ptr(new_length);
    elsif new_length > length(arr.data) then
      -- Reallocate if more length is required
      -- Add extra length to avoid excessive reallocation when appending
      resize(arr.data, new_length + length(arr.data));
    end if;

    arr.length := new_length;
  end procedure;

  procedure reshape(variable arr : inout dynamic_array_t; length : integer) is
  begin
    reshape(arr, length, 1, 1);
  end procedure;

  procedure reshape(variable arr : inout dynamic_array_t; width, height : integer) is
  begin
    reshape(arr, width, height, 1);
  end procedure;

  procedure reshape(variable arr : inout dynamic_array_t; width, height, depth : integer) is
  begin
    arr.width := width;
    arr.height := height;
    arr.depth := depth;
    realloc(arr, width*height*depth);
  end procedure;

  procedure append(variable arr : inout dynamic_array_t; value : value_t) is
  begin
    reshape(arr, arr.length+1);
    set(arr, arr.length-1, value);
  end procedure;

  impure function get(arr : dynamic_array_t; idx : integer) return value_t is
  begin
    validate_data(arr);
    validate_bounds("idx", idx, arr.length);
    return get(arr.data, idx);
  end function;

  impure function get(arr : dynamic_array_t; x, y : integer) return value_t is
  begin
    validate_data(arr);
    validate_bounds("x", x, arr.width);
    validate_bounds("y", y, arr.height);
    return get(arr.data, y*arr.width + x);
  end function;

  impure function get(arr : dynamic_array_t; x,y,z : integer) return value_t is
  begin
    validate_data(arr);
    validate_bounds("x", x, arr.width);
    validate_bounds("y", y, arr.height);
    validate_bounds("z", z, arr.depth);
    return get(arr.data, (y*arr.width + x)*arr.depth + z);
  end function;

  procedure set(arr : dynamic_array_t; idx : integer; value : value_t)  is
  begin
    validate_data(arr);
    validate_bounds("idx", idx, arr.length);
    set(arr.data, idx, value);
  end procedure;

  procedure set(arr : dynamic_array_t; x,y : integer; value : value_t)  is
  begin
    validate_data(arr);
    validate_bounds("x", x, arr.width);
    validate_bounds("y", y, arr.height);
    set(arr.data, y*arr.width + x, value);
  end procedure;

  procedure set(arr : dynamic_array_t; x,y,z : integer; value : value_t)  is
  begin
    validate_data(arr);
    validate_bounds("x", x, arr.width);
    validate_bounds("y", y, arr.height);
    validate_bounds("z", z, arr.depth);
    set(arr.data, (y*arr.width + x)*arr.depth + z, value);
  end procedure;

  impure function new_1d(length : integer := 0) return dynamic_array_t is
  begin
    return new_3d(width => length,
                  height => 1,
                  depth => 1);
  end;

  impure function new_2d(width : integer := 0;
                         height : integer := 0) return dynamic_array_t is
  begin
    return new_3d(width => width,
                  height => height,
                  depth => 1);
  end;

  impure function new_3d(width : integer := 0;
                         height : integer := 0;
                         depth : integer := 0) return dynamic_array_t is
    variable arr : dynamic_array_t := null_dynamic_array;
  begin

    arr.length := width * height * depth;
    arr.width := width;
    arr.height := height;
    arr.depth := depth;

    if arr.length > 0 then
      arr.data := new_array_ptr(arr.length);
    else
      arr.data := null_array_ptr;
    end if;

    return arr;
  end;

  impure function copy(arr : dynamic_array_t) return dynamic_array_t is
    variable arr_copy : dynamic_array_t;
  begin
    arr_copy := new_3d(arr.width, arr.height, arr.depth);
    for i in 0 to arr.length-1 loop
      set(arr_copy, i, get(arr, i));
    end loop;
    return arr_copy;
  end;

  procedure deallocate(variable arr : inout dynamic_array_t) is
  begin
    if arr.data /= null_array_ptr then
      deallocate(arr.data);
    end if;
    arr := null_dynamic_array;
  end procedure;

  impure function is_null(arr : dynamic_array_t) return boolean is
  begin
    return arr = null_dynamic_array;
  end function;

end package body;
