-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
--context vunit_lib.vunit_context;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

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
    constant denormal_string : string(8 to 9) := "ab";
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("test_new_string_ptr") then
        ptr := new_string_ptr;
        check_equal(length(ptr), 0);

        ptr := new_string_ptr(1);
        check_equal(length(ptr), 1);

        ptr := new_string_ptr(2);
        check_equal(length(ptr), 2);

      elsif run("test_new_string_ptr_with_string") then
        ptr := new_string_ptr("hello");
        check_equal(length(ptr), 5);
        check_equal(to_string(ptr), "hello");

      elsif run("test_reallocate_string") then
        ptr := new_string_ptr("hello");
        check_equal(length(ptr), 5);
        check_equal(to_string(ptr), "hello");

        reallocate(ptr, "foobar");
        check_equal(length(ptr), 6);
        check_equal(to_string(ptr), "foobar");

      elsif run("test_element_access") then
        ptr := new_string_ptr(1);
        set(ptr, 1, a_random_value);
        assert get(ptr, 1) = a_random_value;

        ptr2 := new_string_ptr(2);
        set(ptr2, 1, another_random_value);
        set(ptr2, 2, a_random_value);
        assert get(ptr2, 1) = another_random_value;
        assert get(ptr2, 2) = a_random_value;

        assert get(ptr, 1) = a_random_value report
          "Checking that ptr was not affected by ptr2";

      elsif run("test_resize") then
        ptr := new_string_ptr(1);
        check_equal(length(ptr), 1);
        set(ptr, 1, a_random_value);
        assert get(ptr, 1) = a_random_value;

        resize(ptr, 2);
        check_equal(length(ptr), 2);
        set(ptr, 2, another_random_value);
        assert get(ptr, 1) = a_random_value report
          "Checking that resized ptr still contain old value";
        assert get(ptr, 2) = another_random_value;

        resize(ptr, 1);
        check_equal(length(ptr), 1);
        assert get(ptr, 1) = a_random_value report
          "Checking that shrunk ptr still contain old value";

      elsif run("test_resize_with_drop") then

        ptr := new_string_ptr(8);
        for i in 1 to 8 loop
          set(ptr, i, character'val(i));
        end loop;
        resize(ptr, 4, drop => 4);

        for i in 1 to 4 loop
          assert get(ptr, i) = character'val(4+i);
        end loop;

      elsif run("test_from_and_to_integer") then
        ptr := new_string_ptr(2);
        assert to_string_ptr(to_integer(ptr)) = ptr;

      elsif run("test_to_string") then
        ptr := new_string_ptr(3);
        set(ptr, 1, 'a');
        set(ptr, 2, 'b');
        set(ptr, 3, 'c');
        assert to_string(ptr) = "abc";
        resize(ptr, 4);
        set(ptr, 4, '1');
        assert to_string(ptr) = "abc1";

      elsif run("Test codecs") then
        ptr := new_string_ptr(0);
        check(decode(encode(ptr)) = ptr);

        ptr2 := new_string_ptr(2);
        set(ptr2, 1, another_random_value);
        set(ptr2, 2, a_random_value);
        check(decode(encode(ptr2)) = ptr2);

      elsif run("Test denormal string") then
        ptr := new_string_ptr(denormal_string);
        check_equal(to_string(ptr), "ab");

        reallocate(ptr, denormal_string);
        check_equal(to_string(ptr), "ab");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
