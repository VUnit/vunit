-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

use work.string_ptr_pkg.all;

entity tb_string_ptr is
  generic (runner_cfg : string);
end;

architecture a of tb_string_ptr is
begin
  main : process
    variable ptr, ptr2 : string_ptr_t;
    constant a_random_value : character := '7';
    constant another_random_value : character := '9';
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

      elsif run("test_allocate_string") then
        ptr := allocate("hello");
        check_equal(length(ptr), 5);
        check_equal(to_string(ptr), "hello");

      elsif run("test_element_access") then
        ptr := allocate(1);
        set(ptr, 1, a_random_value);
        assert get(ptr, 1) = a_random_value;

        ptr2 := allocate(2);
        set(ptr2, 1, another_random_value);
        set(ptr2, 2, a_random_value);
        assert get(ptr2, 1) = another_random_value;
        assert get(ptr2, 2) = a_random_value;

        assert get(ptr, 1) = a_random_value report
          "Checking that ptr was not affected by ptr2";

      elsif run("test_resize") then
        ptr := allocate(1);
        check_equal(length(ptr), 1);
        set(ptr, 1, a_random_value);
        assert get(ptr, 1) = a_random_value;

        resize(ptr, 2);
        check_equal(length(ptr), 2);
        set(ptr, 2, another_random_value);
        assert get(ptr, 1) = a_random_value report
          "Checking that resized ptr still contain old value";
        assert get(ptr, 2) = another_random_value;

      elsif run("test_from_and_to_integer") then
        ptr := allocate(2);
        assert to_string_ptr(to_integer(ptr)) = ptr;

      elsif run("test_to_string") then
        ptr := allocate(3);
        set(ptr, 1, 'a');
        set(ptr, 2, 'b');
        set(ptr, 3, 'c');
        assert to_string(ptr) = "abc";
        resize(ptr, 4);
        set(ptr, 4, '1');
        assert to_string(ptr) = "abc1";
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
