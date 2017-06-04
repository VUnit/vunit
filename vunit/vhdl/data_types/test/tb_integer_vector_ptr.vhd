-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

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
        ptr := allocate;
        check_equal(length(ptr), 0);

        ptr := allocate(1);
        check_equal(length(ptr), 1);

        ptr := allocate(2);
        check_equal(length(ptr), 2);

      elsif run("test_element_access") then
        ptr := allocate(1);
        set(ptr, 0, a_random_value);
        check_equal(get(ptr, 0), a_random_value);

        ptr2 := allocate(2);
        set(ptr2, 0, another_random_value);
        set(ptr2, 1, a_random_value);
        check_equal(get(ptr2, 0), another_random_value);
        check_equal(get(ptr2, 1), a_random_value);

        check_equal(get(ptr, 0), a_random_value,
                    "Checking that ptr was not affected by ptr2");

      elsif run("test_resize") then
        ptr := allocate(1);
        check_equal(length(ptr), 1);
        set(ptr, 0, a_random_value);
        check_equal(get(ptr, 0), a_random_value);

        resize(ptr, 2);
        check_equal(length(ptr), 2);
        set(ptr, 1, another_random_value);
        check_equal(get(ptr, 0), a_random_value,
                    "Checking that resized ptr still contain old value");
        check_equal(get(ptr, 1), another_random_value);

      elsif run("test_resize_with_default") then
        ptr := allocate(0);
        resize(ptr, 2, value => a_random_value);
        check_equal(length(ptr), 2);
        check_equal(get(ptr, 0), a_random_value);
        check_equal(get(ptr, 1), a_random_value);

      elsif run("test_from_and_to_integer") then
        ptr := allocate(2);
        assert to_integer_vector_ptr(to_integer(ptr)) = ptr;
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
