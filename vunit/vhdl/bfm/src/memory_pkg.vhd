-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

-- Model of a memory address space

library ieee;
use ieee.std_logic_1164.all;

use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.logger_pkg.all;

package memory_pkg is

  -- Memory model object
  type memory_t is record
    -- Private
    p_meta : integer_vector_ptr_t;
    p_data : integer_vector_ptr_t;
    p_allocs : integer_vector_ptr_t;
    p_logger : logger_t;
  end record;
  constant null_memory : memory_t := (p_logger => null_logger, others => null_ptr);

  type endianness_arg_t is (little_endian, big_endian, default_endian);
  subtype endianness_t is endianness_arg_t range little_endian to big_endian;

  -- Reference to buffer allocation within memory
  type alloc_t is record
    -- Private
    p_memory_ref : memory_t;
    p_name : string_ptr_t;
    p_address : natural;
    p_num_bytes : natural;
  end record;
  constant null_alloc : alloc_t := (p_memory_ref => null_memory,
                                    p_name => null_string_ptr,
                                    p_address => natural'low,
                                    p_num_bytes => natural'low);

  type permissions_t is (no_access, write_only, read_only, read_and_write);

  subtype byte_t is integer range 0 to 255;

  constant memory_logger : logger_t := get_logger("vunit_lib:memory_pkg");
  impure function new_memory(logger : logger_t := memory_logger;
                             endian : endianness_t := little_endian) return memory_t;
  procedure clear(memory : memory_t);
  procedure deallocate(variable alloc : inout alloc_t);
  impure function allocate(memory : memory_t;
                           num_bytes : natural;
                           name : string := "";
                           alignment : positive := 1;
                           permissions : permissions_t := read_and_write) return alloc_t;

  -- Return the number of allocated bytes in the memory
  impure function num_bytes(memory : memory_t) return natural;

  procedure write_byte(memory : memory_t; address : natural; byte : byte_t; check_permissions : boolean := false);
  impure function read_byte(memory : memory_t; address : natural; check_permissions : boolean := false) return byte_t;

  procedure write_word(memory : memory_t;
                       address : natural;
                       word : std_logic_vector;
                       endian : endianness_arg_t := default_endian;
                       check_permissions : boolean := false);

  impure function read_word(memory : memory_t;
                            address : natural;
                            bytes_per_word : positive;
                            endian : endianness_arg_t := default_endian;
                            check_permissions : boolean := false) return std_logic_vector;

  procedure write_integer(memory : memory_t;
                          address : natural;
                          word : integer;
                          bytes_per_word : natural range 1 to 4 := 4;
                          endian : endianness_arg_t := default_endian;
                          check_permissions : boolean := false);

  -- Check that all expected bytes was written to addresses within alloc
  procedure check_expected_was_written(alloc : alloc_t);

  -- Check that all expected bytes within address range was written
  procedure check_expected_was_written(memory : memory_t; address : natural; num_bytes : natural);

  -- Check that all expected bytes with the entire memory was written
  procedure check_expected_was_written(memory : memory_t);

  impure function get_permissions(memory : memory_t; address : natural) return permissions_t;
  procedure set_permissions(memory : memory_t; address : natural; permissions : permissions_t);
  impure function has_expected_byte(memory : memory_t; address : natural) return boolean;
  procedure clear_expected_byte(memory : memory_t; address : natural);
  procedure set_expected_byte(memory : memory_t; address : natural; expected : byte_t);
  procedure set_expected_word(memory : memory_t;
                              address : natural;
                              expected : std_logic_vector;
                              endian : endianness_arg_t := default_endian);
  procedure set_expected_integer(memory : memory_t; address : natural;
                                 expected : integer;
                                 bytes_per_word : natural range 1 to 4 := 4;
                                 endian : endianness_arg_t := default_endian);
  impure function get_expected_byte(memory : memory_t; address : natural) return byte_t;

  impure function describe_address(memory : memory_t; address : natural) return string;

  impure function base_address(alloc : alloc_t) return natural;
  impure function last_address(alloc : alloc_t) return natural;
  impure function num_bytes(alloc : alloc_t) return natural;

end package;
