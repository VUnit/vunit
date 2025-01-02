-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
use std.textio.all;

package location_pkg is
  type location_t is record
    file_name : line;
    line_num : natural;
  end record;

  impure function get_location(path_offset, line_num : natural; file_name : string) return location_t;
  procedure deallocate(variable location : inout location_t);
end package;
