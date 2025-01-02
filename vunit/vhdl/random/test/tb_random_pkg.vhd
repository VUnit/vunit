-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
use vunit_lib.integer_vector_ptr_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.random_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_random is
  generic (runner_cfg : string);
end entity;

architecture a of tb_random is
begin
  main : process
    variable rnd : RandomPType;
    variable integer_vector_ptr, tmp : integer_vector_ptr_t;
    variable integer_array : integer_array_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("Test random integer_vector_ptr min max") then
      integer_vector_ptr := random_integer_vector_ptr(256, 10, 14);
      check_equal(length(integer_vector_ptr), 256);
      for i in 0 to length(integer_vector_ptr)-1 loop
        assert get(integer_vector_ptr, i) <= 14;
        assert get(integer_vector_ptr, i) >= 10;
      end loop;

      tmp := integer_vector_ptr;
      random_integer_vector_ptr(rnd, integer_vector_ptr, 13, 2, 4);
      check(tmp = integer_vector_ptr, "Reused pointer");
      check_equal(length(integer_vector_ptr), 13);
      for i in 0 to length(integer_vector_ptr)-1 loop
        assert get(integer_vector_ptr, i) <= 4;
        assert get(integer_vector_ptr, i) >= 2;
      end loop;
      deallocate(integer_vector_ptr);

    elsif run("Test random integer_vector_ptr bits_per_word is_signed") then
      integer_vector_ptr := random_integer_vector_ptr(100, bits_per_word => 10, is_signed => true);
      check_equal(length(integer_vector_ptr), 100);
      for i in 0 to length(integer_vector_ptr)-1 loop
        assert get(integer_vector_ptr, i) < 2**9;
        assert get(integer_vector_ptr, i) >= -2**9;
      end loop;

      random_integer_vector_ptr(rnd, integer_vector_ptr, 100, bits_per_word => 4, is_signed => false);
      check_equal(length(integer_vector_ptr), 100);
      for i in 0 to length(integer_vector_ptr)-1 loop
        assert get(integer_vector_ptr, i) < 2**4;
        assert get(integer_vector_ptr, i) >= 0;
      end loop;

    elsif run("Test random integer_array") then
      integer_array := random_integer_array(256, min_value => 10, max_value => 14);
      check_equal(integer_array.length, 256);
      for i in 0 to integer_array.length-1 loop
        assert get(integer_array, i) <= 14;
        assert get(integer_array, i) >= 10;
      end loop;

      random_integer_array(rnd, integer_array, 13, min_value => 2, max_value => 4);
      check_equal(integer_array.width, 13);
      check_equal(integer_array.height, 1);
      check_equal(integer_array.depth, 1);
      check_equal(integer_array.bit_width, 3);
      check_equal(integer_array.is_signed, false);

      for i in 0 to integer_array.length-1 loop
        assert get(integer_array, i) <= 4;
        assert get(integer_array, i) >= 2;
      end loop;

      random_integer_array(rnd, integer_array, 13, min_value => -2, max_value => 1);
      check_equal(integer_array.bit_width, 2);
      check_equal(integer_array.is_signed, true);

      random_integer_array(rnd, integer_array, 13, min_value => -4, max_value => -1);
      check_equal(integer_array.bit_width, 3);
      check_equal(integer_array.is_signed, true);

      random_integer_array(rnd, integer_array, 13, min_value => 0, max_value => 3);
      check_equal(integer_array.bit_width, 2);
      check_equal(integer_array.is_signed, false);

      random_integer_array(rnd, integer_array, 13, bits_per_word => 13, is_signed => false);
      check_equal(integer_array.bit_width, 13);
      check_equal(integer_array.is_signed, false);

    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
