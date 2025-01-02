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
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use std.textio.all;

use work.codec_builder_pkg.all;

package codec_builder_2008p_pkg is
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   boolean_vector);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   integer_vector);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   real_vector);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   time_vector);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   ufixed);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   sfixed);
  procedure decode (
    constant code   :       string;
    variable index  : inout positive;
    variable result : out   float);
end package codec_builder_2008p_pkg;

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
