-- Test suite for com codec package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- vunit: run_all_in_same_sim

library vunit_lib;
use vunit_lib.string_ops.all;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.path.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.integer_vector_ptr_pkg.all;
use vunit_lib.codec_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.math_real.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;

use std.textio.all;

entity tb_codec is
  generic (
    runner_cfg : string);
end entity tb_codec;

architecture test_fixture of tb_codec is
begin
  test_runner : process
    -- Standard "=" for these types return false when both operands are empty
    -- vectors. However, I want decode(encode("")) = "" to return true when verifying that
    -- empty vectors can be encoded/decoded correctly
    function "=" (
      constant l, r : ieee.numeric_bit.unsigned)
      return boolean is
    begin
      if l'length = 0 and r'length = 0 then
        return true;
      end if;

      return ieee.numeric_bit."="(l, r);
    end function "=";

    function "=" (
      constant l, r : ieee.numeric_bit.signed)
      return boolean is
    begin
      if l'length = 0 and r'length = 0 then
        return true;
      end if;

      return ieee.numeric_bit."="(l, r);
    end function "=";

    function "=" (
      constant l, r : ieee.numeric_std.unsigned)
      return boolean is
    begin
      if l'length = 0 and r'length = 0 then
        return true;
      end if;

      return ieee.numeric_std."="(l, r);
    end function "=";

    function "=" (
      constant l, r : ieee.numeric_std.signed)
      return boolean is
    begin
      if l'length = 0 and r'length = 0 then
        return true;
      end if;

      return ieee.numeric_std."="(l, r);
    end function "=";

    constant positive_zero : real := 0.0;
    constant negative_zero : real := -1.0/1.0e45;
    constant positive_infinity : real := 1.0e39;
    constant negative_infinity : real := -1.0e39;

    constant special_chars       : string(1 to 3) := "),(";
    variable null_string         : string(10 to 9);
    variable t1  : time;
    variable string_15_downto_4 : string(15 downto 4);
    variable bit_vector_5_downto_3 : bit_vector(5 downto 3);
    variable std_ulogic_vector_5_downto_3 : std_ulogic_vector(5 downto 3);
    variable numeric_bit_unsigned_5_downto_3 : ieee.numeric_bit.unsigned(5 downto 3);
    variable numeric_bit_signed_5_downto_3 : ieee.numeric_bit.signed(5 downto 3);
    variable numeric_std_unsigned_5_downto_3 : ieee.numeric_std.unsigned(5 downto 3);
    variable numeric_std_signed_5_downto_3 : ieee.numeric_std.signed(5 downto 3);

    -- Helper functions to make tests pass GHDL v0.37 and Riviera-PRO 2016.10
    function get_decoded_range_left ( constant vec: string ) return integer is
    begin return vec'left; end;

    function get_decoded_range_right ( constant vec: string ) return integer is
    begin return vec'right; end;

    function get_decoded_range_left ( constant vec: bit_vector ) return integer is
    begin return vec'left; end;

    function get_decoded_range_right ( constant vec: bit_vector ) return integer is
    begin return vec'right; end;

    function get_decoded_range_left ( constant vec: std_ulogic_vector ) return integer is
    begin return vec'left; end;

    function get_decoded_range_right ( constant vec: std_ulogic_vector ) return integer is
    begin return vec'right; end;

    function get_decoded_range_left ( constant vec: ieee.numeric_bit.unsigned ) return integer is
    begin return vec'left; end;

    function get_decoded_range_right ( constant vec: ieee.numeric_bit.unsigned ) return integer is
    begin return vec'right; end;

    function get_decoded_range_left ( constant vec: ieee.numeric_bit.signed ) return integer is
    begin return vec'left; end;

    function get_decoded_range_right ( constant vec: ieee.numeric_bit.signed ) return integer is
    begin return vec'right; end;

    function get_decoded_range_left ( constant vec: ieee.numeric_std.unsigned ) return integer is
    begin return vec'left; end;

    function get_decoded_range_right ( constant vec: ieee.numeric_std.unsigned ) return integer is
    begin return vec'right; end;

    function get_decoded_range_left ( constant vec: ieee.numeric_std.signed ) return integer is
    begin return vec'left; end;

    function get_decoded_range_right ( constant vec: ieee.numeric_std.signed ) return integer is
    begin return vec'right; end;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test that integer can be encoded and decoded") then
        check_relation(decode_integer(encode_integer(integer'low)) = integer'low);
        check_relation(decode_integer(encode_integer(integer'high)) = integer'high);
      elsif run("Test that real can be encoded and decoded") then
        check_relation(decode_real(encode_real(real'low)) = real'low);
        check_relation(decode_real(encode_real(real'high)) = real'high);

        check_relation(decode_real(encode_real(positive_zero)) = positive_zero);
        check_relation(decode_real(encode_real(negative_zero)) = negative_zero);
        check_relation(decode_real(encode_real(positive_infinity)) = positive_infinity);
        check_relation(decode_real(encode_real(negative_infinity)) = negative_infinity);
--        check_relation(decode_real(encode_real(negative_zero)) /= positive_zero);

        -- ModelSim doesn't support float meta values for the real type. Positive/negative zero as
        -- well as NaN get the same internal representation (positive
        -- zero). Positive/negative infinity seem to maintain correct internal
        -- representation but doing things like 1.0/0.0 isn't supported. The tests
        -- for encoding/decoding of these values still pass so I've kept them for tests
        -- with other simulators
--        check_relation(decode_real(encode_real(to_real(nan))) /= to_real(positive_zero));
--        check_relation(decode_real(encode_real(to_real(negative_zero))) /= to_real(positive_zero));

        -- r1 := to_real(to_float(
        --   std_logic_vector'(B"0_01111111111_0000000000000000000000000000000000000000000000000001"), f64));
        -- r2 := to_real(to_float(
        --   std_logic_vector'(B"0_01111111111_0000000000000000000000000000000000000000000000000010"), f64));
        -- check_relation(decode_real(encode_real(r1)) = r1);
        -- check_relation(decode_real(encode_real(r2)) = r2);
        -- check_relation(r1 /= r2, "Should be different values in a double precision implementation");
      elsif run("Test that time can be encoded and decoded") then
        t1 := time'low;
        check_relation(decode_time(encode_time(t1)) = t1);
        t1 := time'high;
        check_relation(decode_time(encode_time(t1)) = t1);
        check_relation(decode_time(encode_time(17 ns)) = 17 ns);
        check_relation(decode_time(encode_time(-17 ns)) = -17 ns);
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
        string_15_downto_4 := "Hello world!";
        check_relation(decode_string(encode_string("The quick brown fox jumps over the lazy dog")) = string'("The quick brown fox jumps over the lazy dog"));
        check_relation(decode_string(encode_string(special_chars)) = string'(special_chars));
        check_relation(get_decoded_range_left(decode_string(encode_string(null_string))) = 10);
        check_relation(get_decoded_range_right(decode_string(encode_string(null_string))) = 9);
        check_relation(decode_string(encode_string(string_15_downto_4)) = string'("Hello world!"));
        check_relation(get_decoded_range_left(decode_string(encode_string(string_15_downto_4))) = 15);
        check_relation(get_decoded_range_right(decode_string(encode_string(string_15_downto_4))) = 4);
      elsif run("Test that bit_vector can be encoded and decoded") then
        bit_vector_5_downto_3 := "101";
        check_relation(decode_bit_vector(encode_bit_vector("101")) = bit_vector'("101"));
        check_relation(decode_bit_vector(encode_bit_vector("1")) = bit_vector'("1"));
        check_relation(decode_bit_vector(encode_bit_vector("")) = bit_vector'(""));
        check_relation(decode_bit_vector(encode_bit_vector(bit_vector_5_downto_3)) = bit_vector'("101"));
        check_relation(get_decoded_range_left(decode_bit_vector(encode_bit_vector(bit_vector_5_downto_3))) = 5);
        check_relation(get_decoded_range_right(decode_bit_vector(encode_bit_vector(bit_vector_5_downto_3))) = 3);
      elsif run("Test that std_ulogic_vector can be encoded and decoded") then
        std_ulogic_vector_5_downto_3 := "XU1";
        check_relation(decode_std_ulogic_vector(encode_std_ulogic_vector("XU1")) = std_ulogic_vector'("XU1"));
        check_relation(decode_std_ulogic_vector(encode_std_ulogic_vector("X")) = std_ulogic_vector'("X"));
        check_relation(decode_std_ulogic_vector(encode_std_ulogic_vector("")) = std_ulogic_vector'(""));
        check_relation(decode_std_ulogic_vector(encode_std_ulogic_vector(std_ulogic_vector_5_downto_3)) = std_ulogic_vector'("XU1"));
        check_relation(get_decoded_range_left(decode_std_ulogic_vector(encode_std_ulogic_vector(std_ulogic_vector_5_downto_3))) = 5);
        check_relation(get_decoded_range_right(decode_std_ulogic_vector(encode_std_ulogic_vector(std_ulogic_vector_5_downto_3))) = 3);
      elsif run("Test that complex can be encoded and decoded") then
        check_relation(decode_complex(encode_complex((-17.17, 42.42))) = complex'(-17.17, 42.42));
      elsif run("Test that complex_polar can be encoded and decoded") then
        check_relation(decode_complex_polar(encode_complex_polar((17.17, 0.42))) = complex_polar'(17.17, 0.42));
      elsif run("Test that unsigned from numeric_bit can be encoded and decoded") then
        numeric_bit_unsigned_5_downto_3 := "101";
        check_relation(decode_numeric_bit_unsigned(encode_numeric_bit_unsigned("101")) = ieee.numeric_bit.unsigned'("101"));
        check_relation(decode_numeric_bit_unsigned(encode_numeric_bit_unsigned("1")) = ieee.numeric_bit.unsigned'("1"));
        check_relation(decode_numeric_bit_unsigned(encode_numeric_bit_unsigned("")) = ieee.numeric_bit.unsigned'(""));
        check_relation(decode_numeric_bit_unsigned(encode_numeric_bit_unsigned(numeric_bit_unsigned_5_downto_3)) = ieee.numeric_bit.unsigned'("101"));
        check_relation(get_decoded_range_left(decode_numeric_bit_unsigned(encode_numeric_bit_unsigned(numeric_bit_unsigned_5_downto_3))) = 5);
        check_relation(get_decoded_range_right(decode_numeric_bit_unsigned(encode_numeric_bit_unsigned(numeric_bit_unsigned_5_downto_3))) = 3);
      elsif run("Test that signed from numeric_bit can be encoded and decoded") then
        numeric_bit_signed_5_downto_3 := "101";
        check_relation(decode_numeric_bit_signed(encode_numeric_bit_signed("101")) = ieee.numeric_bit.signed'("101"));
        check_relation(decode_numeric_bit_signed(encode_numeric_bit_signed("1")) = ieee.numeric_bit.signed'("1"));
        check_relation(decode_numeric_bit_signed(encode_numeric_bit_signed("")) = ieee.numeric_bit.signed'(""));
        check_relation(decode_numeric_bit_signed(encode_numeric_bit_signed(numeric_bit_signed_5_downto_3)) = ieee.numeric_bit.signed'("101"));
        check_relation(get_decoded_range_left(decode_numeric_bit_signed(encode_numeric_bit_signed(numeric_bit_signed_5_downto_3))) = 5);
        check_relation(get_decoded_range_right(decode_numeric_bit_signed(encode_numeric_bit_signed(numeric_bit_signed_5_downto_3))) = 3);
      elsif run("Test that unsigned from numeric_std can be encoded and decoded") then
        numeric_std_unsigned_5_downto_3 := "101";
        check_relation(decode_numeric_std_unsigned(encode_numeric_std_unsigned("101")) = ieee.numeric_std.unsigned'("101"));
        check_relation(decode_numeric_std_unsigned(encode_numeric_std_unsigned("1")) = ieee.numeric_std.unsigned'("1"));
        check_relation(decode_numeric_std_unsigned(encode_numeric_std_unsigned("")) = ieee.numeric_std.unsigned'(""));
        check_relation(decode_numeric_std_unsigned(encode_numeric_std_unsigned(numeric_std_unsigned_5_downto_3)) = ieee.numeric_std.unsigned'("101"));
        check_relation(get_decoded_range_left(decode_numeric_std_unsigned(encode_numeric_std_unsigned(numeric_std_unsigned_5_downto_3))) = 5);
        check_relation(get_decoded_range_right(decode_numeric_std_unsigned(encode_numeric_std_unsigned(numeric_std_unsigned_5_downto_3))) = 3);
      elsif run("Test that signed from numeric_std can be encoded and decoded") then
        numeric_std_signed_5_downto_3 := "101";
        check_relation(decode_numeric_std_signed(encode_numeric_std_signed("101")) = ieee.numeric_std.signed'("101"));
        check_relation(decode_numeric_std_signed(encode_numeric_std_signed("1")) = ieee.numeric_std.signed'("1"));
        check_relation(decode_numeric_std_signed(encode_numeric_std_signed("")) = ieee.numeric_std.signed'(""));
        check_relation(decode_numeric_std_signed(encode_numeric_std_signed(numeric_std_signed_5_downto_3)) = ieee.numeric_std.signed'("101"));
        check_relation(get_decoded_range_left(decode_numeric_std_signed(encode_numeric_std_signed(numeric_std_signed_5_downto_3))) = 5);
        check_relation(get_decoded_range_right(decode_numeric_std_signed(encode_numeric_std_signed(numeric_std_signed_5_downto_3))) = 3);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 100 ms);
end test_fixture;
