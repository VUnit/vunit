-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body integer_array_pkg is
  type binary_file_t is file of character;

  procedure read_byte (
    file fread      : binary_file_t;
    variable result : out integer
  ) is
    variable chr : character;
  begin
    assert not endfile(fread) report "Premature end of file";
    read(fread, chr);
    result := character'pos(chr);
  end;

  procedure write_byte (
    file fwrite : binary_file_t;
    value       : natural range 0 to 255
  ) is begin
    write(fwrite, character'val(value));
  end;

  procedure read_integer (
    file fread      : binary_file_t;
    variable result : out integer;
    bytes_per_word  : natural range 1 to 4 := 4;
    is_signed       : boolean := true
  ) is
    variable tmp, byte : integer;
  begin
    tmp := 0;
    for i in 0 to bytes_per_word - 1 loop
      read_byte(fread, byte);
      if i = bytes_per_word-1 and is_signed and byte >= 128 then
        byte := byte - 256;
      end if;
      tmp := tmp + byte*256**i;
    end loop;
    result := tmp;
  end;

  procedure write_integer (
    file fwrite    : binary_file_t;
    value          : integer;
    bytes_per_word : natural range 1 to 4 := 4;
    is_signed      : boolean := true
  ) is
    variable tmp, byte : integer;
  begin
    tmp := value;
    for i in 0 to bytes_per_word-1 loop
      byte := tmp mod 256;
      write_byte(fwrite, byte);
      tmp := (tmp - byte)/256;
    end loop;
  end;

  impure function length (
    arr : integer_array_t
  ) return integer is begin
    return arr.length;
  end;

  impure function width (
    arr : integer_array_t
  ) return integer is begin
    return arr.width;
  end;

  impure function height (
    arr : integer_array_t
  ) return integer is begin
    return arr.height;
  end;

  impure function depth (
    arr : integer_array_t
  ) return integer is begin
    return arr.depth;
  end;

  impure function bit_width (
    arr : integer_array_t
  ) return integer is begin
    return arr.bit_width;
  end;

  impure function is_signed (
    arr : integer_array_t
  ) return boolean is begin
    return arr.is_signed;
  end;

  impure function bytes_per_word (
    arr : integer_array_t
  ) return integer is begin
    return (arr.bit_width + 7)/8;
  end;

  impure function lower_limit (
    arr : integer_array_t
  ) return integer is begin
    return arr.lower_limit;
  end;

  impure function upper_limit (
    arr : integer_array_t
  ) return integer is begin
    return arr.upper_limit;
  end;

  procedure validate_data (
    arr : integer_array_t
  ) is begin
    assert arr.data /= null_ptr report "Data is not allocated";
  end;

  procedure validate_bounds (
    name       : string;
    val, bound : integer
  ) is begin
    assert 0 <= val and val < bound
      report (name & "=" & integer'image(val) & " " &
              "is out of bounds " &
              "0 <= " & name  &" < " & integer'image(bound));
  end;

  procedure validate_value (
    arr   : integer_array_t;
    value : integer
  ) is begin
    assert arr.lower_limit <= value and value <= arr.upper_limit
      report ("value=" & integer'image(value) & " " &
              "is out of bounds " &
              integer'image(arr.lower_limit) &
              " <= value <= " &
              integer'image(arr.upper_limit));
  end;

  procedure realloc (
    variable arr : inout integer_array_t;
    new_length   : integer
  ) is begin
    if arr.data = null_ptr then
      -- Array was empty
      arr.data := new_integer_vector_ptr(new_length);
    elsif new_length > length(arr.data) then
      -- Reallocate if more length is required
      -- Add extra length to avoid excessive reallocation when appending
      resize(arr.data, new_length + length(arr.data));
    end if;
    arr.length := new_length;
  end;

  procedure reshape (
    variable arr : inout integer_array_t;
    length       : integer
  ) is begin
    reshape(arr, length, 1, 1);
  end;

  procedure reshape (
    variable arr  : inout integer_array_t;
    width, height : integer
  ) is begin
    reshape(arr, width, height, 1);
  end;

  procedure reshape (
    variable arr         : inout integer_array_t;
    width, height, depth : integer
  ) is begin
    arr.width := width;
    arr.height := height;
    arr.depth := depth;
    realloc(arr, width*height*depth);
  end;

  procedure append (
    variable arr : inout integer_array_t;
    value        : integer
  ) is begin
    reshape(arr, arr.length+1);
    set(arr, arr.length-1, value);
  end;

  impure function get (
    arr : integer_array_t;
    idx : integer
  ) return integer is begin
    validate_data(arr);
    validate_bounds("idx", idx, arr.length);
    return get(arr.data, idx);
  end;

  impure function get (
    arr  : integer_array_t;
    x, y : integer
  ) return integer is begin
    validate_data(arr);
    validate_bounds("x", x, arr.width);
    validate_bounds("y", y, arr.height);
    return get(arr.data, y*arr.width + x);
  end;

  impure function get (
    arr   : integer_array_t;
    x,y,z : integer
  ) return integer is begin
    validate_data(arr);
    validate_bounds("x", x, arr.width);
    validate_bounds("y", y, arr.height);
    validate_bounds("z", z, arr.depth);
    return get(arr.data, (y*arr.width + x)*arr.depth + z);
  end;

  procedure set (
    arr   : integer_array_t;
    idx   : integer;
    value : integer
  ) is begin
    validate_data(arr);
    validate_bounds("idx", idx, arr.length);
    validate_value(arr, value);
    set(arr.data, idx, value);
  end;

  procedure set (
    arr   : integer_array_t;
    x,y   : integer;
    value : integer
  ) is begin
    validate_data(arr);
    validate_bounds("x", x, arr.width);
    validate_bounds("y", y, arr.height);
    validate_value(arr, value);
    set(arr.data, y*arr.width + x, value);
  end;

  procedure set (
    arr   : integer_array_t;
    x,y,z : integer;
    value : integer
  ) is begin
    validate_data(arr);
    validate_bounds("x", x, arr.width);
    validate_bounds("y", y, arr.height);
    validate_bounds("z", z, arr.depth);
    validate_value(arr, value);
    set(arr.data, (y*arr.width + x)*arr.depth + z, value);
  end;

  procedure set_word_size (
    variable arr : inout integer_array_t;
    bit_width    : natural := 32;
    is_signed    : boolean := true
  ) is begin
    assert (1 <= bit_width and bit_width < 32) or (bit_width = 32 and is_signed)
      report "Unsupported combination of bit_width and is_signed";
    arr.bit_width := bit_width;
    arr.is_signed := is_signed;
    if arr.is_signed then
      if arr.bit_width = 32 then
        -- avoid overflow warning
        arr.lower_limit := integer'left;
        arr.upper_limit := integer'right;
      else
        arr.lower_limit := -2**(arr.bit_width-1);
        arr.upper_limit := 2**(arr.bit_width-1)-1;
      end if;
    else
      arr.lower_limit := 0;
      if arr.bit_width = 31 then
        arr.upper_limit := integer'right;
      else
        arr.upper_limit := 2**arr.bit_width-1;
      end if;
    end if;
  end;

  impure function new_1d (
    length    : integer := 0;
    bit_width : natural := 32;
    is_signed : boolean := true
  ) return integer_array_t is begin
    return new_3d(width => length,
                  height => 1,
                  depth => 1,
                  bit_width => bit_width,
                  is_signed => is_signed);
  end;

  impure function new_2d (
    width     : integer := 0;
    height    : integer := 0;
    bit_width : natural := 32;
    is_signed : boolean := true
  ) return integer_array_t is begin
    return new_3d(width => width,
                  height => height,
                  depth => 1,
                  bit_width => bit_width,
                  is_signed => is_signed);
  end;

  impure function new_3d (
    width     : integer := 0;
    height    : integer := 0;
    depth     : integer := 0;
    bit_width : natural := 32;
    is_signed : boolean := true
  ) return integer_array_t is
    variable arr : integer_array_t := null_integer_array;
  begin
    set_word_size(arr, bit_width, is_signed);
    arr.length := width * height * depth;
    arr.width := width;
    arr.height := height;
    arr.depth := depth;
    if arr.length > 0 then
      arr.data := new_integer_vector_ptr(arr.length);
    else
      arr.data := null_ptr;
    end if;
    return arr;
  end;

  impure function copy (
    arr : integer_array_t
  ) return integer_array_t is
    variable arr_copy : integer_array_t;
  begin
    arr_copy := new_3d(arr.width, arr.height,
                       arr.depth, arr.bit_width, arr.is_signed);
    for i in 0 to arr.length-1 loop
      set(arr_copy, i, get(arr, i));
    end loop;
    return arr_copy;
  end;

  procedure deallocate (
    variable arr : inout integer_array_t
  ) is begin
    if arr.data /= null_ptr then
      deallocate(arr.data);
    end if;
    arr := null_integer_array;
  end;

  impure function is_null (
    arr : integer_array_t
  ) return boolean is begin
    return arr = null_integer_array;
  end;

  procedure save_csv (
    arr       : integer_array_t;
    file_name : string
  ) is
    file fwrite : text;
    variable l : line;
  begin
    file_open(fwrite, file_name, write_mode);
    for y in 0 to arr.height-1 loop
      for x in 0 to arr.width-1 loop
        for z in 0 to arr.depth-1 loop
          write(l, integer'image(get(arr, x, y, z)));
          if x /= arr.width-1 or z /= arr.depth-1 then
            write(l, ',');
          end if;
        end loop;
      end loop;
      writeline(fwrite, l);
    end loop;
    file_close(fwrite);
  end;

  impure function load_csv (
    file_name : string;
    bit_width : natural := 32;
    is_signed : boolean := true
  ) return integer_array_t is
    variable arr     : integer_array_t;
    file     fread   : text;
    variable l       : line;
    variable tmp     : integer;
    variable ctmp    : character;
    variable is_good : boolean;
    variable width   : integer := 0;
    variable height  : integer := 0;
  begin
    arr := new_1d(bit_width => bit_width, is_signed => is_signed);
    file_open(fread, file_name, read_mode);
    while not endfile(fread) loop
      readline(fread, l);
      height := height + 1;
      loop
        read(l, tmp, is_good);
        exit when not is_good;
        if height = 1 then
          width := width + 1;
        end if;
        append(arr, tmp);
        read(l, ctmp, is_good);
        exit when not is_good;
      end loop;
    end loop;
    file_close(fread);
    reshape(arr, width, height);
    return arr;
  end;

  procedure save_raw (
    arr       : integer_array_t;
    file_name : string
  ) is
    file fwrite : binary_file_t;
  begin
    file_open(fwrite, file_name, write_mode);
    for idx in 0 to arr.length-1 loop
      write_integer(fwrite,
                    get(arr, idx),
                    bytes_per_word => (arr.bit_width+7)/8,
                    is_signed => arr.is_signed);
    end loop;
    file_close(fwrite);
  end;

  impure function load_raw (
    file_name : string;
    bit_width : natural := 32;
    is_signed : boolean := true
  ) return integer_array_t is
    variable arr : integer_array_t;
    file fread : binary_file_t;
    variable tmp : integer;
  begin
    arr := new_1d(bit_width => bit_width, is_signed => is_signed);
    file_open(fread, file_name, read_mode);
    while not endfile(fread) loop
      read_integer(fread, tmp,
                   bytes_per_word => (arr.bit_width+7)/8,
                   is_signed => arr.is_signed);
      append(arr, tmp);
    end loop;
    file_close(fread);
    return arr;
  end;

  function encode (
    data : integer_array_t
  ) return string is
  begin
    return encode(data.length) & encode(data.width) & encode(data.height) &
    encode(data.depth) & encode(data.bit_width) & encode(data.is_signed) &
    encode(data.lower_limit) & encode(data.upper_limit) & encode(data.data);
  end;

  function decode (
    code : string
  ) return integer_array_t is
    variable result : integer_array_t;
    variable index : positive := code'left;
  begin
    decode(code, index, result);

    return result;
  end;

  procedure decode (
    constant code   : string;
    variable index  : inout positive;
    variable result : out integer_array_t
  ) is
  begin
    decode(code, index, result.length);
    decode(code, index, result.width);
    decode(code, index, result.height);
    decode(code, index, result.depth);
    decode(code, index, result.bit_width);
    decode(code, index, result.is_signed);
    decode(code, index, result.lower_limit);
    decode(code, index, result.upper_limit);
    decode(code, index, result.data);
  end;
end package body;
