-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
--context vunit_lib.vunit_context;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.integer_vector_ptr_pkg.all;

entity tb_integer_vector_ptr is
  generic (runner_cfg : string);
end;

architecture a of tb_integer_vector_ptr is
begin
  main : process
    variable ptr, ptr2 : integer_vector_ptr_t;
    constant a_random_value : integer := 77;
    constant another_random_value : integer := 999;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("test_allocate") then
        ptr := new_integer_vector_ptr;
        check_equal(length(ptr), 0);

        ptr := new_integer_vector_ptr(1);
        check_equal(length(ptr), 1);
        check_equal(get(ptr, 0), 0, "init value");

        ptr := new_integer_vector_ptr(2, value => 3);
        check_equal(length(ptr), 2);
        check_equal(get(ptr, 0), 3, "init value");
        check_equal(get(ptr, 1), 3, "init value");

        reallocate(ptr, 5, value => 11);
        check_equal(length(ptr), 5);

        for i in 0 to length(ptr)-1 loop
          check_equal(get(ptr, i), 11, "init value");
        end loop;

      elsif run("test_element_access") then
        ptr := new_integer_vector_ptr(1);
        set(ptr, 0, a_random_value);
        check_equal(get(ptr, 0), a_random_value);

        ptr2 := new_integer_vector_ptr(2);
        set(ptr2, 0, another_random_value);
        set(ptr2, 1, a_random_value);
        check_equal(get(ptr2, 0), another_random_value);
        check_equal(get(ptr2, 1), a_random_value);

        check_equal(get(ptr, 0), a_random_value,
                    "Checking that ptr was not affected by ptr2");

      elsif run("test_resize") then
        ptr := new_integer_vector_ptr(1);
        check_equal(length(ptr), 1);
        set(ptr, 0, a_random_value);
        check_equal(get(ptr, 0), a_random_value);

        resize(ptr, 2);
        check_equal(length(ptr), 2);
        set(ptr, 1, another_random_value);
        check_equal(get(ptr, 0), a_random_value,
                    "Checking that grown ptr still contain old value");
        check_equal(get(ptr, 1), another_random_value);

        resize(ptr, 1);
        check_equal(length(ptr), 1);
        check_equal(get(ptr, 0), a_random_value,
                    "Checking that shrunk ptr still contain old value");

      elsif run("test_resize_with_drop") then
        ptr := new_integer_vector_ptr(8);
        for i in 0 to 7 loop
          set(ptr, i, i);
        end loop;
        resize(ptr, 4, drop => 4);

        for i in 0 to 3 loop
          check_equal(get(ptr, i), 4+i);
        end loop;

      elsif run("test_resize_with_default") then
        ptr := new_integer_vector_ptr(0);
        resize(ptr, 2, value => a_random_value);
        check_equal(length(ptr), 2);
        check_equal(get(ptr, 0), a_random_value);
        check_equal(get(ptr, 1), a_random_value);

      elsif run("test_from_and_to_integer") then
        ptr := new_integer_vector_ptr(2);
        assert to_integer_vector_ptr(to_integer(ptr)) = ptr;
      elsif run("Test codecs") then
        ptr := new_integer_vector_ptr(0);
        check(decode(encode(ptr)) = ptr);

        ptr2 := new_integer_vector_ptr(2);
        set(ptr2, 0, another_random_value);
        set(ptr2, 1, a_random_value);
        check(decode(encode(ptr2)) = ptr2);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
