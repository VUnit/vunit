-- Test suite for com codec package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- vunit: run_all_in_same_sim

library vunit_lib;
context vunit_lib.vunit_context;
use vunit_lib.queue_pkg.all;
use vunit_lib.integer_vector_ptr_pkg.all;
use vunit_lib.codec_2008p_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.float_pkg.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

use std.textio.all;

entity tb_codec_2008p is
  generic (
    runner_cfg : string);
end entity tb_codec_2008p;

architecture test_fixture of tb_codec_2008p is
begin
  test_runner : process
    constant f64    : float64 := (others => '0');
    constant positive_zero : float64 := to_float(
      std_logic_vector'(B"0_00000000000_0000000000000000000000000000000000000000000000000000"), f64);
    constant negative_zero : float64 := to_float(
      std_logic_vector'(B"1_00000000000_0000000000000000000000000000000000000000000000000000"), f64);
    constant positive_infinity : float64 := to_float(
      std_logic_vector'(B"0_11111111111_0000000000000000000000000000000000000000000000000000"), f64);
    constant negative_infinity : float64 := to_float(
      std_logic_vector'(B"1_11111111111_0000000000000000000000000000000000000000000000000000"), f64);
    constant nan : float64 := to_float(
      std_logic_vector'(B"1_11111111111_0000000000000000000000000000000000000000000000000001"), f64);
    variable null_boolean_vector : boolean_vector(1 to 0);
    variable null_integer_vector : integer_vector(1 to 0);
    variable null_real_vector    : real_vector(1 to 0);
    variable null_time_vector    : time_vector(1 to 0);

    variable boolean_vector_5_downto_3 : boolean_vector(5 downto 3);
    variable integer_vector_5_downto_3 : integer_vector(5 downto 3);
    variable real_vector_5_downto_3 : real_vector(5 downto 3);
    variable time_vector_5_downto_3 : time_vector(5 downto 3);

    -- Helper functions to make tests pass GHDL v0.37 and Riviera-PRO 2016.10
    function get_decoded_range_left ( constant vec: boolean_vector ) return integer is
    begin return vec'left; end;

    function get_decoded_range_right ( constant vec: boolean_vector ) return integer is
    begin return vec'right; end;

    function get_decoded_range_left ( constant vec: integer_vector ) return integer is
    begin return vec'left; end;

    function get_decoded_range_right ( constant vec: integer_vector ) return integer is
    begin return vec'right; end;

    function get_decoded_range_left ( constant vec: real_vector ) return integer is
    begin return vec'left; end;

    function get_decoded_range_right ( constant vec: real_vector ) return integer is
    begin return vec'right; end;

    function get_decoded_range_left ( constant vec: time_vector ) return integer is
    begin return vec'left; end;

    function get_decoded_range_right ( constant vec: time_vector ) return integer is
    begin return vec'right; end;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that boolean_vector can be encoded and decoded") then
        boolean_vector_5_downto_3 := (true, false, true);
        check_relation(decode_boolean_vector(encode_boolean_vector((true, false, true))) = boolean_vector'(true, false, true));
        check_relation(decode_boolean_vector(encode_boolean_vector((0         => true))) = boolean_vector'(0 => true));
        check_relation(decode_boolean_vector(encode_boolean_vector(null_boolean_vector)) = null_boolean_vector);
        check_relation(decode_boolean_vector(encode_boolean_vector(boolean_vector_5_downto_3)) = boolean_vector'(true, false, true));
        check_relation(get_decoded_range_left(decode_boolean_vector(encode_boolean_vector(boolean_vector_5_downto_3))) = 5);
        check_relation(get_decoded_range_right(decode_boolean_vector(encode_boolean_vector(boolean_vector_5_downto_3))) = 3);
      elsif run("Test that integer_vector can be encoded and decoded") then
        integer_vector_5_downto_3 := (-42, 0, 17);
        check_relation(decode_integer_vector(encode_integer_vector((-2147483648, -2147483648, -2147483648))) = integer_vector'(-2147483648, -2147483648, -2147483648));
        check_relation(decode_integer_vector(encode_integer_vector((-42, 0, 17))) = integer_vector'(-42, 0, 17));
        check_relation(decode_integer_vector(encode_integer_vector((0   => -42))) = integer_vector'(0 => -42));
        check_relation(decode_integer_vector(encode_integer_vector(null_integer_vector)) = null_integer_vector);
        check_relation(decode_integer_vector(encode_integer_vector(integer_vector_5_downto_3)) = integer_vector'(-42, 0, 17));
        check_relation(get_decoded_range_left(decode_integer_vector(encode_integer_vector(integer_vector_5_downto_3))) = 5);
        check_relation(get_decoded_range_right(decode_integer_vector(encode_integer_vector(integer_vector_5_downto_3))) = 3);
      elsif run("Test that real_vector can be encoded and decoded") then
        real_vector_5_downto_3 := (-42.42, 0.001, 17.17);
        check_relation(decode_real_vector(encode_real_vector((-42.42, 0.001, 17.17))) = real_vector'(-42.42, 0.001, 17.17));
        check_relation(decode_real_vector(encode_real_vector((0          => -42.42))) = real_vector'(0 => -42.42));
        check_relation(decode_real_vector(encode_real_vector(null_real_vector)) = null_real_vector);
        check_relation(decode_real_vector(encode_real_vector(real_vector_5_downto_3)) = real_vector'(-42.42, 0.001, 17.17));
        check_relation(get_decoded_range_left(decode_real_vector(encode_real_vector(real_vector_5_downto_3))) = 5);
        check_relation(get_decoded_range_right(decode_real_vector(encode_real_vector(real_vector_5_downto_3))) = 3);
      elsif run("Test that time_vector can be encoded and decoded") then
        time_vector_5_downto_3 := (-42 ms, 0 sec, 17 min);
        check_relation(decode_time_vector(encode_time_vector((-42 ms, 0 sec, 17 min))) = time_vector'(-42 ms, 0 sec, 17 min));
        check_relation(decode_time_vector(encode_time_vector((0           => -42 ms))) = time_vector'(0 => -42 ms));
        check_relation(decode_time_vector(encode_time_vector(null_time_vector)) = null_time_vector);
        check_relation(decode_time_vector(encode_time_vector(time_vector_5_downto_3)) = time_vector'(-42 ms, 0 sec, 17 min));
        check_relation(get_decoded_range_left(decode_time_vector(encode_time_vector(time_vector_5_downto_3))) = 5);
        check_relation(get_decoded_range_right(decode_time_vector(encode_time_vector(time_vector_5_downto_3))) = 3);
      elsif run("Test that ufixed can be encoded and decoded") then
        check_relation(decode_ufixed(encode_ufixed(to_ufixed( 6.5,  3, -3))) = to_ufixed(6.5, 3, -3));
        check_relation(decode_ufixed(encode_ufixed(to_ufixed( 8.0,  3,  1))) = to_ufixed(8.0, 3, 1));
        check_relation(decode_ufixed(encode_ufixed(to_ufixed(0.25, -2, -4))) = to_ufixed(0.25, -2, -4));
      elsif run("Test that sfixed can be encoded and decoded") then
        check_relation(decode_sfixed(encode_sfixed(to_sfixed( 6.5,   3, -3))) = to_sfixed(6.5, 3, -3));
        check_relation(decode_sfixed(encode_sfixed(to_sfixed( 8.0,   4,  1))) = to_sfixed(8.0, 4, 1));
        check_relation(decode_sfixed(encode_sfixed(to_sfixed(0.25,  -1, -4))) = to_sfixed(0.25, -1, -4));
        check_relation(decode_sfixed(encode_sfixed(to_sfixed(-6.5,   3, -3))) = to_sfixed(-6.5, 3, -3));
        check_relation(decode_sfixed(encode_sfixed(to_sfixed(-8.0,   4,  1))) = to_sfixed(-8.0, 4, 1));
        check_relation(decode_sfixed(encode_sfixed(to_sfixed(-0.25, -1, -4))) = to_sfixed(-0.25, -1, -4));
      elsif run("Test that float can be encoded and decoded") then
        check_relation(decode_float(encode_float(to_float(real'low,  11, 52))) = to_float(real'low, 11, 52));
        check_relation(decode_float(encode_float(to_float(real'high, 11, 52))) = to_float(real'high, 11, 52));

        check_relation(to_string(decode_float(encode_float(positive_zero))) = to_string(positive_zero));
        check_relation(to_string(decode_float(encode_float(negative_zero))) = to_string(negative_zero));
        check_relation(to_string(decode_float(encode_float(positive_infinity))) = to_string(positive_infinity));
        check_relation(to_string(decode_float(encode_float(negative_infinity))) = to_string(negative_infinity));
        check_relation(to_string(decode_float(encode_float(nan))) = to_string(nan));
        check_relation(to_string(decode_float(encode_float(nan))) /= to_string(positive_zero));
        check_relation(to_string(decode_float(encode_float(negative_zero))) /= to_string(positive_zero));
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 100 ms);
end test_fixture;
