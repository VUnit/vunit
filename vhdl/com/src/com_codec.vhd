-- Com codec package provides codec functions for basic types
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

use work.com_std_codec_builder_pkg.all;
use work.com_debug_codec_builder_pkg.all;

package body com_codec_pkg is
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
    variable f64 : float64;
  begin
    return to_byte_array(to_bv(to_slv(to_float(data, f64))));
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

  function encode (
    constant data : time)
    return string is

    constant resolution  : time := std.env.resolution_limit;

    function modulo(t : time; m : natural) return integer is
    begin
      return (integer((t - (t/m)*m)/resolution) mod m);
    end function;

    variable ret_val     : string(1 to 8);
    variable t           : time;
    variable ascii       : natural;
  begin
    -- @TODO assumes time is 8 bytes
    t           := data;
    for i in 8 downto 1 loop
      ascii := modulo(t, 256);
      ret_val(i) := character'val(ascii);
      t          := (t - (ascii * resolution))/256;
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
    variable length : natural;
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
    variable ret_val : string(get_range(code)'range) := (others => NUL);
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

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
    variable ret_val : boolean_vector(get_range(code)'range) := (others => false);
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
    variable ret_val : bit_vector(get_range(code)'range) := (others => '0');
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
    variable ret_val : integer_vector(get_range(code)'range) := (others => integer'left);
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

  function encode (
    constant data : real_vector)
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
    return real_vector is
    variable ret_val : real_vector(get_range(code)'range) := (others => real'left);
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
    variable ret_val : time_vector(get_range(code)'range) := (others => time'left);
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
    variable ret_val : std_ulogic_vector(get_range(code)'range) := (others => 'U');
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
    variable ret_val : ieee.numeric_bit.unsigned(get_range(code)'range) := (others => '0');
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
    variable ret_val : ieee.numeric_bit.signed(get_range(code)'range) := (others => '0');
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
    variable ret_val : ieee.numeric_std.unsigned(get_range(code)'range) := (others => 'U');
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
    variable ret_val : ieee.numeric_std.signed(get_range(code)'range) := (others => 'U');
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
    variable ret_val : ufixed(get_range(code)'range);
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
    variable ret_val : sfixed(get_range(code)'range);
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
    variable ret_val : float(get_range(code)'range);
    variable index   : positive := code'left;
  begin
    decode(code, index, ret_val);

    return ret_val;
  end;

end package body com_codec_pkg;
