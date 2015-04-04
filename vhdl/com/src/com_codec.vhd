-- Com codec package provides codec functions for basic types
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

package body com_codec_pkg is
  -----------------------------------------------------------------------------
  -- Predefined scalar types
  -----------------------------------------------------------------------------
  function encode (
    constant data : integer)
    return string is
  begin
    return integer'image(data);
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
    variable f64 : float64;
  begin
    return to_string(to_float(data, f64));
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
    return time'image(data);
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
    variable code_i : string(1 to code'length) := code;
    variable space_pos : natural := find_space(code_i);
    variable resolution : time;
    variable t, t_part : time := 0 ns;
    variable l, r, sign_offset : integer;
  begin
    -- Modelsim can't parse a string representation of time
    -- with a numerical value outside of the integer range (32 bits).
    -- According to standard?
    resolution := time'value("1 " & code_i(space_pos + 1 to code_i'length));

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

      t := t + t_part;
      l := l - 9;
      r := r - 9;
    end loop;

    if code_i(1) = '-' then
      t := -t;
    end if;

    return t;
  end;
  
  function encode (
    constant data : boolean)
    return string is
  begin
    return boolean'image(data);
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
    return bit'image(data);
  end;
  
  function decode (
    constant code : string)
    return bit is
  begin
    return bit'value(code);
  end;
  
  function encode (
    constant data : std_ulogic)
    return string is
  begin
    return std_ulogic'image(data);
  end;
  
  function decode (
    constant code : string)
    return std_ulogic is
  begin
    return std_ulogic'value(code);
  end;
  
  function encode (
    constant data : severity_level)
    return string is
  begin
    return severity_level'image(data);
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
    return file_open_status'image(data);
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
    return file_open_kind'image(data);
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
  begin
    return character'value(unescape_special_characters(code));
  end;

  -----------------------------------------------------------------------------
  -- Predefined composite types
  -----------------------------------------------------------------------------
  function encode (
    constant data : string)
    return string is
    variable length : natural;
    variable escaped_data : string(1 to data'length*6);
  begin
    -- Modelsim sets data'right to 0 which is out of the positive index range used by
    -- strings. This becomes a problem in the decoder which tries to maintain range
    if (data'left = 1) and (data'right = 0) then
      return create_array_group("", encode(2), encode(1), true);
    else
      length := escape_special_characters(data)'length;
      escaped_data(1 to length) := escape_special_characters(data);
      return create_array_group(escaped_data(1 to length), encode(data'left), encode(data'right), data'ascending);
    end if;
  end;

  function decode (
    constant code : string)
    return string is
    function ret_val_range (
      constant code : string)
      return string is
      constant range_left : positive := decode(get_element(code,1));
      constant range_right : positive := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));
      variable ret_val_ascending : string(range_left to range_right);
      variable ret_val_descending : string(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : string(ret_val_range(code)'range);
  begin
    if get_first_element(code) /= "" then
      ret_val := unescape_special_characters(get_first_element(code));
    end if;
    
    return ret_val;
  end;

  function encode (
    constant data : boolean_vector)
    return string is
    variable element : string(1 to 2 + data'length * 6);
    variable l : line;
    variable length : natural;
  begin
    open_group(l);
    for i in data'range loop
      append_group(l, encode(data(i)));
    end loop;
    close_group(l, element, length);

    return create_array_group(element(1 to length), encode(data'left), encode(data'right), data'ascending);
  end;

  function decode (
    constant code : string)
    return boolean_vector is
    function ret_val_range (
      constant code : string)
      return boolean_vector is
      constant range_left : natural := decode(get_element(code,1));
      constant range_right : natural := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));
      variable ret_val_ascending : boolean_vector(range_left to range_right);
      variable ret_val_descending : boolean_vector(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : boolean_vector(ret_val_range(code)'range);
    variable elements : lines_t;
    variable length : natural;
    variable index : natural := 0;
  begin
    split_group(get_first_element(code), elements, ret_val'length, length);
    for i in ret_val'range loop
      ret_val(i) := decode(elements.all(index).all);
      index := index + 1;
    end loop;
    deallocate_elements(elements);
    
    return ret_val;
  end;

  function encode (
    constant data : bit_vector)
    return string is
  begin
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), encode(1), encode(0), true);
    else
      return create_array_group(to_string(data), encode(data'left), encode(data'right), data'ascending);
    end if;    
  end;

  function decode (
    constant code : string)
    return bit_vector is
    function ret_val_range (
      constant code : string)
      return bit_vector is
      constant range_left : natural := decode(get_element(code,1));
      constant range_right : natural := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));      
      variable ret_val_ascending : bit_vector(range_left to range_right);
      variable ret_val_descending : bit_vector(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : bit_vector(ret_val_range(code)'range);
    variable l : line;
    variable index : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := bit'value("'" & l.all(index to index) & "'");
      index := index + 1;
    end loop;
    
    deallocate(l);
    
    return ret_val;
  end;

  function encode (
    constant data : integer_vector)
    return string is
    variable element : string(1 to 2 + data'length * 11);
    variable l : line;
    variable length : natural;
  begin
    open_group(l);
    for i in data'range loop
      append_group(l, encode(data(i)));
    end loop;
    close_group(l, element, length);

    return create_array_group(element(1 to length), encode(data'left), encode(data'right), data'ascending);
  end;

  function decode (
    constant code : string)
    return integer_vector is
    function ret_val_range (
      constant code : string)
      return integer_vector is
      constant range_left : natural := decode(get_element(code,1));
      constant range_right : natural := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));      
      variable ret_val_ascending : integer_vector(range_left to range_right);
      variable ret_val_descending : integer_vector(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : integer_vector(ret_val_range(code)'range);
    variable elements : lines_t;
    variable length : natural;
    variable index : natural := 0;
  begin
    split_group(get_first_element(code), elements, ret_val'length, length);
    for i in ret_val'range loop
      ret_val(i) := decode(elements.all(index).all);
      index := index + 1;
    end loop;
    deallocate_elements(elements);
    
    return ret_val;
  end;

  function encode (
    constant data : real_vector)
    return string is
    variable element : string(1 to 2 + data'length * 67);
    variable l : line;
    variable length : natural;
  begin
    open_group(l);
    for i in data'range loop
      append_group(l, encode(data(i)));
    end loop;
    close_group(l, element, length);

    return create_array_group(element(1 to length), encode(data'left), encode(data'right), data'ascending);
  end;

  function decode (
    constant code : string)
    return real_vector is
    function ret_val_range (
      constant code : string)
      return real_vector is
      constant range_left : natural := decode(get_element(code,1));
      constant range_right : natural := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));            
      variable ret_val_ascending : real_vector(range_left to range_right);
      variable ret_val_descending : real_vector(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : real_vector(ret_val_range(code)'range);
    variable elements : lines_t;
    variable length : natural;
    variable index : natural := 0;
  begin
    split_group(get_first_element(code), elements, ret_val'length, length);
    for i in ret_val'range loop
      ret_val(i) := decode(elements.all(index).all);
      index := index + 1;
    end loop;
    deallocate_elements(elements);
    
    return ret_val;
  end;

  function encode (
    constant data : time_vector)
    return string is
    variable element : string(1 to 2 + data'length * 67);
    variable l : line;
    variable length : natural;
  begin
    open_group(l);
    for i in data'range loop
      append_group(l, encode(data(i)));
    end loop;
    close_group(l, element, length);

    return create_array_group(element(1 to length), encode(data'left), encode(data'right), data'ascending);
  end;

  function decode (
    constant code : string)
    return time_vector is
    function ret_val_range (
      constant code : string)
      return time_vector is
      constant range_left : natural := decode(get_element(code,1));
      constant range_right : natural := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));      
      variable ret_val_ascending : time_vector(range_left to range_right);
      variable ret_val_descending : time_vector(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : time_vector(ret_val_range(code)'range);
    variable elements : lines_t;
    variable length : natural;
    variable index : natural := 0;
  begin
    split_group(get_first_element(code), elements, ret_val'length, length);
    for i in ret_val'range loop
      ret_val(i) := decode(elements.all(index).all);
      index := index + 1;
    end loop;
    deallocate_elements(elements);
    
    return ret_val;
  end;

  function encode (
    constant data : std_ulogic_vector)
    return string is
  begin
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), encode(1), encode(0), true);
    else
      return create_array_group(to_string(data), encode(data'left), encode(data'right), data'ascending);
    end if;    
  end;

  function decode (
    constant code : string)
    return std_ulogic_vector is
    function ret_val_range (
      constant code : string)
      return std_ulogic_vector is
      constant range_left : natural := decode(get_element(code,1));
      constant range_right : natural := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));      
      variable ret_val_ascending : std_ulogic_vector(range_left to range_right);
      variable ret_val_descending : std_ulogic_vector(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : std_ulogic_vector(ret_val_range(code)'range);
    variable l : line;
    variable index : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := std_ulogic'value("'" & l.all(index to index) & "'");
      index := index + 1;
    end loop;
    
    deallocate(l);
    
    return ret_val;
  end;

  function encode (
    constant data : complex)
    return string is
  begin
    return create_group(encode(data.re), encode(data.im));
  end;

  function decode (
    constant code : string)
    return complex is
    variable ret_val : complex;
    variable elements : lines_t;
    variable length : natural;
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
    return create_group(encode(data.mag), encode(data.arg));
  end;

  function decode (
    constant code : string)
    return complex_polar is
    variable ret_val : complex_polar;
    variable elements : lines_t;
    variable length : natural;
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
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), encode(1), encode(0), true);
    else
      return create_array_group(to_string(data), encode(data'left), encode(data'right), data'ascending);
    end if;    
  end;
    
  function decode (
    constant code : string)
    return ieee.numeric_bit.unsigned is
    function ret_val_range (
      constant code : string)
      return ieee.numeric_bit.unsigned is
      constant range_left : natural := decode(get_element(code,1));
      constant range_right : natural := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));      
      variable ret_val_ascending : ieee.numeric_bit.unsigned(range_left to range_right);
      variable ret_val_descending : ieee.numeric_bit.unsigned(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : ieee.numeric_bit.unsigned(ret_val_range(code)'range);
    variable l : line;
    variable index : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := bit'value("'" & l.all(index to index) & "'");
      index := index + 1;
    end loop;
    
    deallocate(l);
    
    return ret_val;
  end;

  function encode (
    constant data : ieee.numeric_bit.signed)
    return string is
  begin
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), encode(1), encode(0), true);
    else
      return create_array_group(to_string(data), encode(data'left), encode(data'right), data'ascending);
    end if;    
  end;

  function decode (
    constant code : string)
    return ieee.numeric_bit.signed is
    function ret_val_range (
      constant code : string)
      return ieee.numeric_bit.signed is
      constant range_left : natural := decode(get_element(code,1));
      constant range_right : natural := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));      
      variable ret_val_ascending : ieee.numeric_bit.signed(range_left to range_right);
      variable ret_val_descending : ieee.numeric_bit.signed(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : ieee.numeric_bit.signed(ret_val_range(code)'range);
    variable l : line;
    variable length : natural;
    variable index : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := bit'value("'" & l.all(index to index) & "'");
      index := index + 1;
    end loop;
    
    deallocate(l);
    
    return ret_val;
  end;
  
  function encode (
    constant data : ieee.numeric_std.unsigned)
    return string is
  begin
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), encode(1), encode(0), true);
    else
      return create_array_group(to_string(data), encode(data'left), encode(data'right), data'ascending);
    end if;    
  end;

  function decode (
    constant code : string)
    return ieee.numeric_std.unsigned is
    function ret_val_range (
      constant code : string)
      return ieee.numeric_std.unsigned is
      constant range_left : natural := decode(get_element(code,1));
      constant range_right : natural := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));      
      variable ret_val_ascending : ieee.numeric_std.unsigned(range_left to range_right);
      variable ret_val_descending : ieee.numeric_std.unsigned(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : ieee.numeric_std.unsigned(ret_val_range(code)'range);
    variable l : line;
    variable index : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := std_logic'value("'" & l.all(index to index) & "'");
      index := index + 1;
    end loop;
    
    deallocate(l);
    
    return ret_val;
  end;
  
  function encode (
    constant data : ieee.numeric_std.signed)
    return string is
  begin
    if (data'left = 0) and (data'right = -1) then
      return create_array_group(to_string(data), encode(1), encode(0), true);
    else
      return create_array_group(to_string(data), encode(data'left), encode(data'right), data'ascending);
    end if;    
  end;
  
  function decode (
    constant code : string)
    return ieee.numeric_std.signed is
    function ret_val_range (
      constant code : string)
      return ieee.numeric_std.signed is
      constant range_left : natural := decode(get_element(code,1));
      constant range_right : natural := decode(get_element(code,2));
      constant is_ascending : boolean := decode(get_element(code,3));      
      variable ret_val_ascending : ieee.numeric_std.signed(range_left to range_right);
      variable ret_val_descending : ieee.numeric_std.signed(range_left downto range_right);
    begin
      if is_ascending then
        return ret_val_ascending;
      else        
        return ret_val_descending;
      end if;
    end function ret_val_range;
    variable ret_val : ieee.numeric_std.signed(ret_val_range(code)'range);
    variable l : line;
    variable index : natural := 1;
  begin
    write(l, get_first_element(code));
    for i in ret_val'range loop
      ret_val(i) := std_logic'value("'" & l.all(index to index) & "'");
      index := index + 1;
    end loop;
    
    deallocate(l);
    
    return ret_val;
  end;

  function encode (
    constant data : ufixed)
    return string is
    variable unsigned_data : ieee.numeric_std.unsigned(data'length - 1 downto 0) := ieee.numeric_std.unsigned(data);
  begin
    return create_group(to_string(unsigned_data), encode(data'left), encode(data'right));
  end;
  
  function decode (
    constant code : string)
    return ufixed is
    variable ret_val : ufixed(decode(get_element(code,1)) downto decode(get_element(code,2)));
    variable l : line;
    variable index : natural := 1;
  begin
    write(l, get_first_element(code));

    for i in ret_val'range loop
      ret_val(i) := std_ulogic'value("'" & l.all(index to index) & "'");
      index := index + 1;
    end loop;

    deallocate(l);
    
    return ret_val;
  end;
  
  function encode (
    constant data : sfixed)
    return string is
    variable unsigned_data : ieee.numeric_std.unsigned(data'length - 1 downto 0) := ieee.numeric_std.unsigned(data);
  begin
    return create_group(to_string(unsigned_data), encode(data'left), encode(data'right));
  end;
  
  function decode (
    constant code : string)
    return sfixed is
    variable ret_val : sfixed(decode(get_element(code,1)) downto decode(get_element(code,2)));
    variable l : line;
    variable index : natural := 1;
  begin
    write(l, get_first_element(code));

    for i in ret_val'range loop
      ret_val(i) := std_ulogic'value("'" & l.all(index to index) & "'");
      index := index + 1;
    end loop;

    deallocate(l);
    
    return ret_val;
  end;

  function encode (
    constant data : float)
    return string is
    variable unsigned_data : ieee.numeric_std.unsigned(data'length - 1 downto 0) := ieee.numeric_std.unsigned(data);
  begin
    return create_group(to_string(unsigned_data), encode(data'left), encode(data'right));
  end;

  function decode (
    constant code : string)
    return float is
    variable ret_val : float(decode(get_element(code,1)) downto decode(get_element(code,2)));
    variable l : line;
    variable index : natural := 1;
  begin
    write(l, get_first_element(code));

    for i in ret_val'range loop
      ret_val(i) := std_ulogic'value("'" & l.all(index to index) & "'");
      index := index + 1;
    end loop;
    
    deallocate(l);
    
    return ret_val;
  end;
  
  -----------------------------------------------------------------------------
  -- Encoding support
  -----------------------------------------------------------------------------
  procedure open_group (
    variable l : inout line) is
  begin
    deallocate(l);
    write(l, '(');
  end procedure open_group;

  procedure append_group (
    variable l       : inout line;
    constant element : in    string) is
  begin
    write(l, element & ",");
  end procedure append_group;

  procedure close_group (
    variable l : inout line;
    variable code : out string;
    variable length : out natural) is
    variable final : line;
  begin
    if l.all /= "(" then
      write(final, l.all(1 to l.all'length - 1));
      deallocate(l);
    else
      final := l;
    end if;
    write(final, ')');
    length := final.all'length;
    code(1 to length) := final.all;
    deallocate(final);
  end procedure close_group;

  function create_group (
    constant element1 : string := "";
    constant element2 : string := "";
    constant element3 : string := "";
    constant element4 : string := "";
    constant element5 : string := "";
    constant element6 : string := "";
    constant element7 : string := "";
    constant element8 : string := "";
    constant element9 : string := "";
    constant element10 : string := "")
    return string is
    variable ret_val : string(1 to 11 + element1'length + element2'length +
                              element3'length + element4'length + element5'length + element6'length +
                              element7'length + element8'length + element9'length + element10'length);
    variable l : line;
    variable length : natural;
  begin
    open_group(l);
    loop
      exit when element1 = "";
      append_group(l, element1);
      exit when element2 = "";
      append_group(l, element2);
      exit when element3 = "";
      append_group(l, element3);
      exit when element4 = "";
      append_group(l, element4);
      exit when element5 = "";
      append_group(l, element5);
      exit when element6 = "";
      append_group(l, element6);
      exit when element7 = "";
      append_group(l, element7);
      exit when element8 = "";
      append_group(l, element8);
      exit when element9 = "";
      append_group(l, element9);
      exit when element10 = "";
      append_group(l, element10);
      exit;
    end loop;
    close_group(l, ret_val, length);
    
    return ret_val(1 to length);
  end;

  function create_array_group (
    constant arr : string;
    constant range_left1 : string;
    constant range_right1 : string;
    constant is_ascending1 : boolean;
    constant range_left2 : string := "";
    constant range_right2 : string := "";
    constant is_ascending2 : boolean := true)
    return string is
    variable ret_val : string(1 to 18 + arr'length + range_left1'length + range_right1'length +
                              range_left2'length + range_right2'length);
    variable l : line;
    variable length : natural;
  begin
    open_group(l);
    append_group(l, arr);
    append_group(l, range_left1);
    append_group(l, range_right1);
    append_group(l, encode(is_ascending1));
    if range_left2 /= "" then
      append_group(l, range_left2);
      append_group(l, range_right2);
      append_group(l, encode(is_ascending2));
    end if;
    close_group(l, ret_val, length);
    
    return ret_val(1 to length);
  end;

  function escape_special_characters (
    constant data : string)
    return string is
  begin
    return replace(replace(replace(data, ')', "\rp"), '(', "\lp"), ',', "\comma");
  end function escape_special_characters;
  
  -----------------------------------------------------------------------------
  -- Decoding support
  -----------------------------------------------------------------------------
  procedure split_group (
    constant grp   : in    string;
    variable elements  : inout lines_t;
    constant max_num_of_elements : in natural;
    variable length : inout   natural) is
    variable element_start : positive;
    variable level : natural := 0;
    constant opening_parenthesis : character := '(';
    constant closing_parenthesis : character := ')';
  begin
    deallocate_elements(elements);

    check(grp(grp'left) = opening_parenthesis, "Group must be opened with a parenthesis");
    check(grp(grp'right) = closing_parenthesis, "Group must be closed with a parenthesis");

    length := 0;

    if grp = "()" then
      return;
    end if;

    elements := new line_vector(0 to max_num_of_elements - 1);    
    element_start := grp'left + 1;
    for i in grp'left + 1 to grp'right loop
      if length = max_num_of_elements then
        return;
      elsif grp(i) = '(' then
        level := level + 1;
      elsif ((grp(i) = ',') or (i = grp'right)) and (level = 0) then
        if grp(i) = ',' then
          write(elements.all(length), grp(element_start to i - 1));
        else
          write(elements.all(length), grp(element_start to i - 1));
        end if;
        
        length := length + 1;
        element_start := i + 1;
      elsif grp(i) = ')' then
        level := level - 1;
      end if;
    end loop;

    check(level = 0, "Parenthesis are not balanced");

  end procedure split_group;

  function get_element (
    constant grp      : in string;
    constant position : in natural)
    return string is
    variable elements : lines_t;
    variable length : natural;
    variable ret_val : string(1 to grp'length);
  begin
    if grp = "" then
      return "";
    end if;

    if grp(grp'left) /= '(' then
      if position = 0 then
        return grp;
      else
        return "";
      end if;
    end if;

    split_group(grp, elements, position + 1, length);
    if length < position + 1 then
      return "";
    else
      length := elements.all(position).all'length;
      ret_val(1 to length) := elements.all(position).all;
      deallocate_elements(elements);
      return ret_val(1 to length);
    end if;
  end function get_element;

  function get_first_element (
    constant grp : string)
    return string is
  begin
    return get_element(grp, 0);
  end function get_first_element;

  function get_second_element (
    constant grp : string)
    return string is
  begin
    return get_element(grp, 1);
  end function get_second_element;

  function get_third_element (
    constant grp : string)
    return string is
  begin
    return get_element(grp, 2);
  end function get_third_element;
  
  procedure deallocate_elements (
    variable elements : inout lines_t) is
  begin
    if elements = null then
      return;
    end if;
    
    for i in elements.all'range loop
      deallocate(elements.all(i));
    end loop;
    deallocate(elements);    
  end procedure deallocate_elements;

  function unescape_special_characters (
    constant code : string)
    return string is
  begin
    return replace(replace(replace(code, "\rp", ')'), "\lp", '('), "\comma", ',');
  end function unescape_special_characters;
  
end package body com_codec_pkg;

  
