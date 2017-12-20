-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

-- Utility functions to write data types to memory model

library ieee;
use ieee.std_logic_1164.all;

use work.integer_vector_ptr_pkg.all;
use work.integer_array_pkg.all;
use work.memory_pkg.all;

package memory_utils_pkg is

  -- Allocate memory for the integer_vector_ptr, write it there
  -- and by default set read_only permission
  impure function allocate_integer_vector_ptr(memory : memory_t;
                                              integer_vector_ptr : integer_vector_ptr_t;
                                              name : string := "";
                                              alignment : positive := 1;
                                              bytes_per_word : natural range 1 to 4 := 4;
                                              endian : endianness_arg_t := default_endian;
                                              permissions : permissions_t := read_only) return alloc_t;

  -- Allocate memory for the integer_vector_ptr, set it as expected data
  -- and by default set write_only permission
  impure function allocate_expected_integer_vector_ptr(memory : memory_t;
                                                       integer_vector_ptr : integer_vector_ptr_t;
                                                       name : string := "";
                                                       alignment : positive := 1;
                                                       bytes_per_word : natural range 1 to 4 := 4;
                                                       endian : endianness_arg_t := default_endian;
                                                       permissions : permissions_t := write_only) return alloc_t;

  -- Allocate memory for the integer_array, write it there
  -- and by default set read_only permission
  -- padding bytes inducted by stride_in_bytes are set to no_access
  impure function allocate_integer_array(memory : memory_t;
                                         integer_array : integer_array_t;
                                         name : string := "";
                                         alignment : positive := 1;
                                         stride_in_bytes : natural := 0; -- 0 stride means use image width
                                         endian : endianness_arg_t := default_endian;
                                         permissions : permissions_t := read_only) return alloc_t;

  -- Allocate memory for the integer_array, set it as expected data
  -- and by default set write_only permission
  -- padding bytes inducted by stride_in_bytes are set to no_access
  impure function allocate_expected_integer_array(memory : memory_t;
                                                  integer_array : integer_array_t;
                                                  name : string := "";
                                                  alignment : positive := 1;
                                                  stride_in_bytes : natural := 0; -- 0 stride means use image width
                                                  endian : endianness_arg_t := default_endian;
                                                  permissions : permissions_t := write_only) return alloc_t;

end package;

package body memory_utils_pkg is

  -- Allocate memory for the integer_vector_ptr and set read_only permission
  impure function allocate_integer_vector_ptr(memory : memory_t;
                                              integer_vector_ptr : integer_vector_ptr_t;
                                              name : string := "";
                                              alignment : positive := 1;
                                              bytes_per_word : natural range 1 to 4 := 4;
                                              endian : endianness_arg_t := default_endian;
                                              permissions : permissions_t := read_only) return alloc_t is

    variable alloc : alloc_t;
    variable base_addr : integer;
  begin
    alloc := allocate(memory, length(integer_vector_ptr) * bytes_per_word, name => name,
                      alignment => alignment, permissions => permissions);

    base_addr := base_address(alloc);
    for i in 0 to length(integer_vector_ptr)-1 loop
      write_integer(memory, base_addr + bytes_per_word*i, get(integer_vector_ptr, i),
                    bytes_per_word => bytes_per_word,
                    endian => endian);
    end loop;
    return alloc;
  end;

  impure function allocate_expected_integer_vector_ptr(memory : memory_t;
                                                       integer_vector_ptr : integer_vector_ptr_t;
                                                       name : string := "";
                                                       alignment : positive := 1;
                                                       bytes_per_word : natural range 1 to 4 := 4;
                                                       endian : endianness_arg_t := default_endian;
                                                       permissions : permissions_t := write_only) return alloc_t is
    variable alloc : alloc_t;
    variable base_addr : integer;
  begin
    alloc := allocate(memory, length(integer_vector_ptr) * bytes_per_word, name => name,
                      alignment => alignment, permissions => permissions);

    base_addr := base_address(alloc);
    for i in 0 to length(integer_vector_ptr)-1 loop
      set_expected_integer(memory,
                           base_addr + bytes_per_word*i,
                           get(integer_vector_ptr, i), bytes_per_word, endian);
    end loop;
    return alloc;
  end function;

  impure function allocate_integer_array(memory : memory_t;
                                         integer_array : integer_array_t;
                                         name : string := "";
                                         alignment : positive := 1;
                                         stride_in_bytes : natural := 0; -- 0 stride means use image width
                                         endian : endianness_arg_t := default_endian;
                                         permissions : permissions_t := read_only) return alloc_t is

    variable alloc : alloc_t;
    constant bytes_per_word : natural := (integer_array.bit_width + 7)/8;
    variable stride_in_bytes_v : natural;
    variable addr : natural;
  begin
    stride_in_bytes_v := stride_in_bytes;

    if stride_in_bytes_v = 0 then
      stride_in_bytes_v := integer_array.width * bytes_per_word;
    end if;

    alloc := allocate(memory, integer_array.depth * integer_array.height * stride_in_bytes_v,
                      name => name, alignment => alignment, permissions => permissions);

    for z in 0 to integer_array.depth-1 loop
      for y in 0 to integer_array.height-1 loop
        addr := base_address(alloc) + stride_in_bytes_v*(y + z*integer_array.height);
        for x in 0 to integer_array.width-1 loop
          write_integer(memory,
                        addr,
                        get(integer_array, x, y, z),
                        bytes_per_word => bytes_per_word,
                        endian => endian);
         addr := addr + bytes_per_word;
        end loop;

        for x in bytes_per_word*integer_array.width to stride_in_bytes_v-1 loop
          set_permissions(memory, addr, no_access);
          addr := addr + 1;
        end loop;

      end loop;
    end loop;

    return alloc;
  end;

  impure function allocate_expected_integer_array(memory : memory_t;
                                                  integer_array : integer_array_t;
                                                  name : string := "";
                                                  alignment : positive := 1;
                                                  stride_in_bytes : natural := 0; -- 0 stride means use image width
                                                  endian : endianness_arg_t := default_endian;
                                                  permissions : permissions_t := write_only) return alloc_t is

    variable alloc : alloc_t;
    constant bytes_per_word : natural := (integer_array.bit_width + 7)/8;
    variable stride_in_bytes_v : natural;
    variable addr : natural;
  begin
    stride_in_bytes_v := stride_in_bytes;

    if stride_in_bytes_v = 0 then
      stride_in_bytes_v := integer_array.width * bytes_per_word;
    end if;

    alloc := allocate(memory, integer_array.depth * integer_array.height * stride_in_bytes_v,
                      name => name, alignment => alignment, permissions => permissions);

    for z in 0 to integer_array.depth-1 loop
      for y in 0 to integer_array.height-1 loop
        addr := base_address(alloc) + stride_in_bytes_v*(y + z*integer_array.height);

        for x in 0 to integer_array.width-1 loop
          set_expected_integer(memory, addr, get(integer_array, x, y, z), bytes_per_word, endian);
          addr := addr + bytes_per_word;
        end loop;

        for x in bytes_per_word*integer_array.width to stride_in_bytes_v-1 loop
          set_permissions(memory, addr, no_access);
          addr := addr + 1;
        end loop;

      end loop;
    end loop;

    return alloc;
  end;
end package body;
