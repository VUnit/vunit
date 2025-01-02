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
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use std.textio.all;

package codec_2008p_pkg is
  -----------------------------------------------------------------------------
  -- Predefined composite types
  -----------------------------------------------------------------------------
  function encode (
    constant data : boolean_vector)
    return string;
  function decode (
    constant code : string)
    return boolean_vector;
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
  alias encode_boolean_vector is encode[boolean_vector return string];
  alias decode_boolean_vector is decode[string return boolean_vector];
  alias encode_integer_vector is encode[integer_vector return string];
  alias decode_integer_vector is decode[string return integer_vector];
  alias encode_real_vector is encode[real_vector return string];
  alias decode_real_vector is decode[string return real_vector];
  alias encode_time_vector is encode[time_vector return string];
  alias decode_time_vector is decode[string return time_vector];
  alias encode_ufixed is encode[ufixed return string];
  alias decode_ufixed is decode[string return ufixed];
  alias encode_sfixed is encode[sfixed return string];
  alias decode_sfixed is decode[string return sfixed];
  alias encode_float is encode[float return string];
  alias decode_float is decode[string return float];

end package;

use work.codec_pkg.all;
use work.codec_builder_pkg.all;
use work.codec_builder_2008p_pkg.all;

package body codec_2008p_pkg is
  -----------------------------------------------------------------------------
  -- Predefined composite types
  -----------------------------------------------------------------------------
  function encode (
    constant data : boolean_vector)
    return string is
    variable data_bv : bit_vector(data'range);
  begin
    for i in data'range loop
      if data(i) then
        data_bv(i) := '1';
      else
        data_bv(i) := '0';
      end if;
    end loop;

    return encode(data_bv);
  end;

  function decode (
    constant code : string)
    return boolean_vector is
    constant ret_range : range_t := get_range(code);
    variable ret_val : boolean_vector(ret_range'range) := (others => false);
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : integer_vector)
    return string is
    variable ret_val : string(1 to 9 + data'length*4);
    variable index   : positive := 10;
  begin
    ret_val(1 to 9) := encode_array_header(encode(data'left), encode(data'right), encode(data'ascending));
    for i in data'range loop
      ret_val(index to index + 3) := encode(data(i));
      index                       := index + 4;
    end loop;

    return ret_val;
  end;

  function decode (
    constant code : string)
    return integer_vector is
    constant ret_range : range_t := get_range(code);
    variable ret_val : integer_vector(ret_range'range) := (others => integer'left);
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : real_vector)
    return string is
    variable ret_val : string(1 to 9 + 13*data'length);
    variable index   : positive := 10;
  begin
    ret_val(1 to 9) := encode_array_header(encode(data'left), encode(data'right), encode(data'ascending));
    for i in data'range loop
      ret_val(index to index + 12) := encode(data(i));
      index                       := index + 13;
    end loop;

    return ret_val;
  end;

  function decode (
    constant code : string)
    return real_vector is
    constant ret_range : range_t := get_range(code);
    variable ret_val : real_vector(ret_range'range) := (others => real'left);
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : time_vector)
    return string is
    variable ret_val : string(1 to 9 + 8*data'length);
    variable index   : positive := 10;
  begin
    ret_val(1 to 9) := encode_array_header(encode(data'left), encode(data'right), encode(data'ascending));
    for i in data'range loop
      ret_val(index to index + 7) := encode(data(i));
      index                       := index + 8;
    end loop;

    return ret_val;
  end;

  function decode (
    constant code : string)
    return time_vector is
    constant ret_range : range_t := get_range(code);
    variable ret_val : time_vector(ret_range'range) := (others => time'left);
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : ufixed)
    return string is
  begin
    return encode(std_ulogic_array(data));
  end;

  function decode (
    constant code : string)
    return ufixed is
    constant ret_range : range_t := get_range(code);
    variable ret_val : ufixed(ret_range'range);
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : sfixed)
    return string is
  begin
    return encode(std_ulogic_array(data));
  end;

  function decode (
    constant code : string)
    return sfixed is
    constant ret_range : range_t := get_range(code);
    variable ret_val : sfixed(ret_range'range);
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : float)
    return string is
  begin
    return encode(std_ulogic_array(data));
  end;

  function decode (
    constant code : string)
    return float is
    constant ret_range : range_t := get_range(code);
    variable ret_val : float(ret_range'range);
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

end package body codec_2008p_pkg;
