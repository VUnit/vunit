-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.memory_pkg.all;
use work.memory_utils_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.integer_array_pkg.all;
use work.random_pkg.all;

entity tb_memory_utils is
  generic (runner_cfg : string);
end entity;

architecture a of tb_memory_utils is
begin

  main : process
    variable memory : memory_t;
    variable buf : buffer_t;
    variable integer_vector_ptr : integer_vector_ptr_t;
    variable integer_array : integer_array_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("Test write integer_vector_ptr") then
      memory := new_memory;
      integer_vector_ptr := random_integer_vector_ptr(10, 0, 255);

      buf := write_integer_vector_ptr(memory, integer_vector_ptr);
      check_equal(base_address(buf), 0);
      check_equal(last_address(buf), 4*10-1);

      for addr in base_address(buf) to last_address(buf) loop
        assert get_permissions(memory, addr) = read_only;
      end loop;

      for i in 0 to length(integer_vector_ptr)-1 loop
        check_equal(read_byte(memory, base_address(buf) + 4*i), get(integer_vector_ptr, i));
        check_equal(read_byte(memory, base_address(buf) + 4*i+1), 0);
        check_equal(read_byte(memory, base_address(buf) + 4*i+2), 0);
        check_equal(read_byte(memory, base_address(buf) + 4*i+3), 0);
      end loop;

      buf := write_integer_vector_ptr(memory, integer_vector_ptr, alignment => 16);
      check_equal(base_address(buf), 48);
      check_equal(last_address(buf), 48 + 4*10-1);

      buf := write_integer_vector_ptr(memory, integer_vector_ptr, bytes_per_word => 1,
                                             permissions => read_and_write);
      check_equal(base_address(buf), 48 + 4*10);
      check_equal(last_address(buf), 48 + 4*10 + 10 - 1);

      for addr in base_address(buf) to last_address(buf) loop
        assert get_permissions(memory, addr) = read_and_write;
        check_equal(read_byte(memory, addr), get(integer_vector_ptr, addr - base_address(buf)));
      end loop;

    elsif run("Test set expected integer_vector_ptr") then
      memory := new_memory;
      integer_vector_ptr := random_integer_vector_ptr(10, 0, 255);

      buf := set_expected_integer_vector_ptr(memory, integer_vector_ptr);
      check_equal(base_address(buf), 0);
      check_equal(last_address(buf), 4*10-1);

      for addr in base_address(buf) to last_address(buf) loop
        assert get_permissions(memory, addr) = write_only;
      end loop;

      for i in 0 to length(integer_vector_ptr)-1 loop
        check_equal(get_expected_byte(memory, base_address(buf) + 4*i), get(integer_vector_ptr, i));
        check_equal(get_expected_byte(memory, base_address(buf) + 4*i+1), 0);
        check_equal(get_expected_byte(memory, base_address(buf) + 4*i+2), 0);
        check_equal(get_expected_byte(memory, base_address(buf) + 4*i+3), 0);
      end loop;

      buf := set_expected_integer_vector_ptr(memory, integer_vector_ptr, alignment => 16);
      check_equal(base_address(buf), 48);
      check_equal(last_address(buf), 48 + 4*10-1);

      buf := set_expected_integer_vector_ptr(memory, integer_vector_ptr,
                                                         bytes_per_word => 1, permissions => read_and_write);
      check_equal(base_address(buf), 48 + 4*10);
      check_equal(last_address(buf), 48 + 4*10 + 10 - 1);

      for addr in base_address(buf) to last_address(buf) loop
        assert get_permissions(memory, addr) = read_and_write;
        check_equal(get_expected_byte(memory, addr), get(integer_vector_ptr, addr - base_address(buf)));
      end loop;

    elsif run("Test write integer_array") then
      memory := new_memory;

      integer_array := random_integer_array(10, min_value => 0, max_value => 255);
      buf := write_integer_array(memory, integer_array);
      check_equal(base_address(buf), 0);
      check_equal(last_address(buf), 10-1);

      for addr in base_address(buf) to last_address(buf) loop
        assert get_permissions(memory, addr) = read_only;
      end loop;

      for i in 0 to integer_array.length-1 loop
        check_equal(read_byte(memory, base_address(buf) + i), get(integer_array, i));
      end loop;

    elsif run("Test write integer_array with stride") then
      memory := new_memory;

      integer_array := random_integer_array(2, 2, min_value => 0, max_value => 255);
      buf := write_integer_array(memory, integer_array, stride_in_bytes => 4);
      check_equal(base_address(buf), 0);
      check_equal(last_address(buf), 2*4-1);

      for y in 0 to integer_array.height - 1 loop
        for x in 0 to integer_array.width - 1 loop
          check_equal(read_byte(memory, base_address(buf) + x + 4*y), get(integer_array, x, y));
          check(get_permissions(memory, base_address(buf) + x + 4*y) = read_only);
        end loop;

        for x in integer_array.width to 3 loop
          check(get_permissions(memory, base_address(buf) + x + 4*y) = read_only,
                "Padding bytes should have same permissions");
        end loop;
      end loop;

    elsif run("Test set expected integer_array") then
      memory := new_memory;

      integer_array := random_integer_array(10, min_value => 0, max_value => 255);
      buf := set_expected_integer_array(memory, integer_array);
      check_equal(base_address(buf), 0);
      check_equal(last_address(buf), 10-1);

      for addr in base_address(buf) to last_address(buf) loop
        assert get_permissions(memory, addr) = write_only;
      end loop;

      for i in 0 to integer_array.length-1 loop
        check_equal(get_expected_byte(memory, base_address(buf) + i), get(integer_array, i));
      end loop;

    elsif run("Test set expected integer_array with stride") then
      memory := new_memory;

      integer_array := random_integer_array(2, 2, min_value => 0, max_value => 255);
      buf := set_expected_integer_array(memory, integer_array, stride_in_bytes => 4);
      check_equal(base_address(buf), 0);
      check_equal(last_address(buf), 2*4-1);

      for y in 0 to integer_array.height - 1 loop
        for x in 0 to integer_array.width - 1 loop
          check_equal(get_expected_byte(memory, base_address(buf) + x + 4*y), get(integer_array, x, y));
          check(get_permissions(memory, base_address(buf) + x + 4*y) = write_only);
        end loop;

        for x in integer_array.width to 3 loop
          check(get_permissions(memory, base_address(buf) + x + 4*y) = write_only,
                "Padding bytes should have same permissions");
        end loop;
      end loop;

    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
