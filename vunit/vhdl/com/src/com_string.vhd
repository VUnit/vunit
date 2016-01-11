-- The com string package provides to_string functions for data types supported
-- by the com codec package that don't have a standard to_string function defined.
-- These functions are also used as the encode function when the debug codecs
-- are used. In some cases the standard to_string function isn't used by the
-- debug encoder. For example, arrays like std_ulogic_vector are encoded along with
-- their ranges such that this property is unchanged by the transfer. In these
-- cases there is a to_detailed_string available in this package.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com
library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use std.textio.all;

use work.com_debug_codec_builder_pkg.all;

package com_string_pkg is
  function to_detailed_string (
    constant data : real)
    return string;
  function to_detailed_string (
    constant data : string)
    return string;
  alias to_string is to_detailed_string[string return string];
  function to_detailed_string (
    constant data : boolean_vector)
    return string;
  alias to_string is to_detailed_string[boolean_vector return string];
  function to_detailed_string (
    constant data : bit_vector)
    return string;
  function to_detailed_string (
    constant data : integer_vector)
    return string;
  alias to_string is to_detailed_string[integer_vector return string];
  function to_detailed_string (
    constant data : real_vector)
    return string;
  alias to_string is to_detailed_string[real_vector return string];
  function to_detailed_string (
    constant data : time_vector)
    return string;
  alias to_string is to_detailed_string[time_vector return string];
  function to_detailed_string (
    constant data : std_ulogic_vector)
    return string;
  function to_string (
    constant data : complex)
    return string;
  function to_string (
    constant data : complex_polar)
    return string;
  function to_detailed_string (
    constant data : ieee.numeric_bit.unsigned)
    return string;
  function to_detailed_string (
    constant data : ieee.numeric_bit.signed)
    return string;
  function to_detailed_string (
    constant data : ieee.numeric_std.unsigned)
    return string;
  function to_detailed_string (
    constant data : ieee.numeric_std.signed)
    return string;
  function to_detailed_string (
    constant data : ufixed)
    return string;
  function to_detailed_string (
    constant data : sfixed)
    return string;
  function to_detailed_string (
    constant data : float)
    return string;
end package com_string_pkg;

package body com_string_pkg is
  function to_detailed_string (
    constant data : real)
    return string is
    variable f64 : float64;
  begin
    return to_string(to_float(data, f64));
  end;

  function to_detailed_string (
    constant data : string)
    return string is
  begin
    -- Modelsim sets data'right to 0 which is out of the positive index range used by
    -- strings. This becomes a problem in the decoder which tries to maintain range
    if (data'left = 1) and (data'right = 0) then
      return create_array_group("", "2", "1", true);
    else
      return create_array_group(escape_special_characters(data), to_string(data'left), to_string(data'right), data'ascending);
    end if;
  end;

  function to_detailed_string (
    constant data : boolean_vector)
    return string is
    variable element : string(1 to 2 + data'length * 6);
    variable l       : line;
    variable length  : natural;
  begin
    open_group(l);
    for i in data'range loop
      append_group(l, to_string(data(i)));
    end loop;
    close_group(l, element, length);

    return create_array_group(element(1 to length), to_string(data'left), to_string(data'right), data'ascending);
  end;

  function to_detailed_string (
    constant data : bit_vector)
    return string is
  begin
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), "1", "0", true);
    else
      return create_array_group(to_string(data), to_string(data'left), to_string(data'right), data'ascending);
    end if;
  end;

  function to_detailed_string (
    constant data : integer_vector)
    return string is
    variable element : string(1 to 2 + data'length * 12);
    variable l       : line;
    variable length  : natural;
  begin
    open_group(l);
    for i in data'range loop
      append_group(l, to_string(data(i)));
    end loop;
    close_group(l, element, length);

    return create_array_group(element(1 to length), to_string(data'left), to_string(data'right), data'ascending);
  end;

  function to_detailed_string (
    constant data : real_vector)
    return string is
    variable element : string(1 to 2 + data'length * 67);
    variable l       : line;
    variable length  : natural;
  begin
    open_group(l);
    for i in data'range loop
      append_group(l, to_detailed_string(data(i)));
    end loop;
    close_group(l, element, length);

    return create_array_group(element(1 to length), to_string(data'left), to_string(data'right), data'ascending);
  end;

  function to_detailed_string (
    constant data : time_vector)
    return string is
    variable element : string(1 to 2 + data'length * 67);
    variable l       : line;
    variable length  : natural;
  begin
    open_group(l);
    for i in data'range loop
      append_group(l, to_string(data(i)));
    end loop;
    close_group(l, element, length);

    return create_array_group(element(1 to length), to_string(data'left), to_string(data'right), data'ascending);
  end;

  function to_detailed_string (
    constant data : std_ulogic_vector)
    return string is
  begin
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), "1", "0", true);
    else
      return create_array_group(to_string(data), to_string(data'left), to_string(data'right), data'ascending);
    end if;
  end;

  function to_string (
    constant data : complex)
    return string is
  begin
    return create_group(2, to_detailed_string(data.re), to_detailed_string(data.im));
  end;

  function to_string (
    constant data : complex_polar)
    return string is
  begin
    return create_group(2, to_detailed_string(data.mag), to_detailed_string(data.arg));
  end;

  function to_detailed_string (
    constant data : ieee.numeric_bit.unsigned)
    return string is
  begin
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), "1", "0", true);
    else
      return create_array_group(to_string(data), to_string(data'left), to_string(data'right), data'ascending);
    end if;
  end;

  function to_detailed_string (
    constant data : ieee.numeric_bit.signed)
    return string is
  begin
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), "1", "0", true);
    else
      return create_array_group(to_string(data), to_string(data'left), to_string(data'right), data'ascending);
    end if;
  end;

  function to_detailed_string (
    constant data : ieee.numeric_std.unsigned)
    return string is
  begin
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), "1", "0", true);
    else
      return create_array_group(to_string(data), to_string(data'left), to_string(data'right), data'ascending);
    end if;
  end;

  function to_detailed_string (
    constant data : ieee.numeric_std.signed)
    return string is
  begin
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), "1", "0", true);
    else
      return create_array_group(to_string(data), to_string(data'left), to_string(data'right), data'ascending);
    end if;
  end;

  function to_detailed_string (
    constant data : ufixed)
    return string is
    variable unsigned_data : ieee.numeric_std.unsigned(data'length - 1 downto 0);
  begin
    for i in unsigned_data'range loop
      unsigned_data(i) := data(i + data'low);
    end loop;
    return create_array_group(to_string(unsigned_data), to_string(data'left), to_string(data'right), false);
  end;

  function to_detailed_string (
    constant data : sfixed)
    return string is
    variable unsigned_data : ieee.numeric_std.unsigned(data'length - 1 downto 0);
  begin
    for i in unsigned_data'range loop
      unsigned_data(i) := data(i + data'low);
    end loop;
    return create_array_group(to_string(unsigned_data), to_string(data'left), to_string(data'right), false);
  end;

  function to_detailed_string (
    constant data : float)
    return string is
    variable unsigned_data : ieee.numeric_std.unsigned(data'length - 1 downto 0);
  begin
    for i in unsigned_data'range loop
      unsigned_data(i) := data(i + data'low);
    end loop;
    return create_array_group(to_string(unsigned_data), to_string(data'left), to_string(data'right), false);
  end;

end package body com_string_pkg;
