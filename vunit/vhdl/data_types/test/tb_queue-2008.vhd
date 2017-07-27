-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.queue_pkg.all;
use work.queue_2008_pkg.all;

entity tb_queue_2008 is
  generic (runner_cfg : string);
end entity;

architecture a of tb_queue_2008 is
begin
  main : process
    variable queue : queue_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("Test push and pop boolean_vector") then
      queue := allocate;
      push_boolean_vector(queue, (1 => true));
      push_boolean_vector(queue, (false, true));
      check(pop_boolean_vector(queue) = (1 => true));
      check(pop_boolean_vector(queue) = (false, true));

    elsif run("Test push and pop integer_vector") then
      queue := allocate;
      push_integer_vector(queue, (1 => 17));
      push_integer_vector(queue, (-21, 42));
      check(pop_integer_vector(queue) = (1 => 17));
      check(pop_integer_vector(queue) = (-21, 42));

    elsif run("Test push and pop real_vector") then
      queue := allocate;
      push_real_vector(queue, (1 => 17.17));
      push_real_vector(queue, (-21.21, 42.42));
      check(pop_real_vector(queue) = (1 => 17.17));
      check(pop_real_vector(queue) = (-21.21, 42.42));

    elsif run("Test push and pop time_vector") then
      queue := allocate;
      push_time_vector(queue, (1 => 17.17 ms));
      push_time_vector(queue, (-21.21 min, 42.42 us));
      check(pop_time_vector(queue) = (1 => 17.17 ms));
      check(pop_time_vector(queue) = (-21.21 min, 42.42 us));

    elsif run("Test push and pop ufixed") then
      queue := allocate;
      push_ufixed(queue, to_ufixed(17.17, 6, -9));
      push_ufixed(queue, to_ufixed(42.42, 6, -9));
      check(pop_ufixed(queue) = to_ufixed(17.17, 6, -9));
      check(pop_ufixed(queue) = to_ufixed(42.42, 6, -9));

    elsif run("Test push and pop sfixed") then
      queue := allocate;
      push_sfixed(queue, to_sfixed(17.17, 6, -9));
      push_sfixed(queue, to_sfixed(-21.21, 6, -9));
      check(pop_sfixed(queue) = to_sfixed(17.17, 6, -9));
      check(pop_sfixed(queue) = to_sfixed(-21.21, 6, -9));

    elsif run("Test push and pop float") then
      queue := allocate;
      push_float(queue, to_float(17.17));
      push_float(queue, to_float(-21.21));
      check(pop_float(queue) = to_float(17.17));
      check(pop_float(queue) = to_float(-21.21));

    end if;

    test_runner_cleanup(runner);
  end process;
end architecture;
