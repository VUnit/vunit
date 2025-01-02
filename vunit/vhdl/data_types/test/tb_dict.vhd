-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;

use work.dict_pkg.all;
use work.queue_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.integer_array_pkg.all;

entity tb_dict is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_dict is
begin

  main : process
    variable dict : dict_t;
    variable dict_value : dict_t;
    variable integer_vector_ptr : integer_vector_ptr_t;
    variable string_ptr : string_ptr_t;
    variable integer_array : integer_array_t;
    variable queue : queue_t;
    constant many_keys : natural := 2**13;
    constant long_key : string := "long--------------------------------------------------------key";
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test default is null") then
      assert dict = null_dict report "expected null dict";

    elsif run("test new dict") then
      dict := new_dict;
      assert dict /= null_dict report "expected non-null dict";

    elsif run("test deallocate dict") then
      dict := new_dict;
      set_string(dict, "key", "value");
      deallocate(dict);
      assert dict = null_dict report "expected null dict";

    elsif run("test has key") then
      dict := new_dict;
      check_false(has_key(dict, "missing"));
      set_string(dict, "key", "value");
      check(has_key(dict, "key"));

    elsif run("test remove key") then
      dict := new_dict;

      set_string(dict, "key", "value");
      check(has_key(dict, "key"));
      check_equal(num_keys(dict), 1);

      remove(dict, "key");
      check_false(has_key(dict, "key"));
      check_equal(num_keys(dict), 0);

      remove(dict, "key");

    elsif run("test set and get string") then
      dict := new_dict;
      set(dict, "key", string'("value"));
      check(get(dict, "key") = string'("value"));

      set_string(dict, "key2", "value2");
      check(get_string(dict, "key2") = "value2");

    elsif run("test overwrite key") then
      dict := new_dict;
      set_string(dict, "key", "value");
      check(get_string(dict, "key") = "value");

      set_string(dict, "key", "value2");
      check(get_string(dict, "key") = "value2");

    elsif run("test set and get many keys") then
      dict := new_dict;

      for k in 1 to 2 loop

        report integer'image(k);

        for i in 1 to many_keys loop
          set(dict, long_key & integer'image(i), integer'image(i));
          check_equal(get(dict, long_key & integer'image(i)), integer'image(i));
          check_equal(num_keys(dict), i);
        end loop;

        for i in 1 to many_keys loop
          check_equal(get(dict, long_key & integer'image(i)), integer'image(i));
        end loop;

        for i in many_keys downto 1 loop
          remove(dict, long_key & integer'image(i));
          check_equal(num_keys(dict), i-1);
        end loop;

      end loop;

      deallocate(dict);

    elsif run("test set and get integer") then
      dict := new_dict;
      set_integer(dict, "key", 17);
      check(get_integer(dict, "key") = 17);

    elsif run("test set and get character") then
      dict := new_dict;
      set_character(dict, "key", 'a');
      check(get_character(dict, "key") = 'a');

    elsif run("test set and get boolean") then
      dict := new_dict;
      set_boolean(dict, "key", true);
      check(get_boolean(dict, "key") = true);

    elsif run("test set and get real") then
      dict := new_dict;
      set_real(dict, "key", 1.23);
      check(get_real(dict, "key") = 1.23);

    elsif run("test set and get bit") then
      dict := new_dict;
      set_bit(dict, "key", '1');
      check(get_bit(dict, "key") = '1');

    elsif run("test set and get std_ulogic") then
      dict := new_dict;
      set_std_ulogic(dict, "key", '1');
      check(get_std_ulogic(dict, "key") = '1');

    elsif run("test set and get severity_level") then
      dict := new_dict;
      set_severity_level(dict, "key", error);
      check(get_severity_level(dict, "key") = error);

    elsif run("test set and get file_open_status") then
      dict := new_dict;
      set_file_open_status(dict, "key", open_ok);
      check(get_file_open_status(dict, "key") = open_ok);

    elsif run("test set and get file_open_kind") then
      dict := new_dict;
      set_file_open_kind(dict, "key", read_mode);
      check(get_file_open_kind(dict, "key") = read_mode);

    elsif run("test set and get bit_vector") then
      dict := new_dict;
      set_bit_vector(dict, "key", "101");
      check(get_bit_vector(dict, "key") = "101");

    elsif run("test set and get std_ulogic_vector") then
      dict := new_dict;
      set_std_ulogic_vector(dict, "key", "101");
      check(get_std_ulogic_vector(dict, "key") = "101");

    elsif run("test set and get complex") then
      dict := new_dict;
      set_complex(dict, "key", (-17.17, 42.42));
      check(get_complex(dict, "key") = (-17.17, 42.42));

    elsif run("test set and get complex_polar") then
      dict := new_dict;
      set_complex_polar(dict, "key", (17.17, 0.42));
      check(get_complex_polar(dict, "key") = (17.17, 0.42));

    elsif run("test set and get ieee.numeric_bit.unsigned") then
      dict := new_dict;
      set_numeric_bit_unsigned(dict, "key", "101");
      check(get_numeric_bit_unsigned(dict, "key") = "101");

    elsif run("test set and get ieee.numeric_bit.signed") then
      dict := new_dict;
      set_numeric_bit_signed(dict, "key", "101");
      check(get_numeric_bit_signed(dict, "key") = "101");

    elsif run("test set and get ieee.numeric_std.unsigned") then
      dict := new_dict;
      set_numeric_std_unsigned(dict, "key", "101");
      check(get_numeric_std_unsigned(dict, "key") = "101");

    elsif run("test set and get ieee.numeric_std.signed") then
      dict := new_dict;
      set_numeric_std_signed(dict, "key", "101");
      check(get_numeric_std_signed(dict, "key") = "101");

    elsif run("test set and get time") then
      dict := new_dict;
      set_time(dict, "key", 17 ns);
      check(get_time(dict, "key") = 17 ns);

    elsif run("test set and get dict_t") then
      dict := new_dict;
      dict_value := new_dict;
      set_integer(dict_value, "my_integer", 17);
      set_dict_t_ref(dict, "key", dict_value);
      check(dict_value = null_dict);
      dict_value := get_dict_t_ref(dict, "key");
      check_equal(get_integer(dict_value, "my_integer"), 17);

    elsif run("test set and get integer_vector_ptr_t") then
      dict := new_dict;
      integer_vector_ptr := new_integer_vector_ptr(1);
      set(integer_vector_ptr, 0, 17);
      set_integer_vector_ptr_t_ref(dict, "key", integer_vector_ptr);
      check(integer_vector_ptr = null_integer_vector_ptr);
      integer_vector_ptr := get_integer_vector_ptr_t_ref(dict, "key");
      check_equal(get(integer_vector_ptr, 0), 17);

    elsif run("test set and get string_ptr_t") then
      dict := new_dict;
      string_ptr := new_string_ptr(1);
      set(string_ptr, 1, 'v');
      set_string_ptr_t_ref(dict, "key", string_ptr);
      check(string_ptr = null_string_ptr);
      string_ptr := get_string_ptr_t_ref(dict, "key");
      check_equal(get(string_ptr, 1), 'v');

    elsif run("test set and get integer_array_t") then
      dict := new_dict;
      integer_array := new_3d(1, 2, 3, bit_width => 13, is_signed => false);
      set(integer_array, 0, 1, 2, 17);
      set_integer_array_t_ref(dict, "key", integer_array);
      check(integer_array = null_integer_array);
      integer_array := get_integer_array_t_ref(dict, "key");
      check_equal(get(integer_array, 0, 1, 2), 17);
      check_equal(width(integer_array), 1);
      check_equal(height(integer_array), 2);
      check_equal(depth(integer_array), 3);
      check_equal(bit_width(integer_array), 13);
      check_false(is_signed(integer_array));

    elsif run("test set and get queue_t") then
      dict := new_dict;
      queue := new_queue;
      push(queue, 17);
      set_queue_t_ref(dict, "key", queue);
      check(queue = null_queue);
      queue := get_queue_t_ref(dict, "key");
      check_equal(pop_integer(queue), 17);

    elsif run("Test push and pop dict_t") then
      queue := new_queue;
      dict := new_dict;
      set_string(dict, "key", "value");
      push_dict_t_ref(queue, dict);
      check(dict = null_dict);
      dict := pop_dict_t_ref(queue);
      check_equal(get_string(dict, "key"), "value");

    elsif run("Test dict encode and decode") then
      dict := new_dict;
      set_integer(dict, "my_integer", 17);
      dict := decode(encode(dict));
      check_equal(get_integer(dict, "my_integer"), 17);


    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
