-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body location_pkg is
  impure function get_location(path_offset, line_num : natural; file_name : string) return location_t is
     variable result : location_t := (file_name => null, line_num => 0);
  begin
    write(result.file_name, file_name);
    result.line_num := line_num;

    return result;
  end;

  procedure deallocate(variable location : inout location_t) is
  begin
    deallocate(location.file_name);
  end;
end package body;
