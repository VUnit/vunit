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
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

library work;
use work.codec_builder_pkg.all;


package codec_2008p_pkg is

  -- This package extends the codec_pkg to support the types
  -- introduced by the VHDL-2008 revision.
  -- The main documentation of the coded functionnality are located
  -- on the codec_pkg.vhd file.


  --===========================================================================
  -- API for the CASUAL USERS
  --===========================================================================

  function encode_boolean_vector(data : boolean_vector) return code_t;
  function decode_boolean_vector(code : string) return boolean_vector;
  alias encode is encode_boolean_vector[boolean_vector return code_t];
  alias decode is decode_boolean_vector[string return boolean_vector];

  function encode_integer_vector(data : integer_vector) return code_t;
  function decode_integer_vector(code : string) return integer_vector;
  alias encode is encode_integer_vector[integer_vector return code_t];
  alias decode is decode_integer_vector[string return integer_vector];

  function encode_real_vector(data : real_vector) return code_t;
  function decode_real_vector(code : string) return real_vector;
  alias encode is encode_real_vector[real_vector return code_t];
  alias decode is decode_real_vector[string return real_vector];

  function encode_time_vector(data : time_vector) return code_t;
  function decode_time_vector(code : string) return time_vector;
  alias encode is encode_time_vector[time_vector return code_t];
  alias decode is decode_time_vector[string return time_vector];

  function encode_ufixed(data : unresolved_ufixed) return code_t;
  function decode_ufixed(code : string) return unresolved_ufixed;
  alias encode is encode_ufixed[unresolved_ufixed return code_t];
  alias decode is decode_ufixed[string return unresolved_ufixed];

  function encode_sfixed(data : unresolved_sfixed) return code_t;
  function decode_sfixed(code : string) return unresolved_sfixed;
  alias encode is encode_sfixed[unresolved_sfixed return code_t];
  alias decode is decode_sfixed[string return unresolved_sfixed];

  function encode_float(data : unresolved_float) return code_t;
  function decode_float(code : string) return unresolved_float;
  alias encode is encode_float[unresolved_float return code_t];
  alias decode is decode_float[string return unresolved_float];

end package;


use work.codec_pkg.all;
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
