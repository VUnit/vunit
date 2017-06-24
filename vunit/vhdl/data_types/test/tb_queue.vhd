-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

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
    variable queue, another_queue : queue_t;
  begin
    test_runner_setup(runner, runner_cfg);
    if run("Test default queue is null") then
      assert queue = null_queue report "Expected null queue";

    elsif run("Test push and pop integer") then
      queue := allocate;
      assert queue /= null_queue report "Expected non null queue";
      check_equal(length(queue), 0, "Empty queue length");

      push(queue, 11);
      check_equal(length(queue), 1, "Length");
      push(queue, 22);
      check_equal(length(queue), 2, "Length");

      check_equal(pop(queue), 11, "data");
      check_equal(length(queue), 1, "Length");
      check_equal(pop(queue), 22, "data");
      check_equal(length(queue), 0, "Length");

    elsif run("Test flush queue") then
      queue := allocate;
      push(queue, 11);
      check_equal(length(queue), 1, "Length");
      push(queue, 22);
      check_equal(length(queue), 2, "Length");
      flush(queue);
      check_equal(length(queue), 0, "Length");

    elsif run("Test push and pop queue") then
      queue := allocate;
      another_queue := allocate;
      push(another_queue, 22);
      push_queue_ref(queue, another_queue);
      assert pop_queue_ref(queue) = another_queue report "Queue should come back";

    elsif run("Test push and pop string") then
      queue := allocate;
      push_string(queue, "hello world");
      push_string(queue, "two");
      push_string(queue, test_string1);
      push_string(queue, test_string2);
      assert pop_string(queue) = "hello world";
      assert pop_string(queue) = "two";
      assert pop_string(queue) = test_string1;
      assert pop_string(queue) = test_string2;

    elsif run("Test push and pop std_ulogic") then
      queue := allocate;
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

    elsif run("Test push and pop std_ulogic_vector") then
      queue := allocate;
      push_std_ulogic_vector(queue, descending_sulv);
      push_std_ulogic_vector(queue, ascending_sulv);
      assert pop_std_ulogic_vector(queue) = descending_sulv;
      assert pop_std_ulogic_vector(queue) = ascending_sulv;

    elsif run("Test push and pop std_logic_vector") then
      queue := allocate;
      push_std_ulogic_vector(queue, descending_slv);
      push_std_ulogic_vector(queue, ascending_slv);
      assert pop_std_ulogic_vector(queue) = descending_slv;
      assert pop_std_ulogic_vector(queue) = ascending_slv;

    elsif run("Test push and pop signed and unsigned") then
      queue := allocate;
      push_std_ulogic_vector(queue, std_ulogic_vector(to_unsigned(11, 16)));
      push_std_ulogic_vector(queue, std_ulogic_vector(to_signed(-1, 8)));
      assert unsigned(pop_std_ulogic_vector(queue)) = to_unsigned(11, 16);
      assert signed(pop_std_ulogic_vector(queue)) = to_signed(-1, 8);

    elsif run("Test push and pop real") then
      queue := allocate;
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
    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
