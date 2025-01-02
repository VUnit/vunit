-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body memory_pkg is

  constant num_bytes_idx : natural := 0;
  constant num_buffers_idx : natural := 1;
  constant num_meta : natural := num_buffers_idx + 1;

  type memory_data_t is record
    byte : byte_t;
    exp : byte_t;
    has_exp : boolean;
    perm : permissions_t;
  end record;

  impure function new_memory(logger : logger_t := memory_logger;
                             endian : endianness_t := little_endian) return memory_t is
    constant p_meta : integer_vector_ptr_t := new_integer_vector_ptr(num_meta);
  begin
    set(p_meta, num_bytes_idx, 0);
    set(p_meta, num_buffers_idx, 0);

    return (p_meta => p_meta,
            p_default_endian => endian,
            p_check_permissions => false,
            p_data => new_integer_vector_ptr(0),
            p_buffers => new_integer_vector_ptr(0),
            p_logger => logger);
  end;

  procedure clear(memory : memory_t) is
  begin
    assert memory /= null_memory;
    set(memory.p_meta, num_bytes_idx, 0);
    set(memory.p_meta, num_buffers_idx, 0);
    reallocate(memory.p_data, 0);
    reallocate(memory.p_buffers, 0);
  end procedure;

  impure function evaluate_endian(memory : memory_t; endian : endianness_arg_t) return endianness_t is
  begin
    if endian = default_endian then
      return memory.p_default_endian;
    else
      return endian;
    end if;
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

  impure function allocate(memory : memory_t;
                           num_bytes : natural;
                           name : string := "";
                           alignment : positive := 1;
                           permissions : permissions_t := read_and_write) return buffer_t is
    variable buf : buffer_t;
    variable num_buffers : natural;
  begin
    buf.p_memory_ref := memory;
    buf.p_name := new_string_ptr(name);
    buf.p_address := work.memory_pkg.num_bytes(memory);
    buf.p_address := buf.p_address + ((-buf.p_address) mod alignment);
    buf.p_num_bytes := num_bytes;
    set(memory.p_meta, num_bytes_idx, last_address(buf)+1);

    if length(memory.p_data) < last_address(buf) + 1 then
      -- Allocate exponentially more memory to avoid to much copying
      resize(memory.p_data, 2*last_address(buf) + 1, value => encode((byte => 0, exp => 0, has_exp => false, perm => no_access)));
    end if;

    num_buffers := get(memory.p_meta, num_buffers_idx) + 1;

    set(memory.p_meta, num_buffers_idx, num_buffers);
    if length(memory.p_buffers) < num_buffers*3 then
      -- Allocate exponentially more memory to avoid to much copying
      resize(memory.p_buffers, 2*num_buffers*3);
    end if;

    set(memory.p_buffers, 3*num_buffers-3, to_integer(buf.p_name));
    set(memory.p_buffers, 3*num_buffers-2, buf.p_address);
    set(memory.p_buffers, 3*num_buffers-1, buf.p_num_bytes);

    -- Set default access type
    for i in 0 to num_bytes-1 loop
      set(memory.p_data, buf.p_address + i, encode((byte => 0, exp => 0, has_exp => false, perm => permissions)));
    end loop;
    return buf;
  end function;

  impure function name(buf : buffer_t) return string is
  begin
    return to_string(buf.p_name);
  end function;

  impure function base_address(buf : buffer_t) return natural is
  begin
    return buf.p_address;
  end function;

  impure function last_address(buf : buffer_t) return natural is
  begin
    return buf.p_address + num_bytes(buf) - 1;
  end function;

  impure function num_bytes(buf : buffer_t) return natural is
  begin
    return buf.p_num_bytes;
  end function;

  impure function address_to_allocation(memory : memory_t; address : natural) return buffer_t is
    variable buf : buffer_t;
  begin
    -- @TODO use bisection for speedup
    for i in 0 to get(memory.p_meta, num_buffers_idx)-1 loop
      buf.p_address := get(memory.p_buffers, 3*i+1);

      if address >= buf.p_address then
        buf.p_num_bytes := get(memory.p_buffers, 3*i+2);

        if address < buf.p_address + buf.p_num_bytes then
          buf.p_name := to_string_ptr(get(memory.p_buffers, 3*i));
          return buf;
        end if;
      end if;
    end loop;

    return null_buffer;
  end;

  impure function check_write_data(memory : memory_t;
                                   address : natural;
                                   byte : byte_t) return boolean is
    constant memory_data : memory_data_t := decode(get(memory.p_data, address));
  begin
    if memory_data.has_exp and byte /= memory_data.exp then
      failure(memory.p_logger, "Writing to " & describe_address(memory, address) &
              ". Got " & to_string(byte) & " expected " & to_string(memory_data.exp));
      return false;
    end if;

    return true;
  end;

  impure function check_address(memory : memory_t; address : natural;
                                reading : boolean;
                                check_permissions : boolean := false) return boolean is
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
    elsif check_permissions and get_permissions(memory, address) = no_access then
      failure(memory.p_logger, verb & " " & describe_address(memory, address) & " without permission (no_access)");
      return false;
    elsif check_permissions and reading and get_permissions(memory, address) = write_only then
      failure(memory.p_logger, verb & " " & describe_address(memory, address) & " without permission (write_only)");
      return false;
    elsif check_permissions and not reading and get_permissions(memory, address) = read_only then
      failure(memory.p_logger, verb & " " & describe_address(memory, address) & " without permission (read_only)");
      return false;
    end if;
    return true;
  end;

  impure function get(memory : memory_t;
                      address : natural;
                      reading : boolean;
                      check_permissions : boolean := false) return memory_data_t is
  begin
    if not check_address(memory, address, reading, check_permissions) then
      return decode(0);
    end if;
    return decode(get(memory.p_data, address));
  end;

  impure function num_bytes(memory : memory_t) return natural is
  begin
    return get(memory.p_meta, num_bytes_idx);
  end;

  procedure write_byte_unchecked(memory : memory_t; address : natural; byte : byte_t) is
    variable old : memory_data_t;
  begin
    old := decode(get(memory.p_data, address));
    set(memory.p_data, address, encode((byte => byte, exp => old.exp, has_exp => old.has_exp, perm => old.perm)));
  end;

  procedure write_byte(memory : memory_t; address : natural; byte : byte_t) is
  begin
    if not check_address(memory, address, false, memory.p_check_permissions) then
      return;
    end if;

    if not check_write_data(memory, address, byte) then
      return;
    end if;
    write_byte_unchecked(memory, address, byte);
  end;

  impure function read_byte(memory : memory_t; address : natural) return byte_t is
  begin
    return get(memory, address, true, memory.p_check_permissions).byte;
  end;

  procedure check_expected_was_written(memory : memory_t; address : natural; num_bytes : natural) is
    variable memory_data : memory_data_t;
  begin
    for addr in address to address + num_bytes - 1 loop
      memory_data := decode(get(memory.p_data, addr));
      if memory_data.has_exp and memory_data.byte /= memory_data.exp then
        failure(memory.p_logger, "The " & describe_address(memory, addr) &
                " was never written with expected byte " & to_string(memory_data.exp));
      end if;
    end loop;
  end procedure;

  impure function expected_was_written(memory    : memory_t;
                                       address   : natural;
                                       num_bytes : natural) return boolean is
    variable memory_data : memory_data_t;
  begin
    for addr in address to address + num_bytes - 1 loop
      memory_data := decode(get(memory.p_data, addr));
      if memory_data.has_exp and memory_data.byte /= memory_data.exp then
        return false;
      end if;
    end loop;

    return true;
  end;

  procedure check_expected_was_written(buf : buffer_t) is
  begin
    check_expected_was_written(buf.p_memory_ref, base_address(buf), num_bytes(buf));
  end procedure;

  impure function expected_was_written(buf : buffer_t) return boolean is
  begin
    return expected_was_written(buf.p_memory_ref, base_address(buf), num_bytes(buf));
  end;

  procedure check_expected_was_written(memory : memory_t) is
  begin
    check_expected_was_written(memory, 0, num_bytes(memory));
  end procedure;

  impure function expected_was_written(memory : memory_t) return boolean is
  begin
    return expected_was_written(memory, 0, num_bytes(memory));
  end;

  impure function get_permissions(memory : memory_t; address : natural) return permissions_t is
  begin
    return get(memory, address, true).perm;
  end;

  procedure set_permissions(memory : memory_t; address : natural; permissions : permissions_t) is
    variable old : memory_data_t;
  begin
    if not check_address(memory, address, false) then
      return;
    end if;
    old := decode(get(memory.p_data, address));
    set(memory.p_data, address, encode((byte => old.byte, exp => old.exp, has_exp => old.has_exp, perm => permissions)));
  end procedure;

  impure function has_expected_byte(memory : memory_t; address : natural) return boolean is
  begin
    return get(memory, address, true).has_exp;
  end;

  procedure clear_expected_byte(memory : memory_t; address : natural) is
    variable old : memory_data_t;
  begin
    if not check_address(memory, address, false) then
      return;
    end if;
    old := decode(get(memory.p_data, address));
    set(memory.p_data, address, encode((byte => old.byte, exp => 0, has_exp => false, perm => old.perm)));
  end procedure;

  procedure set_expected_byte(memory : memory_t; address : natural; expected : byte_t) is
    variable old : memory_data_t;
  begin
    if not check_address(memory, address, false) then
      return;
    end if;
    old := decode(get(memory.p_data, address));
    set(memory.p_data, address, encode((byte => old.byte, exp => expected, has_exp => true, perm => old.perm)));
  end procedure;

  impure function get_expected_byte(memory : memory_t; address : natural) return byte_t is
  begin
    return get(memory, address, true).exp;
  end;

  procedure set_expected_word(memory : memory_t;
                              address : natural;
                              expected : std_logic_vector;
                              endian : endianness_arg_t := default_endian) is
    -- Normalize to downto range to enable std_logic_vector literals which are
    -- 1 to N
    constant word_i : std_logic_vector(expected'length-1 downto 0) := expected;
    constant endianness : endianness_t := evaluate_endian(memory, endian);
  begin
    case endianness is
      when big_endian =>
        for idx in 0 to word_i'length/8-1 loop
          set_expected_byte(memory, address + word_i'length/8 - 1 - idx,
                            to_integer(unsigned(word_i(8*idx+7 downto 8*idx))));
        end loop;
      when little_endian =>
        for idx in 0 to word_i'length/8-1 loop
          set_expected_byte(memory, address + idx,
                            to_integer(unsigned(word_i(8*idx+7 downto 8*idx))));
        end loop;
    end case;
  end;

  impure function serialize(word : integer;
                            bytes_per_word : natural range 1 to 4;
                            endian : endianness_t) return integer_vector is

    variable result : integer_vector(0 to bytes_per_word-1);
    variable byte : byte_t;
    variable word_i : integer := word;
  begin
    case endian is
      when big_endian =>
        for byte_idx in 0 to bytes_per_word-1 loop
          byte := word_i mod 256;
          word_i := (word_i - byte)/256;
          result(bytes_per_word-1-byte_idx) := byte;
        end loop;
      when little_endian =>
        for byte_idx in 0 to bytes_per_word-1 loop
          byte := word_i mod 256;
          word_i := (word_i - byte)/256;
          result(byte_idx) := byte;
        end loop;
    end case;
    return result;
  end function;

  procedure set_expected_integer(memory : memory_t;
                                 address : natural;
                                 expected : integer;
                                 bytes_per_word : natural range 1 to 4 := 4;
                                 endian : endianness_arg_t := default_endian) is
    constant bytes : integer_vector(0 to bytes_per_word-1) := serialize(expected,
                                                                        bytes_per_word,
                                                                        evaluate_endian(memory, endian));
  begin
    for byte_idx in 0 to bytes_per_word-1 loop
      set_expected_byte(memory, address + byte_idx, bytes(byte_idx));
    end loop;
  end;

  impure function describe_address(memory : memory_t; address : natural) return string is
    constant buf : buffer_t := address_to_allocation(memory, address);

    impure function describe_buffer return string is
    begin
      if to_string(buf.p_name) = "" then
        return "anonymous buffer";
      else
        return "buffer '" & to_string(buf.p_name) & "'";
      end if;
    end;
  begin
    if buf = null_buffer then
      return "address " & to_string(address) & " at unallocated location";
    end if;

    return ("address " & to_string(address) & " at offset " & to_string(address - base_address(buf)) &
            " within " & describe_buffer & " at range " &
            "(" & to_string(base_address(buf)) & " to " & to_string(last_address(buf)) & ")");
  end;

  procedure write_word(memory : memory_t;
                       address : natural;
                       word : std_logic_vector;
                       endian : endianness_arg_t := default_endian) is
    constant endianness : endianness_t := evaluate_endian(memory, endian);
    -- Normalize to downto range to enable std_logic_vector literals which are
    -- 1 to N
    constant word_i : std_logic_vector(word'length-1 downto 0) := word;
  begin
    case endianness is
      when big_endian =>
        for idx in 0 to word_i'length/8-1 loop
          write_byte(memory, address + word_i'length/8 - 1 - idx,
                     to_integer(unsigned(word_i(8*idx+7 downto 8*idx))));
        end loop;
      when little_endian =>
        for idx in 0 to word_i'length/8-1 loop
          write_byte(memory, address + idx,
                     to_integer(unsigned(word_i(8*idx+7 downto 8*idx))));
        end loop;
    end case;
  end procedure;


  impure function read_word(memory : memory_t;
                            address : natural;
                            bytes_per_word : positive;
                            endian : endianness_arg_t := default_endian) return std_logic_vector is
    constant endianness : endianness_t := evaluate_endian(memory, endian);
    variable result : std_logic_vector(8*bytes_per_word-1 downto 0);
    variable bidx : natural;
  begin
    for idx in 0 to bytes_per_word-1 loop
      case endianness is
        when big_endian =>
          bidx := bytes_per_word - 1 - idx;
        when little_endian =>
          bidx := idx;
      end case;

      result(8*bidx+7 downto 8*bidx) := std_logic_vector(
        to_unsigned(read_byte(memory, address + idx), 8));

    end loop;
    return result;
  end;

  procedure write_integer(memory : memory_t;
                          address : natural;
                          word : integer;
                          bytes_per_word : natural range 1 to 4 := 4;
                          endian : endianness_arg_t := default_endian) is

    constant bytes : integer_vector := serialize(word,
                                                 bytes_per_word,
                                                 evaluate_endian(memory, endian));
  begin
    for byte_idx in 0 to bytes_per_word-1 loop
      write_byte(memory, address + byte_idx,
                 bytes(byte_idx));
    end loop;
  end procedure;

  impure function to_vc_interface(memory : memory_t;

                                  -- Override logger, null_logger means no override
                                  logger : logger_t := null_logger) return memory_t is
    variable result : memory_t := memory;
  begin
    if logger /= null_logger then
      result.p_logger := logger;
    end if;
    result.p_check_permissions := true;
    return result;
  end;
end package body;
