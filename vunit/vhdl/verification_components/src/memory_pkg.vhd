-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- Model of a memory address space

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

use work.integer_vector_ptr_pkg.all;
use work.logger_pkg.all;
use work.string_ptr_pkg.all;
use work.types_pkg.byte_t;

package memory_pkg is

  type endianness_arg_t is (little_endian,
                            big_endian,
                            default_endian);
  subtype endianness_t is endianness_arg_t range little_endian to big_endian;

  -- Memory model object
  type memory_t is record
    -- Private
    p_meta : integer_vector_ptr_t;
    p_default_endian : endianness_t;
    p_check_permissions : boolean;
    p_data : integer_vector_ptr_t;
    p_buffers : integer_vector_ptr_t;
    p_logger : logger_t;
  end record;
  constant null_memory : memory_t := (p_logger => null_logger,
                                      p_check_permissions => boolean'low,
                                      p_default_endian => endianness_t'low,
                                      others => null_ptr);

  -- Default memory logger
  constant memory_logger : logger_t := get_logger("vunit_lib:memory_pkg");

  -- Create a new memory object
  impure function new_memory(logger : logger_t := memory_logger;
                             endian : endianness_t := little_endian) return memory_t;

  -- Empties the memory by removing all data and permissions
  procedure clear(memory : memory_t);

  -- Return the number of allocated bytes in the memory
  impure function num_bytes(memory : memory_t) return natural;

  -----------------------------------------------------
  -- Memory data read and write functions
  -----------------------------------------------------
  procedure write_byte(memory : memory_t;
                       address : natural;
                       byte : byte_t);
  impure function read_byte(memory : memory_t;
                            address : natural) return byte_t;

  procedure write_word(memory : memory_t;
                       address : natural;
                       word : std_logic_vector;
                       endian : endianness_arg_t := default_endian);

  impure function read_word(memory : memory_t;
                            address : natural;
                            bytes_per_word : positive;
                            endian : endianness_arg_t := default_endian) return std_logic_vector;

  -- Write integer
  procedure write_integer(memory : memory_t;
                          address : natural;
                          word : integer;
                          bytes_per_word : natural range 1 to 4 := 4;
                          endian : endianness_arg_t := default_endian);

  -----------------------------------------------------
  -- Memory access permission control functions
  -----------------------------------------------------
  type permissions_t is (no_access,
                         write_only,
                         read_only,
                         read_and_write);
  impure function get_permissions(memory : memory_t;
                                  address : natural) return permissions_t;
  procedure set_permissions(memory : memory_t;
                            address : natural;
                            permissions : permissions_t);

  -----------------------------------------------------
  -- Functions to set memory expected data
  -----------------------------------------------------
  impure function has_expected_byte(memory : memory_t;
                                    address : natural) return boolean;
  procedure clear_expected_byte(memory : memory_t;
                                address : natural);
  procedure set_expected_byte(memory : memory_t;
                              address : natural;
                              expected : byte_t);
  procedure set_expected_word(memory : memory_t;
                              address : natural;
                              expected : std_logic_vector;
                              endian : endianness_arg_t := default_endian);
  procedure set_expected_integer(memory : memory_t;
                                 address : natural;
                                 expected : integer;
                                 bytes_per_word : natural range 1 to 4 := 4;
                                 endian : endianness_arg_t := default_endian);
  impure function get_expected_byte(memory : memory_t;
                                    address : natural) return byte_t;

  -- Check that all expected bytes within address range was written
  -- with correct value
  procedure check_expected_was_written(memory : memory_t;
                                       address : natural;
                                       num_bytes : natural);

  -- Returns true if all expected bytes within address range was written
  -- with correct value
  impure function expected_was_written(memory    : memory_t;
                                       address   : natural;
                                       num_bytes : natural) return boolean;

  -- Check that all expected bytes within the entire memory was written
  -- with correct value
  procedure check_expected_was_written(memory : memory_t);

  -- Returns true if all expected bytes within the entire memory was written
  -- with correct value
  impure function expected_was_written(memory : memory_t) return boolean;

  -----------------------------------------------------
  -- Memory buffer allocation
  -----------------------------------------------------

  -- Reference to an allocated buffer with the memory
  type buffer_t is record
    -- Private
    p_memory_ref : memory_t;
    p_name : string_ptr_t;
    p_address : natural;
    p_num_bytes : natural;
  end record;
  constant null_buffer : buffer_t := (p_memory_ref => null_memory,
                                      p_name => null_string_ptr,
                                      p_address => natural'low,
                                      p_num_bytes => natural'low);

  -- Allocate a buffer
  impure function allocate(memory : memory_t;
                           num_bytes : natural;
                           name : string := "";
                           alignment : positive := 1;
                           permissions : permissions_t := read_and_write) return buffer_t;
  impure function name(buf : buffer_t) return string;
  impure function num_bytes(buf : buffer_t) return natural;
  impure function base_address(buf : buffer_t) return natural;
  impure function last_address(buf: buffer_t) return natural;

  -- Check that all expected bytes was written with correct value in buffer
  procedure check_expected_was_written(buf : buffer_t);

  -- Returns true if all expected bytes was written with correct value in buffer
  impure function expected_was_written(buf : buffer_t) return boolean;

  -- Return a string describing the address with name of allocation and
  -- permission settings
  impure function describe_address(memory : memory_t;
                                   address : natural) return string;

  -- Return a reference to the memory object that can be used in a verification
  -- component. The verification component can use its own logger and
  -- permissions should be checked.
  impure function to_vc_interface(memory : memory_t;

                                  -- Override logger, null_logger means no override
                                  logger : logger_t := null_logger) return memory_t;

  -- Only perform checks related to address
  -- Check for access permissions and address out of range
  impure function check_address(memory : memory_t; address : natural;
                                reading : boolean;
                                check_permissions : boolean := false) return boolean;

  -- Only perform checks related to write_byte data without performing the write
  -- Does not check address
  impure function check_write_data(memory : memory_t;
                                   address : natural;
                                   byte : byte_t) return boolean;

  -- Perform write of one byte without running any address or data checks
  procedure write_byte_unchecked(memory : memory_t; address : natural; byte : byte_t);

end package;
