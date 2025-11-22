-- This file provides functionality to encode/decode standard types to/from string.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

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
  -- information. The 'codec' package does not know if four bytes represents an
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

  function encode_numeric_std_unsigned(data : ieee.numeric_std.unsigned) return code_t;
  function decode_numeric_std_unsigned(code : code_t) return ieee.numeric_std.unsigned;
  alias encode is encode_numeric_std_unsigned[ieee.numeric_std.unsigned return code_t];
  alias decode is decode_numeric_std_unsigned[code_t return ieee.numeric_std.unsigned];

  function encode_numeric_std_signed(data : ieee.numeric_std.signed) return code_t;
  function decode_numeric_std_signed(code : code_t) return ieee.numeric_std.signed;
  alias encode is encode_numeric_std_signed[ieee.numeric_std.signed return code_t];
  alias decode is decode_numeric_std_signed[code_t return ieee.numeric_std.signed];


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

  --===========================================================================
  -- Encode and decode procedures of predefined enumerated types
  --===========================================================================

  -----------------------------------------------------------------------------
  -- Boolean
  -----------------------------------------------------------------------------
  function encode_boolean(data : boolean) return code_t is
    variable ret_val : code_t(1 to code_length_boolean);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_boolean(data, index, ret_val);
    return ret_val;
  end function;

  function decode_boolean(code : code_t) return boolean is
    variable ret_val : boolean;
    variable index   : code_index_t := code'left;
  begin
    decode_boolean(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- Character
  -----------------------------------------------------------------------------
  function encode_character(data : character) return code_t is
    variable ret_val : code_t(1 to code_length_character);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_character(data, index, ret_val);
    return ret_val;
  end function;

  function decode_character(code : code_t) return character is
    variable ret_val : character;
    variable index   : code_index_t := code'left;
  begin
    decode_character(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- Bit
  -----------------------------------------------------------------------------
  function encode_bit(data : bit) return code_t is
    variable ret_val : code_t(1 to code_length_bit);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_bit(data, index, ret_val);
    return ret_val;
  end function;

  function decode_bit(code : code_t) return bit is
    variable ret_val : bit;
    variable index   : code_index_t := code'left;
  begin
    decode_bit(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- std_ulogic
  -----------------------------------------------------------------------------
  function encode_std_ulogic(data : std_ulogic) return code_t is
    variable ret_val : code_t(1 to code_length_std_ulogic);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_std_ulogic(data, index, ret_val);
    return ret_val;
  end function;

  function decode_std_ulogic(code : code_t) return std_ulogic is
    variable ret_val : std_ulogic;
    variable index   : code_index_t := code'left;
  begin
    decode_std_ulogic(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- severity_level
  -----------------------------------------------------------------------------
  function encode_severity_level(data : severity_level) return code_t is
    variable ret_val : code_t(1 to code_length_severity_level);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_severity_level(data, index, ret_val);
    return ret_val;
  end function;

  function decode_severity_level(code : code_t) return severity_level is
    variable ret_val : severity_level;
    variable index   : code_index_t := code'left;
  begin
    decode_severity_level(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- file_open_kind
  -----------------------------------------------------------------------------
  function encode_file_open_kind(data : file_open_kind) return code_t is
    variable ret_val : code_t(1 to code_length_file_open_kind);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_file_open_kind(data, index, ret_val);
    return ret_val;
  end function;

  function decode_file_open_kind(code : code_t) return file_open_kind is
    variable ret_val : file_open_kind;
    variable index   : code_index_t := code'left;
  begin
    decode_file_open_kind(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- file_open_status
  -----------------------------------------------------------------------------
  function encode_file_open_status(data : file_open_status) return code_t is
    variable ret_val : code_t(1 to code_length_file_open_status);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_file_open_status(data, index, ret_val);
    return ret_val;
  end function;

  function decode_file_open_status(code : code_t) return file_open_status is
    variable ret_val : file_open_status;
    variable index   : code_index_t := code'left;
  begin
    decode_file_open_status(code, index, ret_val);
    return ret_val;
  end function;


  --===========================================================================
  -- Encode and decode procedures of predefined scalar types
  --===========================================================================

  -----------------------------------------------------------------------------
  -- integer
  -----------------------------------------------------------------------------
  function encode_integer(data : integer) return code_t is
    variable ret_val : code_t(1 to code_length_integer);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_integer(data, index, ret_val);
    return ret_val;
  end function;

  function decode_integer(code : code_t) return integer is
    variable ret_val : integer;
    variable index   : code_index_t := code'left;
  begin
    decode_integer(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- real
  -----------------------------------------------------------------------------
  function encode_real(data : real) return code_t is
    variable ret_val : code_t(1 to code_length_real);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_real(data, index, ret_val);
    return ret_val;
  end function;

  function decode_real(code : code_t) return real is
    variable ret_val : real;
    variable index   : code_index_t := code'left;
  begin
    decode_real(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- time
  -----------------------------------------------------------------------------
  function encode_time(data : time) return code_t is
    variable ret_val : code_t(1 to code_length_time);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_time(data, index, ret_val);
    return ret_val;
  end function;

  function decode_time(code : code_t) return time is
    variable ret_val : time;
    variable index   : code_index_t := code'left;
  begin
    decode_time(code, index, ret_val);
    return ret_val;
  end function;


  --===========================================================================
  -- Encode and decode procedures of predefined composite types (records)
  --===========================================================================

  -----------------------------------------------------------------------------
  -- complex
  -----------------------------------------------------------------------------
  function encode_complex(data : complex) return code_t is
    variable ret_val : code_t(1 to code_length_complex);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_complex(data, index, ret_val);
    return ret_val;
  end function;

  function decode_complex(code : code_t) return complex is
    variable ret_val : complex;
    variable index   : code_index_t := code'left;
  begin
    decode_complex(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- complex_polar
  -----------------------------------------------------------------------------
  function encode_complex_polar(data : complex_polar) return code_t is
    variable ret_val : code_t(1 to code_length_complex_polar);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_complex_polar(data, index, ret_val);
    return ret_val;
  end function;

  function decode_complex_polar(code : code_t) return complex_polar is
    variable ret_val : complex_polar;
    variable index   : code_index_t := code'left;
  begin
    decode_complex_polar(code, index, ret_val);
    return ret_val;
  end function;


  --===========================================================================
  -- Encode and decode functions and procedures for range
  --===========================================================================

  function encode_range(range_left : integer; range_right : integer; is_ascending : boolean) return code_t is
    variable ret_val : code_t(1 to code_length_integer_range);
    variable index   : code_index_t := ret_val'left;
  begin
    encode_range(range_left, range_right, is_ascending, index, ret_val);
    return ret_val;
  end function;

  function decode_range(code : code_t; index : code_index_t) return range_t is
    variable code_alias : code_t(1 to code'length-index+1) := code(index to code'length);
    constant range_left : integer := decode_integer(
      code_alias(1 to code_length_integer)
    );
    constant range_right : integer := decode_integer(
      code_alias(1 + code_length_integer to code_length_integer*2)
    );
    constant is_ascending : boolean := decode_boolean(
      code_alias(1 + code_length_integer*2 to code_length_integer*2 + code_length_boolean)
    );
    constant ret_val_ascending  : range_t(range_left to range_right) := (others => '0');
    constant ret_val_descending : range_t(range_left downto range_right) := (others => '0');
  begin
    if is_ascending then
      return ret_val_ascending;
    else
      return ret_val_descending;
    end if;
  end function;

  function decode_range(code : code_t) return range_t is
  begin
    return decode_range(code, code'left);
  end function;


  --===========================================================================
  -- Encode and decode procedures of predefined composite types (arrays)
  --===========================================================================

  -----------------------------------------------------------------------------
  -- string
  -----------------------------------------------------------------------------
  function encode_string(data : string) return code_t is
    variable ret_val : code_t(1 to code_length_string(data'length));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_string(data, index, ret_val);
    return ret_val;
  end function;

  function decode_string(code : code_t) return string is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : string(ret_range'range) := (others => NUL);
    variable index   : code_index_t := code'left;
  begin
    decode_string(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- bit_array
  -----------------------------------------------------------------------------
  function encode_bit_array(data : bit_array) return code_t is
    variable ret_val : code_t(1 to code_length_bit_array(data'length));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_bit_array(data, index, ret_val);
    return ret_val;
  end function;

  function decode_bit_array(code : code_t) return bit_array is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : bit_array(ret_range'range);
    variable index   : code_index_t := code'left;
  begin
    decode_bit_array(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- bit_vector
  -----------------------------------------------------------------------------
  function encode_bit_vector(data : bit_vector) return code_t is
    variable ret_val : code_t(1 to code_length_bit_vector(data'length));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_bit_vector(data, index, ret_val);
    return ret_val;
  end function;

  function decode_bit_vector(code : code_t) return bit_vector is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : bit_vector(ret_range'range);
    variable index   : code_index_t := code'left;
  begin
    decode_bit_vector(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- ieee.numeric_bit.unsigned
  -----------------------------------------------------------------------------
  function encode_numeric_bit_unsigned(data : ieee.numeric_bit.unsigned) return code_t is
    variable ret_val : code_t(1 to code_length_numeric_bit_unsigned(data'length));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_numeric_bit_unsigned(data, index, ret_val);
    return ret_val;
  end function;

  function decode_numeric_bit_unsigned(code : code_t) return ieee.numeric_bit.unsigned is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : ieee.numeric_bit.unsigned(ret_range'range);
    variable index   : code_index_t := code'left;
  begin
    decode_numeric_bit_unsigned(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- ieee.numeric_bit.signed
  -----------------------------------------------------------------------------
  function encode_numeric_bit_signed(data : ieee.numeric_bit.signed) return code_t is
    variable ret_val : code_t(1 to code_length_numeric_bit_signed(data'length));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_numeric_bit_signed(data, index, ret_val);
    return ret_val;
  end function;

  function decode_numeric_bit_signed(code : code_t) return ieee.numeric_bit.signed is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : ieee.numeric_bit.signed(ret_range'range);
    variable index   : code_index_t := code'left;
  begin
    decode_numeric_bit_signed(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- std_ulogic_array
  -----------------------------------------------------------------------------
  function encode_std_ulogic_array(data : std_ulogic_array) return code_t is
    variable ret_val : code_t(1 to code_length_std_ulogic_array(data'length));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_std_ulogic_array(data, index, ret_val);
    return ret_val;
  end function;

  function decode_std_ulogic_array(code : code_t) return std_ulogic_array is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : std_ulogic_array(ret_range'range);
    variable index   : code_index_t := code'left;
  begin
    decode_std_ulogic_array(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- std_ulogic_vector
  -----------------------------------------------------------------------------
  function encode_std_ulogic_vector(data : std_ulogic_vector) return code_t is
    variable ret_val : code_t(1 to code_length_std_ulogic_vector(data'length));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_std_ulogic_vector(data, index, ret_val);
    return ret_val;
  end function;

  function decode_std_ulogic_vector(code : code_t) return std_ulogic_vector is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : std_ulogic_vector(ret_range'range);
    variable index   : code_index_t := code'left;
  begin
    decode_std_ulogic_vector(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- ieee.numeric_std.unsigned
  -----------------------------------------------------------------------------
  function encode_numeric_std_unsigned(data : ieee.numeric_std.unsigned) return code_t is
    variable ret_val : code_t(1 to code_length_numeric_std_unsigned(data'length));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_numeric_std_unsigned(data, index, ret_val);
    return ret_val;
  end function;

  function decode_numeric_std_unsigned(code : code_t) return ieee.numeric_std.unsigned is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : ieee.numeric_std.unsigned(ret_range'range);
    variable index   : code_index_t := code'left;
  begin
    decode_numeric_std_unsigned(code, index, ret_val);
    return ret_val;
  end function;

  -----------------------------------------------------------------------------
  -- ieee.numeric_std.signed
  -----------------------------------------------------------------------------
  function encode_numeric_std_signed(data : ieee.numeric_std.signed) return code_t is
    variable ret_val : code_t(1 to code_length_numeric_std_signed(data'length));
    variable index   : code_index_t := ret_val'left;
  begin
    encode_numeric_std_signed(data, index, ret_val);
    return ret_val;
  end function;

  function decode_numeric_std_signed(code : code_t) return ieee.numeric_std.signed is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : ieee.numeric_std.signed(ret_range'range);
    variable index   : code_index_t := code'left;
  begin
    decode_numeric_std_signed(code, index, ret_val);
    return ret_val;
  end function;


  --===========================================================================
  -- Encode and Decode functions of for a 'raw' string, 'raw' bit_array and 'raw' std_ulogic_array
  --===========================================================================

  -----------------------------------------------------------------------------
  -- raw_string
  -----------------------------------------------------------------------------
  function encode_raw_string(data : string) return code_t is
    variable ret_val : code_t(1 to code_length_raw_string(data'length));
    variable index : code_index_t := ret_val'left;
  begin
    encode_raw_string(data, index, ret_val);
    return ret_val;
  end function;

  function decode_raw_string(code : code_t; length : positive) return string is
    variable ret_val : string(length-1 downto 0);
    variable index : code_index_t := code'left;
  begin
    decode_raw_string(code, index, ret_val);
    return ret_val;
  end function;

  function decode_raw_string(code : code_t) return string is
  begin
    return decode_raw_string(code, code'length * basic_code_length);
  end function;

  -----------------------------------------------------------------------------
  -- raw_bit_array
  -----------------------------------------------------------------------------
  function encode_raw_bit_array(data : bit_array) return code_t is
    variable ret_val : code_t(1 to code_length_raw_bit_array(data'length));
    variable index : code_index_t := ret_val'left;
  begin
    encode_raw_bit_array(data, index, ret_val);
    return ret_val;
  end function;

  function decode_raw_bit_array(code : code_t; length : positive) return bit_array is
    variable ret_val : bit_array(length-1 downto 0);
    variable index : code_index_t := code'left;
  begin
    decode_raw_bit_array(code, index, ret_val);
    return ret_val;
  end function;

  function decode_raw_bit_array(code : code_t) return bit_array is
  begin
    return decode_raw_bit_array(code, code'length * basic_code_length);
  end function;

  -----------------------------------------------------------------------------
  -- raw_std_ulogic_array
  -----------------------------------------------------------------------------
  function encode_raw_std_ulogic_array(data : std_ulogic_array) return code_t is
    variable ret_val : code_t(1 to code_length_raw_std_ulogic_array(data'length));
    variable index : code_index_t := ret_val'left;
  begin
    encode_raw_std_ulogic_array(data, index, ret_val);
    return ret_val;
  end function;

  function decode_raw_std_ulogic_array(code : code_t; length : positive) return std_ulogic_array is
    variable ret_val : std_ulogic_array(length-1 downto 0);
    variable index : code_index_t := code'left;
  begin
    decode_raw_std_ulogic_array(code, index, ret_val);
    return ret_val;
  end function;

  function decode_raw_std_ulogic_array(code : code_t) return std_ulogic_array is
  begin
    return decode_raw_std_ulogic_array(code, code'length * basic_code_length);
  end function;


  --===========================================================================
  -- Deprecated functions - Maintained for backward compatibility.
  --===========================================================================

  -- Deprecated. Maintained for backward compatibility.
  function get_range(code : code_t) return range_t is
    constant range_left   : integer := decode_integer(code(code'left                       to code'left+code_length_integer-1));
    constant range_right  : integer := decode_integer(code(code'left+code_length_integer   to code'left+code_length_integer*2-1));
    constant is_ascending : boolean := decode_boolean(code(code'left+code_length_integer*2 to code'left+code_length_integer*2+code_length_boolean-1));
    constant ret_val_ascending  : range_t(range_left to range_right) := (others => '0');
    constant ret_val_descending : range_t(range_left downto range_right) := (others => '0');
  begin
    assert False report
      "This function ('get_range') is deprecated. Please use 'decode_range' from codec_pkg.vhd"
    severity warning;
    return decode_range(code);
  end function;

end package body;
