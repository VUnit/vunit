-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_bit.all;
use ieee.math_complex.all;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.integer_vector_ptr_pkg.all;
use vunit_lib.string_ptr_pkg.all;
use vunit_lib.integer_array_pkg.all;
use work.queue_pkg.all;

entity tb_queue is
  generic (runner_cfg : string);
end entity;

architecture a of tb_queue is
  constant test_string1 : string(1 to 7) := "abcdefg";
  constant test_string2 : string(7 downto 1) := "abcdefg";
  constant ascending_slv : std_logic_vector(22 to 23) := "UX";
  constant ascending_sulv : std_ulogic_vector(22 to 23) := "UX";
  constant descending_slv : std_logic_vector(9 downto 1) := "000111UUU";
  constant descending_sulv : std_ulogic_vector(9 downto 1) := "000111UUU";
begin
  main : process
    variable queue, another_queue, queue_copy : queue_t;
    variable bv : bit_vector(0 to 5);
    variable integer_vector_ptr, integer_vector_ptr_copy : integer_vector_ptr_t;
    variable string_ptr, string_ptr_copy : string_ptr_t;
    variable integer_array, integer_array_copy: integer_array_t;
  begin
    test_runner_setup(runner, runner_cfg);
    if run("Test default queue is null") then
      assert queue = null_queue report "Expected null queue";

    elsif run("Test is_empty") then
      queue := new_queue;
      check(is_empty(queue), "Empty queue");

      push_integer(queue, 11);
      check_false(is_empty(queue), "Empty queue");

      check_equal(pop_integer(queue), 11, "data");
      check(is_empty(queue), "Empty queue");

    elsif run("Test push and pop integer") then
      queue := new_queue;
      assert queue /= null_queue report "Expected non null queue";
      check_equal(length(queue), 0, "Empty queue length");

      push_integer(queue, 11);
      check_equal(length(queue), 5, "Length");
      push_integer(queue, 22);
      check_equal(length(queue), 10, "Length");

      check_equal(pop_integer(queue), 11, "data");
      check_equal(length(queue), 5, "Length");
      check_equal(pop_integer(queue), 22, "data");
      check_equal(length(queue), 0, "Length");

      push_integer(queue, integer'low);
      check_equal(pop_integer(queue), integer'low, "data");
      push_integer(queue, integer'high);
      check_equal(pop_integer(queue), integer'high, "data");

    elsif run("Test push and pop byte") then
      queue := new_queue;
      push_byte(queue, 11);
      push_byte(queue, 22);
      check_equal(pop_byte(queue), 11, "data");
      check_equal(pop_byte(queue), 22, "data");

    elsif run("Test push and pop boolean") then
      queue := new_queue;
      push_boolean(queue, false);
      push_boolean(queue, true);
      check_false(pop_boolean(queue), "data");
      check_true(pop_boolean(queue), "data");

    elsif run("Test push and pop character") then
      queue := new_queue;
      assert queue /= null_queue report "Expected non null queue";
      check_equal(length(queue), 0, "Empty queue length");

      push_character(queue, '1');
      check_equal(length(queue), 2, "Length");
      push_character(queue, '2');
      check_equal(length(queue), 4, "Length");

      assert pop_character(queue) = '1';
      check_equal(length(queue), 2, "Length");
      assert pop_character(queue) = '2';
      check_equal(length(queue), 0, "Length");

    elsif run("Test flush queue") then
      queue := new_queue;
      push_character(queue, '1');
      check_equal(length(queue), 2, "Length");
      push_character(queue, '2');
      check_equal(length(queue), 4, "Length");
      flush(queue);
      check_equal(length(queue), 0, "Length");

    elsif run("Test push and pop queue_t") then
      queue := new_queue;
      another_queue := new_queue;
      push(another_queue, 22);
      queue_copy := another_queue;
      push_queue_ref(queue, another_queue);
      assert another_queue = null_queue report "Ownership was transfered";
      assert pop_queue_ref(queue) = queue_copy report "Queue should come back";

    elsif run("Test push and pop string") then
      queue := new_queue;
      push_string(queue, "hello world");
      push_string(queue, "two");
      push_string(queue, test_string1);
      push_string(queue, test_string2);
      assert pop_string(queue) = "hello world";
      assert pop_string(queue) = "two";
      assert pop_string(queue) = test_string1;
      assert pop_string(queue) = test_string2;

    elsif run("Test push and pop bit") then
      queue := new_queue;
      push_bit(queue, '0');
      push_bit(queue, '1');
      check(pop_bit(queue) = '0');
      check(pop_bit(queue) = '1');

    elsif run("Test push and pop std_ulogic") then
      queue := new_queue;
      push_std_ulogic(queue, 'U');
      push_std_ulogic(queue, 'X');
      push_std_ulogic(queue, '0');
      push_std_ulogic(queue, '1');
      push_std_ulogic(queue, 'Z');
      push_std_ulogic(queue, 'W');
      push_std_ulogic(queue, 'L');
      push_std_ulogic(queue, 'H');
      push_std_ulogic(queue, '-');
      assert pop_std_ulogic(queue) = 'U';
      assert pop_std_ulogic(queue) = 'X';
      assert pop_std_ulogic(queue) = '0';
      assert pop_std_ulogic(queue) = '1';
      assert pop_std_ulogic(queue) = 'Z';
      assert pop_std_ulogic(queue) = 'W';
      assert pop_std_ulogic(queue) = 'L';
      assert pop_std_ulogic(queue) = 'H';
      assert pop_std_ulogic(queue) = '-';

    elsif run("Test push and pop severity_level") then
      queue := new_queue;
      push_severity_level(queue, note);
      push_severity_level(queue, error);
      check(pop_severity_level(queue) = note);
      check(pop_severity_level(queue) = error);

    elsif run("Test push and pop file_open_status") then
      queue := new_queue;
      push_file_open_status(queue, open_ok);
      push_file_open_status(queue, mode_error);
      check(pop_file_open_status(queue) = open_ok);
      check(pop_file_open_status(queue) = mode_error);

    elsif run("Test push and pop file_open_kind") then
      queue := new_queue;
      push_file_open_kind(queue, read_mode);
      push_file_open_kind(queue, append_mode);
      check(pop_file_open_kind(queue) = read_mode);
      check(pop_file_open_kind(queue) = append_mode);

    elsif run("Test push and pop bit_vector") then
      queue := new_queue;
      push_bit_vector(queue, "1");
      push_bit_vector(queue, "010101");
      bv(0 to 0) := pop_bit_vector(queue);
      check(bv(0) = '1');
      bv := pop_bit_vector(queue);
      check(bv = "010101");

    elsif run("Test push and pop std_ulogic_vector") then
      queue := new_queue;
      push_std_ulogic_vector(queue, descending_sulv);
      push_std_ulogic_vector(queue, ascending_sulv);
      assert pop_std_ulogic_vector(queue) = descending_sulv;
      assert pop_std_ulogic_vector(queue) = ascending_sulv;

    elsif run("Test push and pop complex") then
      queue := new_queue;
      push_complex(queue, (1.0, 2.2));
      push_complex(queue, (-1.0, -2.2));
      check(pop_complex(queue) = (1.0, 2.2));
      check(pop_complex(queue) = (-1.0, -2.2));

    elsif run("Test push and pop complex_polar") then
      queue := new_queue;
      push_complex_polar(queue, (1.0, 0.707));
      push_complex_polar(queue, (3.14, -0.707));
      check(pop_complex_polar(queue) = (1.0, 0.707));
      check(pop_complex_polar(queue) = (3.14, -0.707));

    elsif run("Test push and pop ieee.numeric_bit.unsigned") then
      queue := new_queue;
      push_numeric_bit_unsigned(queue, "1");
      push_numeric_bit_unsigned(queue, "010101");
      check(pop_numeric_bit_unsigned(queue) = "1");
      check(pop_numeric_bit_unsigned(queue) = "010101");

    elsif run("Test push and pop ieee.numeric_bit.signed") then
      queue := new_queue;
      push_numeric_bit_signed(queue, "1");
      push_numeric_bit_signed(queue, "010101");
      check(pop_numeric_bit_signed(queue) = "1");
      check(pop_numeric_bit_signed(queue) = "010101");

    elsif run("Test push and pop ieee.numeric_std.unsigned") then
      queue := new_queue;
      push_numeric_std_unsigned(queue, "1");
      push_numeric_std_unsigned(queue, "010101");
      check(pop_numeric_std_unsigned(queue) = "1");
      check(pop_numeric_std_unsigned(queue) = "010101");

    elsif run("Test push and pop ieee.numeric_std.signed") then
      queue := new_queue;
      push_numeric_std_signed(queue, "1");
      push_numeric_std_signed(queue, "010101");
      check(pop_numeric_std_signed(queue) = "1");
      check(pop_numeric_std_signed(queue) = "010101");

    elsif run("Test push and pop std_logic_vector") then
      queue := new_queue;
      push_std_ulogic_vector(queue, std_ulogic_vector(descending_slv));
      push_std_ulogic_vector(queue, std_ulogic_vector(ascending_slv));
      assert std_logic_vector(pop_std_ulogic_vector(queue)) = descending_slv;
      assert std_logic_vector(pop_std_ulogic_vector(queue)) = ascending_slv;

    elsif run("Test push and pop signed and unsigned") then
      queue := new_queue;
      push_std_ulogic_vector(queue, std_ulogic_vector(ieee.numeric_std.to_unsigned(11, 16)));
      push_std_ulogic_vector(queue, std_ulogic_vector(ieee.numeric_std.to_signed(-1, 8)));
      assert ieee.numeric_std.unsigned(pop_std_ulogic_vector(queue)) = ieee.numeric_std.to_unsigned(11, 16);
      assert ieee.numeric_std.signed(pop_std_ulogic_vector(queue)) = ieee.numeric_std.to_signed(-1, 8);

    elsif run("Test push and pop real") then
      queue := new_queue;
      push_real(queue, 1.0);
      push_real(queue, -1.0);
      push_real(queue, 2.0);
      push_real(queue, 0.5);
      push_real(queue, -0.5);
      assert pop_real(queue) = 1.0;
      assert pop_real(queue) = -1.0;
      assert pop_real(queue) = 2.0;
      assert pop_real(queue) = 0.5;
      assert pop_real(queue) = -0.5;

      push_real(queue, 1.0 + 0.5**23); -- Single
      push_real(queue, -(1.0 + 0.5**23)); -- Single
      push_real(queue, 1.0 + 0.5**53); -- Double
      push_real(queue, -(1.0 + 0.5**53)); -- Double
      assert pop_real(queue) = 1.0 + 0.5**23;
      assert pop_real(queue) = -(1.0 + 0.5**23);
      assert pop_real(queue) = 1.0 + 0.5**53;
      assert pop_real(queue) = -(1.0 + 0.5**53);

    elsif run("Test push and pop time") then
      queue := new_queue;
      push_time(queue, 1 fs);
      push_time(queue, 1 ps);
      push_time(queue, 1 ns);
      push_time(queue, 1 ms);
      push_time(queue, 1 sec);
      push_time(queue, 1 min);
      push_time(queue, 1 hr);
      assert pop_time(queue) = 1 fs;
      assert pop_time(queue) = 1 ps;
      assert pop_time(queue) = 1 ns;
      assert pop_time(queue) = 1 ms;
      assert pop_time(queue) = 1 sec;
      assert pop_time(queue) = 1 min;
      assert pop_time(queue) = 1 hr;

      push_time(queue, 1 hr + 1 fs);
      assert pop_time(queue) = 1 hr + 1 fs;

      push_time(queue, -1 fs);
      push_time(queue, -1 hr);
      push_time(queue, -1 hr - 1 fs);
      assert pop_time(queue) = -1 fs;
      assert pop_time(queue) = -1 hr;
      assert pop_time(queue) = -1 hr - 1 fs;

    elsif run("Test push and pop integer_vector_ptr_t") then
      queue := new_queue;
      integer_vector_ptr := new_integer_vector_ptr;
      integer_vector_ptr_copy := integer_vector_ptr;
      push_integer_vector_ptr_ref(queue, integer_vector_ptr);
      assert integer_vector_ptr = null_ptr report "Ownership was transfered";
      assert pop_integer_vector_ptr_ref(queue) = integer_vector_ptr_copy;

    elsif run("Test push and pop string_ptr_t") then
      queue := new_queue;
      string_ptr := new_string_ptr;
      string_ptr_copy := string_ptr;
      push_string_ptr_ref(queue, string_ptr);
      assert string_ptr = null_string_ptr report "Ownership was transfered";
      assert pop_string_ptr_ref(queue) = string_ptr_copy;

    elsif run("Test push and pop integer_array_t") then
      queue := new_queue;
      integer_array := new_3d(1, 2, 3, 4);
      integer_array_copy := integer_array;
      push_integer_array_t_ref(queue, integer_array);
      assert integer_array = null_integer_array;
      assert pop_integer_array_t_ref(queue) = integer_array_copy;

    elsif run("Test codecs") then
      queue := new_queue;
      check(decode(encode(queue)) = queue);

      another_queue := new_queue;
      push_string(another_queue, "hello world");
      push_real(another_queue, 1.0);
      check(decode(encode(another_queue)) = another_queue);
    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
