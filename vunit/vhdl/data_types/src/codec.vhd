-- This file provides functionality to encode/decode standard types to/from string.
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
use ieee.math_real.all;

use std.textio.all;

use work.codec_builder_pkg.all;

package codec_pkg is
  -----------------------------------------------------------------------------
  -- Predefined scalar types
  -----------------------------------------------------------------------------
  function encode (
    constant data : integer)
    return string;
  function decode (
    constant code : string)
    return integer;
  function encode (
    constant data : real)
    return string;
  function decode (
    constant code : string)
    return real;
  function encode (
    constant data : time)
    return string;
  function decode (
    constant code : string)
    return time;
  function encode (
    constant data : boolean)
    return string;
  function decode (
    constant code : string)
    return boolean;
  function encode (
    constant data : bit)
    return string;
  function decode (
    constant code : string)
    return bit;
  function encode (
    constant data : std_ulogic)
    return string;
  function decode (
    constant code : string)
    return std_ulogic;
  function encode (
    constant data : severity_level)
    return string;
  function decode (
    constant code : string)
    return severity_level;
  function encode (
    constant data : file_open_status)
    return string;
  function decode (
    constant code : string)
    return file_open_status;
  function encode (
    constant data : file_open_kind)
    return string;
  function decode (
    constant code : string)
    return file_open_kind;
  function encode (
    constant data : character)
    return string;
  function decode (
    constant code : string)
    return character;

  -----------------------------------------------------------------------------
  -- Predefined composite types
  -----------------------------------------------------------------------------
  function encode (
    constant data : string)
    return string;
  function decode (
    constant code : string)
    return string;
  function encode (
    constant data : bit_vector)
    return string;
  function decode (
    constant code : string)
    return bit_vector;
  function encode (
    constant data : std_ulogic_vector)
    return string;
  function decode (
    constant code : string)
    return std_ulogic_vector;
  function encode (
    constant data : complex)
    return string;
  function decode (
    constant code : string)
    return complex;
  function encode (
    constant data : complex_polar)
    return string;
  function decode (
    constant code : string)
    return complex_polar;
  function encode (
    constant data : ieee.numeric_bit.unsigned)
    return string;
  function decode (
    constant code : string)
    return ieee.numeric_bit.unsigned;
  function encode (
    constant data : ieee.numeric_bit.signed)
    return string;
  function decode (
    constant code : string)
    return ieee.numeric_bit.signed;
  function encode (
    constant data : ieee.numeric_std.unsigned)
    return string;
  function decode (
    constant code : string)
    return ieee.numeric_std.unsigned;
  function encode (
    constant data : ieee.numeric_std.signed)
    return string;
  function decode (
    constant code : string)
    return ieee.numeric_std.signed;

  -----------------------------------------------------------------------------
  -- Aliases
  -----------------------------------------------------------------------------
  alias encode_integer is encode[integer return string];
  alias decode_integer is decode[string return integer];
  alias encode_real is encode[real return string];
  alias decode_real is decode[string return real];
  alias encode_time is encode[time return string];
  alias decode_time is decode[string return time];
  alias encode_boolean is encode[boolean return string];
  alias decode_boolean is decode[string return boolean];
  alias encode_bit is encode[bit return string];
  alias decode_bit is decode[string return bit];
  alias encode_std_ulogic is encode[std_ulogic return string];
  alias decode_std_ulogic is decode[string return std_ulogic];
  alias encode_severity_level is encode[severity_level return string];
  alias decode_severity_level is decode[string return severity_level];
  alias encode_file_open_status is encode[file_open_status return string];
  alias decode_file_open_status is decode[string return file_open_status];
  alias encode_file_open_kind is encode[file_open_kind return string];
  alias decode_file_open_kind is decode[string return file_open_kind];
  alias encode_character is encode[character return string];
  alias decode_character is decode[string return character];

  alias encode_string is encode[string return string];
  alias decode_string is decode[string return string];
  alias encode_bit_vector is encode[bit_vector return string];
  alias decode_bit_vector is decode[string return bit_vector];
  alias encode_std_ulogic_vector is encode[std_ulogic_vector return string];
  alias decode_std_ulogic_vector is decode[string return std_ulogic_vector];
  alias encode_complex is encode[complex return string];
  alias decode_complex is decode[string return complex];
  alias encode_complex_polar is encode[complex_polar return string];
  alias decode_complex_polar is decode[string return complex_polar];
  alias encode_numeric_bit_unsigned is encode[ieee.numeric_bit.unsigned return string];
  alias decode_numeric_bit_unsigned is decode[string return ieee.numeric_bit.unsigned];
  alias encode_numeric_bit_signed is encode[ieee.numeric_bit.signed return string];
  alias decode_numeric_bit_signed is decode[string return ieee.numeric_bit.signed];
  alias encode_numeric_std_unsigned is encode[ieee.numeric_std.unsigned return string];
  alias decode_numeric_std_unsigned is decode[string return ieee.numeric_std.unsigned];
  alias encode_numeric_std_signed is encode[ieee.numeric_std.signed return string];
  alias decode_numeric_std_signed is decode[string return ieee.numeric_std.signed];

  -----------------------------------------------------------------------------
  -- Support
  -----------------------------------------------------------------------------
  type range_t is array (integer range <>) of bit;

  function get_range (
    constant code : string)
    return range_t;
  function encode (
    constant data : std_ulogic_array)
    return string;

end package;

package body codec_pkg is
  -----------------------------------------------------------------------------
  -- Predefined scalar types
  -----------------------------------------------------------------------------
  function encode (
    constant data : integer)
    return string is
  begin
    return to_byte_array(bit_vector(ieee.numeric_bit.to_signed(data, 32)));
  end function encode;

  function decode (
    constant code : string)
    return integer is
    variable ret_val : integer;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end function decode;

  function encode (
    constant data : real)
    return string is
    constant is_signed : boolean := data < 0.0;
    variable val : real := data;
    variable exp : integer;
    variable low : integer;
    variable high : integer;

    function log2 (a : real) return integer is
      variable y : real;
      variable n : integer := 0;
    begin
      if (a = 1.0 or a = 0.0) then
        return 0;
      end if;
      y := a;
      if(a > 1.0) then
        while y >= 2.0 loop
          y := y / 2.0;
          n := n + 1;
        end loop;
        return n;
      end if;
      -- o < y < 1
      while y < 1.0 loop
        y := y * 2.0;
        n := n - 1;
      end loop;
      return n;
    end function;
  begin
    if is_signed then
      val := -val;
    end if;

    exp := log2(val);
    -- Assume 53 mantissa bits
    val := val * 2.0 ** (-exp + 53);
    high := integer(floor(val * 2.0 ** (-31)));
    low := integer(val - real(high) * 2.0 ** 31);

    return encode(is_signed) & encode(exp) & encode(low) & encode(high);
  end;

  function decode (
    constant code : string)
    return real is
    variable ret_val : real;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  constant simulator_resolution : time := get_simulator_resolution;

  function encode (
    constant data : time)
    return string is

    function modulo(t : time; m : natural) return integer is
    begin
      return (integer((t - (t/m)*m)/simulator_resolution) mod m);
    end function;

    variable ret_val     : string(1 to time_code_length);
    variable t           : time;
    variable ascii       : natural;
  begin
    -- @TODO assumes time is time_code_length bytes
    t           := data;
    for i in time_code_length downto 1 loop
      ascii := modulo(t, 256);
      ret_val(i) := character'val(ascii);
      t          := (t - (ascii * simulator_resolution))/256;
    end loop;
    return ret_val;
  end;

  function decode (
    constant code : string)
    return time is
    variable ret_val : time;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : boolean)
    return string is
  begin
    if data then
      return "T";
    else
      return "F";
    end if;
  end;

  function decode (
    constant code : string)
    return boolean is
    variable ret_val : boolean;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : bit)
    return string is
  begin
    if data = '1' then
      return "1";
    else
      return "0";
    end if;
  end;

  function decode (
    constant code : string)
    return bit is
    variable ret_val : bit;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : std_ulogic)
    return string is
  begin
    return std_ulogic'image(data)(2 to 2);
  end;

  function decode (
    constant code : string)
    return std_ulogic is
    variable ret_val : std_ulogic;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : severity_level)
    return string is
  begin
    return (1 => character'val(severity_level'pos(data)));
  end;

  function decode (
    constant code : string)
    return severity_level is
    variable ret_val : severity_level;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : file_open_status)
    return string is
  begin
    return (1 => character'val(file_open_status'pos(data)));
  end;

  function decode (
    constant code : string)
    return file_open_status is
    variable ret_val : file_open_status;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : file_open_kind)
    return string is
  begin
    return (1 => character'val(file_open_kind'pos(data)));
  end;

  function decode (
    constant code : string)
    return file_open_kind is
    variable ret_val : file_open_kind;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : character)
    return string is
  begin
    return (1 => data);
  end;

  function decode (
    constant code : string)
    return character is
    variable ret_val : character;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  -----------------------------------------------------------------------------
  -- Predefined composite types
  -----------------------------------------------------------------------------
  function get_range (
    constant code : string)
    return range_t is
    constant range_left         : integer := decode(code(1 to 4));
    constant range_right        : integer := decode(code(5 to 8));
    constant is_ascending       : boolean := decode(code(9 to 9));
    constant ret_val_ascending  : range_t(range_left to range_right) := (others => '0');
    constant ret_val_descending : range_t(range_left downto range_right) := (others => '0');
  begin
    if is_ascending then
      return ret_val_ascending;
    else
      return ret_val_descending;
    end if;
  end function get_range;

  function encode (
    constant data : std_ulogic_array)
    return string is
    variable ret_val : string(1 to 9 + (data'length+1)/2);
    variable index   : positive := 10;
    variable i       : integer  := data'left;
    variable byte    : natural;
  begin
    if data'length = 0 then
      return encode_array_header(encode(1), encode(0), encode(true));
    end if;
    ret_val(1 to 9) := encode_array_header(encode(data'left), encode(data'right), encode(data'ascending));
    if data'ascending then
      while i <= data'right loop
        byte := std_ulogic'pos(data(i));
        if i /= data'right then
          byte := byte + std_ulogic'pos(data(i + 1)) * 16;
        end if;
        ret_val(index) := character'val(byte);
        i              := i + 2;
        index          := index + 1;
      end loop;
    else
      while i >= data'right loop
        byte := std_ulogic'pos(data(i));
        if i /= data'right then
          byte := byte + std_ulogic'pos(data(i - 1)) * 16;
        end if;
        ret_val(index) := character'val(byte);
        i              := i - 2;
        index          := index + 1;
      end loop;
    end if;

    return ret_val;
  end;

  function encode (
    constant data : string)
    return string is
  begin
    -- Modelsim sets data'right to 0 which is out of the positive index range used by
    -- strings.
    if data'length = 0 then
      return encode_array_header(encode(data'left), encode(data'right), encode(data'ascending));
    else
      return encode_array_header(encode(data'left), encode(data'right), encode(data'ascending)) & data;
    end if;
  end;

  function decode (
    constant code : string)
    return string is
    constant ret_range : range_t := get_range(code);
    variable ret_val : string(ret_range'range) := (others => NUL);
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : bit_vector)
    return string is
    variable ret_val : string(1 to 9 + (data'length + 7) / 8);
  begin
    if data'length = 0 then
      return encode_array_header(encode(1), encode(0), encode(true));
    end if;
    ret_val(1 to 9)               := encode_array_header(encode(data'left), encode(data'right), encode(data'ascending));
    ret_val(10 to ret_val'length) := to_byte_array(data);

    return ret_val;
  end;

  function decode (
    constant code : string)
    return bit_vector is
    constant ret_range : range_t := get_range(code);
    variable ret_val : bit_vector(ret_range'range) := (others => '0');
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : std_ulogic_vector)
    return string is
  begin
    return encode(std_ulogic_array(data));
  end;

  function decode (
    constant code : string)
    return std_ulogic_vector is
    constant ret_range : range_t := get_range(code);
    variable ret_val : std_ulogic_vector(ret_range'range) := (others => 'U');
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : complex)
    return string is
  begin
    return encode(data.re) & encode(data.im);
  end;

  function decode (
    constant code : string)
    return complex is
    variable ret_val : complex;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : complex_polar)
    return string is
  begin
    return encode(data.mag) & encode(data.arg);
  end;

  function decode (
    constant code : string)
    return complex_polar is
    variable ret_val : complex_polar;
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : ieee.numeric_bit.unsigned)
    return string is
  begin
    return encode(bit_vector(data));
  end;

  function decode (
    constant code : string)
    return ieee.numeric_bit.unsigned is
    constant ret_range : range_t := get_range(code);
    variable ret_val : ieee.numeric_bit.unsigned(ret_range'range) := (others => '0');
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : ieee.numeric_bit.signed)
    return string is
  begin
    return encode(bit_vector(data));
  end;

  function decode (
    constant code : string)
    return ieee.numeric_bit.signed is
    constant ret_range : range_t := get_range(code);
    variable ret_val : ieee.numeric_bit.signed(ret_range'range) := (others => '0');
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : ieee.numeric_std.unsigned)
    return string is
  begin
    return encode(std_ulogic_vector(data));
  end;

  function decode (
    constant code : string)
    return ieee.numeric_std.unsigned is
    constant ret_range : range_t := get_range(code);
    variable ret_val : ieee.numeric_std.unsigned(ret_range'range) := (others => 'U');
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : ieee.numeric_std.signed)
    return string is
  begin
    return encode(std_ulogic_vector(data));
  end;

  function decode (
    constant code : string)
    return ieee.numeric_std.signed is
    constant ret_range : range_t := get_range(code);
    variable ret_val : ieee.numeric_std.signed(ret_range'range) := (others => 'U');
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;
end package body codec_pkg;
