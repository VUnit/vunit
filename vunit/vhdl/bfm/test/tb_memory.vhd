-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.memory_pkg.all;
use work.string_ptr_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.integer_array_pkg.all;
use work.random_pkg.all;

entity tb_memory is
  generic (runner_cfg : string);
end entity;

architecture a of tb_memory is
begin

  main : process
    variable memory : memory_t;

    procedure test_write_integer(word : integer; bytes : integer_vector) is
    begin
      write_integer(memory, 0, word, bytes_per_word => bytes'length);
      for i in 0 to bytes'length-1 loop
        check_equal(read_byte(memory, i), bytes(i));
      end loop;
      write_integer(memory, 0, word, bytes_per_word => bytes'length, big_endian => true);
      for i in 0 to bytes'length-1 loop
        check_equal(read_byte(memory, i), bytes(bytes'length - 1 - i));
      end loop;
    end procedure;

    procedure test_write_word(word : std_logic_vector; bytes : integer_vector) is
    begin
      write_word(memory, 0, word);
      for i in 0 to word'length/8-1 loop
        check_equal(read_byte(memory, i), bytes(i));
      end loop;

      write_word(memory, 0, word, big_endian => true);
      for i in 0 to word'length/8-1 loop
        check_equal(read_byte(memory, i), bytes(word'length/8 - 1 - i));
      end loop;
    end procedure;

    variable allocation : alloc_t;
    variable integer_vector_ptr : integer_vector_ptr_t;
    variable integer_array : integer_array_t;
    variable byte : byte_t;
    variable dummy_permissions : permissions_t;
    variable dummy_boolean : boolean;

  begin
    test_runner_setup(runner, runner_cfg);

    if run("Test default is null") then
      assert memory = null_memory report "Default should be null memory";

    elsif run("Test new memory") then
      memory := new_memory;
      assert memory /= null_memory report "Should not be null memory";

    elsif run("Test clear memory") then
      memory := new_memory;
      for i in 0 to 2 loop
        allocation := allocate(memory, 1024);
        check_equal(base_address(allocation), 0, "base address");
        check_equal(last_address(allocation), 1023, "last address");
        clear(memory);
      end loop;

    elsif run("Test allocate") then
      memory := new_memory;

      for i in 0 to 2 loop
        allocation := allocate(memory, 1024);
        check_equal(base_address(allocation), 1024*i, "base address");
        check_equal(last_address(allocation), 1024*(i+1)-1, "last address");
      end loop;

    elsif run("Test allocate a lot") then
      -- Test that allocation is efficient
      memory := new_memory;

      for i in 0 to 500-1 loop
        allocation := allocate(memory, 500);
        check_equal(base_address(allocation), 500*i, "base address");
        check_equal(last_address(allocation), 500*(i+1)-1, "last address");
      end loop;

    elsif run("Test allocate with alignment") then
      memory := new_memory;
      allocation := allocate(memory, 1);
      allocation := allocate(memory, 1, alignment => 8);
      check_equal(base_address(allocation), 8, "aligned base address");

      assert get_permissions(memory, 1) = no_access report "No access at unallocated location";
      assert get_permissions(memory, 7) = no_access report "No access at unallocated location";

      allocation := allocate(memory, 1, alignment => 16);
      check_equal(base_address(allocation), 16, "aligned base address");

    elsif run("Test read and write byte") then
      memory := new_memory;
      allocation := allocate(memory, 2);

      write_byte(memory, 0, 255);
      write_byte(memory, 1, 128);
      check_equal(read_byte(memory, 0), 255);
      check_equal(read_byte(memory, 1), 128);

    elsif run("Test access empty memory") then
      memory := new_memory;
      mock(memory_logger);
      write_byte(memory, 0, 255);
      check_only_log(memory_logger, "Writing to empty memory", failure);

      byte := read_byte(memory, 0);
      check_only_log(memory_logger, "Reading from empty memory", failure);
      unmock(memory_logger);

    elsif run("Test access memory out of range") then
      memory := new_memory;
      allocation := allocate(memory, 1);

      mock(memory_logger);
      write_byte(memory, 1, 255);
      check_only_log(memory_logger, "Writing to address 1 out of range 0 to 0", failure);

      byte := read_byte(memory, 1);
      check_only_log(memory_logger, "Reading from address 1 out of range 0 to 0", failure);
      unmock(memory_logger);

    elsif run("Test default permissions") then
      memory := new_memory;
      allocation := allocate(memory, 1);
      assert get_permissions(memory, 0) = read_and_write;

    elsif run("Test set permissions") then
      memory := new_memory;
      allocation := allocate(memory, 1);

      set_permissions(memory, 0, no_access);
      assert get_permissions(memory, 0) = no_access;

      set_permissions(memory, 0, write_only);
      assert get_permissions(memory, 0) = write_only;

      set_permissions(memory, 0, read_only);
      assert get_permissions(memory, 0) = read_only;

      set_permissions(memory, 0, read_and_write);
      assert get_permissions(memory, 0) = read_and_write;

    elsif run("Test access memory without permission (no_access)") then
      memory := new_memory;
      allocation := allocate(memory, 10);
      set_permissions(memory, 5, no_access);

      mock(memory_logger);
      write_byte(memory, 5, 255);
      check_only_log(memory_logger, "Writing to " & describe_address(memory, 5) & " without permission (no_access)", failure);

      byte := read_byte(memory, 5);
      check_only_log(memory_logger, "Reading from " & describe_address(memory, 5) & " without permission (no_access)", failure);
      unmock(memory_logger);

      -- Ignore permissions
      write_byte(memory, 5, 255, ignore_permissions => true);
      byte := read_byte(memory, 5, ignore_permissions => true);

    elsif run("Test access memory without permission (write_only)") then
      memory := new_memory;
      allocation := allocate(memory, 10);
      set_permissions(memory, 5, write_only);

      write_byte(memory, 5, 255);

      mock(memory_logger);
      byte := read_byte(memory, 5);
      check_only_log(memory_logger, "Reading from " & describe_address(memory, 5) & " without permission (write_only)", failure);
      unmock(memory_logger);

      -- Ignore permissions
      write_byte(memory, 5, 255, ignore_permissions => true);

      byte := read_byte(memory, 5, ignore_permissions => true);

    elsif run("Test access memory without permission (read_only)") then
      memory := new_memory;
      allocation := allocate(memory, 10);
      set_permissions(memory, 5, read_only);

      mock(memory_logger);
      write_byte(memory, 5, 255);
      check_only_log(memory_logger, "Writing to " & describe_address(memory, 5) & " without permission (read_only)", failure);
      unmock(memory_logger);

      byte := read_byte(memory, 5);

      -- Ignore permissions
      write_byte(memory, 5, 255, ignore_permissions => true);

      byte := read_byte(memory, 5, ignore_permissions => true);

    elsif run("Test describe address") then
      memory := new_memory;
      allocation := allocate(memory, 2);
      allocation := allocate(memory, 10, name => "alloc_name");

      check_equal(describe_address(memory, 12),
                  "address 12 at unallocated location");
      check_equal(describe_address(memory, 1),
                  "address 1 at offset 1 within anonymous allocation at range (0 to 1)");
      check_equal(describe_address(memory, 2),
                  "address 2 at offset 0 within allocation 'alloc_name' at range (2 to 11)");
      check_equal(describe_address(memory, 5),
                  "address 5 at offset 3 within allocation 'alloc_name' at range (2 to 11)");

    elsif run("Test set expected byte") then
      memory := new_memory;
      allocation := allocate(memory, 2);
      set_expected_byte(memory, 0, 77);
      check_equal(has_expected_byte(memory, 0), true, "address 0 has expected byte");
      check_equal(has_expected_byte(memory, 1), false, "address 1 has no expected byte");

      mock(memory_logger);
      write_byte(memory, 0, 255);
      check_only_log(memory_logger, "Writing to " & describe_address(memory, 0) & ". Got 255 expected 77", failure);
      unmock(memory_logger);

    elsif run("Test set expected word") then
      memory := new_memory;
      allocation := allocate(memory, 2);
      set_expected_word(memory, 0, x"3322");

      mock(memory_logger);
      write_byte(memory, 0, 16#33#);
      check_only_log(memory_logger, "Writing to " & describe_address(memory, 0) & ". Got 51 expected 34", failure);
      write_byte(memory, 1, 16#22#);
      check_only_log(memory_logger, "Writing to " & describe_address(memory, 1) & ". Got 34 expected 51", failure);
      unmock(memory_logger);

    elsif run("Test clear expected byte") then
      memory := new_memory;
      allocation := allocate(memory, 2);
      set_expected_byte(memory, 0, 77);
      check_equal(has_expected_byte(memory, 0), true, "address 0 has expected byte");
      check_equal(has_expected_byte(memory, 1), false, "address 1 has no expected byte");
      clear_expected_byte(memory, 0);
      check_equal(has_expected_byte(memory, 0), false, "address 0 cleared expected byte");

    elsif run("Test permissions and expected access functions ignore permissions") then
      memory := new_memory;
      allocation := allocate(memory, 1, permissions => no_access);

      dummy_permissions := get_permissions(memory, 0);
      set_permissions(memory, 0, no_access);

      dummy_boolean := has_expected_byte(memory, 0);
      clear_expected_byte(memory, 0);
      set_expected_byte(memory, 0, 0);
      byte := get_expected_byte(memory, 0);

    elsif run("Test permissions and expected access functions have address check") then
      memory := new_memory;

      mock(memory_logger);
      dummy_permissions := get_permissions(memory, 0);
      check_only_log(memory_logger, "Reading from empty memory", failure);

      set_permissions(memory, 0, no_access);
      check_only_log(memory_logger, "Writing to empty memory", failure);

      dummy_boolean := has_expected_byte(memory, 0);
      check_only_log(memory_logger, "Reading from empty memory", failure);

      clear_expected_byte(memory, 0);
      check_only_log(memory_logger, "Writing to empty memory", failure);

      set_expected_byte(memory, 0, 0);
      check_only_log(memory_logger, "Writing to empty memory", failure);

      byte := get_expected_byte(memory, 0);
      check_only_log(memory_logger, "Reading from empty memory", failure);
      unmock(memory_logger);

    elsif run("Test check all was written") then
      memory := new_memory;
      allocation := allocate(memory, 3);
      set_expected_byte(memory, 0, 77);
      set_expected_byte(memory, 2, 66);

      mock(memory_logger);
      check_all_was_written(allocation);
      check_log(memory_logger, "The " & describe_address(memory, 0) & " was never written with expected byte 77", failure);
      check_only_log(memory_logger, "The " & describe_address(memory, 2) & " was never written with expected byte 66", failure);

      write_byte(memory, 0, 77);
      check_all_was_written(allocation);
      check_only_log(memory_logger, "The " & describe_address(memory, 2) & " was never written with expected byte 66", failure);
      unmock(memory_logger);

      write_byte(memory, 2, 66);
      check_all_was_written(allocation);
      unmock(memory_logger);

    elsif run("Test write_integer") then
      memory := new_memory;
      allocation := allocate(memory, 4);

      test_write_integer(1, (0 => 1));
      test_write_integer(-1, (0 => 255));

      test_write_integer(1, (1, 0, 0, 0));
      test_write_integer(-1, (255, 255, 255, 255));

      test_write_integer(256, (0, 1, 0, 0));
      test_write_integer(-256, (0, 255, 255, 255));

      test_write_integer(integer'high, (255, 255, 255, 127));
      test_write_integer(integer'low, (0, 0, 0, 128));

    elsif run("Test write word") then
      memory := new_memory;
      allocation := allocate(memory, 7);
      test_write_word(x"11223344556677", (16#77#, 16#66#, 16#55#, 16#44#, 16#33#, 16#22#, 16#11#));

    elsif run("Test read word") then
      memory := new_memory;
      allocation := allocate(memory, 7+5);

      write_word(memory, 0, x"11223344556677");
      check_equal(read_word(memory, 0, 7), std_logic_vector'(x"11223344556677"));

      write_word(memory, 7, x"aaffbbccdd", big_endian => True);
      check_equal(read_word(memory, 7, 5, big_endian => True), std_logic_vector'(x"aaffbbccdd"));

    elsif run("Test allocate integer_vector_ptr") then
      memory := new_memory;
      integer_vector_ptr := random_integer_vector_ptr(10, 0, 255);

      allocation := allocate_integer_vector_ptr(memory, integer_vector_ptr);
      check_equal(base_address(allocation), 0);
      check_equal(last_address(allocation), 4*10-1);

      for addr in base_address(allocation) to last_address(allocation) loop
        assert get_permissions(memory, addr) = read_only;
      end loop;

      for i in 0 to length(integer_vector_ptr)-1 loop
        check_equal(read_byte(memory, base_address(allocation) + 4*i), get(integer_vector_ptr, i));
        check_equal(read_byte(memory, base_address(allocation) + 4*i+1), 0);
        check_equal(read_byte(memory, base_address(allocation) + 4*i+2), 0);
        check_equal(read_byte(memory, base_address(allocation) + 4*i+3), 0);
      end loop;

      allocation := allocate_integer_vector_ptr(memory, integer_vector_ptr, alignment => 16);
      check_equal(base_address(allocation), 48);
      check_equal(last_address(allocation), 48 + 4*10-1);

      allocation := allocate_integer_vector_ptr(memory, integer_vector_ptr, bytes_per_word => 1,
                                             permissions => read_and_write);
      check_equal(base_address(allocation), 48 + 4*10);
      check_equal(last_address(allocation), 48 + 4*10 + 10 - 1);

      for addr in base_address(allocation) to last_address(allocation) loop
        assert get_permissions(memory, addr) = read_and_write;
        check_equal(read_byte(memory, addr), get(integer_vector_ptr, addr - base_address(allocation)));
      end loop;

    elsif run("Test allocate expected integer_vector_ptr") then
      memory := new_memory;
      integer_vector_ptr := random_integer_vector_ptr(10, 0, 255);

      allocation := allocate_expected_integer_vector_ptr(memory, integer_vector_ptr);
      check_equal(base_address(allocation), 0);
      check_equal(last_address(allocation), 4*10-1);

      for addr in base_address(allocation) to last_address(allocation) loop
        assert get_permissions(memory, addr) = write_only;
      end loop;

      for i in 0 to length(integer_vector_ptr)-1 loop
        check_equal(get_expected_byte(memory, base_address(allocation) + 4*i), get(integer_vector_ptr, i));
        check_equal(get_expected_byte(memory, base_address(allocation) + 4*i+1), 0);
        check_equal(get_expected_byte(memory, base_address(allocation) + 4*i+2), 0);
        check_equal(get_expected_byte(memory, base_address(allocation) + 4*i+3), 0);
      end loop;

      allocation := allocate_expected_integer_vector_ptr(memory, integer_vector_ptr, alignment => 16);
      check_equal(base_address(allocation), 48);
      check_equal(last_address(allocation), 48 + 4*10-1);

      allocation := allocate_expected_integer_vector_ptr(memory, integer_vector_ptr,
                                                    bytes_per_word => 1, permissions => read_and_write);
      check_equal(base_address(allocation), 48 + 4*10);
      check_equal(last_address(allocation), 48 + 4*10 + 10 - 1);

      for addr in base_address(allocation) to last_address(allocation) loop
        assert get_permissions(memory, addr) = read_and_write;
        check_equal(get_expected_byte(memory, addr), get(integer_vector_ptr, addr - base_address(allocation)));
      end loop;

    elsif run("Test allocate integer_array") then
      memory := new_memory;

      integer_array := random_integer_array(10, min_value => 0, max_value => 255);
      allocation := allocate_integer_array(memory, integer_array);
      check_equal(base_address(allocation), 0);
      check_equal(last_address(allocation), 10-1);

      for addr in base_address(allocation) to last_address(allocation) loop
        assert get_permissions(memory, addr) = read_only;
      end loop;

      for i in 0 to integer_array.length-1 loop
        check_equal(read_byte(memory, base_address(allocation) + i), get(integer_array, i));
      end loop;

    elsif run("Test allocate integer_array with stride") then
      memory := new_memory;

      integer_array := random_integer_array(2, 2, min_value => 0, max_value => 255);
      allocation := allocate_integer_array(memory, integer_array, stride_in_bytes => 4);
      check_equal(base_address(allocation), 0);
      check_equal(last_address(allocation), 2*4-1);

      for y in 0 to integer_array.height - 1 loop
        for x in 0 to integer_array.width - 1 loop
          check_equal(read_byte(memory, base_address(allocation) + x + 4*y), get(integer_array, x, y));
          check(get_permissions(memory, base_address(allocation) + x + 4*y) = read_only);
        end loop;

        for x in integer_array.width to 3 loop
          check(get_permissions(memory, base_address(allocation) + x + 4*y) = no_access,
                "Stride should have no-access");
        end loop;
      end loop;

    elsif run("Test allocate expected integer_array") then
      memory := new_memory;

      integer_array := random_integer_array(10, min_value => 0, max_value => 255);
      allocation := allocate_expected_integer_array(memory, integer_array);
      check_equal(base_address(allocation), 0);
      check_equal(last_address(allocation), 10-1);

      for addr in base_address(allocation) to last_address(allocation) loop
        assert get_permissions(memory, addr) = write_only;
      end loop;

      for i in 0 to integer_array.length-1 loop
        check_equal(get_expected_byte(memory, base_address(allocation) + i), get(integer_array, i));
      end loop;

    elsif run("Test allocate expected integer_array with stride") then
      memory := new_memory;

      integer_array := random_integer_array(2, 2, min_value => 0, max_value => 255);
      allocation := allocate_expected_integer_array(memory, integer_array, stride_in_bytes => 4);
      check_equal(base_address(allocation), 0);
      check_equal(last_address(allocation), 2*4-1);

      for y in 0 to integer_array.height - 1 loop
        for x in 0 to integer_array.width - 1 loop
          check_equal(get_expected_byte(memory, base_address(allocation) + x + 4*y), get(integer_array, x, y));
          check(get_permissions(memory, base_address(allocation) + x + 4*y) = write_only);
        end loop;

        for x in integer_array.width to 3 loop
          check(get_permissions(memory, base_address(allocation) + x + 4*y) = no_access,
                "Stride should have no-access");
        end loop;
      end loop;

    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
