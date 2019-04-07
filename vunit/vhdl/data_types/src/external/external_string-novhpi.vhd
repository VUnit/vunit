-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

use work.types_pkg.all;

package external_string_pkg is
  procedure write_char (
    id : integer;
    i  : integer;
    v  : character
  );

  impure function read_char (
    id : integer;
    i  : integer
  ) return character;

  impure function get_ptr (
    id : integer
  ) return extstring_access_t;
end package;
