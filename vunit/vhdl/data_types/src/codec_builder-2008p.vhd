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


package codec_builder_2008p_pkg is

  --===========================================================================
  -- API for the ADVANCED USERS
  --===========================================================================

  -----------------------------------------------------------------------------
  -- Encoding length for each types
  -----------------------------------------------------------------------------
  -- If you need to retrieve the length of the encoded data without
  -- encoding it, you can use these functions:

  -- These functions give you the length of the encoded array depending on the
  -- length of the array to encode
  function code_length_boolean_vector(length : natural) return natural;
  function code_length_integer_vector(length : natural) return natural;
  function code_length_real_vector(length : natural) return natural;
  function code_length_time_vector(length : natural) return natural;
  function code_length_ufixed(length : natural) return natural;
  function code_length_sfixed(length : natural) return natural;
  function code_length_float(length : natural) return natural;

  function code_length_boolean_vector(data : boolean_vector) return natural;
  function code_length_integer_vector(data : integer_vector) return natural;
  function code_length_real_vector(data : real_vector) return natural;
  function code_length_time_vector(data : time_vector) return natural;
  function code_length_ufixed(data : ufixed) return natural;
  function code_length_sfixed(data : sfixed) return natural;
  function code_length_float(data : float) return natural;



  --===========================================================================
  -- API for the VUnit DEVELOPERS
  --===========================================================================

  procedure encode_boolean_vector(constant data : in boolean_vector; variable index : inout code_index_t; variable code : out code_t);
  procedure decode_boolean_vector(constant code : in code_t; variable index : inout code_index_t; variable result : out boolean_vector);
  alias encode is encode_boolean_vector[boolean_vector, code_index_t, code_t];
  alias decode is decode_boolean_vector[code_t, code_index_t, boolean_vector];

  procedure encode_integer_vector(constant data : in integer_vector; variable index : inout code_index_t; variable code : out code_t);
  procedure decode_integer_vector(constant code : in code_t; variable index : inout code_index_t; variable result : out integer_vector);
  alias encode is encode_integer_vector[integer_vector, code_index_t, code_t];
  alias decode is decode_integer_vector[code_t, code_index_t, integer_vector];

  procedure encode_real_vector(constant data : in real_vector; variable index : inout code_index_t; variable code : out code_t);
  procedure decode_real_vector(constant code : in code_t; variable index : inout code_index_t; variable result : out real_vector);
  alias encode is encode_real_vector[real_vector, code_index_t, code_t];
  alias decode is decode_real_vector[code_t, code_index_t, real_vector];

  procedure encode_time_vector(constant data : in time_vector; variable index : inout code_index_t; variable code : out code_t);
  procedure decode_time_vector(constant code : in code_t; variable index : inout code_index_t; variable result : out time_vector);
  alias encode is encode_time_vector[time_vector, code_index_t, code_t];
  alias decode is decode_time_vector[code_t, code_index_t, time_vector];

  procedure encode_ufixed(constant data : in unresolved_ufixed; variable index : inout code_index_t; variable code : out code_t);
  procedure decode_ufixed(constant code : in code_t; variable index : inout code_index_t; variable result : out unresolved_ufixed);
  alias encode is encode_ufixed[unresolved_ufixed, code_index_t, code_t];
  alias decode is decode_ufixed[code_t, code_index_t, unresolved_ufixed];

  procedure encode_sfixed(constant data : in unresolved_sfixed; variable index : inout code_index_t; variable code : out code_t);
  procedure decode_sfixed(constant code : in code_t; variable index : inout code_index_t; variable result : out unresolved_sfixed);
  alias encode is encode_sfixed[unresolved_sfixed, code_index_t, code_t];
  alias decode is decode_sfixed[code_t, code_index_t, unresolved_sfixed];

  procedure encode_float(constant data : in unresolved_float; variable index : inout code_index_t; variable code : out code_t);
  procedure decode_float(constant code : in code_t; variable index : inout code_index_t; variable result : out unresolved_float);
  alias encode is encode_float[unresolved_float, code_index_t, code_t];
  alias decode is decode_float[code_t, code_index_t, unresolved_float];

end package;

package body codec_builder_2008p_pkg is
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

end package body codec_builder_2008p_pkg;
