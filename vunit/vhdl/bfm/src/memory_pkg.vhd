-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;

package memory_pkg is

  type memory_t is record
    -- Private
    p_data : integer_vector_ptr_t;
    p_allocs : integer_vector_ptr_t;
  end record;
  constant null_memory : memory_t := (others => null_ptr);

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
    ref : byte_t;
    has_ref : boolean;
    perm : permissions_t;
  end record;

  impure function new_memory return memory_t;
  impure function allocate(memory : memory_t; num_bytes : natural; name : string := ""; alignment : positive := 1) return alloc_t;

  impure function decode(value : integer) return memory_data_t;
  impure function encode(memory_data : memory_data_t) return integer;

  procedure write_byte(memory : memory_t; address : natural; byte : byte_t; ignore_permissions : boolean := false);
  procedure write_byte(memory : memory_t; address : natural; byte : byte_t; variable error_msg : inout string_ptr_t; ignore_permissions : boolean := false);
  procedure read_byte(memory : memory_t; address : natural; variable byte : inout byte_t; variable error_msg : inout string_ptr_t; ignore_permissions : boolean := false);
  impure function read_byte(memory : memory_t; address : natural; ignore_permissions : boolean := false) return byte_t;

  procedure check_all_was_written(alloc : alloc_t; variable error_msg : inout string_ptr_t);
  procedure check_all_was_written(alloc : alloc_t);

  impure function get_permissions(memory : memory_t; address : natural) return permissions_t;
  procedure set_permissions(memory : memory_t; address : natural; permissions : permissions_t);
  procedure set_reference(memory : memory_t; address : natural; reference : byte_t);
  impure function describe_address(memory : memory_t; address : natural) return string;

  impure function base_address(alloc : alloc_t) return natural;
  impure function last_address(alloc : alloc_t) return natural;

end package;

package body memory_pkg is
  impure function new_memory return memory_t is
  begin
    return (p_data => allocate(0), p_allocs => allocate(0));
  end;

  impure function allocate(memory : memory_t; num_bytes : natural; name : string := ""; alignment : positive := 1) return alloc_t is
    variable alloc : alloc_t;
  begin
    alloc.p_memory_ref := memory;
    alloc.p_name := allocate(name);
    alloc.p_address := length(memory.p_data);
    alloc.p_address := alloc.p_address + ((-alloc.p_address) mod alignment);
    alloc.p_num_bytes := num_bytes;
    resize(memory.p_data, last_address(alloc) + 1, value => encode((byte => 0, ref => 0, has_ref => false, perm => no_access)));
    resize(memory.p_allocs, length(memory.p_allocs)+3);

    set(memory.p_allocs, length(memory.p_allocs)-3, to_integer(alloc.p_name));
    set(memory.p_allocs, length(memory.p_allocs)-2, alloc.p_address);
    set(memory.p_allocs, length(memory.p_allocs)-1, alloc.p_num_bytes);

    -- Set default access type
    for i in 0 to num_bytes-1 loop
      set(memory.p_data, alloc.p_address + i, encode((byte => 0, ref => 0, has_ref => false, perm => read_and_write)));
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
    for i in 0 to length(memory.p_allocs)/3-1 loop
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
                             byte : byte_t;
                             variable error_msg : inout string_ptr_t) is
    variable memory_data : memory_data_t := decode(get(memory.p_data, address));
  begin
    if memory_data.has_ref and byte /= memory_data.ref then
      error_msg := allocate("Writing to " & describe_address(memory, address) &
                            ". Got " & to_string(byte) & " expected " & to_string(memory_data.ref));
    else
      error_msg := null_string_ptr;
    end if;
  end procedure;

  procedure check_address(memory : memory_t; address : natural;
                          reading : boolean;
                          variable error_msg : inout string_ptr_t;
                          ignore_permissions : boolean := false) is
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
      error_msg := allocate(verb & " empty memory");
    elsif address >= length(memory.p_data) then
      error_msg := allocate(verb & " memory out of range 0 to " & to_string(length(memory.p_data)-1));
    elsif not ignore_permissions and get_permissions(memory, address) = no_access then
      error_msg := allocate(verb & " " & describe_address(memory, address) & " without permission (no_access)");
    elsif not ignore_permissions and reading and get_permissions(memory, address) = write_only then
      error_msg := allocate(verb & " " & describe_address(memory, address) & " without permission (write_only)");
    elsif not ignore_permissions and not reading and get_permissions(memory, address) = read_only then
      error_msg := allocate(verb & " " & describe_address(memory, address) & " without permission (read_only)");
    else
      error_msg := null_string_ptr;
    end if;
  end;

  impure function decode(value : integer) return memory_data_t is
  begin
    return (byte => value mod 256,
            ref => (value/256) mod 256,
            has_ref => (value/256**2) mod 2 = 1,
            perm => permissions_t'val((value/(2*256**2)) mod 256));
  end;

  impure function encode(memory_data : memory_data_t) return integer is
    variable result : integer;
  begin
    result := (memory_data.byte +
               memory_data.ref*256 +
               permissions_t'pos(memory_data.perm)*(2*256**2));
    if memory_data.has_ref then
      result := result + 256**2;
    end if;
    return result;
  end;

  procedure write_byte(memory : memory_t; address : natural; byte : byte_t; variable error_msg : inout string_ptr_t; ignore_permissions : boolean := false) is
    variable old : memory_data_t;
  begin
    check_address(memory, address, false, error_msg, ignore_permissions);
    if error_msg /= null_string_ptr then
      return;
    end if;

    if not ignore_permissions then
      check_write_data(memory, address, byte, error_msg);
      if error_msg /= null_string_ptr then
        return;
      end if;
    end if;

    old := decode(get(memory.p_data, address));
    set(memory.p_data, address, encode((byte => byte, ref => old.ref, has_ref => old.has_ref, perm => old.perm)));
  end;

  procedure write_byte(memory : memory_t; address : natural; byte : byte_t; ignore_permissions : boolean := false) is
    variable error_msg : string_ptr_t := null_string_ptr;
  begin
    write_byte(memory, address, byte, error_msg, ignore_permissions);
    assert error_msg = null_string_ptr report to_string(error_msg);
  end;

  procedure read_byte(memory : memory_t; address : natural;
                      variable byte : inout byte_t;
                      variable error_msg : inout string_ptr_t;
                      ignore_permissions : boolean := false) is
  begin
    check_address(memory, address, true, error_msg, ignore_permissions);
    if error_msg /= null_string_ptr then
      return;
    end if;
    byte := decode(get(memory.p_data, address)).byte;
  end;

  impure function read_byte(memory : memory_t; address : natural; ignore_permissions : boolean := false) return byte_t is
    variable byte : byte_t;
    variable error_msg : string_ptr_t := null_string_ptr;
  begin
    read_byte(memory, address, byte, error_msg, ignore_permissions);
    assert error_msg = null_string_ptr report to_string(error_msg);
    return byte;
  end;

  procedure check_all_was_written(alloc : alloc_t; variable error_msg : inout string_ptr_t) is
    variable byte : byte_t;
    variable memory_data : memory_data_t;
  begin
    for address in base_address(alloc) to last_address(alloc) loop
      memory_data := decode(get(alloc.p_memory_ref.p_data, address));
      if memory_data.has_ref and memory_data.byte /= memory_data.ref then
        error_msg := allocate("The " & describe_address(alloc.p_memory_ref, address) &
                              " was never written with expected byte " & to_string(memory_data.ref));
        return;
      end if;
    end loop;

    error_msg := null_string_ptr;
  end procedure;

  procedure check_all_was_written(alloc : alloc_t) is
    variable error_msg : string_ptr_t := null_string_ptr;
  begin
    assert error_msg = null_string_ptr report to_string(error_msg);
  end procedure;

  impure function get_permissions(memory : memory_t; address : natural) return permissions_t is
  begin
    return decode(get(memory.p_data, address)).perm;
  end;

  procedure set_permissions(memory : memory_t; address : natural; permissions : permissions_t) is
    variable old : memory_data_t := decode(get(memory.p_data, address));
  begin
    set(memory.p_data, address, encode((byte => old.byte, ref => old.ref, has_ref => old.has_ref, perm => permissions)));
  end procedure;

  procedure set_reference(memory : memory_t; address : natural; reference : byte_t) is
    variable old : memory_data_t := decode(get(memory.p_data, address));
  begin
    set(memory.p_data, address, encode((byte => old.byte, ref => reference, has_ref => true, perm => old.perm)));
  end procedure;

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

end package body;
