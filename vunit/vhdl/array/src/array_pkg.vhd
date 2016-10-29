-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

-- @TODO > 32-bit ieee signed/unsigned

use std.textio.all;
use work.integer_array_pkg.all;

package array_pkg is

  type array_t is protected
    procedure init(arr : integer_array_t);

    procedure init(length : integer := 0;
                   bit_width : natural := 32;
                   is_signed : boolean := true);

    procedure init_2d(width : integer := 0;
                      height : integer := 0;
                      bit_width : natural := 32;
                      is_signed : boolean := true);

    procedure init_3d(width : integer := 0;
                      height : integer := 0;
                      depth : integer := 0;
                      bit_width : natural := 32;
                      is_signed : boolean := true);

    procedure copy_from(input : inout array_t);

    procedure load_csv(file_name : string;
                       bit_width : natural := 32;
                       is_signed : boolean := true);

    procedure load_raw(file_name : string;
                       bit_width : natural := 32;
                       is_signed : boolean := true);
    procedure clear;

    impure function height return integer;
    impure function width return integer;
    impure function depth return integer;
    impure function length return integer;
    impure function bit_width return integer;
    impure function is_signed return boolean;
    impure function lower_limit return integer;
    impure function upper_limit return integer;

    impure function get(idx : integer) return integer;
    impure function get(x,y : integer) return integer;
    impure function get(x,y,z : integer) return integer;
    procedure set(idx : integer; value : integer);
    procedure set(x,y : integer; value : integer);
    procedure set(x,y,z : integer; value : integer);

    -- Return interal integer_array_t object
    impure function get_integer_array return integer_array_t;

    procedure append(value : integer);
    procedure reshape(length : integer);
    procedure reshape(width, height : integer);
    procedure reshape(width, height, depth : integer);
    procedure save_csv(file_name : string);
    procedure save_raw(file_name : string);
  end protected;
end package;

package body array_pkg is
  type array_t is protected body
    variable my_arr : integer_array_t := null_integer_array;

    impure function length return integer is
    begin
      return my_arr.length;
    end function;

    impure function width return integer is
    begin
      return my_arr.width;
    end function;

    impure function height return integer is
    begin
      return my_arr.height;
    end function;

    impure function depth return integer is
    begin
      return my_arr.depth;
    end function;

    impure function bit_width return integer is
    begin
      return my_arr.bit_width;
    end function;

    impure function is_signed return boolean is
    begin
      return my_arr.is_signed;
    end function;

    impure function bytes_per_word return integer is
    begin
      return (my_arr.bit_width + 7)/8;
    end function;

    impure function lower_limit return integer is
    begin
      return my_arr.lower_limit;
    end function;

    impure function upper_limit return integer is
    begin
      return my_arr.upper_limit;
    end function;

    procedure reshape(length : integer) is
    begin
      reshape(my_arr, length);
    end procedure;

    procedure reshape(width, height : integer) is
    begin
      reshape(my_arr, width, height);
    end procedure;

    procedure reshape(width, height, depth : integer) is
    begin
      reshape(my_arr, width, height, depth);
    end procedure;

    impure function get_integer_array return integer_array_t is
    begin
      return my_arr;
    end;

    procedure append(value : integer) is
    begin
      append(my_arr, value);
    end procedure;

    impure function get(idx : integer) return integer is
    begin
      return get(my_arr, idx);
    end function;

    impure function get(x, y : integer) return integer is
    begin
      return get(my_arr, x, y);
    end function;

    impure function get(x,y,z : integer) return integer is
    begin
      return get(my_arr, x, y, z);
    end function;

    procedure set(idx : integer; value : integer)  is
    begin
      set(my_arr, idx, value);
    end procedure;

    procedure set(x,y : integer; value : integer)  is
    begin
      set(my_arr, x, y, value);
    end procedure;

    procedure set(x,y,z : integer; value : integer)  is
    begin
      set(my_arr, x, y, z, value);
    end procedure;

    procedure init(arr : integer_array_t) is
    begin
      my_arr := arr;
    end procedure;

    procedure init(length : integer := 0;
                   bit_width : natural := 32;
                   is_signed : boolean := true) is
    begin
      init_3d(width => length,
              height => 1,
              depth => 1,
              bit_width => bit_width,
              is_signed => is_signed);
    end procedure;

    procedure init_2d(width : integer := 0;
                      height : integer := 0;
                      bit_width : natural := 32;
                      is_signed : boolean := true) is
    begin
      init_3d(width => width,
              height => height,
              depth => 1,
              bit_width => bit_width,
              is_signed => is_signed);
    end procedure;

    procedure init_3d(width : integer := 0;
                      height : integer := 0;
                      depth : integer := 0;
                      bit_width : natural := 32;
                      is_signed : boolean := true) is
    begin
      deallocate(my_arr);
      my_arr := new_3d(width, height, depth, bit_width, is_signed);
    end procedure;

    procedure copy_from(input : inout array_t) is
    begin
      init_3d(input.width, input.height, input.depth, input.bit_width, input.is_signed);
      for i in 0 to input.length-1 loop
        set(i, input.get(i));
      end loop;
    end procedure;

    procedure clear is
    begin
      deallocate(my_arr);
    end procedure;

    procedure save_csv(file_name : string) is
    begin
      save_csv(my_arr, file_name);
    end procedure;

    procedure load_csv(file_name : string;
                       bit_width : natural := 32;
                       is_signed : boolean := true) is
    begin
      deallocate(my_arr);
      my_arr := load_csv(file_name, bit_width, is_signed);
    end procedure;

    procedure save_raw(file_name : string) is
    begin
      save_raw(my_arr, file_name);
    end procedure;

    procedure load_raw(file_name : string;
                       bit_width : natural := 32;
                       is_signed : boolean := true) is
    begin
      deallocate(my_arr);
      my_arr := load_raw(file_name, bit_width, is_signed);
    end procedure;
  end protected body;
end package body;
