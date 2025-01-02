-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- @TODO add explicit check of csv string data

-- vunit: fail_on_warning
-- vunit: run_all_in_same_sim

use std.textio.all;

library vunit_lib;
--context vunit_lib.vunit_context;
use work.integer_array_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

entity tb_integer_array is
  generic (
    output_path : string;
    runner_cfg : string);
end entity;

architecture a of tb_integer_array is
begin

  main : process
    variable arr : integer_array_t := null_integer_array;
    variable other_arr : integer_array_t := null_integer_array;

    impure function num_bytes(file_name : string) return integer is
      type binary_file_t is file of character;
      file fread : binary_file_t;
      variable num_bytes : integer := 0;
      variable chr : character;
    begin
      file_open(fread, file_name, read_mode);
      while not endfile(fread) loop
        num_bytes := num_bytes + 1;
        read(fread, chr);
      end loop;
      file_close(fread);
      return num_bytes;
    end function;

    procedure test_save_and_load_raw(bit_width : integer;
                                     is_signed : boolean) is
      variable arr : integer_array_t;
      variable other_arr : integer_array_t;

      impure function file_name return string is
      begin
        if is_signed then
          return output_path & "s" & integer'image(bit_width) & ".raw";
        else
          return output_path & "u" & integer'image(bit_width) & ".raw";
        end if;
      end function;

      constant bytes_per_word : integer := (bit_width+7)/8;

    begin
      arr := new_1d(bit_width => bit_width, is_signed => is_signed);
      append(arr, arr.lower_limit);
      append(arr, 0);
      append(arr, arr.upper_limit);
      save_raw(arr, file_name);
      other_arr := load_raw(file_name,
                            bit_width => bit_width, is_signed => is_signed);
      check_equal(get(other_arr, 0), get(arr, 0));
      check_equal(get(other_arr, 1), get(arr, 1));
      check_equal(get(other_arr, 2), get(arr, 2));
      check_equal(num_bytes(file_name), bytes_per_word * arr.length);
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      deallocate(arr);
      deallocate(other_arr);

      if run("Has length") then
        arr := new_1d;
        check_equal(arr.length, 0);

      elsif run("Has bit_width") then
        arr := new_1d;
        check_equal(arr.bit_width, 32);

      elsif run("Has is_signed") then
        arr := new_1d;
        check_equal(arr.is_signed, true);

      elsif run("Has new_1d") then
        arr := new_1d(length => 10, bit_width => 16, is_signed => false);
        check_equal(arr.length, 10);
        check_equal(arr.bit_width, 16);
        check_equal(arr.is_signed, false);

      elsif run("Has new_2d") then
        arr := new_2d(width => 7, height => 13, bit_width => 28, is_signed => true);
        check_equal(arr.width, 7);
        check_equal(arr.height, 13);
        check_equal(arr.length, 7*13);
        check_equal(arr.bit_width, 28);
        check_equal(arr.is_signed, true);

      elsif run("Has new_3d") then
        arr := new_3d(width => 7, height => 13, depth => 5,
                      bit_width => 28, is_signed => true);
        check_equal(arr.width, 7);
        check_equal(arr.height, 13);
        check_equal(arr.depth, 5);
        check_equal(arr.length, 5*7*13);
        check_equal(arr.bit_width, 28);
        check_equal(arr.is_signed, true);

      elsif run("Has copy") then
        arr := new_3d(width => 7, height => 13, depth => 5,
                      bit_width => 28, is_signed => true);
        for i in 0 to arr.length-1 loop
          set(arr, idx=>i, value => i);
        end loop;

        other_arr := copy(arr);
        check_equal(arr.width, other_arr.width);
        check_equal(arr.height, other_arr.height);
        check_equal(arr.depth, other_arr.depth);
        check_equal(arr.length, other_arr.length);
        check_equal(arr.bit_width, other_arr.bit_width);
        check_equal(arr.is_signed, other_arr.is_signed);
        for i in 0 to other_arr.length-1 loop
          check_equal(get(arr, i), get(other_arr, i));
        end loop;

      elsif run("Has set") then
        arr := new_1d(length => 1);
        set(arr, 0,7);

      elsif run("Has set 2d") then
        arr := new_2d(width => 1, height => 2);
        set(arr, x => 0, y => 0, value => 7);
        set(arr, x => 0, y => 1, value => 11);

      elsif run("Test reshape") then
        arr := new_1d(length => 1);
        set(arr, 0, value => 100);

        reshape(arr, 2);
        check_equal(arr.length, 2);
        check_equal(get(arr, 0), 100);
        set(arr, 1, value => 200);
        check_equal(get(arr, 1), 200);

        reshape(arr, 1);
        check_equal(arr.length, 1);
        check_equal(get(arr, 0), 100);

      elsif run("Test reshape 2d") then
        arr := new_1d(length => 3);
        for i in 0 to 2 loop
          set(arr, i, value => 10+i);
        end loop;

        reshape(arr, 1, 3);
        check_equal(arr.width, 1);
        check_equal(arr.height, 3);
        check_equal(arr.depth, 1);
        for i in 0 to 2 loop
          check_equal(get(arr, i), 10+i);
        end loop;

        for i in 0 to 2 loop
          check_equal(get(arr, 0, i), 10+i);
        end loop;

        reshape(arr, 3, 1);
        check_equal(arr.width, 3);
        check_equal(arr.height, 1);
        check_equal(arr.depth, 1);
        for i in 0 to 2 loop
          check_equal(get(arr, i), 10+i);
        end loop;
        for i in 0 to 2 loop
          check_equal(get(arr, i, 0), 10+i);
        end loop;

        reshape(arr, 2, 1);
        check_equal(arr.width, 2);
        check_equal(arr.height, 1);
        check_equal(arr.depth, 1);
        check_equal(get(arr, 0, 0), 10);
        check_equal(get(arr, 1, 0), 11);

      elsif run("Test reshape 3d") then
        arr := new_1d(length => 6);
        for i in 0 to 5 loop
          set(arr, i, value => 10+i);
        end loop;

        reshape(arr, 1, 2, 3);
        check_equal(arr.width, 1);
        check_equal(arr.height, 2);
        check_equal(arr.depth, 3);
        for i in 0 to 5 loop
          check_equal(get(arr, i), 10+i);
        end loop;

        for i in 0 to 5 loop
          check_equal(get(arr, 0, i / 3, i mod 3), 10+i);
        end loop;


      elsif run("Has get") then
        arr := new_1d(2);
        set(arr, 0, 7);
        set(arr, 1, 11);
        check_equal(get(arr, 0), 7);
        check_equal(get(arr, 1), 11);

      elsif run("Has get 2d") then
        arr := new_2d(width => 2, height => 3);
        for i in 0 to 5 loop
          set(arr, i mod 2,  i/2, 10 + i);
        end loop;

        for i in 0 to 5 loop
          check_equal(get(arr, i mod 2, i/2), 10 + i);
        end loop;

        for i in 0 to 5 loop
          check_equal(get(arr, i), 10 + i);
        end loop;

      elsif run("Has set and get 2d") then
        arr := new_3d(width => 2, height => 3, depth => 5);
        for x in 0 to arr.width-1 loop
          for y in 0 to arr.height-1 loop
            for z in 0 to arr.depth-1 loop
              set(arr, x,y,z, 1000*x + 100*y + z);
            end loop;
          end loop;
        end loop;

        for x in 0 to arr.width-1 loop
          for y in 0 to arr.height-1 loop
            for z in 0 to arr.depth-1 loop
              check_equal(get(arr, x,y,z), 1000*x + 100*y + z);
            end loop;
          end loop;
        end loop;

      elsif run("Has append") then
        arr := new_1d;
        append(arr, 11);
        check_equal(arr.length, 1);
        check_equal(get(arr, 0), 11);

        append(arr, 7);
        check_equal(arr.length, 2);
        check_equal(get(arr, 1), 7);

      elsif run("Deallocate sets length to 0") then
        arr := new_1d;
        append(arr, 10);
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

      elsif run("Can save and load csv") then
        arr := new_1d;
        append(arr, integer'left);
        append(arr, 0);
        append(arr, integer'right);
        save_csv(arr, output_path & "can_save.csv");
        other_arr := load_csv(output_path & "can_save.csv");
        check_equal(other_arr.length, arr.length);
        for idx in 0 to arr.length-1 loop
          check_equal(get(arr, idx), get(other_arr, idx));
        end loop;

      elsif run("Can save and load csv 2d") then
        arr := new_1d;
        append(arr, integer'left);
        append(arr, 0);
        append(arr, integer'right);
        append(arr, 1);
        reshape(arr, 2, 2);
        save_csv(arr, output_path & "can_save_2d.csv");

        other_arr := load_csv(output_path & "can_save_2d.csv");
        check_equal(other_arr.length, arr.length);
        check_equal(other_arr.width, arr.width);
        check_equal(other_arr.height, arr.height);
        check_equal(other_arr.depth, arr.depth);

        for x in 0 to arr.width-1 loop
          for y in 0 to arr.height-1 loop
            check_equal(get(arr, x,y), get(other_arr, x,y));
          end loop;
        end loop;

      elsif run("Can save and load csv 3d") then
        arr := new_1d;
        for i in 0 to 30 loop
          append(arr, i);
        end loop;
        reshape(arr, 2, 3, 5);
        save_csv(arr, output_path & "can_save_3d.csv");

        other_arr := load_csv(output_path & "can_save_3d.csv");
        check_equal(other_arr.length, arr.length);
        check_equal(other_arr.width, arr.width*arr.depth);
        check_equal(other_arr.height, arr.height);

        for idx in 0 to arr.length-1 loop
          check_equal(get(arr, idx), get(other_arr, idx));
        end loop;

      elsif run("Can save and load raw") then
        for bit_width in 1 to 31 loop
          for is_signed in 0 to 1 loop
            test_save_and_load_raw(bit_width => bit_width, is_signed => is_signed=1);
          end loop;
        end loop;
        test_save_and_load_raw(bit_width => 32, is_signed => true);

      elsif run("Save signed and load unsigned") then
        arr := new_1d(bit_width => 14,
                      is_signed => true);
        append(arr, -1);
        append(arr, -2**13);
        save_raw(arr, output_path & "s14_to_u16.csv");
        other_arr := load_raw(output_path & "s14_to_u16.csv",
                              bit_width => 16,
                              is_signed => false);
        check_equal(other_arr.length, 2);
        check_equal(get(other_arr, 0), 2**16-1);
        check_equal(get(other_arr, 1), 2**16 - 2**13);

      elsif run("is null") then
        deallocate(arr);
        check_true(is_null(arr));
        arr := new_1d;
        check_false(is_null(arr));
        append(arr, 1);
        deallocate(arr);
        check_true(is_null(arr));
      end if;

    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
