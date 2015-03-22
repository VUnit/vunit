-- Test suite for com codec package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library com_lib;
use com_lib.com_codec_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.float_pkg.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

entity tb_com_codec is
  generic (
    runner_cfg : runner_cfg_t := runner_cfg_default);
end entity tb_com_codec;

architecture test_fixture of tb_com_codec is

begin
  test_runner : process
    alias to_string is encode[string return string];
    alias to_string is encode[boolean_vector return string];
    alias to_string is encode[integer_vector return string];
    alias to_string is encode[real_vector return string];
    alias to_string is encode[time_vector return string];
    alias to_string is encode[complex return string];
    alias to_string is encode[complex_polar return string];

    -- Standard "=" for these types return false when both operands are empty
    -- vectors. However, I want decode(encode("")) = "" to retun true when verifying that
    -- empty vectors can be encoded/decoded correctly
    function "=" (
      constant l, r : ieee.numeric_bit.unsigned)
      return boolean is
      variable ret_val : boolean;
    begin
      if l'length = 0 and r'length = 0 then
        return true;
      end if;

      return ieee.numeric_bit."="(l, r);
    end function "=";
    
    function "=" (
      constant l, r : ieee.numeric_bit.signed)
      return boolean is
      variable ret_val : boolean;
    begin
      if l'length = 0 and r'length = 0 then
        return true;
      end if;

      return ieee.numeric_bit."="(l, r);
    end function "=";

    function "=" (
      constant l, r : ieee.numeric_std.unsigned)
      return boolean is
      variable ret_val : boolean;
    begin
      if l'length = 0 and r'length = 0 then
        return true;
      end if;

      return ieee.numeric_std."="(l, r);
    end function "=";
    
    function "=" (
      constant l, r : ieee.numeric_std.signed)
      return boolean is
      variable ret_val : boolean;
    begin
      if l'length = 0 and r'length = 0 then
        return true;
      end if;

      return ieee.numeric_std."="(l, r);
    end function "=";

    variable f64 : float64;
    variable r1, r2 : real;
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
    variable null_real_vector : real_vector(1 to 0);
    variable null_time_vector : time_vector(1 to 0);
    variable test : ufixed(-2 downto -4);
  begin
    checker_init(display_format => verbose,
                 file_name => join(output_path(runner_cfg), "error.csv"),
                 file_format => verbose_csv);    
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that integer can be encoded and decoded") then
        check_relation(decode_integer(encode_integer(integer'low)) = integer'low);
        check_relation(decode_integer(encode_integer(integer'high)) = integer'high);
      elsif run("Test that real can be encoded and decoded") then
        check_relation(decode_real(encode_real(real'low)) = real'low);
        check_relation(decode_real(encode_real(real'high)) = real'high);

        check_relation(decode_real(encode_real(to_real(positive_zero))) = to_real(positive_zero));
        check_relation(decode_real(encode_real(to_real(negative_zero))) = to_real(negative_zero));
        check_relation(decode_real(encode_real(to_real(positive_infinity))) = to_real(positive_infinity));
        check_relation(decode_real(encode_real(to_real(negative_infinity))) = to_real(negative_infinity));
        check_relation(decode_real(encode_real(to_real(nan))) = to_real(nan));
        -- ModelSim doesn't support float meta values for the real type. Positive/negative zero as
        -- well as NaN get the same internal representation (positive
        -- zero). Positive/negative infinity seem to maintain correct internal
        -- representation but doing things like 1.0/0.0 isn't supported. The tests
        -- for encoding/decoding of these values still pass so I've kept them for tests
        -- with other simulators
--        check_relation(decode_real(encode_real(to_real(nan))) /= to_real(positive_zero));
--        check_relation(decode_real(encode_real(to_real(negative_zero))) /= to_real(positive_zero));

        r1 := to_real(to_float(
          std_logic_vector'(B"0_01111111111_0000000000000000000000000000000000000000000000000001"), f64));
        r2 := to_real(to_float(
          std_logic_vector'(B"0_01111111111_0000000000000000000000000000000000000000000000000010"), f64));
        check_relation(decode_real(encode_real(r1)) = r1);
        check_relation(decode_real(encode_real(r2)) = r2);
        check_relation(r1 /= r2, "Should be different values in a double precision implementation");
      elsif run("Test that time can be encoded and decoded") then
        check_relation(decode_time(encode_time(time'low)) = time'low);
        check_relation(decode_time(encode_time(time'high)) = time'high);
      elsif run("Test that boolean can be encoded and decoded") then
        check_relation(decode_boolean(encode_boolean(true)) = true);
        check_relation(decode_boolean(encode_boolean(false)) = false);
      elsif run("Test that bit can be encoded and decoded") then
        check_relation(decode_bit(encode_bit('0')) = bit'('0'));
        check_relation(decode_bit(encode_bit('1')) = bit'('1'));
      elsif run("Test that std_ulogic can be encoded and decoded") then
        for i in std_ulogic'pos(std_ulogic'left) to std_ulogic'pos(std_ulogic'right) loop
          check_relation(decode_std_ulogic(encode_std_ulogic(std_ulogic'val(i))) = std_ulogic'val(i));
        end loop;
      elsif run("Test that severity_level can be encoded and decoded") then
        for i in severity_level'pos(severity_level'left) to severity_level'pos(severity_level'right) loop
          check_relation(decode_severity_level(encode_severity_level(severity_level'val(i))) = severity_level'val(i));
        end loop;
      elsif run("Test that file_open_status can be encoded and decoded") then
        for i in file_open_status'pos(file_open_status'left) to file_open_status'pos(file_open_status'right) loop
          check_relation(decode_file_open_status(encode_file_open_status(file_open_status'val(i))) = file_open_status'val(i));
        end loop;
      elsif run("Test that file_open_kind can be encoded and decoded") then
        for i in file_open_kind'pos(file_open_kind'left) to file_open_kind'pos(file_open_kind'right) loop
          check_relation(decode_file_open_kind(encode_file_open_kind(file_open_kind'val(i))) = file_open_kind'val(i));
        end loop;
      elsif run("Test that character can be encoded and decoded") then
        for i in character'pos(character'left) to character'pos(character'right) loop
          check_relation(decode_character(encode_character(character'val(i))) = character'val(i));
        end loop;
      elsif run("Test that string can be encoded and decoded") then
        check_relation(decode_string(encode_string("The brown fox jumped the lazy cat")) = string'("The brown fox jumped the lazy cat"));
      elsif run("Test that boolean_vector can be encoded and decoded") then
        check_relation(decode_boolean_vector(encode_boolean_vector((true,false,true))) = boolean_vector'((true,false,true)));
        check_relation(decode_boolean_vector(encode_boolean_vector((0 => true))) = boolean_vector'((0 => true)));
        check_relation(decode_boolean_vector(encode_boolean_vector(null_boolean_vector)) = null_boolean_vector);
      elsif run("Test that bit_vector can be encoded and decoded") then
        check_relation(decode_bit_vector(encode_bit_vector("101")) = bit_vector'("101"));
        check_relation(decode_bit_vector(encode_bit_vector("1")) = bit_vector'("1"));
        check_relation(decode_bit_vector(encode_bit_vector("")) = bit_vector'(""));
      elsif run("Test that integer_vector can be encoded and decoded") then
        check_relation(decode_integer_vector(encode_integer_vector((-42,0,17))) = integer_vector'((-42,0,17)));
        check_relation(decode_integer_vector(encode_integer_vector((0 => -42))) = integer_vector'((0 => -42)));
        check_relation(decode_integer_vector(encode_integer_vector(null_integer_vector)) = null_integer_vector);
      elsif run("Test that real_vector can be encoded and decoded") then
        check_relation(decode_real_vector(encode_real_vector((-42.42,0.001,17.17))) = real_vector'((-42.42,0.001,17.17)));
        check_relation(decode_real_vector(encode_real_vector((0 => -42.42))) = real_vector'((0 => -42.42)));
        check_relation(decode_real_vector(encode_real_vector(null_real_vector)) = null_real_vector);
      elsif run("Test that time_vector can be encoded and decoded") then
        check_relation(decode_time_vector(encode_time_vector((-42 ms,0 sec,17 min))) = time_vector'((-42 ms,0 sec,17 min)));
        check_relation(decode_time_vector(encode_time_vector((0 => -42 ms))) = time_vector'((0 => -42 ms)));
        check_relation(decode_time_vector(encode_time_vector(null_time_vector)) = null_time_vector);
      elsif run("Test that std_ulogic_vector can be encoded and decoded") then
        check_relation(decode_std_ulogic_vector(encode_std_ulogic_vector("XU1")) = std_ulogic_vector'("XU1"));
        check_relation(decode_std_ulogic_vector(encode_std_ulogic_vector("X")) = std_ulogic_vector'("X"));
        check_relation(decode_std_ulogic_vector(encode_std_ulogic_vector("")) = std_ulogic_vector'(""));
      elsif run("Test that complex can be encoded and decoded") then
        check_relation(decode_complex(encode_complex((-17.17, 42.42))) = complex'((-17.17, 42.42)));
      elsif run("Test that complex_polar can be encoded and decoded") then
        check_relation(decode_complex_polar(encode_complex_polar((17.17, 0.42))) = complex_polar'((17.17, 0.42)));
      elsif run("Test that unsigned from numeric_bit can be encoded and decoded") then
        check_relation(decode_numeric_bit_unsigned(encode_numeric_bit_unsigned("101")) = ieee.numeric_bit.unsigned'("101"));
        check_relation(decode_numeric_bit_unsigned(encode_numeric_bit_unsigned("1")) = ieee.numeric_bit.unsigned'("1"));
        check_relation(decode_numeric_bit_unsigned(encode_numeric_bit_unsigned("")) = ieee.numeric_bit.unsigned'(""));
      elsif run("Test that signed from numeric_bit can be encoded and decoded") then
        check_relation(decode_numeric_bit_signed(encode_numeric_std_signed("101")) = ieee.numeric_bit.signed'("101"));
        check_relation(decode_numeric_bit_signed(encode_numeric_std_signed("1")) = ieee.numeric_bit.signed'("1"));
        check_relation(decode_numeric_bit_signed(encode_numeric_bit_signed("")) = ieee.numeric_bit.signed'(""));
      elsif run("Test that unsigned from numeric_std can be encoded and decoded") then
        check_relation(decode_numeric_std_unsigned(encode_numeric_std_unsigned("101")) = ieee.numeric_std.unsigned'("101"));
        check_relation(decode_numeric_std_unsigned(encode_numeric_std_unsigned("1")) = ieee.numeric_std.unsigned'("1"));
        check_relation(decode_numeric_std_unsigned(encode_numeric_std_unsigned("")) = ieee.numeric_std.unsigned'(""));
      elsif run("Test that signed from numeric_std can be encoded and decoded") then
        check_relation(decode_numeric_std_signed(encode_numeric_std_signed("101")) = ieee.numeric_std.signed'("101"));
        check_relation(decode_numeric_std_signed(encode_numeric_std_signed("1")) = ieee.numeric_std.signed'("1"));
        check_relation(decode_numeric_std_signed(encode_numeric_std_signed("")) = ieee.numeric_std.signed'(""));
      elsif run("Test that ufixed can be encoded and decoded") then
        check_relation(decode_ufixed(encode_ufixed(to_ufixed(6.5, 3, -3))) = to_ufixed(6.5, 3, -3));
        check_relation(decode_ufixed(encode_ufixed(to_ufixed(8.0, 3, 1))) = to_ufixed(8.0, 3, 1));
        check_relation(decode_ufixed(encode_ufixed(to_ufixed(0.25, -2, -4))) = to_ufixed(0.25, -2, -4));
      elsif run("Test that sfixed can be encoded and decoded") then
        check_relation(decode_sfixed(encode_sfixed(to_sfixed(6.5, 3, -3))) = to_sfixed(6.5, 3, -3));
        check_relation(decode_sfixed(encode_sfixed(to_sfixed(8.0, 4, 1))) = to_sfixed(8.0, 4, 1));
        check_relation(decode_sfixed(encode_sfixed(to_sfixed(0.25, -1, -4))) = to_sfixed(0.25, -1, -4));
        check_relation(decode_sfixed(encode_sfixed(to_sfixed(-6.5, 3, -3))) = to_sfixed(-6.5, 3, -3));
        check_relation(decode_sfixed(encode_sfixed(to_sfixed(-8.0, 4, 1))) = to_sfixed(-8.0, 4, 1));
        check_relation(decode_sfixed(encode_sfixed(to_sfixed(-0.25, -1, -4))) = to_sfixed(-0.25, -1, -4));
      elsif run("Test that float can be encoded and decoded") then
        check_relation(decode_float(encode_float(to_float(real'low, 11, 52))) = to_float(real'low, 11, 52));
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

-- vunit_pragma run_all_in_same_sim
