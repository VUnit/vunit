-- Com codec package provides codec functions for basic types
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

use work.com_string_pkg.all;
use work.com_debug_codec_builder_pkg.all;

package body com_codec_pkg is
  -----------------------------------------------------------------------------
  -- Predefined scalar types
  -----------------------------------------------------------------------------
  function encode (
    constant data : integer)
    return string is
  begin
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return integer is
  begin
    return integer'value(code);
  end;

  function encode (
    constant data : real)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return real is
    variable f64 : float64;
  begin
    return to_real(from_string(code, f64));
  end;

  function encode (
    constant data : time)
    return string is
  begin
    -- Modelsim has a 64-bit integer representation of time
    -- with the unit = resolution time. According to standard.
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return time is
    function find_space (
      constant code : string)
      return natural is
    begin
      for i in code'range loop
        if code(i) = ' ' then
          return i;
        end if;
      end loop;

      return 0;
    end function find_space;
    variable code_i            : string(1 to code'length) := code;
    variable space_pos         : natural                  := find_space(code_i);
    variable resolution        : time;
    variable t, t_part         : time                     := 0 ns;
    variable l, r, sign_offset : integer;
    variable is_negative : boolean;
  begin
    -- Modelsim can't parse a string representation of time
    -- with a numerical value outside of the integer range (32 bits).
    -- According to standard?
    resolution := time'value("1 " & code_i(space_pos + 1 to code_i'length));
    is_negative := code_i(1) = '-';
    l := space_pos - 9;
    r := space_pos - 1;
    if code_i(1) = '-' then
      sign_offset := 1;
    else
      sign_offset := 0;
    end if;

    for i in 0 to (space_pos - 2 - sign_offset)/9 loop
      if i = (space_pos - 2 - sign_offset)/9 then
        l := 1 + sign_offset;
      end if;
      t_part := integer'value(code_i(l to r)) * resolution;
      for j in 1 to i loop
        t_part := t_part * 1e9;
      end loop;

      if is_negative then
        t := t - t_part;
      else
        t := t + t_part;
      end if;
      l := l - 9;
      r := r - 9;
    end loop;

    return t;
  end;

  function encode (
    constant data : boolean)
    return string is
  begin
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return boolean is
  begin
    return boolean'value(code);
  end;

  function encode (
    constant data : bit)
    return string is
  begin
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return bit is
  begin
    return bit'value("'" & code & "'");
  end;

  function encode (
    constant data : std_ulogic)
    return string is
  begin
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return std_ulogic is
  begin
    return std_ulogic'value("'" & code & "'");
  end;

  function encode (
    constant data : severity_level)
    return string is
  begin
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return severity_level is
  begin
    return severity_level'value(code);
  end;

  function encode (
    constant data : file_open_status)
    return string is
  begin
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return file_open_status is
  begin
    return file_open_status'value(code);
  end;

  function encode (
    constant data : file_open_kind)
    return string is
  begin
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return file_open_kind is
  begin
    return file_open_kind'value(code);
  end;

  function encode (
    constant data : character)
    return string is
  begin
    return escape_special_characters(character'image(data));
  end;

  function decode (
    constant code : string)
    return character is
    variable chars : string(1 to 2);
  begin
    -- @TODO Use just character'value when Aldec issue SPT72992 has been solved
    chars := unescape_special_characters(code)(1 to 2);
    if chars(1) = ''' then
      return chars(2);
    else
      return character'value(unescape_special_characters(code));
    end if;
  end;

  -----------------------------------------------------------------------------
  -- Predefined composite types
  -----------------------------------------------------------------------------
  function get_range (
    constant code : string)
    return range_t is
    constant range_left         : natural := decode(get_element(code, 1));
    constant range_right        : natural := decode(get_element(code, 2));
    constant is_ascending       : boolean := decode(get_element(code, 3));
    variable ret_val_ascending  : range_t(range_left to range_right);
    variable ret_val_descending : range_t(range_left downto range_right);
  begin
    if is_ascending then
      return ret_val_ascending;
    else
      return ret_val_descending;
    end if;
  end function get_range;

  function encode (
    constant data : string)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return string is
    variable ret_val : string(get_range(code)'range) := (others => NUL);
  begin
    if get_first_element(code) /= "" then
        ret_val := unescape_special_characters(get_first_element(code));
      end if;

    return ret_val;
  end;

  function encode (
    constant data : boolean_vector)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return boolean_vector is
    variable ret_val  : boolean_vector(get_range(code)'range) := (others => false);
    variable elements : lines_t;
    variable length   : natural;
    variable index    : natural := 0;
  begin
    split_group(get_first_element(code), elements, ret_val'length, length);
    for i in ret_val'range loop
      ret_val(i) := decode(elements.all(index).all);
      index      := index + 1;
    end loop;
    deallocate_elements(elements);

    return ret_val;
  end;

  function encode (
    constant data : bit_vector)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return bit_vector is
    variable ret_val : bit_vector(get_range(code)'range) := (others => '0');
    variable l       : line;
    variable index   : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := bit'value("'" & l.all(index to index) & "'");
      index      := index + 1;
    end loop;

    deallocate(l);

    return ret_val;
  end;

  function encode (
    constant data : integer_vector)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return integer_vector is
    variable ret_val  : integer_vector(get_range(code)'range) := (others => integer'left);
    variable elements : lines_t;
    variable length   : natural;
    variable index    : natural := 0;
  begin
    split_group(get_first_element(code), elements, ret_val'length, length);
    for i in ret_val'range loop
      ret_val(i) := decode(elements.all(index).all);
      index      := index + 1;
    end loop;
    deallocate_elements(elements);

    return ret_val;
  end;

  function encode (
    constant data : real_vector)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return real_vector is
    variable ret_val  : real_vector(get_range(code)'range) := (others => real'left);
    variable elements : lines_t;
    variable length   : natural;
    variable index    : natural := 0;
  begin
    split_group(get_first_element(code), elements, ret_val'length, length);
    for i in ret_val'range loop
      ret_val(i) := decode(elements.all(index).all);
      index      := index + 1;
    end loop;
    deallocate_elements(elements);

    return ret_val;
  end;

  function encode (
    constant data : time_vector)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return time_vector is
    variable ret_val  : time_vector(get_range(code)'range) := (others => time'left);
    variable elements : lines_t;
    variable length   : natural;
    variable index    : natural := 0;
  begin
    split_group(get_first_element(code), elements, ret_val'length, length);
    for i in ret_val'range loop
      ret_val(i) := decode(elements.all(index).all);
      index      := index + 1;
    end loop;
    deallocate_elements(elements);

    return ret_val;
  end;

  function encode (
    constant data : std_ulogic_vector)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return std_ulogic_vector is
    variable ret_val : std_ulogic_vector(get_range(code)'range) := (others => 'U');
    variable l       : line;
    variable index   : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := std_ulogic'value("'" & l.all(index to index) & "'");
      index      := index + 1;
    end loop;

    deallocate(l);

    return ret_val;
  end;

  function encode (
    constant data : complex)
    return string is
  begin
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return complex is
    variable ret_val  : complex;
    variable elements : lines_t;
    variable length   : natural;
  begin
    split_group(code, elements, 2, length);
    ret_val.re := decode(elements.all(0).all);
    ret_val.im := decode(elements.all(1).all);
    deallocate_elements(elements);

    return ret_val;
  end;

  function encode (
    constant data : complex_polar)
    return string is
  begin
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return complex_polar is
    variable ret_val  : complex_polar;
    variable elements : lines_t;
    variable length   : natural;
  begin
    split_group(code, elements, 2, length);
    ret_val.mag := decode(elements.all(0).all);
    ret_val.arg := decode(elements.all(1).all);
    deallocate_elements(elements);

    return ret_val;
  end;

  function encode (
    constant data : ieee.numeric_bit.unsigned)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return ieee.numeric_bit.unsigned is
    variable ret_val : ieee.numeric_bit.unsigned(get_range(code)'range) := (others => '0');
    variable l       : line;
    variable index   : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := bit'value("'" & l.all(index to index) & "'");
      index      := index + 1;
    end loop;

    deallocate(l);

    return ret_val;
  end;

  function encode (
    constant data : ieee.numeric_bit.signed)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return ieee.numeric_bit.signed is
    variable ret_val : ieee.numeric_bit.signed(get_range(code)'range) := (others => '0');
    variable l       : line;
    variable length  : natural;
    variable index   : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := bit'value("'" & l.all(index to index) & "'");
      index      := index + 1;
    end loop;

    deallocate(l);

    return ret_val;
  end;

  function encode (
    constant data : ieee.numeric_std.unsigned)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return ieee.numeric_std.unsigned is
    variable ret_val : ieee.numeric_std.unsigned(get_range(code)'range) := (others => 'U');
    variable l       : line;
    variable index   : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := std_logic'value("'" & l.all(index to index) & "'");
      index      := index + 1;
    end loop;

    deallocate(l);

    return ret_val;
  end;

  function encode (
    constant data : ieee.numeric_std.signed)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return ieee.numeric_std.signed is
    variable ret_val : ieee.numeric_std.signed(get_range(code)'range) := (others => 'U');
    variable l       : line;
    variable index   : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := std_logic'value("'" & l.all(index to index) & "'");
      index      := index + 1;
    end loop;

    deallocate(l);

    return ret_val;
  end;

  function encode (
    constant data : ufixed)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return ufixed is
    variable ret_val : ufixed(decode(get_element(code, 1)) downto decode(get_element(code, 2)));
    variable l       : line;
    variable index   : natural := 1;
  begin
    write(l, get_first_element(code));

    for i in ret_val'range loop
      ret_val(i) := std_ulogic'value("'" & l.all(index to index) & "'");
      index      := index + 1;
    end loop;

    deallocate(l);

    return ret_val;
  end;

  function encode (
    constant data : sfixed)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return sfixed is
    variable ret_val : sfixed(decode(get_element(code, 1)) downto decode(get_element(code, 2)));
    variable l       : line;
    variable index   : natural := 1;
  begin
    write(l, get_first_element(code));

    for i in ret_val'range loop
      ret_val(i) := std_ulogic'value("'" & l.all(index to index) & "'");
      index      := index + 1;
    end loop;

    deallocate(l);

    return ret_val;
  end;

  function encode (
    constant data : float)
    return string is
  begin
    return to_detailed_string(data);
  end;

  function decode (
    constant code : string)
    return float is
    variable ret_val : float(decode(get_element(code, 1)) downto decode(get_element(code, 2)));
    variable l       : line;
    variable index   : natural := 1;
  begin
    write(l, get_first_element(code));

    for i in ret_val'range loop
      ret_val(i) := std_ulogic'value("'" & l.all(index to index) & "'");
      index      := index + 1;
    end loop;

    deallocate(l);

    return ret_val;
  end;

end package body com_codec_pkg;
