-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.file_line;

entity tb_reflection_check_pkg is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_reflection_check_pkg is
  type state_t is (idle, busy);
  type states_t is array (natural range <>) of state_t;

  type scalars_t is record
    int : integer;
    float : real;
    flag : boolean;
    sl : std_logic;
    delay : time;
    state : state_t;
  end record;

  type header_t is record
    addr : natural;
    kind : state_t;
  end record;

  type packet_t is record
    hdr : header_t;
    data : std_ulogic_vector(7 downto 0);
    ascending : std_logic_vector(0 to 3);
    count : unsigned(3 downto 0);
    name : string(1 to 3);
  end record;

  type vectors_t is record
    values : integer_vector(0 to 3);
  end record;

  type config_t is record
    enabled : boolean;
  end record;

  package scalars_checks is new vunit_lib.reflection_check_generic_pkg generic map (t => scalars_t);
  package packet_checks is new vunit_lib.reflection_check_generic_pkg generic map (t => packet_t);
  package vectors_checks is new vunit_lib.reflection_check_generic_pkg generic map (t => vectors_t);
  -- Types that check_pkg covers, such as integer, would make check_equal ambiguous
  package state_checks is new vunit_lib.reflection_check_generic_pkg generic map (t => state_t);
  package states_checks is new vunit_lib.reflection_check_generic_pkg generic map (t => states_t);
  use scalars_checks.all;
  use packet_checks.all;
  use vectors_checks.all;
  use state_checks.all;
  use states_checks.all;
begin

  main : process
    constant my_checker : checker_t := new_checker("my_checker");
    constant packet : packet_t := (
      hdr => (addr => 5, kind => idle), data => x"a5", ascending => "0011", count => x"9", name => "abc");
    constant scalars : scalars_t := (
      int => -7, float => 2.5, flag => true, sl => 'Z', delay => 3 ns, state => busy);
    variable other_packet : packet_t;
    variable other_scalars : scalars_t;
    variable state : state_t := idle;
    variable states : states_t(1 to 3) := (idle, busy, idle);

    procedure check_equal is new vunit_lib.reflection_check_pkg.check_equal generic map (t => config_t);
    procedure check_equal is new vunit_lib.reflection_check_pkg.check_equal_with_checker generic map (t => config_t);

    -- A row of the failure message for one difference
    function row(text : string) return string is
    begin
      return LF & "  " & text;
    end;

    -- With VHDL-2019 call paths, the log item holds the location of the check_equal call
    procedure check_logged(
      msg : string; line_num : positive; level : log_level_t := error; logger : logger_t := check_logger) is
    begin
      check_only_log(logger, msg, level, line_num => line_num, file_name => std.env.file_name);
    end;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      other_packet := packet;
      other_scalars := scalars;
      mock(check_logger);

      if run("Test equal values pass") then
        check_equal(packet, packet);
        check_logged("Equality check passed", file_line - 1, pass);
        check_equal(scalars, scalars, "My scalars");
        check_logged("My scalars", file_line - 1, pass);

      elsif run("Test a differing element is named") then
        other_packet.hdr.addr := 6;
        check_equal(packet, other_packet);
        check_logged("Equality check failed" & row("hdr.addr: got 5, expected 6"), file_line - 1);

      elsif run("Test all differing elements are named") then
        other_packet.hdr.kind := busy;
        other_packet.data(1) := '1';
        other_packet.ascending(1) := '1';
        other_packet.count := x"a";
        other_packet.name(3) := 'd';
        check_equal(packet, other_packet);
        check_logged(
          "Equality check failed" & row("hdr.kind: got idle, expected busy") & row("data(1): got '0', expected '1'") &
          row("ascending(1): got '0', expected '1'") & row("count(1): got '0', expected '1'") &
          row("count(0): got '1', expected '0'") & row("name(3): got 'c', expected 'd'"),
          file_line - 5
        );

      elsif run("Test scalar element types") then
        -- float is left equal, since the format of real'image differs between simulators
        other_scalars := (int => 7, float => 2.5, flag => false, sl => 'H', delay => 2 us, state => idle);
        check_equal(scalars, other_scalars);
        check_logged(
          "Equality check failed" & row("int: got -7, expected 7") & row("flag: got true, expected false") &
          row("sl: got 'z', expected 'h'") & row("delay: got " & time'image(3 ns) & ", expected " & time'image(2 us)) &
          row("state: got busy, expected idle"),
          file_line - 5
        );

      elsif run("Test other arrays") then
        check_equal(vectors_t'(values => (1, 2, 3, 4)), vectors_t'(values => (1, 2, 0, 4)));
        check_logged("Equality check failed" & row("values(2): got 3, expected 0"), file_line - 1);

      elsif run("Test a scalar type") then
        check_equal(state, busy);
        check_logged("Equality check failed" & row("got idle, expected busy"), file_line - 1);

      elsif run("Test arrays of different lengths") then
        check_equal(states, states_t'(idle, busy));
        check_logged("Equality check failed" & row("'length: got 3, expected 2"), file_line - 1);
        check_equal(states, states_t'(idle, busy, busy));
        check_logged("Equality check failed" & row("(3): got idle, expected busy"), file_line - 1);

      elsif run("Test a custom checker, message and level") then
        other_packet.hdr.addr := 6;
        mock(get_logger(my_checker));
        check_equal(my_checker, packet, other_packet, "Packet", warning);
        check_logged("Packet" & row("hdr.addr: got 5, expected 6"), file_line - 1, warning, get_logger(my_checker));
        unmock(get_logger(my_checker));

      elsif run("Test the procedures instantiated in a process") then
        check_equal(config_t'(enabled => true), config_t'(enabled => false));
        check_logged("Equality check failed" & row("enabled: got true, expected false"), file_line - 1);
        mock(get_logger(my_checker));
        check_equal(my_checker, config_t'(enabled => true), config_t'(enabled => true));
        check_logged("Equality check passed", file_line - 1, pass, get_logger(my_checker));
        unmock(get_logger(my_checker));
      end if;

      unmock(check_logger);
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
