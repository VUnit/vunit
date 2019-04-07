-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

package body external_string_pkg is
  procedure write_char (
    id : integer;
    i  : integer;
    v  : character
  )is begin
    assert false report "VHPI write_char" severity failure;
  end;

  impure function read_char (
    id : integer;
    i  : integer
  ) return character is begin
    assert false report "VHPI read_char" severity failure;
  end;

  impure function get_ptr (
    id : integer
  ) return extstring_access_t is begin
    assert false report "VHPI get_string_ptr" severity failure;
  end;
end package body;
