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
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

library work;
use work.codec_builder_pkg.all;


package codec_2008p_pkg is

  -- This package extends the codec_pkg to support the types
  -- introduced by the VHDL-2008 revision.
  -- The main documentation of the coded functionnality are located
  -- in the codec_pkg.vhd file.


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

  --===========================================================================
  -- Encode functions of new predefined types from VHDL 2008
  --===========================================================================

  function encode_boolean_vector(data : boolean_vector) return code_t is
    variable ret_val : code_t(1 to code_length_boolean_vector(data'length));
    variable index : code_index_t := ret_val'left;
  begin
    encode_boolean_vector(data, index, ret_val);
    return ret_val;
  end function;

  function encode_integer_vector(data : integer_vector) return code_t is
    variable ret_val : code_t(1 to code_length_integer_vector(data'length));
    variable index : code_index_t := ret_val'left;
  begin
    encode_integer_vector(data, index, ret_val);
    return ret_val;
  end function;

  function encode_real_vector(data : real_vector) return code_t is
    variable ret_val : code_t(1 to code_length_real_vector(data'length));
    variable index : code_index_t := ret_val'left;
  begin
    encode_real_vector(data, index, ret_val);
    return ret_val;
  end function;

  function encode_time_vector(data : time_vector) return code_t is
    variable ret_val : code_t(1 to code_length_time_vector(data'length));
    variable index : code_index_t := ret_val'left;
  begin
    encode_time_vector(data, index, ret_val);
    return ret_val;
  end function;

  function encode_ufixed(data : unresolved_ufixed) return code_t is
    variable ret_val : code_t(1 to code_length_ufixed(data'length));
    variable index : code_index_t := ret_val'left;
  begin
    encode_ufixed(data, index, ret_val);
    return ret_val;
  end function;

  function encode_sfixed(data : unresolved_sfixed) return code_t is
    variable ret_val : code_t(1 to code_length_sfixed(data'length));
    variable index : code_index_t := ret_val'left;
  begin
    encode_sfixed(data, index, ret_val);
    return ret_val;
  end function;

  function encode_float(data : unresolved_float) return code_t is
    variable ret_val : code_t(1 to code_length_float(data'length));
    variable index : code_index_t := ret_val'left;
  begin
    encode_float(data, index, ret_val);
    return ret_val;
  end function;


  --===========================================================================
  -- Decode functions of new predefined types from VHDL 2008
  --===========================================================================

  function decode_boolean_vector(code : code_t) return boolean_vector is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : boolean_vector(ret_range'range);
    variable index : code_index_t := code'left;
  begin
    decode_boolean_vector(code, index, ret_val);
    return ret_val;
  end function;

  function decode_integer_vector(code : code_t) return integer_vector is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : integer_vector(ret_range'range);
    variable index : code_index_t := code'left;
  begin
    decode_integer_vector(code, index, ret_val);
    return ret_val;
  end function;

  function decode_real_vector(code : code_t) return real_vector is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : real_vector(ret_range'range);
    variable index : code_index_t := code'left;
  begin
    decode_real_vector(code, index, ret_val);
    return ret_val;
  end function;

  function decode_time_vector(code : code_t) return time_vector is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : time_vector(ret_range'range);
    variable index : code_index_t := code'left;
  begin
    decode_time_vector(code, index, ret_val);
    return ret_val;
  end function;

  function decode_ufixed(code : code_t) return unresolved_ufixed is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : unresolved_ufixed(ret_range'range);
    variable index : code_index_t := code'left;
  begin
    decode_ufixed(code, index, ret_val);
    return ret_val;
  end function;

  function decode_sfixed(code : code_t) return unresolved_sfixed is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : unresolved_sfixed(ret_range'range);
    variable index : code_index_t := code'left;
  begin
    decode_sfixed(code, index, ret_val);
    return ret_val;
  end function;

  function decode_float(code : code_t) return unresolved_float is
    constant ret_range : range_t := decode_range(code);
    variable ret_val : unresolved_float(ret_range'range);
    variable index : code_index_t := code'left;
  begin
    decode_float(code, index, ret_val);
    return ret_val;
  end function;

end package body;
