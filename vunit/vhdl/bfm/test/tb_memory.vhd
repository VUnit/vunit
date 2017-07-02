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
    variable error_msg : string_ptr_t;
    variable byte : byte_t;

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

      for i in 0 to 1023 loop
        allocation := allocate(memory, 1000);
        check_equal(base_address(allocation), 1000*i, "base address");
        check_equal(last_address(allocation), 1000*(i+1)-1, "last address");
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
      write_byte(memory, 0, 255, error_msg);
      check_equal(to_string(error_msg), "Writing to empty memory");

      read_byte(memory, 0, byte, error_msg);
      check_equal(to_string(error_msg), "Reading from empty memory");

    elsif run("Test access memory out of range") then
      memory := new_memory;

      allocation := allocate(memory, 1);

      write_byte(memory, 1, 255, error_msg);
      check_equal(to_string(error_msg), "Writing to address 1 out of range 0 to 0");

      read_byte(memory, 1, byte, error_msg);
      check_equal(to_string(error_msg), "Reading from address 1 out of range 0 to 0");

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

      write_byte(memory, 5, 255, error_msg);
      check_equal(to_string(error_msg), "Writing to " & describe_address(memory, 5) & " without permission (no_access)");

      read_byte(memory, 5, byte, error_msg);
      check_equal(to_string(error_msg), "Reading from " & describe_address(memory, 5) & " without permission (no_access)");

      -- Ignore permissions
      write_byte(memory, 5, 255, error_msg, ignore_permissions => true);
      assert error_msg = null_string_ptr;

      read_byte(memory, 5, byte, error_msg, ignore_permissions => true);
      assert error_msg = null_string_ptr;


    elsif run("Test access memory without permission (write_only)") then
      memory := new_memory;
      allocation := allocate(memory, 10);
      set_permissions(memory, 5, write_only);

      write_byte(memory, 5, 255, error_msg);
      assert error_msg = null_string_ptr;

      read_byte(memory, 5, byte, error_msg);
      check_equal(to_string(error_msg), "Reading from " & describe_address(memory, 5) & " without permission (write_only)");

      -- Ignore permissions
      write_byte(memory, 5, 255, error_msg, ignore_permissions => true);
      assert error_msg = null_string_ptr;

      read_byte(memory, 5, byte, error_msg, ignore_permissions => true);
      assert error_msg = null_string_ptr;

    elsif run("Test access memory without permission (read_only)") then
      memory := new_memory;
      allocation := allocate(memory, 10);
      set_permissions(memory, 5, read_only);

      write_byte(memory, 5, 255, error_msg);
      check_equal(to_string(error_msg), "Writing to " & describe_address(memory, 5) & " without permission (read_only)");

      read_byte(memory, 5, byte, error_msg);
      assert error_msg = null_string_ptr;

      -- Ignore permissions
      write_byte(memory, 5, 255, error_msg, ignore_permissions => true);
      assert error_msg = null_string_ptr;

      read_byte(memory, 5, byte, error_msg, ignore_permissions => true);
      assert error_msg = null_string_ptr;

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

      write_byte(memory, 0, 255, error_msg);
      check_equal(to_string(error_msg), "Writing to " & describe_address(memory, 0) & ". Got 255 expected 77");

    elsif run("Test set expected word") then
      memory := new_memory;
      allocation := allocate(memory, 2);
      set_expected_word(memory, 0, x"3322");
      write_byte(memory, 0, 16#33#, error_msg);
      check_equal(to_string(error_msg), "Writing to " & describe_address(memory, 0) & ". Got 51 expected 34");
      write_byte(memory, 1, 16#22#, error_msg);
      check_equal(to_string(error_msg), "Writing to " & describe_address(memory, 1) & ". Got 34 expected 51");

    elsif run("Test check all was written") then
      memory := new_memory;
      allocation := allocate(memory, 3);
      set_expected_byte(memory, 0, 77);
      set_expected_byte(memory, 2, 66);

      check_all_was_written(allocation, error_msg);
      check_equal(to_string(error_msg), "The " & describe_address(memory, 0) & " was never written with expected byte 77");

      write_byte(memory, 0, 77);
      check_all_was_written(allocation, error_msg);
      check_equal(to_string(error_msg), "The " & describe_address(memory, 2) & " was never written with expected byte 66");

      write_byte(memory, 2, 66);
      check_all_was_written(allocation, error_msg);
      assert error_msg = null_string_ptr;

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

    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
