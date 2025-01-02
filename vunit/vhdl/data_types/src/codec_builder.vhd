-- This package contains support functions for standard codec building
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;

use std.textio.all;

package codec_builder_pkg is
  type std_ulogic_array is array (integer range <>) of std_ulogic;

  function get_simulator_resolution return time;
  function to_byte_array (
    constant value : bit_vector)
    return string;
  function from_byte_array (
    constant byte_array : string)
    return bit_vector;

  constant integer_code_length : positive := 4;
  constant boolean_code_length : positive := 1;
  constant real_code_length : positive := boolean_code_length + 3 * integer_code_length;
  constant std_ulogic_code_length : positive := 1;
  constant bit_code_length : positive := 1;
  constant time_code_length : positive := 8;
  constant severity_level_code_length : positive := 1;
  constant file_open_status_code_length : positive := 1;
  constant file_open_kind_code_length : positive := 1;
  constant complex_code_length : positive := 2 * real_code_length;
  constant complex_polar_code_length : positive := 2 * real_code_length;

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
    variable result : out   bit_vector);
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
  function encode_array_header (
    constant range_left1   : string;
    constant range_right1  : string;
    constant is_ascending1 : string;
    constant range_left2   : string := "";
    constant range_right2  : string := "";
    constant is_ascending2 : string := "T")
    return string;
end package codec_builder_pkg;

package body codec_builder_pkg is
  function get_simulator_resolution return time is
    type time_array_t is array (integer range <>) of time;
    variable resolution : time;
    constant resolutions : time_array_t(1 to 8) := (
      1.0e-15 sec, 1.0e-12 sec , 1.0e-9 sec, 1.0e-6 sec, 1.0e-3 sec, 1 sec, 1 min, 1 hr);
  begin
    for r in resolutions'range loop
      resolution := resolutions(r);
      exit when resolution > 0 sec;
    end loop;

    return resolution;
  end;

  constant simulator_resolution : time := get_simulator_resolution;

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
    constant byte_array_int : string(1 to byte_array'length) := byte_array;
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
    result := to_integer(ieee.numeric_bit.signed(from_byte_array(code(index to index + integer_code_length - 1))));
    index  := index + integer_code_length;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   real) is
    variable is_signed : boolean;
    variable exp, low, high : integer;
    variable result_i : real;
  begin
    decode(code, index, is_signed);
    decode(code, index, exp);
    decode(code, index, low);
    decode(code, index, high);

    result_i := (real(low) + real(high) * 2.0**31) * 2.0 ** (exp - 53);
    if is_signed then
      result_i := -result_i;
    end if;
    result := result_i;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   time) is
    constant code_int    : string(1 to time_code_length) := code(index to index + time_code_length - 1);
    variable r : time;
    variable b : integer;
  begin
    -- @TODO assumes time is time_code_length bytes
    r := simulator_resolution * 0;

    for i in code_int'range loop
      b := character'pos(code_int(i));
      r := r * 256;
      if i = 1 and b >= 128 then
        b := b - 256;
      end if;
      r := r + b * simulator_resolution;
    end loop;

    index := index + time_code_length;
    result := r;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   boolean) is
  begin
    result := code(index) = 'T';
    index  := index + boolean_code_length;
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
    index := index + bit_code_length;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   std_ulogic) is
  begin
    result := std_ulogic'value("'" & code(index) & "'");
    index  := index + std_ulogic_code_length;
  end procedure decode;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   severity_level) is
  begin
    result := severity_level'val(character'pos(code(index)));
    index  := index + severity_level_code_length;
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   file_open_status) is
  begin
    result := file_open_status'val(character'pos(code(index)));
    index  := index + file_open_status_code_length;
  end;

  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   file_open_kind) is
  begin
    result := file_open_kind'val(character'pos(code(index)));
    index  := index + file_open_kind_code_length;
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
end package body codec_builder_pkg;
