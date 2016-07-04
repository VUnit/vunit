-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

-- @TODO add explicit check of csv string data
use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;
use work.array_pkg.all;

entity tb_array is
  generic (
    output_path : string;
    runner_cfg : string);
end entity;

architecture a of tb_array is
begin

  main : process
    variable arr : array_t;
    variable other_arr : array_t;

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
      variable arr : array_t;
      variable other_arr : array_t;

      impure function file_name return string is
      begin
        if is_signed then
          return output_path & "s" & to_string(bit_width) & ".raw";
        else
          return output_path & "u" & to_string(bit_width) & ".raw";
        end if;
      end function;

      constant bytes_per_word : integer := (bit_width+7)/8;

    begin
        arr.init(bit_width => bit_width, is_signed => is_signed);
        arr.append(arr.lower_limit);
        arr.append(0);
        arr.append(arr.upper_limit);
        arr.save_raw(file_name);
        other_arr.load_raw(file_name,
                           bit_width => bit_width, is_signed => is_signed);
        check_equal(other_arr.get(0), arr.get(0));
        check_equal(other_arr.get(1), arr.get(1));
        check_equal(other_arr.get(2), arr.get(2));
        check_equal(num_bytes(file_name), bytes_per_word * arr.length);
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      arr.init;

      if run("Has length") then
        check_equal(arr.length, 0);

      elsif run("Has bit_width") then
        check_equal(arr.bit_width, 32);

      elsif run("Has is_signed") then
        check_equal(arr.is_signed, true);

      elsif run("Has init") then
        arr.init(length => 10, bit_width => 16, is_signed => false);
        check_equal(arr.length, 10);
        check_equal(arr.bit_width, 16);
        check_equal(arr.is_signed, false);

      elsif run("Has init_2d") then
        arr.init_2d(width => 7, height => 13, bit_width => 28, is_signed => true);
        check_equal(arr.width, 7);
        check_equal(arr.height, 13);
        check_equal(arr.length, 7*13);
        check_equal(arr.bit_width, 28);
        check_equal(arr.is_signed, true);

      elsif run("Has init_3d") then
        arr.init_3d(width => 7, height => 13, depth => 5,
                    bit_width => 28, is_signed => true);
        check_equal(arr.width, 7);
        check_equal(arr.height, 13);
        check_equal(arr.depth, 5);
        check_equal(arr.length, 5*7*13);
        check_equal(arr.bit_width, 28);
        check_equal(arr.is_signed, true);

     elsif run("Has copy_from") then
        arr.init_3d(width => 7, height => 13, depth => 5,
                    bit_width => 28, is_signed => true);
        for i in 0 to arr.length-1 loop
          arr.set(idx=>i, value => i);
        end loop;

        other_arr.copy_from(arr);
        check_equal(arr.width, other_arr.width);
        check_equal(arr.height, other_arr.height);
        check_equal(arr.depth, other_arr.depth);
        check_equal(arr.length, other_arr.length);
        check_equal(arr.bit_width, other_arr.bit_width);
        check_equal(arr.is_signed, other_arr.is_signed);
        for i in 0 to other_arr.length-1 loop
          check_equal(arr.get(i), other_arr.get(i));
        end loop;

      elsif run("Has set") then
        arr.init(length => 1);
        arr.set(0,7);

      elsif run("Has set 2d") then
        arr.init_2d(width => 1, height => 2);
        arr.set(x => 0, y => 0, value => 7);
        arr.set(x => 0, y => 1, value => 11);

      elsif run("Test reshape") then
        arr.init(length => 1);
        arr.set(0, value => 100);

        arr.reshape(2);
        check_equal(arr.length, 2);
        check_equal(arr.get(0), 100);
        arr.set(1, value => 200);
        check_equal(arr.get(1), 200);

        arr.reshape(1);
        check_equal(arr.length, 1);
        check_equal(arr.get(0), 100);

      elsif run("Test reshape 2d") then
        arr.init(length => 3);
        for i in 0 to 2 loop
          arr.set(i, value => 10+i);
        end loop;

        arr.reshape(1, 3);
        check_equal(arr.width, 1);
        check_equal(arr.height, 3);
        check_equal(arr.depth, 1);
        for i in 0 to 2 loop
          check_equal(arr.get(i), 10+i);
        end loop;

        for i in 0 to 2 loop
          check_equal(arr.get(0, i), 10+i);
        end loop;

        arr.reshape(3, 1);
        check_equal(arr.width, 3);
        check_equal(arr.height, 1);
        check_equal(arr.depth, 1);
        for i in 0 to 2 loop
          check_equal(arr.get(i), 10+i);
        end loop;
        for i in 0 to 2 loop
          check_equal(arr.get(i, 0), 10+i);
        end loop;

        arr.reshape(2, 1);
        check_equal(arr.width, 2);
        check_equal(arr.height, 1);
        check_equal(arr.depth, 1);
        check_equal(arr.get(0, 0), 10);
        check_equal(arr.get(1, 0), 11);

      elsif run("Test reshape 3d") then
        arr.init(length => 6);
        for i in 0 to 5 loop
          arr.set(i, value => 10+i);
        end loop;

        arr.reshape(1, 2, 3);
        check_equal(arr.width, 1);
        check_equal(arr.height, 2);
        check_equal(arr.depth, 3);
        for i in 0 to 5 loop
          check_equal(arr.get(i), 10+i);
        end loop;

        for i in 0 to 5 loop
          check_equal(arr.get(0, i / 3, i mod 3), 10+i);
        end loop;


      elsif run("Has get") then
        arr.init(2);
        arr.set(0, 7);
        arr.set(1, 11);
        check_equal(arr.get(0), 7);
        check_equal(arr.get(1), 11);

      elsif run("Has get 2d") then
        arr.init_2d(width => 2, height => 3);
        for i in 0 to 5 loop
          arr.set(i mod 2,  i/2, 10 + i);
        end loop;

        for i in 0 to 5 loop
          check_equal(arr.get(i mod 2, i/2), 10 + i);
        end loop;

        for i in 0 to 5 loop
          check_equal(arr.get(i), 10 + i);
        end loop;

      elsif run("Has set and get 2d") then
        arr.init_3d(width => 2, height => 3, depth => 5);
        for x in 0 to arr.width-1 loop
          for y in 0 to arr.height-1 loop
            for z in 0 to arr.depth-1 loop
              arr.set(x,y,z, 1000*x + 100*y + z);
            end loop;
          end loop;
        end loop;

        for x in 0 to arr.width-1 loop
          for y in 0 to arr.height-1 loop
            for z in 0 to arr.depth-1 loop
              check_equal(arr.get(x,y,z), 1000*x + 100*y + z);
            end loop;
          end loop;
        end loop;

      elsif run("Has append") then
        arr.append(11);
        check_equal(arr.length, 1);
        check_equal(arr.get(0), 11);

        arr.append(7);
        check_equal(arr.length, 2);
        check_equal(arr.get(1), 7);

      elsif run("Clear sets length to 0") then
        arr.append(10);
        check_equal(arr.length, 1);
        arr.clear;
        check_equal(arr.length, 0);

      elsif run("Clear sets width height depth to 0") then
        arr.init_3d(width => 2, height => 3, depth => 5);
        check_equal(arr.width, 2);
        check_equal(arr.height, 3);
        check_equal(arr.depth, 5);
        arr.clear;
        check_equal(arr.width, 0);
        check_equal(arr.height, 0);
        check_equal(arr.depth, 0);

      elsif run("Can save and load csv") then
        arr.append(integer'left);
        arr.append(0);
        arr.append(integer'right);
        arr.save_csv(output_path & "can_save.csv");
        other_arr.load_csv(output_path & "can_save.csv");
        check_equal(other_arr.length, arr.length);
        for idx in 0 to arr.length-1 loop
          check_equal(arr.get(idx), other_arr.get(idx));
        end loop;

      elsif run("Can save and load csv 2d") then
        arr.append(integer'left);
        arr.append(0);
        arr.append(integer'right);
        arr.append(1);
        arr.reshape(2, 2);
        arr.save_csv(output_path & "can_save_2d.csv");

        other_arr.load_csv(output_path & "can_save_2d.csv");
        check_equal(other_arr.length, arr.length);
        check_equal(other_arr.width, arr.width);
        check_equal(other_arr.height, arr.height);
        check_equal(other_arr.depth, arr.depth);

        for x in 0 to arr.width-1 loop
          for y in 0 to arr.height-1 loop
            check_equal(arr.get(x,y), other_arr.get(x,y));
          end loop;
        end loop;

      elsif run("Can save and load csv 3d") then
        for i in 0 to 30 loop
          arr.append(i);
        end loop;
        arr.reshape(2, 3, 5);
        arr.save_csv(output_path & "can_save_3d.csv");

        other_arr.load_csv(output_path & "can_save_3d.csv");
        check_equal(other_arr.length, arr.length);
        check_equal(other_arr.width, arr.width*arr.depth);
        check_equal(other_arr.height, arr.height);

        for idx in 0 to arr.length-1 loop
          check_equal(arr.get(idx), other_arr.get(idx));
        end loop;

      elsif run("Can save and load raw") then
        for bit_width in 1 to 31 loop
          for is_signed in 0 to 1 loop
            test_save_and_load_raw(bit_width => bit_width, is_signed => is_signed=1);
          end loop;
        end loop;
        test_save_and_load_raw(bit_width => 32, is_signed => true);

      elsif run("Save signed and load unsigned") then
        arr.init(bit_width => 14,
                 is_signed => true);
        arr.append(-1);
        arr.append(-2**13);
        arr.save_raw(output_path & "s14_to_u16.csv");
        other_arr.load_raw(output_path & "s14_to_u16.csv",
                           bit_width => 16,
                           is_signed => false);
        check_equal(other_arr.length, 2);
        check_equal(other_arr.get(0), 2**16-1);
        check_equal(other_arr.get(1), 2**16 - 2**13);
      end if;

    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;

-- vunit_pragma fail_on_warning
-- vunit_pragma run_all_in_same_sim
