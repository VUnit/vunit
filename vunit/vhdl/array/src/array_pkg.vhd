-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

-- @TODO > 32-bit ieee signed/unsigned

use std.textio.all;

package array_pkg is

  type array_t is protected
    procedure init(length : integer := 0;
                   bit_width : natural := 32;
                   is_signed : boolean := true);

    procedure init_2d(width : integer := 0;
                      height : integer := 0;
                      bit_width : natural := 32;
                      is_signed : boolean := true);

    procedure init_3d(width : integer := 0;
                      height : integer := 0;
                      depth : integer := 0;
                      bit_width : natural := 32;
                      is_signed : boolean := true);

    procedure copy_from(input : inout array_t);

    procedure load_csv(file_name : string;
                       bit_width : natural := 32;
                       is_signed : boolean := true);

    procedure load_raw(file_name : string;
                       bit_width : natural := 32;
                       is_signed : boolean := true);
    procedure clear;

    impure function height return integer;
    impure function width return integer;
    impure function depth return integer;
    impure function length return integer;
    impure function bit_width return integer;
    impure function is_signed return boolean;
    impure function lower_limit return integer;
    impure function upper_limit return integer;

    impure function get(idx : integer) return integer;
    impure function get(x,y : integer) return integer;
    impure function get(x,y,z : integer) return integer;
    procedure set(idx : integer; value : integer);
    procedure set(x,y : integer; value : integer);
    procedure set(x,y,z : integer; value : integer);

    procedure append(value : integer);
    procedure reshape(length : integer);
    procedure reshape(width, height : integer);
    procedure reshape(width, height, depth : integer);
    procedure save_csv(file_name : string);
    procedure save_raw(file_name : string);
  end protected;
end package;

package body array_pkg is
  type binary_file_t is file of character;
  type integer_vector_access_t is access integer_vector;

  procedure read_byte(file fread : binary_file_t;
                      variable result : out integer) is
    variable chr : character;
  begin
    assert not endfile(fread) report "Premature end of file";
    read(fread, chr);
    result := character'pos(chr);
  end procedure;

  procedure write_byte(file fwrite : binary_file_t;
                       value : natural range 0 to 255) is
  begin
    write(fwrite, character'val(value));
  end procedure;

  procedure read_integer(file fread : binary_file_t;
                         variable result : out integer;
                         bytes_per_word : natural range 1 to 4 := 4;
                         is_signed : boolean := true) is
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
  end procedure;

  procedure write_integer(file fwrite : binary_file_t;
                          value : integer;
                          bytes_per_word : natural range 1 to 4 := 4;
                          is_signed : boolean := true) is
    variable tmp, byte : integer;
  begin
    tmp := value;
    for i in 0 to bytes_per_word-1 loop
      byte := tmp mod 256;
      write_byte(fwrite, byte);
      tmp := (tmp - byte)/256;
    end loop;
  end procedure;


  type array_t is protected body
    variable my_length : natural := 0;
    variable my_width : natural := 0;
    variable my_height : natural := 0;
    variable my_depth : natural := 0;
    variable my_bit_width : natural;
    variable my_is_signed : boolean;
    variable my_lower_limit : integer;
    variable my_upper_limit : integer;
    variable my_data : integer_vector_access_t := null;

    impure function length return integer is
    begin
      return my_length;
    end function;

    impure function width return integer is
    begin
      return my_width;
    end function;

    impure function height return integer is
    begin
      return my_height;
    end function;

    impure function depth return integer is
    begin
      return my_depth;
    end function;

    impure function bit_width return integer is
    begin
      return my_bit_width;
    end function;

    impure function is_signed return boolean is
    begin
      return my_is_signed;
    end function;

    impure function bytes_per_word return integer is
    begin
      return (my_bit_width + 7)/8;
    end function;

    impure function lower_limit return integer is
    begin
      return my_lower_limit;
    end function;

    impure function upper_limit return integer is
    begin
      return my_upper_limit;
    end function;

    procedure validate_data is
    begin
      assert my_data /= null report "Data is not allocated";
    end procedure;

    procedure validate_bounds(name : string; val, bound : integer) is
    begin
      assert 0 <= val and val < bound
                  report (name & "=" & integer'image(val) & " " &
                          "is out of bounds " &
                          "0 <= " & name  &" < " & integer'image(bound));
    end procedure;

    procedure validate_value(value : integer) is
    begin
      assert my_lower_limit <= value and value <= my_upper_limit
          report ("value=" & integer'image(value) & " " &
                  "is out of bounds " &
                  integer'image(my_lower_limit) &
                  " <= value <= " &
                  integer'image(my_upper_limit));
    end procedure;

    procedure realloc(new_length : integer) is
      variable new_data : integer_vector_access_t;
    begin
      if my_data = null then
        -- Array was empty
        my_data := new integer_vector'(0 to new_length-1 => 0);
      elsif new_length > my_data'length then
        -- Reallocate if more length is required
        new_data := new integer_vector'(0 to 2*my_data'length-1 => 0);
        for idx in 0 to my_length-1 loop
          new_data(idx) := my_data(idx);
        end loop;
        deallocate(my_data);
        my_data := new_data;
      end if;

      my_length := new_length;
    end procedure;

    procedure reshape(length : integer) is
    begin
      reshape(length, 1, 1);
    end procedure;

    procedure reshape(width, height : integer) is
    begin
      reshape(width, height, 1);
    end procedure;

    procedure reshape(width, height, depth : integer) is
    begin
      my_width := width;
      my_height := height;
      my_depth := depth;
      realloc(width*height*depth);
    end procedure;

    procedure append(value : integer) is
    begin
      reshape(my_length+1);
      set(my_length-1, value);
    end procedure;

    impure function get(idx : integer) return integer is
    begin
      validate_data;
      validate_bounds("idx", idx, my_length);
      return my_data(idx);
    end function;

    impure function get(x, y : integer) return integer is
    begin
      validate_data;
      validate_bounds("x", x, my_width);
      validate_bounds("y", y, my_height);
      return my_data(y*my_width + x);
    end function;

    impure function get(x,y,z : integer) return integer is
    begin
      validate_data;
      validate_bounds("x", x, my_width);
      validate_bounds("y", y, my_height);
      validate_bounds("z", z, my_depth);
      return my_data((y*my_width + x)*my_depth + z);
    end function;

    procedure set(idx : integer; value : integer)  is
    begin
      validate_data;
      validate_bounds("idx", idx, my_length);
      validate_value(value);
      my_data(idx) := value;
    end procedure;

    procedure set(x,y : integer; value : integer)  is
    begin
      validate_data;
      validate_bounds("x", x, my_width);
      validate_bounds("y", y, my_height);
      validate_value(value);
      my_data(y*my_width + x) := value;
    end procedure;

    procedure set(x,y,z : integer; value : integer)  is
    begin
      validate_data;
      validate_bounds("x", x, my_width);
      validate_bounds("y", y, my_height);
      validate_bounds("z", z, my_depth);
      validate_value(value);
      my_data((y*my_width + x)*my_depth + z) := value;
    end procedure;

    procedure set_word_size(bit_width : natural := 32;
                            is_signed : boolean := true) is
    begin
      assert (1 <= bit_width and bit_width < 32) or (bit_width = 32 and is_signed)
        report "Unsupported combination of bit_width and is_signed";
      my_bit_width := bit_width;
      my_is_signed := is_signed;

      if my_is_signed then
        if my_bit_width = 32 then
          -- avoid overflow warning
          my_lower_limit := integer'left;
          my_upper_limit := integer'right;
        else
          my_lower_limit := -2**(my_bit_width-1);
          my_upper_limit := 2**(my_bit_width-1)-1;
        end if;
      else
        my_lower_limit := 0;
        if my_bit_width = 31 then
          my_upper_limit := integer'right;
        else
          my_upper_limit := 2**my_bit_width-1;
        end if;
      end if;
    end procedure;

    procedure init(length : integer := 0;
                   bit_width : natural := 32;
                   is_signed : boolean := true) is
    begin
      init_3d(width => length,
              height => 1,
              depth => 1,
              bit_width => bit_width,
              is_signed => is_signed);
    end procedure;

    procedure init_2d(width : integer := 0;
                      height : integer := 0;
                      bit_width : natural := 32;
                      is_signed : boolean := true) is
    begin
      init_3d(width => width,
              height => height,
              depth => 1,
              bit_width => bit_width,
              is_signed => is_signed);
    end procedure;

    procedure init_3d(width : integer := 0;
                      height : integer := 0;
                      depth : integer := 0;
                      bit_width : natural := 32;
                      is_signed : boolean := true) is
    begin
      clear;
      set_word_size(bit_width, is_signed);

      my_length := width * height * depth;
      my_width := width;
      my_height := height;
      my_depth := depth;

      if my_length > 0 then
        my_data := new integer_vector'(0 to my_length-1 => 0);
      else
        my_data := null;
      end if;
    end procedure;

    procedure copy_from(input : inout array_t) is
    begin
      init_3d(input.width, input.height, input.depth, input.bit_width, input.is_signed);
      for i in 0 to input.length-1 loop
        my_data(i) := input.get(i);
      end loop;
    end procedure;

    procedure clear is
    begin
      my_length := 0;
      my_width := 0;
      my_height := 0;
      my_depth := 0;
      if my_data /= null then
        deallocate(my_data);
      end if;
    end procedure;

    procedure save_csv(file_name : string) is
      file fwrite : text;
      variable l : line;
    begin
      file_open(fwrite, file_name, write_mode);
      for y in 0 to my_height-1 loop
        for x in 0 to my_width-1 loop
          for z in 0 to my_depth-1 loop
            write(l, integer'image(get(x, y, z)));
            if x /= my_width-1 or z /= my_depth-1 then
              write(l, ',');
            end if;
          end loop;
        end loop;
        writeline(fwrite, l);
      end loop;
      file_close(fwrite);
    end procedure;

    procedure load_csv(file_name : string;
                       bit_width : natural := 32;
                       is_signed : boolean := true) is
      file fread : text;
      variable l : line;
      variable tmp : integer;
      variable ctmp : character;
      variable is_good : boolean;
      variable width : integer := 0;
      variable height : integer := 0;
    begin
      init(bit_width => bit_width, is_signed => is_signed);
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
          append(tmp);
          read(l, ctmp, is_good);
          exit when not is_good;
        end loop;
      end loop;
      file_close(fread);
      reshape(width, height);
    end procedure;

    procedure save_raw(file_name : string) is
      file fwrite : binary_file_t;
    begin
      file_open(fwrite, file_name, write_mode);
      for idx in 0 to length-1 loop
        write_integer(fwrite,
                      get(idx),
                      bytes_per_word => bytes_per_word,
                      is_signed => my_is_signed);
      end loop;
      file_close(fwrite);
    end procedure;

    procedure load_raw(file_name : string;
                       bit_width : natural := 32;
                       is_signed : boolean := true) is
      file fread : binary_file_t;
      variable tmp : integer;
    begin
      init(bit_width => bit_width, is_signed => is_signed);
      file_open(fread, file_name, read_mode);
      while not endfile(fread) loop
        read_integer(fread, tmp,
                     bytes_per_word=>bytes_per_word,
                     is_signed=>my_is_signed);
        append(tmp);
      end loop;
      file_close(fread);
    end procedure;
  end protected body;
end package body;
