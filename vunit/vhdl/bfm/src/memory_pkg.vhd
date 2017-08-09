-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.integer_vector_ptr_pkg.all;
use work.integer_array_pkg.all;
use work.string_ptr_pkg.all;
use work.logger_pkg.all;

package memory_pkg is

  type memory_t is record
    -- Private
    p_meta : integer_vector_ptr_t;
    p_data : integer_vector_ptr_t;
    p_allocs : integer_vector_ptr_t;
    p_logger : logger_t;
  end record;
  constant null_memory : memory_t := (p_logger => null_logger, others => null_ptr);

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

  type memory_data_t is record
    byte : byte_t;
    exp : byte_t;
    has_exp : boolean;
    perm : permissions_t;
  end record;

  constant memory_logger : logger_t := get_logger("vunit_lib.memory_pkg");
  impure function new_memory(logger : logger_t := memory_logger) return memory_t;
  procedure clear(memory : memory_t);
  procedure deallocate(variable alloc : inout alloc_t);
  impure function allocate(memory : memory_t;
                           num_bytes : natural;
                           name : string := "";
                           alignment : positive := 1;
                           permissions : permissions_t := read_and_write) return alloc_t;

  impure function decode(value : integer) return memory_data_t;
  impure function encode(memory_data : memory_data_t) return integer;

  procedure write_byte(memory : memory_t; address : natural; byte : byte_t; ignore_permissions : boolean := false);
  impure function read_byte(memory : memory_t; address : natural; ignore_permissions : boolean := false) return byte_t;

  procedure write_word(memory : memory_t;
                       address : natural;
                       word : std_logic_vector;
                       big_endian : boolean := false;
                       ignore_permissions : boolean := false);

  impure function read_word(memory : memory_t;
                            address : natural;
                            bytes_per_word : positive;
                            big_endian : boolean := false;
                            ignore_permissions : boolean := false) return std_logic_vector;

  procedure write_integer(memory : memory_t;
                          address : natural;
                          word : integer;
                          bytes_per_word : natural range 1 to 4 := 4;
                          big_endian : boolean := false;
                          ignore_permissions : boolean := false);

  procedure check_all_was_written(alloc : alloc_t);

  impure function get_permissions(memory : memory_t; address : natural) return permissions_t;
  procedure set_permissions(memory : memory_t; address : natural; permissions : permissions_t);
  impure function has_expected_byte(memory : memory_t; address : natural) return boolean;
  procedure clear_expected_byte(memory : memory_t; address : natural);
  procedure set_expected_byte(memory : memory_t; address : natural; expected : byte_t);
  procedure set_expected_word(memory : memory_t; address : natural; expected : std_logic_vector; big_endian : boolean := false);
  impure function get_expected_byte(memory : memory_t; address : natural) return byte_t;

  impure function describe_address(memory : memory_t; address : natural) return string;

  impure function base_address(alloc : alloc_t) return natural;
  impure function last_address(alloc : alloc_t) return natural;

  -- Allocate memory for the integer_vector_ptr, write it there
  -- and by default set read_only permission
  impure function allocate_integer_vector_ptr(memory : memory_t;
                                              integer_vector_ptr : integer_vector_ptr_t;
                                              name : string := "";
                                              alignment : positive := 1;
                                              bytes_per_word : natural range 1 to 4 := 4;
                                              big_endian : boolean := false;
                                              permissions : permissions_t := read_only) return alloc_t;

  -- Allocate memory for the integer_vector_ptr, set it as expected data
  -- and by default set write_only permission
  impure function allocate_expected_integer_vector_ptr(memory : memory_t;
                                                       integer_vector_ptr : integer_vector_ptr_t;
                                                       name : string := "";
                                                       alignment : positive := 1;
                                                       bytes_per_word : natural range 1 to 4 := 4;
                                                       big_endian : boolean := false;
                                                       permissions : permissions_t := write_only) return alloc_t;

  -- Allocate memory for the integer_array, write it there
  -- and by default set read_only permission
  -- padding bytes inducted by stride_in_bytes are set to no_access
  impure function allocate_integer_array(memory : memory_t;
                                         integer_array : integer_array_t;
                                         name : string := "";
                                         alignment : positive := 1;
                                         stride_in_bytes : natural := 0; -- 0 stride means use image width
                                         big_endian : boolean := false;
                                         permissions : permissions_t := read_only) return alloc_t;

  -- Allocate memory for the integer_array, set it as expected data
  -- and by default set write_only permission
  -- padding bytes inducted by stride_in_bytes are set to no_access
  impure function allocate_expected_integer_array(memory : memory_t;
                                                  integer_array : integer_array_t;
                                                  name : string := "";
                                                  alignment : positive := 1;
                                                  stride_in_bytes : natural := 0; -- 0 stride means use image width
                                                  big_endian : boolean := false;
                                                  permissions : permissions_t := write_only) return alloc_t;

end package;

package body memory_pkg is

  constant num_bytes_idx : natural := 0;
  constant num_allocations_idx : natural := 1;
  constant num_meta : natural := num_allocations_idx + 1;

  impure function new_memory(logger : logger_t := memory_logger) return memory_t is
  begin
    return (p_meta => allocate(num_meta),
            p_data => allocate(0),
            p_allocs => allocate(0),
            p_logger => logger);
  end;

  procedure clear(memory : memory_t) is
  begin
    assert memory /= null_memory;
    set(memory.p_meta, num_bytes_idx, 0);
    set(memory.p_meta, num_allocations_idx, 0);
    reallocate(memory.p_data, 0);
    reallocate(memory.p_allocs, 0);
  end procedure;

  procedure deallocate(variable alloc : inout alloc_t) is
  begin
    deallocate(alloc.p_name);
    alloc := null_alloc;
  end;

  impure function allocate(memory : memory_t;
                           num_bytes : natural;
                           name : string := "";
                           alignment : positive := 1;
                           permissions : permissions_t := read_and_write) return alloc_t is
    variable alloc : alloc_t;
    variable num_allocs : natural;
  begin
    alloc.p_memory_ref := memory;
    alloc.p_name := allocate(name);
    alloc.p_address := get(memory.p_meta, num_bytes_idx);
    alloc.p_address := alloc.p_address + ((-alloc.p_address) mod alignment);
    alloc.p_num_bytes := num_bytes;
    set(memory.p_meta, num_bytes_idx, last_address(alloc)+1);

    if length(memory.p_data) < last_address(alloc) + 1 then
      -- Allocate exponentially more memory to avoid to much copying
      resize(memory.p_data, 2*last_address(alloc) + 1, value => encode((byte => 0, exp => 0, has_exp => false, perm => no_access)));
    end if;

    num_allocs := get(memory.p_meta, num_allocations_idx) + 1;

    set(memory.p_meta, num_allocations_idx, num_allocs);
    if length(memory.p_allocs) < num_allocs*3 then
      -- Allocate exponentially more memory to avoid to much copying
      resize(memory.p_allocs, 2*num_allocs*3);
    end if;

    set(memory.p_allocs, 3*num_allocs-3, to_integer(alloc.p_name));
    set(memory.p_allocs, 3*num_allocs-2, alloc.p_address);
    set(memory.p_allocs, 3*num_allocs-1, alloc.p_num_bytes);

    -- Set default access type
    for i in 0 to num_bytes-1 loop
      set(memory.p_data, alloc.p_address + i, encode((byte => 0, exp => 0, has_exp => false, perm => permissions)));
    end loop;
    return alloc;
  end function;

  impure function base_address(alloc : alloc_t) return natural is
  begin
    return alloc.p_address;
  end function;

  impure function last_address(alloc : alloc_t) return natural is
  begin
    return alloc.p_address + alloc.p_num_bytes - 1;
  end function;

  impure function address_to_allocation(memory : memory_t; address : natural) return alloc_t is
    variable alloc : alloc_t;
  begin
    -- @TODO use bisection for speedup
    for i in 0 to get(memory.p_meta, num_allocations_idx)-1 loop
      alloc.p_address := get(memory.p_allocs, 3*i+1);

      if address >= alloc.p_address then
        alloc.p_num_bytes := get(memory.p_allocs, 3*i+2);

        if address < alloc.p_address + alloc.p_num_bytes then
          alloc.p_name := to_string_ptr(get(memory.p_allocs, 3*i));
          return alloc;
        end if;
      end if;
    end loop;

    return null_alloc;
  end;

  procedure check_write_data(memory : memory_t;
                             address : natural;
                             byte : byte_t) is
    variable memory_data : memory_data_t := decode(get(memory.p_data, address));
  begin
    if memory_data.has_exp and byte /= memory_data.exp then
      failure(memory.p_logger, "Writing to " & describe_address(memory, address) &
              ". Got " & to_string(byte) & " expected " & to_string(memory_data.exp));
    end if;
  end procedure;

  impure function check_address(memory : memory_t; address : natural;
                                reading : boolean;
                                ignore_permissions : boolean := false) return boolean is
    impure function verb return string is
    begin
      if reading then
        return "Reading from";
      else
        return "Writing to";
      end if;
    end function;

  begin
    if length(memory.p_data) = 0 then
      failure(memory.p_logger, verb & " empty memory");
      return false;
    elsif address >= length(memory.p_data) then
      failure(memory.p_logger, verb & " address " & to_string(address) & " out of range 0 to " & to_string(length(memory.p_data)-1));
      return false;
    elsif not ignore_permissions and get_permissions(memory, address) = no_access then
      failure(memory.p_logger, verb & " " & describe_address(memory, address) & " without permission (no_access)");
      return false;
    elsif not ignore_permissions and reading and get_permissions(memory, address) = write_only then
      failure(memory.p_logger, verb & " " & describe_address(memory, address) & " without permission (write_only)");
      return false;
    elsif not ignore_permissions and not reading and get_permissions(memory, address) = read_only then
      failure(memory.p_logger, verb & " " & describe_address(memory, address) & " without permission (read_only)");
      return false;
    end if;
    return true;
  end;

  impure function get(memory : memory_t; address : natural; reading : boolean; ignore_permissions : boolean) return memory_data_t is
  begin
    if not check_address(memory, address, reading, ignore_permissions) then
      return decode(0);
    end if;
    return decode(get(memory.p_data, address));
  end;

  impure function decode(value : integer) return memory_data_t is
  begin
    return (byte => value mod 256,
            exp => (value/256) mod 256,
            has_exp => (value/256**2) mod 2 = 1,
            perm => permissions_t'val((value/(2*256**2)) mod 256));
  end;

  impure function encode(memory_data : memory_data_t) return integer is
    variable result : integer;
  begin
    result := (memory_data.byte +
               memory_data.exp*256 +
               permissions_t'pos(memory_data.perm)*(2*256**2));
    if memory_data.has_exp then
      result := result + 256**2;
    end if;
    return result;
  end;

  procedure write_byte(memory : memory_t; address : natural; byte : byte_t; ignore_permissions : boolean := false) is
    variable old : memory_data_t;
  begin
    if not check_address(memory, address, false, ignore_permissions) then
      return;
    end if;

    if not ignore_permissions then
      check_write_data(memory, address, byte);
    end if;

    old := decode(get(memory.p_data, address));
    set(memory.p_data, address, encode((byte => byte, exp => old.exp, has_exp => old.has_exp, perm => old.perm)));
  end;

  impure function read_byte(memory : memory_t; address : natural; ignore_permissions : boolean := false) return byte_t is
  begin
    return get(memory, address, true, ignore_permissions).byte;
  end;

  procedure check_all_was_written(alloc : alloc_t) is
    variable byte : byte_t;
    variable memory_data : memory_data_t;
  begin
    for address in base_address(alloc) to last_address(alloc) loop
      memory_data := decode(get(alloc.p_memory_ref.p_data, address));
      if memory_data.has_exp and memory_data.byte /= memory_data.exp then
        failure(alloc.p_memory_ref.p_logger, "The " & describe_address(alloc.p_memory_ref, address) &
                " was never written with expected byte " & to_string(memory_data.exp));
      end if;
    end loop;
  end procedure;

  impure function get_permissions(memory : memory_t; address : natural) return permissions_t is
  begin
    return get(memory, address, true, ignore_permissions => true).perm;
  end;

  procedure set_permissions(memory : memory_t; address : natural; permissions : permissions_t) is
    variable old : memory_data_t;
  begin
    if not check_address(memory, address, false, ignore_permissions => true) then
      return;
    end if;
    old := decode(get(memory.p_data, address));
    set(memory.p_data, address, encode((byte => old.byte, exp => old.exp, has_exp => old.has_exp, perm => permissions)));
  end procedure;

  impure function has_expected_byte(memory : memory_t; address : natural) return boolean is
  begin
    return get(memory, address, true, ignore_permissions => true).has_exp;
  end;

  procedure clear_expected_byte(memory : memory_t; address : natural) is
    variable old : memory_data_t;
  begin
    if not check_address(memory, address, false, ignore_permissions => true) then
      return;
    end if;
    old := decode(get(memory.p_data, address));
    set(memory.p_data, address, encode((byte => old.byte, exp => 0, has_exp => false, perm => old.perm)));
  end procedure;

  procedure set_expected_byte(memory : memory_t; address : natural; expected : byte_t) is
    variable old : memory_data_t;
  begin
    if not check_address(memory, address, false, ignore_permissions => true) then
      return;
    end if;
    old := decode(get(memory.p_data, address));
    set(memory.p_data, address, encode((byte => old.byte, exp => expected, has_exp => true, perm => old.perm)));
  end procedure;

  impure function get_expected_byte(memory : memory_t; address : natural) return byte_t is
  begin
    return get(memory, address, true, ignore_permissions => true).exp;
  end;

  procedure set_expected_word(memory : memory_t; address : natural; expected : std_logic_vector; big_endian : boolean := false) is
    -- Normalize to downto range to enable std_logic_vector literals which are
    -- 1 to N
    constant word_i : std_logic_vector(expected'length-1 downto 0) := expected;
  begin
    if big_endian then
      for idx in 0 to word_i'length/8-1 loop
        set_expected_byte(memory, address + word_i'length/8 - 1 - idx,
                          to_integer(unsigned(word_i(8*idx+7 downto 8*idx))));
      end loop;
    else
      for idx in 0 to word_i'length/8-1 loop
        set_expected_byte(memory, address + idx,
                          to_integer(unsigned(word_i(8*idx+7 downto 8*idx))));
      end loop;
    end if;
  end;

  impure function describe_address(memory : memory_t; address : natural) return string is
    variable alloc : alloc_t := address_to_allocation(memory, address);

    impure function describe_allocation return string is
    begin
      if to_string(alloc.p_name) = "" then
        return "anonymous allocation";
      else
        return "allocation '" & to_string(alloc.p_name) & "'";
      end if;
    end;
  begin
    if alloc = null_alloc then
      return "address " & to_string(address) & " at unallocated location";
    end if;

    return ("address " & to_string(address) & " at offset " & to_string(address - base_address(alloc)) &
            " within " & describe_allocation & " at range " &
            "(" & to_string(base_address(alloc)) & " to " & to_string(last_address(alloc)) & ")");
  end;

  impure function serialize(word : integer;
                            bytes_per_word : natural range 1 to 4;
                            big_endian : boolean) return integer_vector is

    variable result : integer_vector(0 to bytes_per_word-1);
    variable byte : byte_t;
    variable word_i : integer := word;

  begin
    if big_endian then
      for byte_idx in 0 to bytes_per_word-1 loop
        byte := word_i mod 256;
        word_i := (word_i - byte)/256;
        result(bytes_per_word-1-byte_idx) := byte;
      end loop;
    else
      for byte_idx in 0 to bytes_per_word-1 loop
        byte := word_i mod 256;
        word_i := (word_i - byte)/256;
        result(byte_idx) := byte;
      end loop;
    end if;
    return result;
  end function;

  procedure write_word(memory : memory_t;
                       address : natural;
                       word : std_logic_vector;
                       big_endian : boolean := false;
                       ignore_permissions : boolean := false) is

    -- Normalize to downto range to enable std_logic_vector literals which are
    -- 1 to N
    constant word_i : std_logic_vector(word'length-1 downto 0) := word;
  begin
    if big_endian then
      for idx in 0 to word_i'length/8-1 loop
        write_byte(memory, address + word_i'length/8 - 1 - idx,
                   to_integer(unsigned(word_i(8*idx+7 downto 8*idx))),
                   ignore_permissions => ignore_permissions);
      end loop;
    else
      for idx in 0 to word_i'length/8-1 loop
        write_byte(memory, address + idx,
                   to_integer(unsigned(word_i(8*idx+7 downto 8*idx))),
                   ignore_permissions => ignore_permissions);
      end loop;
    end if;
  end procedure;


  impure function read_word(memory : memory_t;
                            address : natural;
                            bytes_per_word : positive;
                            big_endian : boolean := false;
                            ignore_permissions : boolean := false) return std_logic_vector is
    variable result : std_logic_vector(8*bytes_per_word-1 downto 0);
    variable bidx : natural;
  begin
    for idx in 0 to bytes_per_word-1 loop
      if big_endian then
        bidx := bytes_per_word - 1 - idx;
      else
        bidx := idx;
      end if;

      result(8*bidx+7 downto 8*bidx) := std_logic_vector(
        to_unsigned(read_byte(memory, address + idx,
                              ignore_permissions => ignore_permissions), 8));

    end loop;
    return result;
  end;

  procedure write_integer(memory : memory_t;
                          address : natural;
                          word : integer;
                          bytes_per_word : natural range 1 to 4 := 4;
                          big_endian : boolean := false;
                          ignore_permissions : boolean := false) is

    constant bytes : integer_vector := serialize(word, bytes_per_word, big_endian);
  begin
    for byte_idx in 0 to bytes_per_word-1 loop
      write_byte(memory, address + byte_idx,
                 bytes(byte_idx),
                 ignore_permissions => true);
    end loop;
  end procedure;

  -- Allocate memory for the integer_vector_ptr and set read_only permission
  impure function allocate_integer_vector_ptr(memory : memory_t;
                                              integer_vector_ptr : integer_vector_ptr_t;
                                              name : string := "";
                                              alignment : positive := 1;
                                              bytes_per_word : natural range 1 to 4 := 4;
                                              big_endian : boolean := false;
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
                    big_endian => big_endian,
                    ignore_permissions => true);
    end loop;
    return alloc;
  end;

  impure function allocate_expected_integer_vector_ptr(memory : memory_t;
                                                       integer_vector_ptr : integer_vector_ptr_t;
                                                       name : string := "";
                                                       alignment : positive := 1;
                                                       bytes_per_word : natural range 1 to 4 := 4;
                                                       big_endian : boolean := false;
                                                       permissions : permissions_t := write_only) return alloc_t is
    variable alloc : alloc_t;
    variable base_addr : integer;
    variable bytes : integer_vector(0 to bytes_per_word-1);
  begin
    alloc := allocate(memory, length(integer_vector_ptr) * bytes_per_word, name => name,
                      alignment => alignment, permissions => permissions);

    base_addr := base_address(alloc);
    for i in 0 to length(integer_vector_ptr)-1 loop
      bytes := serialize(get(integer_vector_ptr, i), bytes_per_word, big_endian);
      for byte_idx in 0 to bytes_per_word-1 loop
        set_expected_byte(memory, base_addr + bytes_per_word*i + byte_idx, bytes(byte_idx));
      end loop;
    end loop;
    return alloc;
  end function;

  impure function allocate_integer_array(memory : memory_t;
                                         integer_array : integer_array_t;
                                         name : string := "";
                                         alignment : positive := 1;
                                         stride_in_bytes : natural := 0; -- 0 stride means use image width
                                         big_endian : boolean := false;
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
                        big_endian => big_endian,
                        ignore_permissions => true);
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
                                                  big_endian : boolean := false;
                                                  permissions : permissions_t := write_only) return alloc_t is

    variable alloc : alloc_t;
    constant bytes_per_word : natural := (integer_array.bit_width + 7)/8;
    variable bytes : integer_vector(0 to bytes_per_word-1);
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
          bytes := serialize(get(integer_array, x, y, z), bytes_per_word, big_endian);
          for byte_idx in 0 to bytes_per_word-1 loop
            set_expected_byte(memory, addr + byte_idx, bytes(byte_idx));
            addr := addr + 1;
          end loop;
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
