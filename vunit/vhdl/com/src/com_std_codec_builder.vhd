-- This package contains support functions for standard codec building
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use std.textio.all;

package com_std_codec_builder_pkg is
  type std_ulogic_array is array (integer range <>) of std_ulogic;

  function to_byte_array (
    constant value : bit_vector)
    return string;
  function from_byte_array (
    constant byte_array : string)
    return bit_vector;
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   integer);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   real);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   time);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   boolean);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   bit);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   std_ulogic);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   severity_level);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   file_open_status);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   file_open_kind);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   character);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   std_ulogic_array);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   string);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   boolean_vector);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   bit_vector);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   integer_vector);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   real_vector);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   time_vector);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   std_ulogic_vector);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   complex);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   complex_polar);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   ieee.numeric_bit.unsigned);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   ieee.numeric_bit.signed);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   ieee.numeric_std.unsigned);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   ieee.numeric_std.signed);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   ufixed);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   sfixed);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   float);
  function encode_array_header (
    constant range_left1   : string;
    constant range_right1  : string;
    constant is_ascending1 : string;
    constant range_left2   : string := "";
    constant range_right2  : string := "";
    constant is_ascending2 : string := "T")
    return string;
end package com_std_codec_builder_pkg;

package body com_std_codec_builder_pkg is
  function to_byte_array (
    constant value : bit_vector)
    return string is
    variable ret_val   : string(1 to (value'length + 7) / 8);
    variable value_int : ieee.numeric_bit.unsigned(value'length - 1 downto 0) := ieee.numeric_bit.unsigned(value);
  begin
    for i in ret_val'reverse_range loop
      ret_val(i) := character'val(to_integer(value_int and to_unsigned(255, value_int'length)));
      value_int  := value_int srl 8;
    end loop;

    return ret_val;
  end function to_byte_array;

  function from_byte_array (
    constant byte_array : string)
    return bit_vector is
    variable byte_array_int : string(1 to byte_array'length) := byte_array;
    variable ret_val        : bit_vector(byte_array'length*8-1 downto 0);
  begin
    for i in byte_array_int'range loop
      ret_val((byte_array_int'length-i)*8 + 7 downto (byte_array_int'length-i)*8) := bit_vector(ieee.numeric_bit.to_unsigned(character'pos(byte_array_int(i)), 8));
    end loop;

    return ret_val;
  end function from_byte_array;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   integer) is
  begin
    result := to_integer(ieee.numeric_bit.signed(from_byte_array(code(index to index + 3))));
    index  := index + 4;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   real) is
    variable f64 : float64;
  begin
    result := to_real(to_float(to_slv(from_byte_array(code(index to index + 7))), f64));
    index  := index + 8;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   time) is
    constant resolution  : time           := std.env.resolution_limit;
    variable code_int    : string(1 to 8) := code(index to index + 7);
    variable r : time;
    variable b : integer;
  begin
    -- @TODO assumes time is 8 bytes
    r := resolution * 0;

    for i in code_int'range loop
      b := character'pos(code_int(i));
      r := r * 256;
      if i = 1 and b >= 128 then
        b := b - 256;
      end if;
      r := r + b * resolution;
    end loop;

    index := index + 8;
    result := r;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   boolean) is
  begin
    result := code(index) = 'T';
    index  := index + 1;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   bit) is
  begin
    if code(index) = '1' then
      result := '1';
    else
      result := '0';
    end if;
    index := index + 1;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   std_ulogic) is
  begin
    result := std_ulogic'value("'" & code(index) & "'");
    index  := index + 1;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   severity_level) is
  begin
    result := severity_level'val(character'pos(code(index)));
    index  := index + 1;
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   file_open_status) is
  begin
    result := file_open_status'val(character'pos(code(index)));
    index  := index + 1;
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   file_open_kind) is
  begin
    result := file_open_kind'val(character'pos(code(index)));
    index  := index + 1;
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   character) is
  begin
    result := code(index);
    index  := index + 1;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   std_ulogic_array) is
    variable i            : integer := result'left;
    variable upper_nibble : natural;
  begin
    index := index + 9;
    if result'ascending then
      while i <= result'right loop
        if i /= result'right then
          upper_nibble  := character'pos(code(index))/16;
          result(i + 1) := std_ulogic'val(upper_nibble);
        else
          upper_nibble := 0;
        end if;
        result(i) := std_ulogic'val(character'pos(code(index)) - upper_nibble*16);
        i         := i + 2;
        index     := index + 1;
      end loop;
    else
      while i >= result'right loop
        if i /= result'right then
          upper_nibble  := character'pos(code(index))/16;
          result(i - 1) := std_ulogic'val(upper_nibble);
        else
          upper_nibble := 0;
        end if;
        result(i) := std_ulogic'val(character'pos(code(index)) - upper_nibble*16);
        i         := i - 2;
        index     := index + 1;
      end loop;
    end if;
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   string) is
  begin
    result := code(index + 9 to index + 9 + result'length - 1);
    index  := index + 9 + result'length;
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   boolean_vector) is
    variable result_bv : bit_vector(result'range);
  begin
    decode(code, index, result_bv);
    for i in result'range loop
      result(i) := result_bv(i) = '1';
    end loop;
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   bit_vector) is
    constant n_bytes     : natural := (result'length + 7) / 8;
    variable result_temp : bit_vector(n_bytes * 8 - 1 downto 0);
  begin
    result_temp := from_byte_array(code(index + 9 to index + 9 + n_bytes - 1));
    result      := result_temp(result'length - 1 downto 0);

    index := index + 9 + n_bytes;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   integer_vector) is
  begin
    index := index + 9;
    for i in result'range loop
      decode(code, index, result(i));
    end loop;
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   real_vector) is
  begin
    index := index + 9;
    for i in result'range loop
      decode(code, index, result(i));
    end loop;
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   time_vector) is
  begin
    index := index + 9;
    for i in result'range loop
      decode(code, index, result(i));
    end loop;
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   std_ulogic_vector) is
    variable result_sula : std_ulogic_array(result'range);
  begin
    decode(code, index, result_sula);
    result := std_ulogic_vector(result_sula);
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   complex) is
  begin
    decode(code, index, result.re);
    decode(code, index, result.im);
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   complex_polar) is
  begin
    decode(code, index, result.mag);
    decode(code, index, result.arg);
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   ieee.numeric_bit.unsigned) is
    variable result_bv : bit_vector(result'range);
  begin
    decode(code, index, result_bv);
    result := ieee.numeric_bit.unsigned(result_bv);
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   ieee.numeric_bit.signed) is
    variable result_bv : bit_vector(result'range);
  begin
    decode(code, index, result_bv);
    result := ieee.numeric_bit.signed(result_bv);
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   ieee.numeric_std.unsigned) is
    variable result_slv : std_ulogic_vector(result'range);
  begin
    decode(code, index, result_slv);
    result := ieee.numeric_std.unsigned(result_slv);
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   ieee.numeric_std.signed) is
    variable result_slv : std_ulogic_vector(result'range);
  begin
    decode(code, index, result_slv);
    result := ieee.numeric_std.signed(result_slv);
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   ufixed) is
    variable result_sula : std_ulogic_array(result'range);
  begin
    decode(code, index, result_sula);
    result := ufixed(result_sula);
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   sfixed) is
    variable result_sula : std_ulogic_array(result'range);
  begin
    decode(code, index, result_sula);
    result := sfixed(result_sula);
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   float) is
    variable result_sula : std_ulogic_array(result'range);
  begin
    decode(code, index, result_sula);
    result := float(result_sula);
  end;

  function encode_array_header (
    constant range_left1   : string;
    constant range_right1  : string;
    constant is_ascending1 : string;
    constant range_left2   : string := "";
    constant range_right2  : string := "";
    constant is_ascending2 : string := "T")
    return string is
  begin
    if range_left2 = "" then
      return range_left1 & range_right1 & is_ascending1;
    else
      return range_left1 & range_right1 & is_ascending1 & range_left2 & range_right2 & is_ascending2;
    end if;
  end function encode_array_header;
end package body com_std_codec_builder_pkg;
