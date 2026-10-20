-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.data_types_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.file_line;

entity tb_reflection_queue_pkg is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_reflection_queue_pkg is
  type state_t is (idle, busy);

  type packet_t is record
    addr : natural;
    data : std_ulogic_vector(7 downto 0);
    count : unsigned(3 downto 0);
    name : string(1 to 3);
    ratio : real;
    delay : time;
    state : state_t;
  end record;

  type config_t is record
    enabled : boolean;
  end record;

  package packet_queue is new vunit_lib.reflection_queue_pkg generic map (t => packet_t);
  package config_queue is new vunit_lib.reflection_queue_pkg generic map (t => config_t);
  package vector_queue is new vunit_lib.reflection_queue_pkg generic map (t => integer_vector);
  use packet_queue.all;
  use config_queue.all;
  use vector_queue.all;

  constant packet : packet_t := (
    addr => 5, data => x"a5", count => x"9", name => "abc", ratio => 0.1, delay => 3 ns, state => busy);

  -- For the test across processes
  constant shared_queue : queue_t := new_queue;
  signal pushed : boolean := false;
begin

  main : process
    constant queue : queue_t := new_queue;
    constant other_queue : queue_t := new_queue;
    variable got : packet_t;
    variable config : config_t;
    constant reflection_queue_logger : logger_t := get_logger("vunit_lib:reflection_queue_pkg");
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test a record comes back unchanged") then
        push(queue, packet);
        got := pop(queue);
        check(got = packet, "The popped packet differs from the pushed one");
        check(is_empty(queue));

      elsif run("Test an unconstrained type") then
        push(queue, integer_vector'(1, 2, 3));
        push(queue, integer_vector'(0 => 7));
        check(pop(queue) = integer_vector'(1, 2, 3));
        check(pop(queue) = integer_vector'(0 => 7));

      elsif run("Test the order with other items") then
        push(queue, packet);
        push_integer(queue, 17);
        push(queue, config_t'(enabled => true));
        push_string(queue, "end");
        check(pop(queue) = packet);
        check_equal(pop_integer(queue), 17);
        config := pop(queue);
        check(config.enabled);
        check_equal(pop_string(queue), "end");

      elsif run("Test many values") then
        -- Grows the store past its initial size, then reuses the freed handles
        for i in 1 to 100 loop
          got := packet;
          got.addr := i;
          push(queue, got);
        end loop;
        for i in 1 to 100 loop
          got := pop(queue);
          check_equal(got.addr, i);
        end loop;
        for i in 1 to 100 loop
          got.addr := i;
          push(queue, got);
          got := pop(queue);
          check_equal(got.addr, i);
        end loop;

      elsif run("Test pushing and popping in different processes") then
        if not pushed then
          wait until pushed;
        end if;
        got := pop(shared_queue);
        check(got = packet);

      elsif run("Test popping a value of another instance fails") then
        -- A vector in the store, so that the failing pop has something to return
        push(other_queue, integer_vector'(1, 2));
        push(queue, config_t'(enabled => true));
        mock(reflection_queue_logger, failure);
        check(pop(queue) = integer_vector'(1, 2));
        check_only_log(
          reflection_queue_logger, "The next item on the queue was not pushed by this instance.", failure,
          line_num => file_line - 3, file_name => std.env.file_name
        );
        unmock(reflection_queue_logger);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  pusher : process
  begin
    push(shared_queue, packet);
    pushed <= true;
    wait;
  end process;
end architecture;
