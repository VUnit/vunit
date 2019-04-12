-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

package body external_integer_vector_pkg is
  procedure write_integer (
    id : integer;
    i  : integer;
    v  : integer
  )is begin
    assert false report "VHPI write_integer" severity failure;
  end;

  impure function read_integer (
    id : integer;
    i  : integer
  ) return integer is begin
    assert false report "VHPI read_integer" severity failure;
  end;

  impure function get_ptr (
    id : integer
  ) return extintvec_access_t is begin
    assert false report "VHPI get_intvec_ptr" severity failure;
  end;
end package body;
