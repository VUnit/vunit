-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;

package file_pkg is
  -- NOTE: This package is private, do not use outside of VUnit

  type file_id_t is record
    p_data : integer_vector_ptr_t;
  end record;
  constant null_file_id : file_id_t := (p_data => null_ptr);

  function to_integer(file_id : file_id_t) return integer;
  impure function to_file_id(value : integer) return file_id_t;

  impure function is_open(file_id : file_id_t) return boolean;
  procedure file_close(file_id : file_id_t);
  procedure file_open_for_write(file_id : inout file_id_t;
                                file_name : string);
  procedure writeline(file_id : file_id_t;
                      l : inout line);
end package;

package body file_pkg is

  constant next_id : integer_vector_ptr_t := new_integer_vector_ptr(length => 1, value => 0);

  constant id_idx : natural := 0;
  constant open_idx : natural := 1;
  constant name_idx : natural := 2;
  constant file_id_length : natural := name_idx + 1;


  -- VHDL does not support file arrays so we have to hard code N-files
  file f0 : text;
  file f1 : text;
  file f2 : text;
  file f3 : text;
  file f4 : text;
  file f5 : text;
  file f6 : text;
  file f7 : text;
  file f8 : text;
  file f9 : text;
  file f10 : text;
  file f11 : text;
  file f12 : text;
  file f13 : text;
  file f14 : text;
  file f15 : text;
  file f16 : text;
  file f17 : text;
  file f18 : text;
  file f19 : text;
  file f20 : text;
  file f21 : text;
  file f22 : text;
  file f23 : text;
  file f24 : text;
  file f25 : text;
  file f26 : text;
  file f27 : text;
  file f28 : text;
  file f29 : text;
  file f30 : text;
  file f31 : text;

  function to_integer(file_id : file_id_t) return integer is
  begin
    return to_integer(file_id.p_data);
  end;

  impure function to_file_id(value : integer) return file_id_t is
  begin
    return (p_data => to_integer_vector_ptr(value));
  end;

  procedure assert_status(status : file_open_status; file_name : string) is
  begin
    assert status = open_ok
      report "Failed to open file " & file_name & " - " & file_open_status'image(status) severity failure;
  end procedure;

  impure function is_open(file_id : file_id_t) return boolean is
  begin
    return (file_id /= null_file_id) and get(file_id.p_data, open_idx) = 1;
  end;

  procedure file_close(file_id : file_id_t) is
    variable id : natural;
  begin
    if not is_open(file_id) then
      return;
    end if;

    id := get(file_id.p_data, id_idx);
    case id is
      when 0 => file_close(f0);
      when 1 => file_close(f1);
      when 2 => file_close(f2);
      when 3 => file_close(f3);
      when 4 => file_close(f4);
      when 5 => file_close(f5);
      when 6 => file_close(f6);
      when 7 => file_close(f7);
      when 8 => file_close(f8);
      when 9 => file_close(f9);
      when 10 => file_close(f10);
      when 11 => file_close(f11);
      when 12 => file_close(f12);
      when 13 => file_close(f13);
      when 14 => file_close(f14);
      when 15 => file_close(f15);
      when 16 => file_close(f16);
      when 17 => file_close(f17);
      when 18 => file_close(f18);
      when 19 => file_close(f19);
      when 20 => file_close(f20);
      when 21 => file_close(f21);
      when 22 => file_close(f22);
      when 23 => file_close(f23);
      when 24 => file_close(f24);
      when 25 => file_close(f25);
      when 26 => file_close(f26);
      when 27 => file_close(f27);
      when 28 => file_close(f28);
      when 29 => file_close(f29);
      when 30 => file_close(f30);
      when 31 => file_close(f31);
      when others => null;
    end case;

    set(file_id.p_data, open_idx, 0);
  end;

  procedure file_open_for_write(file_id : inout file_id_t;
                                file_name : string) is
    variable status : file_open_status;
    variable id : natural;
    file ftmp : text;
  begin
    if is_open(file_id) then
      file_close(file_id);
    end if;

    if file_id = null_file_id then
      id := get(next_id, 0);
      set(next_id, 0, id + 1);

      file_id.p_data := new_integer_vector_ptr(length => file_id_length);
      set(file_id.p_data, id_idx, id);
      set(file_id.p_data, name_idx, to_integer(new_string_ptr(file_name)));
    else
      reallocate(to_string_ptr(get(file_id.p_data, name_idx)), file_name);
    end if;

    set(file_id.p_data, open_idx, 1);

    id := get(file_id.p_data, id_idx);
    case id is
      when 0 => file_open(status, f0, file_name, write_mode);
      when 1 => file_open(status, f1, file_name, write_mode);
      when 2 => file_open(status, f2, file_name, write_mode);
      when 3 => file_open(status, f3, file_name, write_mode);
      when 4 => file_open(status, f4, file_name, write_mode);
      when 5 => file_open(status, f5, file_name, write_mode);
      when 6 => file_open(status, f6, file_name, write_mode);
      when 7 => file_open(status, f7, file_name, write_mode);
      when 8 => file_open(status, f8, file_name, write_mode);
      when 9 => file_open(status, f9, file_name, write_mode);
      when 10 => file_open(status, f10, file_name, write_mode);
      when 11 => file_open(status, f11, file_name, write_mode);
      when 12 => file_open(status, f12, file_name, write_mode);
      when 13 => file_open(status, f13, file_name, write_mode);
      when 14 => file_open(status, f14, file_name, write_mode);
      when 15 => file_open(status, f15, file_name, write_mode);
      when 16 => file_open(status, f16, file_name, write_mode);
      when 17 => file_open(status, f17, file_name, write_mode);
      when 18 => file_open(status, f18, file_name, write_mode);
      when 19 => file_open(status, f19, file_name, write_mode);
      when 20 => file_open(status, f20, file_name, write_mode);
      when 21 => file_open(status, f21, file_name, write_mode);
      when 22 => file_open(status, f22, file_name, write_mode);
      when 23 => file_open(status, f23, file_name, write_mode);
      when 24 => file_open(status, f24, file_name, write_mode);
      when 25 => file_open(status, f25, file_name, write_mode);
      when 26 => file_open(status, f26, file_name, write_mode);
      when 27 => file_open(status, f27, file_name, write_mode);
      when 28 => file_open(status, f28, file_name, write_mode);
      when 29 => file_open(status, f29, file_name, write_mode);
      when 30 => file_open(status, f30, file_name, write_mode);
      when 31 => file_open(status, f31, file_name, write_mode);

      when others =>
        report ("Warning: All 32 file objects in use, " &
                "reduced logging performance due to append open for each writeline (" & file_name & ")")
          severity warning;

        file_open(status, ftmp, file_name, write_mode);
        file_close(ftmp);

    end case;

    assert_status(status, file_name);
  end;

  procedure writeline(file_id : file_id_t;
                      l : inout line) is
    variable id : natural := get(file_id.p_data, id_idx);
    variable name_ptr : string_ptr_t;
    file ftmp : text;
    variable status : file_open_status;
  begin
    case id is
      when 0 => writeline(f0, l);
      when 1 => writeline(f1, l);
      when 2 => writeline(f2, l);
      when 3 => writeline(f3, l);
      when 4 => writeline(f4, l);
      when 5 => writeline(f5, l);
      when 6 => writeline(f6, l);
      when 7 => writeline(f7, l);
      when 8 => writeline(f8, l);
      when 9 => writeline(f9, l);
      when 10 => writeline(f10, l);
      when 11 => writeline(f11, l);
      when 12 => writeline(f12, l);
      when 13 => writeline(f13, l);
      when 14 => writeline(f14, l);
      when 15 => writeline(f15, l);
      when 16 => writeline(f16, l);
      when 17 => writeline(f17, l);
      when 18 => writeline(f18, l);
      when 19 => writeline(f19, l);
      when 20 => writeline(f20, l);
      when 21 => writeline(f21, l);
      when 22 => writeline(f22, l);
      when 23 => writeline(f23, l);
      when 24 => writeline(f24, l);
      when 25 => writeline(f25, l);
      when 26 => writeline(f26, l);
      when 27 => writeline(f27, l);
      when 28 => writeline(f28, l);
      when 29 => writeline(f29, l);
      when 30 => writeline(f30, l);
      when 31 => writeline(f31, l);

      when others =>
        name_ptr := to_string_ptr(get(file_id.p_data, name_idx));
        file_open(status, ftmp, to_string(name_ptr), append_mode);
        assert_status(status, to_string(name_ptr));
        writeline(ftmp, l);
        file_close(ftmp);
    end case;

  end;

end package body;
