-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
use vunit_lib.record_dict_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.reflection.all;

entity tb_record_dict_pkg is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_record_dict_pkg is
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
  end record;

  type outer_t is record
    inner : inner_t;
    MixedCase : integer;
  end record;

  type unsupported_t is record
    values : integer_vector(0 to 1);
  end record;
begin

  main : process
    variable scalars : scalars_t := (
      int => -7, float => 2.5, flag => true, b => '1', sl => 'Z', char => 'x', delay => 3 ns, state => busy);
    variable arrays : arrays_t := (
      name => "abc", data => x"a5", ascending => "0011", count => x"9", offset => "1110");
    variable outer : outer_t := (inner => (level => 4), MixedCase => 1);
    variable unsupported : unsupported_t := (values => (1, 2));
    variable int : integer := 17;
    variable mirror : value_mirror;
    variable dict, inner : dict_t;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test scalar elements") then
        mirror := scalars'reflect;
        dict := to_dict(mirror);
        check_equal(num_keys(dict), 8);
        check_equal(get_integer(dict, "int"), -7);
        check_equal(get_real(dict, "float"), 2.5);
        check_true(get_boolean(dict, "flag"));
        check(get_bit(dict, "b") = '1');
        check_equal(get_std_ulogic(dict, "sl"), 'Z');
        check(get_character(dict, "char") = 'x');
        check_equal(get_time(dict, "delay"), 3 ns);
        check_equal(get_string(dict, "state"), "busy");

      elsif run("Test array elements") then
        mirror := arrays'reflect;
        dict := to_dict(mirror);
        check_equal(get_string(dict, "name"), "abc");
        check_equal(get_std_ulogic_vector(dict, "data"), std_ulogic_vector'(x"a5"));
        check_equal(get_std_ulogic_vector(dict, "ascending"), std_ulogic_vector'("0011"));
        check_equal(get_numeric_std_unsigned(dict, "count"), 9);
        check_equal(get_numeric_std_signed(dict, "offset"), -2);

      elsif run("Test a nested record becomes a nested dict") then
        mirror := outer'reflect;
        dict := to_dict(mirror);
        inner := get_dict_t_ref(dict, "inner");
        check_equal(get_integer(inner, "level"), 4);

      elsif run("Test keys are lower case") then
        mirror := outer'reflect;
        dict := to_dict(mirror);
        check_equal(get_integer(dict, "mixedcase"), 1);

      elsif run("Test an unsupported element fails with its name") then
        mock(record_dict_logger, failure);
        mirror := unsupported'reflect;
        dict := to_dict(mirror);
        -- VHDL-2019 call paths add the location of the failure to the log item
        check_only_log(
          record_dict_logger, "values: array type INTEGER_VECTOR is not supported.", failure,
          line_num => 100, file_name => "record_dict_pkg.vhd"
        );
        unmock(record_dict_logger);

      elsif run("Test a value that is not a record fails") then
        mock(record_dict_logger, failure);
        mirror := int'reflect;
        dict := to_dict(mirror);
        check_only_log(
          record_dict_logger, "to_dict expects a record, got INTEGER.", failure,
          line_num => 120, file_name => "record_dict_pkg.vhd"
        );
        unmock(record_dict_logger);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
