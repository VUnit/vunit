-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.types_pkg.all;

package external_integer_vector_pkg is
  procedure write_integer (
    id : integer;
    i  : integer;
    v  : integer
  );

  impure function read_integer (
    id : integer;
    i  : integer
  ) return integer;

  impure function get_ptr (
    id : integer
  ) return extintvec_access_t;
end package;

package body external_integer_vector_pkg is
  procedure write_integer (
    id : integer;
    i  : integer;
    v  : integer
  ) is begin
    assert false report "EXTERNAL write_integer" severity failure;
  end;

  impure function read_integer (
    id : integer;
    i  : integer
  ) return integer is begin
    assert false report "EXTERNAL read_integer" severity failure;
    return integer'low;
  end;

  impure function get_ptr (
    id : integer
  ) return extintvec_access_t is begin
    assert false report "EXTERNAL get_intvec_ptr" severity failure;
    return null;
  end;
end package body;
