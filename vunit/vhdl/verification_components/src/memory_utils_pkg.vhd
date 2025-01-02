-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- Utility functions to write data types to memory model

library ieee;
use ieee.std_logic_1164.all;

use work.integer_vector_ptr_pkg.all;
use work.integer_array_pkg.all;
use work.memory_pkg.all;

package memory_utils_pkg is

  -- Allocate memory for the integer_vector_ptr
  impure function allocate_integer_vector_ptr(memory : memory_t;
                                              integer_vector_ptr : integer_vector_ptr_t;
                                              name : string := "";
                                              alignment : positive := 1;
                                              bytes_per_word : natural range 1 to 4 := 4;
                                              permissions : permissions_t := write_only) return buffer_t;

  -- Write integer vector pointer to memory address
  procedure write_integer_vector_ptr(memory : memory_t;
                                     base_address : natural;
                                     integer_vector_ptr : integer_vector_ptr_t;
                                     bytes_per_word : natural range 1 to 4 := 4;
                                     endian : endianness_arg_t := default_endian);

  -- Allocate memory for the integer_vector_ptr and write it there
  impure function write_integer_vector_ptr(memory : memory_t;
                                           integer_vector_ptr : integer_vector_ptr_t;
                                           name : string := "";
                                           alignment : positive := 1;
                                           bytes_per_word : natural range 1 to 4 := 4;
                                           endian : endianness_arg_t := default_endian;
                                           permissions : permissions_t := read_only) return buffer_t;

  -- Set expected integer vector pointer data at memory address
  procedure set_expected_integer_vector_ptr(memory : memory_t;
                                            base_address : natural;
                                            integer_vector_ptr : integer_vector_ptr_t;
                                            bytes_per_word : natural range 1 to 4 := 4;
                                            endian : endianness_arg_t := default_endian);

  -- Allocate memory and set expected integer vector pointer data at memory address
  impure function set_expected_integer_vector_ptr(memory : memory_t;
                                                  integer_vector_ptr : integer_vector_ptr_t;
                                                  name : string := "";
                                                  alignment : positive := 1;
                                                  bytes_per_word : natural range 1 to 4 := 4;
                                                  endian : endianness_arg_t := default_endian;
                                                  permissions : permissions_t := write_only) return buffer_t;

  -- Allocate memory for the integer_array
  impure function allocate_integer_array(memory : memory_t;
                                         integer_array : integer_array_t;
                                         name : string := "";
                                         alignment : positive := 1;
                                         stride_in_bytes : natural := 0; -- 0 stride means use image width
                                         permissions : permissions_t := read_only) return buffer_t;

  -- Write integer array to memory address
  procedure write_integer_array(memory : memory_t;
                                base_address : natural;
                                integer_array : integer_array_t;
                                stride_in_bytes : natural := 0; -- 0 stride means use image width
                                endian : endianness_arg_t := default_endian);

  -- Allocate memory for the integer_array and write the data there
  impure function write_integer_array(memory : memory_t;
                                      integer_array : integer_array_t;
                                      name : string := "";
                                      alignment : positive := 1;
                                      stride_in_bytes : natural := 0; -- 0 stride means use image width
                                      endian : endianness_arg_t := default_endian;
                                      permissions : permissions_t := read_only) return buffer_t;

  -- Set integer_array as expected data
  procedure set_expected_integer_array(memory : memory_t;
                                       base_address : natural;
                                       integer_array : integer_array_t;
                                       stride_in_bytes : natural := 0; -- 0 stride means use image width
                                       endian : endianness_arg_t := default_endian);

  -- Allocate memory for the integer_array and set it as expected data
  impure function set_expected_integer_array(memory : memory_t;
                                             integer_array : integer_array_t;
                                             name : string := "";
                                             alignment : positive := 1;
                                             stride_in_bytes : natural := 0; -- 0 stride means use image width
                                             endian : endianness_arg_t := default_endian;
                                             permissions : permissions_t := write_only) return buffer_t;

end package;

package body memory_utils_pkg is

  -- Allocate memory for the integer_vector_ptr and set read_only permission
  impure function allocate_integer_vector_ptr(memory : memory_t;
                                              integer_vector_ptr : integer_vector_ptr_t;
                                              name : string := "";
                                              alignment : positive := 1;
                                              bytes_per_word : natural range 1 to 4 := 4;
                                              permissions : permissions_t := write_only) return buffer_t is
  begin
    return allocate(memory, length(integer_vector_ptr) * bytes_per_word, name => name,
                    alignment => alignment, permissions => permissions);
  end;

  procedure write_integer_vector_ptr(memory : memory_t;
                                     base_address : natural;
                                     integer_vector_ptr : integer_vector_ptr_t;
                                     bytes_per_word : natural range 1 to 4 := 4;
                                     endian : endianness_arg_t := default_endian) is
  begin
    for i in 0 to length(integer_vector_ptr)-1 loop
      write_integer(memory, base_address + bytes_per_word*i, get(integer_vector_ptr, i),
                    bytes_per_word => bytes_per_word,
                    endian => endian);
    end loop;
  end;

  impure function write_integer_vector_ptr(memory : memory_t;
                                           integer_vector_ptr : integer_vector_ptr_t;
                                           name : string := "";
                                           alignment : positive := 1;
                                           bytes_per_word : natural range 1 to 4 := 4;
                                           endian : endianness_arg_t := default_endian;
                                           permissions : permissions_t := read_only) return buffer_t is
    variable buf : buffer_t;
  begin
    buf := allocate_integer_vector_ptr(memory, integer_vector_ptr, name, alignment, bytes_per_word, permissions);
    write_integer_vector_ptr(memory, base_address(buf), integer_vector_ptr, bytes_per_word, endian);
    return buf;
  end;

  procedure set_expected_integer_vector_ptr(memory : memory_t;
                                            base_address : natural;
                                            integer_vector_ptr : integer_vector_ptr_t;
                                            bytes_per_word : natural range 1 to 4 := 4;
                                            endian : endianness_arg_t := default_endian) is
  begin
    for i in 0 to length(integer_vector_ptr)-1 loop
      set_expected_integer(memory,
                           base_address + bytes_per_word*i,
                           get(integer_vector_ptr, i), bytes_per_word, endian);
    end loop;
  end;

  impure function set_expected_integer_vector_ptr(memory : memory_t;
                                                  integer_vector_ptr : integer_vector_ptr_t;
                                                  name : string := "";
                                                  alignment : positive := 1;
                                                  bytes_per_word : natural range 1 to 4 := 4;
                                                  endian : endianness_arg_t := default_endian;
                                                  permissions : permissions_t := write_only) return buffer_t is
    variable buf : buffer_t;
  begin
    buf := allocate_integer_vector_ptr(memory, integer_vector_ptr, name, alignment, bytes_per_word, permissions);
    set_expected_integer_vector_ptr(memory, base_address(buf), integer_vector_ptr, bytes_per_word, endian);
    return buf;
  end function;

  impure function get_stride_in_bytes(integer_array : integer_array_t;
                                      -- 0 stride means integer_array.width * bytes_per_word
                                      stride_in_bytes : natural := 0) return natural is
  begin
    if stride_in_bytes = 0 then
      return integer_array.width * bytes_per_word(integer_array);
    else
      return stride_in_bytes;
    end if;
  end;

  impure function allocate_integer_array(memory : memory_t;
                                         integer_array : integer_array_t;
                                         name : string := "";
                                         alignment : positive := 1;
                                         stride_in_bytes : natural := 0; -- 0 stride means use image width
                                         permissions : permissions_t := read_only) return buffer_t is
  begin
    return allocate(memory,
                      integer_array.depth * integer_array.height * get_stride_in_bytes(integer_array, stride_in_bytes),
                      name => name, alignment => alignment, permissions => permissions);
  end;

  procedure write_integer_array(memory : memory_t;
                                base_address : natural;
                                integer_array : integer_array_t;
                                stride_in_bytes : natural := 0; -- 0 stride means use image width
                                endian : endianness_arg_t := default_endian) is
    constant bytes_per_word : natural := work.integer_array_pkg.bytes_per_word(integer_array);
    variable stride : natural;
    variable addr : natural;
  begin
    stride := get_stride_in_bytes(integer_array, stride_in_bytes);

    for z in 0 to integer_array.depth-1 loop
      for y in 0 to integer_array.height-1 loop
        addr := base_address + stride*(y + z*integer_array.height);
        for x in 0 to integer_array.width-1 loop
          write_integer(memory,
                        addr,
                        get(integer_array, x, y, z),
                        bytes_per_word => bytes_per_word,
                        endian => endian);
          addr := addr + bytes_per_word;
        end loop;
      end loop;
    end loop;
  end;

  impure function write_integer_array(memory : memory_t;
                                      integer_array : integer_array_t;
                                      name : string := "";
                                      alignment : positive := 1;
                                      stride_in_bytes : natural := 0; -- 0 stride means use image width
                                      endian : endianness_arg_t := default_endian;
                                      permissions : permissions_t := read_only) return buffer_t is
    variable buf : buffer_t;
  begin
    buf := allocate_integer_array(memory, integer_array, name, alignment, stride_in_bytes, permissions);
    write_integer_array(memory, base_address(buf), integer_array, stride_in_bytes, endian);
    return buf;
  end;

  procedure set_expected_integer_array(memory : memory_t;
                                       base_address : natural;
                                       integer_array : integer_array_t;
                                       stride_in_bytes : natural := 0; -- 0 stride means use image width
                                       endian : endianness_arg_t := default_endian) is
    constant bytes_per_word : natural := work.integer_array_pkg.bytes_per_word(integer_array);
    constant stride : natural := get_stride_in_bytes(integer_array, stride_in_bytes);
    variable addr : natural;
  begin
    for z in 0 to integer_array.depth-1 loop
      for y in 0 to integer_array.height-1 loop
        addr := base_address + stride*(y + z*integer_array.height);

        for x in 0 to integer_array.width-1 loop
          set_expected_integer(memory, addr, get(integer_array, x, y, z), bytes_per_word, endian);
          addr := addr + bytes_per_word;
        end loop;

      end loop;
    end loop;
  end;

  impure function set_expected_integer_array(memory : memory_t;
                                             integer_array : integer_array_t;
                                             name : string := "";
                                             alignment : positive := 1;
                                             stride_in_bytes : natural := 0; -- 0 stride means use image width
                                             endian : endianness_arg_t := default_endian;
                                             permissions : permissions_t := write_only) return buffer_t is

    variable buf : buffer_t;
  begin
    buf := allocate_integer_array(memory, integer_array, name, alignment, stride_in_bytes, permissions);
    set_expected_integer_array(memory, base_address(buf), integer_array, stride_in_bytes, endian);
    return buf;
  end;
end package body;
