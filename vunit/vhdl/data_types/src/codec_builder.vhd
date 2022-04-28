-- This package contains support functions for standard codec building
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
use ieee.math_real.all;
use ieee.math_complex.all;

library work;
use work.common_pkg.all;


package codec_builder_pkg is

  -- This packages enables the user to encode any predefined type into a unique type.
  -- This unique type is a 'string' (array of 'character').
  -- The functionality can be used to build a queue capable of storing different
  -- types in it (see the VUnit 'queue' package)
  alias code_t is string;

  -- Remark: this package encodes any predefined type into a string, however, this
  -- package is not meant for serialization and deserialization of data accross
  -- versions of VUnit.


  --===========================================================================
  -- API for the ADVANCED USERS
  --===========================================================================

  -----------------------------------------------------------------------------
  -- Base types and constants describing how the encoding is performed
  -----------------------------------------------------------------------------

  -- A character (string of length 1) is 8 bits long
  constant basic_code_length : positive := 8;
  -- A character (string of length 1) can store up to 2**8 = 256 values
  constant basic_code_nb_values : positive := 2**basic_code_length;


  -----------------------------------------------------------------------------
  -- VUnit defined types
  -----------------------------------------------------------------------------

  -- The std.bit_vector is defined with a natural range.
  -- If you need to encode an array of std.bit (or an array of any subtype
  -- of std.bit) with an integer range, you can use the type 'bit_array'
  type bit_array is array(integer range <>) of bit;

  -- The ieee.std_ulogic_vector is defined with a natural range.
  -- If you need to encode an array of ieee.std_ulogic (or an array of any subtype
  -- of ieee.std_ulogic) with an integer range, you can use the type 'std_ulogic_array'
  type std_ulogic_array is array(integer range <>) of std_ulogic;


  -----------------------------------------------------------------------------
  -- Encoding length for each type
  -----------------------------------------------------------------------------
  -- If you need to retrieve the length of the encoded data without
  -- encoding it, you can use these functions:
  -- There are useful to automatically get the encoding length of a subtype
  -- using the 'generic' function: "code_length(data)"

  -- Note: some of these functions have a default value for the parameter 'data'. This is useful
  -- for automatically generating encode and decode procedure/functions of more complex types
  -- has all the functions have the same parameter 'data'.

  -- The details of how each type is encoded is described in the package body

  -- Predefined enumerated types
  function code_length_boolean(data : boolean := boolean'left) return natural;
  function code_length_character(data : character := character'left) return natural;
  function code_length_bit(data : bit := bit'left) return natural;
  function code_length_std_ulogic(data : std_ulogic := std_ulogic'left) return natural;
  function code_length_severity_level(data : severity_level := severity_level'left) return natural;
  function code_length_file_open_kind(data : file_open_kind := file_open_kind'left) return natural;
  function code_length_file_open_status(data : file_open_status := file_open_status'left) return natural;

  alias code_length is code_length_boolean[boolean return natural];
  alias code_length is code_length_character[character return natural];
  alias code_length is code_length_bit[bit return natural];
  alias code_length is code_length_std_ulogic[std_ulogic return natural];
  alias code_length is code_length_severity_level[severity_level return natural];
  alias code_length is code_length_file_open_kind[file_open_kind return natural];
  alias code_length is code_length_file_open_status[file_open_status return natural];

  -- Predefined scalar types
  function code_length_integer(data : integer := integer'left) return natural;
  function code_length_real(data : real := real'left) return natural;
  function code_length_time(data : time := time'left) return natural;

  alias code_length is code_length_integer[integer return natural];
  alias code_length is code_length_real[real return natural];
  alias code_length is code_length_time[time return natural];

  -- Predefined composite types (records)
  function code_length_complex(data : complex := MATH_CZERO) return natural;
  function code_length_complex_polar(data : complex_polar := (MAG => 0.0, ARG => 0.0)) return natural;

  alias code_length is code_length_complex[complex return natural];
  alias code_length is code_length_complex_polar[complex_polar return natural];

  -- Predefined composite types (arrays)
  -- Note: We can use an alternate function for array types which takes the
  -- length of the array to encode instead of the array itself.
  function code_length_string(length : natural) return natural;
  function code_length_bit_vector(length : natural) return natural;
  function code_length_numeric_bit_unsigned(length : natural) return natural;
  function code_length_numeric_bit_signed(length : natural) return natural;
  function code_length_std_ulogic_vector(length : natural) return natural;
  function code_length_numeric_std_unsigned(length : natural) return natural;
  function code_length_numeric_std_signed(length : natural) return natural;
  function code_length_bit_array(length : natural) return natural;
  function code_length_std_ulogic_array(length : natural) return natural;

  function code_length_string(data : string) return natural;
  function code_length_bit_vector(data : bit_vector) return natural;
  function code_length_numeric_bit_unsigned(data : ieee.numeric_bit.unsigned) return natural;
  function code_length_numeric_bit_signed(data : ieee.numeric_bit.signed) return natural;
  function code_length_std_ulogic_vector(data : std_ulogic_vector) return natural;
  function code_length_numeric_std_unsigned(data : ieee.numeric_std.unresolved_unsigned) return natural;
  function code_length_numeric_std_signed(data : ieee.numeric_std.unresolved_signed) return natural;
  function code_length_bit_array(data : bit_array) return natural;
  function code_length_std_ulogic_array(data : std_ulogic_array) return natural;

  alias code_length is code_length_string[string return natural];
  alias code_length is code_length_bit_vector[bit_vector return natural];
  alias code_length is code_length_numeric_bit_unsigned[ieee.numeric_bit.unsigned return natural];
  alias code_length is code_length_numeric_bit_signed[ieee.numeric_bit.signed return natural];
  alias code_length is code_length_std_ulogic_vector[std_ulogic_vector return natural];
  alias code_length is code_length_numeric_std_unsigned[ieee.numeric_std.unresolved_unsigned return natural];
  alias code_length is code_length_numeric_std_signed[ieee.numeric_std.unresolved_signed return natural];
  alias code_length is code_length_bit_array[bit_array return natural];
  alias code_length is code_length_std_ulogic_array[std_ulogic_array return natural];



  --===========================================================================
  -- API for the VUnit DEVELOPERS
  --===========================================================================
  -- This section present low level procedures to encode and decode. They are not
  -- intented to be used by the casual user.
  -- These are intended for VUnit developers (and advanced users) to build encode
  -- and decode procedures and functions of more complex types.

  -- Index to track the position of an encoded element inside an instance of code_t
  alias code_index_t is positive;

  -----------------------------------------------------------------------------
  -- Alternate encode and decode procedures
  -----------------------------------------------------------------------------
  -- In most of the procedures, there are:
  --  * the 'code' parameter which is the encoded data.
  --  * the 'index' parameter which indicates from where inside the 'code' parameter
  --    we must start to encode the data or decode the data.
  -- The 'index' is updated by the procedures in order for the next encode/decode
  -- procedure to be able to keep encoding or decoding the data without having to deal
  -- with the length of the internal representation.
  -- The implementations on the 'encode_complex' and 'decode_complex' is an example
  -- of that feature. We first encode/decode the real part, then the imaginary part.

  -- Predefined enumerated types
  procedure encode_boolean(constant data : in boolean; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_boolean(constant code : in code_t; variable index : inout code_index_t; variable result : out boolean);
  alias encode is encode_boolean[boolean, code_index_t, code_t];
  alias decode is decode_boolean[code_t, code_index_t, boolean];

  procedure encode_character(constant data : in character; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_character(constant code : in code_t; variable index : inout code_index_t; variable result : out character);
  alias encode is encode_character[character, code_index_t, code_t];
  alias decode is decode_character[code_t, code_index_t, character];

  procedure encode_bit(constant data : in bit; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_bit(constant code : in code_t; variable index : inout code_index_t; variable result : out bit);
  alias encode is encode_bit[bit, code_index_t, code_t];
  alias decode is decode_bit[code_t, code_index_t, bit];

  procedure encode_std_ulogic(constant data : in std_ulogic; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_std_ulogic(constant code : in code_t; variable index : inout code_index_t; variable result : out std_ulogic);
  alias encode is encode_std_ulogic[std_ulogic, code_index_t, code_t];
  alias decode is decode_std_ulogic[code_t, code_index_t, std_ulogic];

  procedure encode_severity_level(constant data : in severity_level; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_severity_level(constant code : in code_t; variable index : inout code_index_t; variable result : out severity_level);
  alias encode is encode_severity_level[severity_level, code_index_t, code_t];
  alias decode is decode_severity_level[code_t, code_index_t, severity_level];

  procedure encode_file_open_kind(constant data : in file_open_kind; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_file_open_kind(constant code : in code_t; variable index : inout code_index_t; variable result : out file_open_kind);
  alias encode is encode_file_open_kind[file_open_kind, code_index_t, code_t];
  alias decode is decode_file_open_kind[code_t, code_index_t, file_open_kind];

  procedure encode_file_open_status(constant data : in file_open_status; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_file_open_status(constant code : in code_t; variable index : inout code_index_t; variable result : out file_open_status);
  alias encode is encode_file_open_status[file_open_status, code_index_t, code_t];
  alias decode is decode_file_open_status[code_t, code_index_t, file_open_status];

  -- Predefined scalar types
  procedure encode_integer(constant data : in integer; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_integer(constant code : in code_t; variable index : inout code_index_t; variable result : out integer);
  alias encode is encode_integer[integer, code_index_t, code_t];
  alias decode is decode_integer[code_t, code_index_t, integer];

  procedure encode_real(constant data : in real; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_real(constant code : in code_t; variable index : inout code_index_t; variable result : out real);
  alias encode is encode_real[real, code_index_t, code_t];
  alias decode is decode_real[code_t, code_index_t, real];

  procedure encode_time(constant data : in time; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_time(constant code : in code_t; variable index : inout code_index_t; variable result : out time);
  alias encode is encode_time[time, code_index_t, code_t];
  alias decode is decode_time[code_t, code_index_t, time];

  -- Predefined composite types (records)
  procedure encode_complex(constant data : in complex; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_complex(constant code : in code_t; variable index : inout code_index_t; variable result : out complex);
  alias encode is encode_complex[complex, code_index_t, code_t];
  alias decode is decode_complex[code_t, code_index_t, complex];

  procedure encode_complex_polar(constant data : in complex_polar; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_complex_polar(constant code : in code_t; variable index : inout code_index_t; variable result : out complex_polar);
  alias encode is encode_complex_polar[complex_polar, code_index_t, code_t];
  alias decode is decode_complex_polar[code_t, code_index_t, complex_polar];

  -- Predefined composite types (arrays)
  -- Note: these function encode the range of the array alongside its data. If the
  -- array is empty(null range), its range is still encoded

  procedure encode_string(constant data : in string; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_string(constant code : in code_t; variable index : inout code_index_t; variable result : out string);
  alias encode is encode_string[string, code_index_t, code_t];
  alias decode is decode_string[code_t, code_index_t, string];

  procedure encode_bit_array(constant data : in bit_array; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_bit_array(constant code : in code_t; variable index : inout code_index_t; variable result : out bit_array);
  alias encode is encode_bit_array[bit_array, code_index_t, code_t];
  alias decode is decode_bit_array[code_t, code_index_t, bit_array];

  procedure encode_bit_vector(constant data : in bit_vector; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_bit_vector(constant code : in code_t; variable index : inout code_index_t; variable result : out bit_vector);
  alias encode is encode_bit_vector[bit_vector, code_index_t, code_t];
  alias decode is decode_bit_vector[code_t, code_index_t, bit_vector];

  procedure encode_numeric_bit_unsigned(constant data : in ieee.numeric_bit.unsigned; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_numeric_bit_unsigned(constant code : in code_t; variable index : inout code_index_t; variable result : out ieee.numeric_bit.unsigned);
  alias encode is encode_numeric_bit_unsigned[ieee.numeric_bit.unsigned, code_index_t, code_t];
  alias decode is decode_numeric_bit_unsigned[code_t, code_index_t, ieee.numeric_bit.unsigned];

  procedure encode_numeric_bit_signed(constant data : in ieee.numeric_bit.signed; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_numeric_bit_signed(constant code : in code_t; variable index : inout code_index_t; variable result : out ieee.numeric_bit.signed);
  alias encode is encode_numeric_bit_signed[ieee.numeric_bit.signed, code_index_t, code_t];
  alias decode is decode_numeric_bit_signed[code_t, code_index_t, ieee.numeric_bit.signed];

  procedure encode_std_ulogic_array(constant data : in std_ulogic_array; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_std_ulogic_array(constant code : in code_t; variable index : inout code_index_t; variable result : out std_ulogic_array);
  alias encode is encode_std_ulogic_array[std_ulogic_array, code_index_t, code_t];
  alias decode is decode_std_ulogic_array[code_t, code_index_t, std_ulogic_array];

  procedure encode_std_ulogic_vector(constant data : in std_ulogic_vector; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_std_ulogic_vector(constant code : in code_t; variable index : inout code_index_t; variable result : out std_ulogic_vector);
  alias encode is encode_std_ulogic_vector[std_ulogic_vector, code_index_t, code_t];
  alias decode is decode_std_ulogic_vector[code_t, code_index_t, std_ulogic_vector];

  procedure encode_numeric_std_unsigned(constant data : in ieee.numeric_std.unresolved_unsigned; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_numeric_std_unsigned(constant code : in code_t; variable index : inout code_index_t; variable result : out ieee.numeric_std.unresolved_unsigned);
  alias encode is encode_numeric_std_unsigned[ieee.numeric_std.unresolved_unsigned, code_index_t, code_t];
  alias decode is decode_numeric_std_unsigned[code_t, code_index_t, ieee.numeric_std.unresolved_unsigned];

  procedure encode_numeric_std_signed(constant data : in ieee.numeric_std.unresolved_signed; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_numeric_std_signed(constant code : in code_t; variable index : inout code_index_t; variable result : out ieee.numeric_std.unresolved_signed);
  alias encode is encode_numeric_std_signed[ieee.numeric_std.unresolved_signed, code_index_t, code_t];
  alias decode is decode_numeric_std_signed[code_t, code_index_t, ieee.numeric_std.unresolved_signed];


  -----------------------------------------------------------------------------
  -- Encoding of 'raw' string, 'raw' bit_array and 'raw' std_ulogic_array
  -----------------------------------------------------------------------------
  -- We define procedures which encode a 'string', 'bit_array' or a 'std_ulogic_array' without its range.
  -- It can be useful when you encode a value which has always same width. For example,
  -- integers are encoded using 'encode_raw_bit_array' because thay are always
  -- 32 bits (or 64 bits in VHDL-2019).

  -- Note that the 'encode' procedure do not have aliases procedure 'encode' as they
  -- are homograph with the 'encode_string', 'encode_bit_array' or
  -- 'encode_std_ulogic_array'. Same thing for decode procedure.

  -- To encode/decode string with its range, use encode_string and decode_string.
  procedure encode_raw_string(constant data : in string; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_raw_string(constant code : in code_t; variable index : inout code_index_t; variable result : out string);
  -- To encode/decode bit_array with its range, use encode_bit_array and decode_bit_array.
  procedure encode_raw_bit_array(constant data : in bit_array; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_raw_bit_array(constant code : in code_t; variable index : inout code_index_t; variable result : out bit_array);
  -- To encode/decode std_ulogic_array with its range, use encode_std_ulogic_array and decode_std_ulogic_array.
  procedure encode_raw_std_ulogic_array(constant data : in std_ulogic_array; variable index : inout code_index_t; variable code : inout code_t);
  procedure decode_raw_std_ulogic_array(constant code : in code_t; variable index : inout code_index_t; variable result : out std_ulogic_array);

  -- Thes functions give you the length of the encoded array depending on the
  -- length of the array to encode
  function code_length_raw_string(length : natural) return natural;
  function code_length_raw_bit_array(length : natural) return natural;
  function code_length_raw_std_ulogic_array(length : natural) return natural;

  function code_length_raw_string(data : string) return natural;
  function code_length_raw_bit_array(data : bit_array) return natural;
  function code_length_raw_std_ulogic_array(data : std_ulogic_array) return natural;


  -----------------------------------------------------------------------------
  -- Encoding of predefined composite types (arrays)
  -----------------------------------------------------------------------------

  -- Two things need to be extracted from an array to encode it:
  --  * The range of the array
  --  * The data inside the array
  -- The range encoding is performed by 'encode_range' and 'decode_range' functions.

  -- This type is used so that we can return an array with any integer range.
  -- It is not meant to carry any other information.
  type range_t is array(integer range <>) of bit;

  -- Encode and decode functions for range
  procedure encode_range(
    constant range_left : integer;
    constant range_right : integer;
    constant is_ascending : boolean;
    variable index : inout code_index_t;
    variable code : inout code_t
  );
  alias encode is encode_range[integer, integer, boolean, code_index_t, code_t];
  -- Note, there is no procedure 'decode_range' because we want to retrieve an unknown range.
  -- If we had a procedure, we would need to provide a variable to the parameter 'result' which
  -- must be constrained. This contradicts the purpose of the functionnality.
  -- However, there is a 'decode_range' function inside the codec.vhd package

  -- Encoding length of an integer range
  function code_length_integer_range return natural;


  --===========================================================================
  -- Deprecated functions. Maintained for backward compatibility
  --===========================================================================

  -- Deferred constants
  constant integer_code_length          : positive;
  constant boolean_code_length          : positive;
  constant real_code_length             : positive;
  constant std_ulogic_code_length       : positive;
  constant bit_code_length              : positive;
  constant time_code_length             : positive;
  constant severity_level_code_length   : positive;
  constant file_open_status_code_length : positive;
  constant file_open_kind_code_length   : positive;
  constant complex_code_length          : positive;
  constant complex_polar_code_length    : positive;

  -- This function is deprecated.
  -- Use the 'encode_range' function instead.
  -- If you need to encode two ranges, make two call to the 'encode_range' function.
  function encode_array_header(
    constant range_left1   : in code_t;
    constant range_right1  : in code_t;
    constant is_ascending1 : in code_t;
    constant range_left2   : in code_t := "";
    constant range_right2  : in code_t := "";
    constant is_ascending2 : in code_t := "T"
  ) return code_t;

  -- This function is deprecated.
  -- Use the 'encode_raw_bit_array' function instead.
  function to_byte_array(value : bit_vector) return code_t;

  -- This function is deprecated.
  -- Use the 'decode_raw_bit_array' function instead.
  function from_byte_array(byte_array : code_t) return bit_vector;

end package;



package body codec_builder_pkg is

  --===========================================================================
  -- Constants used to give the number of code_t element to be used to encode the type
  --===========================================================================

  -- Number of literals of the predefined enumerated types:
  -- The formulation "type'pos(type'right) + 1" gives the number of literals defined by the enumerated type
  constant length_boolean          : positive := boolean'pos(boolean'right) + 1;
  constant length_character        : positive := character'pos(character'right) + 1;
  constant length_bit              : positive := bit'pos(bit'right) + 1;
  constant length_std_ulogic       : positive := std_ulogic'pos(std_ulogic'right) + 1;
  constant length_severity_level   : positive := severity_level'pos(severity_level'right) + 1;
  constant length_file_open_kind   : positive := file_open_kind'pos(file_open_kind'right) + 1;
  constant length_file_open_status : positive := file_open_status'pos(file_open_status'right) + 1;


  --===========================================================================
  -- Functions which gives the number of code_t element to be used to encode the type
  --===========================================================================

  -----------------------------------------------------------------------------
  -- Boolean
  -----------------------------------------------------------------------------
  -- A boolean is transfomed the characters 'T' or 'F' to be encoded
  constant static_code_length_boolean : positive := ceil_div(length_boolean, basic_code_nb_values);

  function code_length_boolean(data : boolean := boolean'left) return natural is
  begin
    return static_code_length_boolean;
  end function;

  -----------------------------------------------------------------------------
  -- Character
  -----------------------------------------------------------------------------
  -- A character can direclty be encoded
  constant static_code_length_character : positive := ceil_div(length_character, basic_code_nb_values);

  function code_length_character(data : character := character'left) return natural is
  begin
    return static_code_length_character;
  end function;

  -----------------------------------------------------------------------------
  -- Bit
  -----------------------------------------------------------------------------
  -- A bit holds 2 values ('0' or '1') which are transformed intp the character '0' or '1'.
  constant static_code_length_bit : positive := ceil_div(length_bit, basic_code_nb_values);

  function code_length_bit(data : bit := bit'left) return natural is
  begin
    return static_code_length_bit;
  end function;

  -----------------------------------------------------------------------------
  -- std_ulogic
  -----------------------------------------------------------------------------
  -- A std_ulogic holds 9 values which are translated into their equivalent character
  constant static_code_length_std_ulogic : positive := ceil_div(length_std_ulogic, basic_code_nb_values);

  function code_length_std_ulogic(data : std_ulogic := std_ulogic'left) return natural is
  begin
    return static_code_length_std_ulogic;
  end function;

  -----------------------------------------------------------------------------
  -- severity_level
  -----------------------------------------------------------------------------
  -- A value of the enumerated type severity_level is encoded
  -- using the position of the value into the enumerated type declaration.
  -- The position in encoded on 1 character
  constant static_code_length_severity_level : positive := ceil_div(length_severity_level, basic_code_nb_values);

  function code_length_severity_level(data : severity_level := severity_level'left) return natural is
  begin
    return static_code_length_severity_level;
  end function;

  -----------------------------------------------------------------------------
  -- file_open_kind
  -----------------------------------------------------------------------------
  -- A value of the enumerated type file_open_kind is encoded
  -- using the position of the value into the enumerated type declaration.
  -- The position in encoded on 1 character
  constant static_code_length_file_open_kind : positive := ceil_div(length_file_open_kind, basic_code_nb_values);

  function code_length_file_open_kind(data : file_open_kind := file_open_kind'left) return natural is
  begin
    return static_code_length_file_open_kind;
  end function;

  -----------------------------------------------------------------------------
  -- file_open_status
  -----------------------------------------------------------------------------
  -- A value of the enumerated type file_open_status is encoded
  -- using the position of the value into the enumerated type declaration.
  -- The position in encoded on 1 character
  constant static_code_length_file_open_status : positive := ceil_div(length_file_open_status, basic_code_nb_values);

  function code_length_file_open_status(data : file_open_status := file_open_status'left) return natural is
  begin
    return static_code_length_file_open_status;
  end function;

  -----------------------------------------------------------------------------
  -- Raw string
  -----------------------------------------------------------------------------
  -- A string can directly be stored into the encoded string
  -- We do not encode the range
  function code_length_raw_string(length : natural) return natural is
  begin
    return length;
  end function;

  function code_length_raw_string(data : string) return natural is
  begin
    return code_length_raw_string(data'length);
  end function;

  -----------------------------------------------------------------------------
  -- String
  -----------------------------------------------------------------------------
  -- bit_array are encoded inte string. The array of bits is divided into
  -- chunks of basic_code_length=8 bits (gives a number N between 0 and 255) which
  -- can be directly used to select the Nth character in the string type.
  -- We do not encode the range
  function code_length_raw_bit_array(length : natural) return natural is
  begin
    return ceil_div(length, basic_code_length);
  end function;

  function code_length_raw_bit_array(data : bit_array) return natural is
  begin
    return code_length_raw_bit_array(data'length);
  end function;

  -----------------------------------------------------------------------------
  -- std_ulogic_array
  -----------------------------------------------------------------------------
  -- std_ulogic_array are encoded into string. The array is divided into
  -- groups of 2 std_ulogic.
  -- One std_ulogic can represent length_std_ulogic=9 value: it needs bits_length_std_ulogic=4 bits to store it.
  -- In a character (basic_code_length=8 bits), we can store basic_code_length/bits_length_std_ulogic=2 std_ulogic elements.
  -- We do not encode the range
  constant bits_length_std_ulogic : positive := positive(ceil(log2(real(length_std_ulogic))));

  function code_length_raw_std_ulogic_array(length : natural) return natural is
  begin
    return ceil_div(length, basic_code_length / bits_length_std_ulogic);
  end function;

  function code_length_raw_std_ulogic_array(data : std_ulogic_array) return natural is
  begin
    return code_length_raw_std_ulogic_array(data'length);
  end function;

  -----------------------------------------------------------------------------
  -- Integer
  -----------------------------------------------------------------------------
  -- An integer is encoded as a 32 bits bit_array.
  -- Note: we do not encode the range into the encoded string
  constant static_code_length_integer : positive := code_length_raw_bit_array(simulator_integer_width);

  function code_length_integer(data : integer := integer'left) return natural is
  begin
    -- A string can directly be stored into the encoded string
    -- We do not encode the range
    return static_code_length_integer;
  end function;

  -----------------------------------------------------------------------------
  -- Integer range
  -----------------------------------------------------------------------------
  -- A range is constituted of:
  --  * two bounds:
  --     - a left bound (encoded as integer)
  --     - a right bound (encoded as integer)
  --  * ascending/descending attribute (encoded as boolean).
  -- Note that the range is also encoded when the range is null.
  constant static_code_length_integer_range : positive := 2 * code_length_integer + code_length_boolean;

  function code_length_integer_range return natural is
  begin
    return static_code_length_integer_range;
  end function;

  -----------------------------------------------------------------------------
  -- Real
  -----------------------------------------------------------------------------
  -- A 'real' is decomposed into:
  -- * a sign (encoded as boolean)
  -- * a mantisse (encoded as 2 integers)
  -- * an exponent (encoded as 1 integer)
  constant static_code_length_real : positive := code_length_boolean + 3 * code_length_integer;

  function code_length_real(data : real := real'left) return natural is
  begin
    return static_code_length_real;
  end function;

  -----------------------------------------------------------------------------
  -- Time
  -----------------------------------------------------------------------------
  -- A 'time' type is encoded TBC
  constant static_code_length_time : positive := ceil_div(simulator_time_width, basic_code_length);

  function code_length_time(data : time := time'left) return natural is
  begin
    return static_code_length_time;
  end function;

  -----------------------------------------------------------------------------
  -- Complex
  -----------------------------------------------------------------------------
  -- A 'complex' is decomposed into:
  -- * a real part (encoded as 1 integer)
  -- * an imaginary part (encoded as 1 integer)
  constant static_code_length_complex : positive := 2 * code_length_real;

  function code_length_complex(data : complex := MATH_CZERO) return natural is
  begin
    return static_code_length_complex;
  end function;

  -----------------------------------------------------------------------------
  -- Complex_polar
  -----------------------------------------------------------------------------
  -- A 'complex' is decomposed into:
  -- * a angle (encoded as 1 integer)
  -- * a length (encoded as 1 integer)
  constant static_code_length_complex_polar : positive := 2 * code_length_real;

  function code_length_complex_polar(data : complex_polar := (MAG => 0.0, ARG => 0.0)) return natural is
  begin
    return static_code_length_complex_polar;
  end function;

  -----------------------------------------------------------------------------
  -- String
  -----------------------------------------------------------------------------
  -- A string can directly be stored into the encoded string
  -- We also encode the range
  function code_length_string(length : natural) return natural is
  begin
    return code_length_integer_range + code_length_raw_string(length);
  end function;

  function code_length_string(data : string) return natural is
  begin
    return code_length_string(data'length);
  end function;

  -----------------------------------------------------------------------------
  -- bit_array
  -----------------------------------------------------------------------------
  -- We also encode the range along side the raw_bit_array
  function code_length_bit_array(length : natural) return natural is
  begin
    return code_length_integer_range + code_length_raw_bit_array(length);
  end function;

  function code_length_bit_array(data : bit_array) return natural is
  begin
    return code_length_bit_array(data'length);
  end function;

  -----------------------------------------------------------------------------
  -- bit_vector
  -----------------------------------------------------------------------------
  -- We cast the bit_vector into a bit_array to encode it
  function code_length_bit_vector(length : natural) return natural is
  begin
    return code_length_bit_array(length);
  end function;

  function code_length_bit_vector(data : bit_vector) return natural is
  begin
    return code_length_bit_vector(data'length);
  end function;

  -----------------------------------------------------------------------------
  -- ieee.numeric_bit.unsigned
  -----------------------------------------------------------------------------
  -- We cast the ieee.numeric_bit.unsigned into a bit_array to encode it
  function code_length_numeric_bit_unsigned(length : natural) return natural is
  begin
    return code_length_bit_array(length);
  end function;

  function code_length_numeric_bit_unsigned(data : ieee.numeric_bit.unsigned) return natural is
  begin
    return code_length_numeric_bit_unsigned(data'length);
  end function;

  -----------------------------------------------------------------------------
  -- ieee.numeric_bit.signed
  -----------------------------------------------------------------------------
  -- We cast the ieee.numeric_bit.signed into a bit_array to encode it
  function code_length_numeric_bit_signed(length : natural) return natural is
  begin
    return code_length_bit_array(length);
  end function;

  function code_length_numeric_bit_signed(data : ieee.numeric_bit.signed) return natural is
  begin
    return code_length_numeric_bit_signed(data'length);
  end function;

  -----------------------------------------------------------------------------
  -- std_ulogic_array
  -----------------------------------------------------------------------------
  -- We also encode the range along side the raw_bit_array
  function code_length_std_ulogic_array(length : natural) return natural is
  begin
    return code_length_integer_range + code_length_raw_std_ulogic_array(length);
  end function;

  function code_length_std_ulogic_array(data : std_ulogic_array) return natural is
  begin
    return code_length_std_ulogic_array(data'length);
  end function;

  -----------------------------------------------------------------------------
  -- std_ulogic_vector
  -----------------------------------------------------------------------------
  -- We cast the std_ulogic_vector into a bit_array to encode it
  function code_length_std_ulogic_vector(length : natural) return natural is
  begin
    return code_length_std_ulogic_array(length);
  end function;

  function code_length_std_ulogic_vector(data : std_ulogic_vector) return natural is
  begin
    return code_length_std_ulogic_vector(data'length);
  end function;

  -----------------------------------------------------------------------------
  -- ieee.numeric_std.unresolved_unsigned
  -----------------------------------------------------------------------------
  -- We cast the ieee.numeric_std.unresolved_unsigned into a bit_array to encode it
  function code_length_numeric_std_unsigned(length : natural) return natural is
  begin
    return code_length_std_ulogic_array(length);
  end function;

  function code_length_numeric_std_unsigned(data : ieee.numeric_std.unresolved_unsigned) return natural is
  begin
    return code_length_numeric_std_unsigned(data'length);
  end function;

  -----------------------------------------------------------------------------
  -- ieee.numeric_std.unresolved_signed
  -----------------------------------------------------------------------------
  -- We cast the ieee.numeric_std.unresolved_signed into a bit_array to encode it
  function code_length_numeric_std_signed(length : natural) return natural is
  begin
    return code_length_std_ulogic_array(length);
  end function;

  function code_length_numeric_std_signed(data : ieee.numeric_std.unresolved_signed) return natural is
  begin
    return code_length_numeric_std_signed(data'length);
  end function;



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

end package body;
