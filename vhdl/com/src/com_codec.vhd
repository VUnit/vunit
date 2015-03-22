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
    return character'image(data);
  end;
  
  function decode (
    constant code : string)
    return character is
  begin
    return character'value(code);
  end;

  -----------------------------------------------------------------------------
  -- Predefined composite types
  -----------------------------------------------------------------------------
  function encode (
    constant data : string)
    return string is
  begin
    return data;
  end;

  function decode (
    constant code : string)
    return string is
  begin
    return code;
  end;

  procedure initialize_composite_encode (
    variable l : inout line) is
  begin
    write(l, '(');
  end procedure initialize_composite_encode;

  procedure finalize_composite_encode (
    variable l : inout line;
    variable code : out string;
    variable length : out natural) is
  begin
    write(l, ')');
    length := l.all'length;
    code(1 to length) := l.all;
    deallocate(l);
  end procedure finalize_composite_encode;


  procedure initialize_composite_decode (
    constant code   : in    string;
    variable parts  : inout lines_t;
    variable length : inout   natural) is
  begin
    if code = "()" then
      length := 0;
    end if;
    parts := split(code(2 to code'length - 1), ",");
  end procedure initialize_composite_decode;

  procedure finalize_composite_decode (
    variable parts : inout lines_t) is
  begin
    for i in parts.all'range loop
      deallocate(parts.all(i));
    end loop;
    deallocate(parts);
  end procedure finalize_composite_decode;
  
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

    return element(1 to length);
  end;

  function decode (
    constant code : string)
    return boolean_vector is
    constant max_num_of_elements : natural := count(code, ',') + 1;
    variable ret_val : boolean_vector(0 to max_num_of_elements - 1);
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, max_num_of_elements, length);
    for i in 0 to length - 1 loop
      ret_val(i) := decode(elements.all(i).all);
    end loop;
    deallocate_elements(elements);
    
    return ret_val(0 to length - 1);
  end;

  function encode (
    constant data : bit_vector)
    return string is
  begin
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return bit_vector is
    variable ret_val : bit_vector(code'range);
  begin
    for i in code'range loop
      ret_val(i) := bit'value("'" & code(i to i) & "'");
    end loop;

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

    return element(1 to length);
  end;

  function decode (
    constant code : string)
    return integer_vector is
    constant max_num_of_elements : natural := count(code, ',') + 1;
    variable ret_val : integer_vector(0 to max_num_of_elements - 1);
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, max_num_of_elements, length);
    for i in 0 to length - 1 loop
      ret_val(i) := decode(elements.all(i).all);
    end loop;
    deallocate_elements(elements);
    
    return ret_val(0 to length - 1);
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

    return element(1 to length);
  end;

  function decode (
    constant code : string)
    return real_vector is
    constant max_num_of_elements : natural := count(code, ',') + 1;
    variable ret_val : real_vector(0 to max_num_of_elements - 1);
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, max_num_of_elements, length);
    for i in 0 to length - 1 loop
      ret_val(i) := decode(elements.all(i).all);
    end loop;
    deallocate_elements(elements);
    
    return ret_val(0 to length - 1);
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

    return element(1 to length);
  end;

  function decode (
    constant code : string)
    return time_vector is
    constant max_num_of_elements : natural := count(code, ',') + 1;
    variable ret_val : time_vector(0 to max_num_of_elements - 1);
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, max_num_of_elements, length);
    for i in 0 to length - 1 loop
      ret_val(i) := decode(elements.all(i).all);
    end loop;
    deallocate_elements(elements);
    
    return ret_val(0 to length - 1);
  end;

  function encode (
    constant data : std_ulogic_vector)
    return string is
  begin
    return to_string(data);
  end;

  function decode (
    constant code : string)
    return std_ulogic_vector is
    variable ret_val : std_ulogic_vector(code'range);
  begin
    for i in code'range loop
      ret_val(i) := std_ulogic'value("'" & code(i to i) & "'");
    end loop;

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
    return to_string(data);
  end;
  
  function decode (
    constant code : string)
    return ieee.numeric_bit.unsigned is
    variable ret_val : ieee.numeric_bit.unsigned(code'range);
  begin
    for i in code'range loop
      ret_val(i) := bit'value("'" & code(i to i) & "'");
    end loop;

    return ret_val;
  end;
  
  function encode (
    constant data : ieee.numeric_bit.signed)
    return string is
  begin
    return to_string(data);
  end;
  
  function decode (
    constant code : string)
    return ieee.numeric_bit.signed is
    variable ret_val : ieee.numeric_bit.signed(code'range);
  begin
    for i in code'range loop
      ret_val(i) := bit'value("'" & code(i to i) & "'");
    end loop;

    return ret_val;
  end;
  
  function encode (
    constant data : ieee.numeric_std.unsigned)
    return string is
  begin
    return to_string(data);
  end;
  
  function decode (
    constant code : string)
    return ieee.numeric_std.unsigned is
    variable ret_val : ieee.numeric_std.unsigned(code'range);
  begin
    for i in code'range loop
      ret_val(i) := std_ulogic'value("'" & code(i to i) & "'");
    end loop;

    return ret_val;
  end;
  
  function encode (
    constant data : ieee.numeric_std.signed)
    return string is
  begin
    return to_string(data);
  end;
  
  function decode (
    constant code : string)
    return ieee.numeric_std.signed is
    variable ret_val : ieee.numeric_std.signed(code'range);
  begin
    for i in code'range loop
      ret_val(i) := std_ulogic'value("'" & code(i to i) & "'");
    end loop;

    return ret_val;
  end;
  
  function ret_val_left (
    constant code : string)
    return integer is
    variable ret_val : integer;
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, 3, length);
    ret_val := decode(elements.all(1).all);
    deallocate_elements(elements);

    return ret_val;
  end function ret_val_left;

  function ret_val_right (
    constant code : string)
    return integer is
    variable ret_val : integer;
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, 3, length);
    ret_val := decode(elements.all(2).all);
    deallocate_elements(elements);

    return ret_val;
  end function ret_val_right;

  function encode (
    constant data : ufixed)
    return string is
    -- Converting to unsigned since to_string on an ufixed will insert at radix
    -- point. This radix point can't be handled by the from_string function in
    -- the decode unction when both the left and rights of the ufixed vector are negative.
    variable unsigned_data : ieee.numeric_std.unsigned(data'length - 1 downto 0) := ieee.numeric_std.unsigned(data);
  begin
    return create_group(to_string(unsigned_data), to_string(data'left), to_string(data'right));
  end;
  
  function decode (
    constant code : string)
    return ufixed is
    variable ret_val : ufixed(ret_val_left(code) downto ret_val_right(code));
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, 3, length);
    ret_val := from_string(elements.all(0).all, decode(elements.all(1).all), decode(elements.all(2).all));
    deallocate_elements(elements);

    return ret_val;
  end;
  
  function encode (
    constant data : sfixed)
    return string is
    -- Converting to unsigned since to_string on a sfixed will insert a radix
    -- point. This radix point can't be handled by the from_string function in
    -- the decode function when both the left and rights of the sfixed vector are negative.
    variable unsigned_data : ieee.numeric_std.unsigned(data'length - 1 downto 0) := ieee.numeric_std.unsigned(data);
  begin
    return create_group(to_string(unsigned_data), to_string(data'left), to_string(data'right));
  end;
  
  function decode (
    constant code : string)
    return sfixed is
    variable ret_val : sfixed(ret_val_left(code) downto ret_val_right(code));
    variable elements : lines_t;
    variable length : natural;
  begin
    split_group(code, elements, 3, length);
    ret_val := from_string(elements.all(0).all, decode(elements.all(1).all), decode(elements.all(2).all));
    deallocate_elements(elements);

    return ret_val;
  end;

  function encode (
    constant data : float)
    return string is
  begin
    return create_group(to_string(data), to_string(data'left), to_string(data'right));
  end;

  function decode (
    constant code : string)
    return float is
    variable ret_val : float(ret_val_left(code) downto ret_val_right(code));
    variable elements : lines_t;
    variable length : natural;    
  begin
    split_group(code, elements, 3, length);
    ret_val := from_string(elements.all(0).all, decode(elements.all(1).all), -decode(elements.all(2).all));
    deallocate_elements(elements);

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
    if l.all /= "(" then
      write(l, "," & element);
    else
      write(l, element);
    end if;
  end procedure append_group;

  procedure close_group (
    variable l : inout line;
    variable code : out string;
    variable length : out natural) is
  begin
    write(l, ')');
    length := l.all'length;
    code(1 to length) := l.all;
    deallocate(l);
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
    variable ret_val : string(1 to 11 + element1'length + element1'length + element2'length +
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

    check(grp(grp'left) = opening_parenthesis, "Group must be opend with a parenthesis");
    check(grp(grp'right) = closing_parenthesis, "Group must be closed with a parenthesis");

    elements := new line_vector(0 to max_num_of_elements - 1);
    length := 0;

    if grp = "()" then
      return;
    end if;

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
    
end package body com_codec_pkg;

  
