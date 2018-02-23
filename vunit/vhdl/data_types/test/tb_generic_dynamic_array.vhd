-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2018, Lars Asplund lars.anders.asplund@gmail.com

package real_dynamic_array is new work.generic_dynamic_array_pkg
                                generic map (value_t => real);
use work.real_dynamic_array.all;


library vunit_lib;
--context vunit_lib.vunit_context;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

entity tb_generic_dynamic_array is
  generic (runner_cfg : string);
end;

architecture a of tb_generic_dynamic_array is
begin
  main : process
    variable ptr, ptr2 : array_ptr_t;
    constant a_random_value : real := 77.0;
    constant another_random_value : real := 999.0;

    variable arr : dynamic_array_t := null_dynamic_array;
    variable other_arr : dynamic_array_t := null_dynamic_array;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("test_allocate") then
        ptr := new_array_ptr;
        check_equal(length(ptr), 0);

        ptr := new_array_ptr(1, value => 0.0);
        check_equal(length(ptr), 1);
        check_equal(get(ptr, 0), 0.0, "init value");

        ptr := new_array_ptr(2, value => 3.0);
        check_equal(length(ptr), 2);
        check_equal(get(ptr, 0), 3.0, "init value");
        check_equal(get(ptr, 1), 3.0, "init value");

        reallocate(ptr, 5, value => 11.0);
        check_equal(length(ptr), 5);

        for i in 0 to length(ptr)-1 loop
          check_equal(get(ptr, i), 11.0, "init value");
        end loop;

      elsif run("test_element_access") then
        ptr := new_array_ptr(1);
        set(ptr, 0, a_random_value);
        check_equal(get(ptr, 0), a_random_value);

        ptr2 := new_array_ptr(2);
        set(ptr2, 0, another_random_value);
        set(ptr2, 1, a_random_value);
        check_equal(get(ptr2, 0), another_random_value);
        check_equal(get(ptr2, 1), a_random_value);

        check_equal(get(ptr, 0), a_random_value,
                    "Checking that ptr was not affected by ptr2");

      elsif run("test_resize") then
        ptr := new_array_ptr(1);
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
        ptr := new_array_ptr(8);
        for i in 0 to 7 loop
          set(ptr, i, real(i));
        end loop;
        resize(ptr, 4, drop => 4);

        for i in 0 to 3 loop
          check_equal(get(ptr, i), real(4+i));
        end loop;

      elsif run("test_resize_with_default") then
        ptr := new_array_ptr(0);
        resize(ptr, 2, value => a_random_value);
        check_equal(length(ptr), 2);
        check_equal(get(ptr, 0), a_random_value);
        check_equal(get(ptr, 1), a_random_value);

      elsif run("test_from_and_to_integer") then
        ptr := new_array_ptr(2);
        assert to_array_ptr(to_integer(ptr)) = ptr;

      elsif run("Has length") then
        arr := new_1d;
        check_equal(arr.length, 0);

      elsif run("Has new_1d") then
        arr := new_1d(length => 10);
        check_equal(arr.length, 10);

      elsif run("Has new_2d") then
        arr := new_2d(width => 7, height => 13);
        check_equal(arr.width, 7);
        check_equal(arr.height, 13);
        check_equal(arr.length, 7*13);

      elsif run("Has new_3d") then
        arr := new_3d(width => 7, height => 13, depth => 5);
        check_equal(arr.width, 7);
        check_equal(arr.height, 13);
        check_equal(arr.depth, 5);
        check_equal(arr.length, 5*7*13);

      elsif run("Has copy") then
        arr := new_3d(width => 7, height => 13, depth => 5);
        for i in 0 to arr.length-1 loop
          set(arr, idx=>i, value => real(i));
        end loop;

        other_arr := copy(arr);
        check_equal(arr.width, other_arr.width);
        check_equal(arr.height, other_arr.height);
        check_equal(arr.depth, other_arr.depth);
        check_equal(arr.length, other_arr.length);
        for i in 0 to other_arr.length-1 loop
          check_equal(get(arr, i), get(other_arr, i));
        end loop;

      elsif run("Has set") then
        arr := new_1d(length => 1);
        set(arr, 0, 7.0);

      elsif run("Has set 2d") then
        arr := new_2d(width => 1, height => 2);
        set(arr, x => 0, y => 0, value => 7.0);
        set(arr, x => 0, y => 1, value => 11.0);

      elsif run("Test reshape") then
        arr := new_1d(length => 1);
        set(arr, 0, value => 100.0);

        reshape(arr, 2);
        check_equal(arr.length, 2);
        check_equal(get(arr, 0), 100.0);
        set(arr, 1, value => 200.0);
        check_equal(get(arr, 1), 200.0);

        reshape(arr, 1);
        check_equal(arr.length, 1);
        check_equal(get(arr, 0), 100.0);

      elsif run("Test reshape 2d") then
        arr := new_1d(length => 3);
        for i in 0 to 2 loop
          set(arr, i, value => real(10+i));
        end loop;

        reshape(arr, 1, 3);
        check_equal(arr.width, 1);
        check_equal(arr.height, 3);
        check_equal(arr.depth, 1);
        for i in 0 to 2 loop
          check_equal(get(arr, i), real(10+i));
        end loop;

        for i in 0 to 2 loop
          check_equal(get(arr, 0, i), real(10+i));
        end loop;

        reshape(arr, 3, 1);
        check_equal(arr.width, 3);
        check_equal(arr.height, 1);
        check_equal(arr.depth, 1);
        for i in 0 to 2 loop
          check_equal(get(arr, i), real(10+i));
        end loop;
        for i in 0 to 2 loop
          check_equal(get(arr, i, 0), real(10+i));
        end loop;

        reshape(arr, 2, 1);
        check_equal(arr.width, 2);
        check_equal(arr.height, 1);
        check_equal(arr.depth, 1);
        check_equal(get(arr, 0, 0), 10.0);
        check_equal(get(arr, 1, 0), 11.0);

      elsif run("Test reshape 3d") then
        arr := new_1d(length => 6);
        for i in 0 to 5 loop
          set(arr, i, value => real(10+i));
        end loop;

        reshape(arr, 1, 2, 3);
        check_equal(arr.width, 1);
        check_equal(arr.height, 2);
        check_equal(arr.depth, 3);
        for i in 0 to 5 loop
          check_equal(get(arr, i), real(10+i));
        end loop;

        for i in 0 to 5 loop
          check_equal(get(arr, 0, i / 3, i mod 3), real(10+i));
        end loop;


      elsif run("Has get") then
        arr := new_1d(2);
        set(arr, 0, 7.0);
        set(arr, 1, 11.0);
        check_equal(get(arr, 0), 7.0);
        check_equal(get(arr, 1), 11.0);

      elsif run("Has get 2d") then
        arr := new_2d(width => 2, height => 3);
        for i in 0 to 5 loop
          set(arr, i mod 2,  i/2, real(10 + i));
        end loop;

        for i in 0 to 5 loop
          check_equal(get(arr, i mod 2, i/2), real(10 + i));
        end loop;

        for i in 0 to 5 loop
          check_equal(get(arr, i), real(10 + i));
        end loop;

      elsif run("Has set and get 2d") then
        arr := new_3d(width => 2, height => 3, depth => 5);
        for x in 0 to arr.width-1 loop
          for y in 0 to arr.height-1 loop
            for z in 0 to arr.depth-1 loop
              set(arr, x,y,z, real(1000*x + 100*y + z));
            end loop;
          end loop;
        end loop;

        for x in 0 to arr.width-1 loop
          for y in 0 to arr.height-1 loop
            for z in 0 to arr.depth-1 loop
              check_equal(get(arr, x,y,z), real(1000*x + 100*y + z));
            end loop;
          end loop;
        end loop;

      elsif run("Has append") then
        arr := new_1d;
        append(arr, 11.0);
        check_equal(arr.length, 1);
        check_equal(get(arr, 0), 11.0);

        append(arr, 7.0);
        check_equal(arr.length, 2);
        check_equal(get(arr, 1), 7.0);

      elsif run("Deallocate sets length to 0") then
        arr := new_1d;
        append(arr, 10.0);
        check_equal(arr.length, 1);
        deallocate(arr);
        check_equal(arr.length, 0);

      elsif run("Deallocate sets width height depth to 0") then
        arr := new_3d(width => 2, height => 3, depth => 5);
        check_equal(arr.width, 2);
        check_equal(arr.height, 3);
        check_equal(arr.depth, 5);
        deallocate(arr);
        check_equal(arr.width, 0);
        check_equal(arr.height, 0);
        check_equal(arr.depth, 0);

      elsif run("is null") then
        deallocate(arr);
        check_true(is_null(arr));
        arr := new_1d;
        check_false(is_null(arr));
        append(arr, 1.0);
        deallocate(arr);
        check_true(is_null(arr));
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
