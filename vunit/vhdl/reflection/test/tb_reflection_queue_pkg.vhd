-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.data_types_context;
use vunit_lib.reflection_queue_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_reflection_queue_pkg is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_reflection_queue_pkg is
  type state_t is (idle, busy);

  type scalars_t is record
    int : integer;
    float : real;
    flag : boolean;
    b : bit;
    sl : std_logic;
    char : character;
    delay : time;
    state : state_t;
  end record;

  type arrays_t is record
    name : string(1 to 3);
    data : std_ulogic_vector(7 downto 0);
    ascending : std_logic_vector(0 to 3);
    count : unsigned(3 downto 0);
    offset : signed(3 downto 0);
  end record;

  type inner_t is record
    level : natural;
    enabled : boolean;
  end record;

  type outer_t is record
    first : integer;
    inner : inner_t;
    last : integer;
  end record;

  type unsupported_t is record
    values : integer_vector(0 to 1);
  end record;

  -- Types that queue_pkg covers, such as integer, would make push ambiguous
  procedure push is new vunit_lib.reflection_queue_pkg.push generic map (t => scalars_t);
  procedure push is new vunit_lib.reflection_queue_pkg.push generic map (t => arrays_t);
  procedure push is new vunit_lib.reflection_queue_pkg.push generic map (t => outer_t);
  procedure push is new vunit_lib.reflection_queue_pkg.push generic map (t => unsupported_t);
  procedure push is new vunit_lib.reflection_queue_pkg.push generic map (t => state_t);
begin

  main : process
    constant queue : queue_t := new_queue;
    constant scalars : scalars_t := (
      int => -7, float => 2.5, flag => true, b => '1', sl => 'Z', char => 'x', delay => 3 ns, state => busy);
    constant arrays : arrays_t := (
      name => "abc", data => x"a5", ascending => "0011", count => x"9", offset => "1110");
    constant outer : outer_t := (first => 1, inner => (level => 4, enabled => true), last => 9);
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      flush(queue);

      if run("Test scalar elements") then
        push(queue, scalars);
        check_equal(pop_integer(queue), -7);
        check_equal(pop_real(queue), 2.5);
        check_equal(pop_boolean(queue), true);
        check(pop_bit(queue) = '1');
        check_equal(pop_std_ulogic(queue), 'Z');
        check_equal(pop_character(queue), 'x');
        check_equal(pop_time(queue), 3 ns);
        check_equal(pop_string(queue), "busy");
        check(is_empty(queue));

      elsif run("Test array elements") then
        push(queue, arrays);
        check_equal(pop_string(queue), "abc");
        check_equal(pop_std_ulogic_vector(queue), std_ulogic_vector'(x"a5"));
        check_equal(pop_std_ulogic_vector(queue), std_ulogic_vector'("0011"));
        check_equal(pop_numeric_std_unsigned(queue), unsigned'(x"9"));
        check_equal(pop_numeric_std_signed(queue), signed'("1110"));
        check(is_empty(queue));

      elsif run("Test a nested record is pushed in place") then
        push(queue, outer);
        check_equal(pop_integer(queue), 1);
        check_equal(pop_integer(queue), 4);
        check_equal(pop_boolean(queue), true);
        check_equal(pop_integer(queue), 9);
        check(is_empty(queue));

      elsif run("Test a value that is not a record") then
        push(queue, busy);
        -- An enumeration comes back with 'value
        check(state_t'value(pop_string(queue)) = busy);
        check(is_empty(queue));

      elsif run("Test the order with other items") then
        push_string(queue, "start");
        push(queue, outer);
        push_integer(queue, 42);
        check_equal(pop_string(queue), "start");
        check_equal(pop_integer(queue), 1);
        check_equal(pop_integer(queue), 4);
        check_equal(pop_boolean(queue), true);
        check_equal(pop_integer(queue), 9);
        check_equal(pop_integer(queue), 42);

      elsif run("Test an unsupported element fails with its name") then
        mock(reflection_queue_logger, failure);
        push(queue, unsupported_t'(values => (1, 2)));
        -- VHDL-2019 call paths add the location of the failure to the log item
        check_only_log(
          reflection_queue_logger, "values: array type INTEGER_VECTOR is not supported.", failure,
          line_num => 105, file_name => "reflection_queue_pkg.vhd"
        );
        unmock(reflection_queue_logger);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
