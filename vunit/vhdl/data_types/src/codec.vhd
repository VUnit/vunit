-- This file provides functionality to encode/decode standard types to/from string.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library std;
use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;
use ieee.math_complex.all;

library work;
use work.codec_builder_pkg.all;



package codec_pkg is

  -- This packages enables the user to encode any predefined type into a unique type.
  -- This unique type is a 'string' (array of 'character').
  -- The functionality can be used to build a queue capable of storing different
  -- types in it (see the VUnit 'queue' package)

  -- Remark: this package encodes any predefined type into a string, however, this
  -- package is not meant for serialization and deserialization of data accross
  -- versions of VUnit.


  --===========================================================================
  -- API for the CASUAL USERS
  --===========================================================================
  -- All data going through the encoding process becomes a string: it
  -- basically becomes a sequence of bytes without any overhead for type
  -- information. The 'codec' package doesn’t know if four bytes represents an
  -- integer, four characters or something else. The interpretation of these
  -- bytes takes place when the user decodes the data using a type specific
  -- 'decode' function.

  -----------------------------------------------------------------------------
  -- Encode and decode functions of predefined enumerated types
  -----------------------------------------------------------------------------

  function encode_boolean(data : boolean) return code_t;
  function decode_boolean(code : code_t) return boolean;
  alias encode is encode_boolean[boolean return code_t];
  alias decode is decode_boolean[code_t return boolean];

  function encode_character(data : character) return code_t;
  function decode_character(code : code_t) return character;
  alias encode is encode_character[character return code_t];
  alias decode is decode_character[code_t return character];

  function encode_bit(data : bit) return code_t;
  function decode_bit(code : code_t) return bit;
  alias encode is encode_bit[bit return code_t];
  alias decode is decode_bit[code_t return bit];

  function encode_std_ulogic(data : std_ulogic) return code_t;
  function decode_std_ulogic(code : code_t) return std_ulogic;
  alias encode is encode_std_ulogic[std_ulogic return code_t];
  alias decode is decode_std_ulogic[code_t return std_ulogic];

  function encode_severity_level(data : severity_level) return code_t;
  function decode_severity_level(code : code_t) return severity_level;
  alias encode is encode_severity_level[severity_level return code_t];
  alias decode is decode_severity_level[code_t return severity_level];

  function encode_file_open_kind(data : file_open_kind) return code_t;
  function decode_file_open_kind(code : code_t) return file_open_kind;
  alias encode is encode_file_open_kind[file_open_kind return code_t];
  alias decode is decode_file_open_kind[code_t return file_open_kind];

  function encode_file_open_status(data : file_open_status) return code_t;
  function decode_file_open_status(code : code_t) return file_open_status;
  alias encode is encode_file_open_status[file_open_status return code_t];
  alias decode is decode_file_open_status[code_t return file_open_status];


  -----------------------------------------------------------------------------
  -- Encode and decode functions of predefined scalar types
  -----------------------------------------------------------------------------

  function encode_integer(data : integer) return code_t;
  function decode_integer(code : code_t) return integer;
  alias encode is encode_integer[integer return code_t];
  alias decode is decode_integer[code_t return integer];

  function encode_real(data : real) return code_t;
  function decode_real(code : code_t) return real;
  alias encode is encode_real[real return code_t];
  alias decode is decode_real[code_t return real];

  function encode_time(data : time) return code_t;
  function decode_time(code : code_t) return time;
  alias encode is encode_time[time return code_t];
  alias decode is decode_time[code_t return time];


  -----------------------------------------------------------------------------
  -- Encode and decode functions of predefined composite types (records)
  -----------------------------------------------------------------------------

  function encode_complex(data : complex) return code_t;
  function decode_complex(code : code_t) return complex;
  alias encode is encode_complex[complex return code_t];
  alias decode is decode_complex[code_t return complex];

  function encode_complex_polar(data : complex_polar) return code_t;
  function decode_complex_polar(code : code_t) return complex_polar;
  alias encode is encode_complex_polar[complex_polar return code_t];
  alias decode is decode_complex_polar[code_t return complex_polar];


  -----------------------------------------------------------------------------
  -- Encode and decode functions and procedures for range
  -----------------------------------------------------------------------------

  function encode_range(range_left : integer; range_right : integer; is_ascending : boolean) return code_t;
  function decode_range(code : code_t) return range_t;
  function decode_range(code : code_t; index : code_index_t) return range_t;
  alias encode is encode_range[integer, integer, boolean return code_t];
  alias decode is decode_range[code_t return range_t];
  alias decode is decode_range[code_t, code_index_t return range_t];


  -----------------------------------------------------------------------------
  -- Encode and decode functions of predefined composite types (arrays)
  -----------------------------------------------------------------------------

  function encode_string(data : string) return code_t;
  function decode_string(code : code_t) return string;
  alias encode is encode_string[string return code_t];
  alias decode is decode_string[code_t return string];

  -- The ieee.std_ulogic_vector is defined with a natural range.
  -- If you need to encode an array of ieee.std_ulogic (or an array of any subtype
  -- of ieee.std_ulogic) with an integer range, you can use the type 'std_ulogic_array'
  -- type bit_array is array(integer range <>) of bit;
  function encode_bit_array(data : bit_array) return code_t;
  function decode_bit_array(code : code_t) return bit_array;
  alias encode is encode_bit_array[bit_array return code_t];
  alias decode is decode_bit_array[code_t return bit_array];

  function encode_bit_vector(data : bit_vector) return code_t;
  function decode_bit_vector(code : code_t) return bit_vector;
  alias encode is encode_bit_vector[bit_vector return code_t];
  alias decode is decode_bit_vector[code_t return bit_vector];

  function encode_numeric_bit_unsigned(data : ieee.numeric_bit.unsigned) return code_t;
  function decode_numeric_bit_unsigned(code : code_t) return ieee.numeric_bit.unsigned;
  alias encode is encode_numeric_bit_unsigned[ieee.numeric_bit.unsigned return code_t];
  alias decode is decode_numeric_bit_unsigned[code_t return ieee.numeric_bit.unsigned];

  function encode_numeric_bit_signed(data : ieee.numeric_bit.signed) return code_t;
  function decode_numeric_bit_signed(code : code_t) return ieee.numeric_bit.signed;
  alias encode is encode_numeric_bit_signed[ieee.numeric_bit.signed return code_t];
  alias decode is decode_numeric_bit_signed[code_t return ieee.numeric_bit.signed];

  -- The std.bit_vector is defined with a natural range.
  -- If you need to encode an array of std.bit (or an array of any subtype
  -- of std.bit) with an integer range, you can use the type 'bit_array'
  -- type std_ulogic_array is array(integer range <>) of std_ulogic;
  function encode_std_ulogic_array(data : std_ulogic_array) return code_t;
  function decode_std_ulogic_array(code : code_t) return std_ulogic_array;
  alias encode is encode_std_ulogic_array[std_ulogic_array return code_t];
  alias decode is decode_std_ulogic_array[code_t return std_ulogic_array];

  function encode_std_ulogic_vector(data : std_ulogic_vector) return code_t;
  function decode_std_ulogic_vector(code : code_t) return std_ulogic_vector;
  alias encode is encode_std_ulogic_vector[std_ulogic_vector return code_t];
  alias decode is decode_std_ulogic_vector[code_t return std_ulogic_vector];

  function encode_numeric_std_unsigned(data : ieee.numeric_std.unresolved_unsigned) return code_t;
  function decode_numeric_std_unsigned(code : code_t) return ieee.numeric_std.unresolved_unsigned;
  alias encode is encode_numeric_std_unsigned[ieee.numeric_std.unresolved_unsigned return code_t];
  alias decode is decode_numeric_std_unsigned[code_t return ieee.numeric_std.unresolved_unsigned];

  function encode_numeric_std_signed(data : ieee.numeric_std.unresolved_signed) return code_t;
  function decode_numeric_std_signed(code : code_t) return ieee.numeric_std.unresolved_signed;
  alias encode is encode_numeric_std_signed[ieee.numeric_std.unresolved_signed return code_t];
  alias decode is decode_numeric_std_signed[code_t return ieee.numeric_std.unresolved_signed];


  --===========================================================================
  -- API for the ADVANCED USERS
  --===========================================================================

  -----------------------------------------------------------------------------
  -- Encoding of 'raw' string, 'raw' bit_array and 'raw' std_ulogic_array
  -----------------------------------------------------------------------------
  -- We define functions which encode a 'string', 'bit_array' or a 'std_ulogic_array' without its range.
  -- It can be useful when you encode a value which has always same width. For example,
  -- integers are encoded using 'encode_raw_bit_array' because thay are always
  -- 32 bits (or 64 bits in VHDL-2019).

  -- Note that the 'encode' functions do not have aliases functions 'encode' as they
  -- are homograph with the 'encode_string', 'encode_bit_array' or
  -- 'encode_std_ulogic_array'. Same thing for decode functions.

  -- To encode/decode string with its range, use encode_string and decode_string.
  function encode_raw_string(data : string) return code_t;
  function decode_raw_string(code : code_t) return string;
  function decode_raw_string(code : code_t; length : positive) return string;

  -- To encode/decode bit_array with its range, use encode_bit_array and decode_bit_array.
  function encode_raw_bit_array(data : bit_array) return code_t;
  function decode_raw_bit_array(code : code_t) return bit_array;
  function decode_raw_bit_array(code : code_t; length : positive) return bit_array;

  -- To encode/decode std_ulogic_array with its range, use encode_std_ulogic_array and decode_std_ulogic_array.
  function encode_raw_std_ulogic_array(data : std_ulogic_array) return code_t;
  function decode_raw_std_ulogic_array(code : code_t) return std_ulogic_array;
  function decode_raw_std_ulogic_array(code : code_t; length : positive) return std_ulogic_array;


  --===========================================================================
  -- Deprecated functions. Maintained for backward compatibility
  --===========================================================================

  -- This function is deprecated.
  -- Use the 'decode_range' function instead.
  function get_range(code : code_t) return range_t;

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
