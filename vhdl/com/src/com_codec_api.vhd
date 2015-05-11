-- Com codec API package provides the common API for all
-- implementations of the com codec functionality (VHDL 2002+ and VHDL 1993)
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

package com_codec_pkg is
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
    constant data : boolean_vector)
    return string;
  function decode (
    constant code : string)
    return boolean_vector;
  function encode (
    constant data : bit_vector)
    return string;
  function decode (
    constant code : string)
    return bit_vector;
  function encode (
    constant data : integer_vector)
    return string;
  function decode (
    constant code : string)
    return integer_vector;
  function encode (
    constant data : real_vector)
    return string;
  function decode (
    constant code : string)
    return real_vector;
  function encode (
    constant data : time_vector)
    return string;
  function decode (
    constant code : string)
    return time_vector;
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
  function encode (
    constant data : ufixed)
    return string;
  function decode (
    constant code : string)
    return ufixed;
  function encode (
    constant data : sfixed)
    return string;
  function decode (
    constant code : string)
    return sfixed;
  function encode (
    constant data : float)
    return string;
  function decode (
    constant code : string)
    return float;

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
  alias encode_boolean_vector is encode[boolean_vector return string];
  alias decode_boolean_vector is decode[string return boolean_vector];
  alias encode_bit_vector is encode[bit_vector return string];
  alias decode_bit_vector is decode[string return bit_vector];
  alias encode_integer_vector is encode[integer_vector return string];
  alias decode_integer_vector is decode[string return integer_vector];
  alias encode_real_vector is encode[real_vector return string];
  alias decode_real_vector is decode[string return real_vector];
  alias encode_time_vector is encode[time_vector return string];
  alias decode_time_vector is decode[string return time_vector];
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
  alias encode_ufixed is encode[ufixed return string];
  alias decode_ufixed is decode[string return ufixed];
  alias encode_sfixed is encode[sfixed return string];
  alias decode_sfixed is decode[string return sfixed];
  alias encode_float is encode[float return string];
  alias decode_float is decode[string return float];

  -----------------------------------------------------------------------------
  -- Support
  -----------------------------------------------------------------------------
  type range_t is array (integer range <>) of bit;

  function get_range (
    constant code : string)
    return range_t;

end package;
