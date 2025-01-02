-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use std.env.all;
use std.textio.all;

package body location_pkg is
  impure function get_location(path_offset, line_num : natural; file_name : string) return location_t is
    variable call_path : call_path_vector_ptr := get_call_path;
    variable result : location_t := (file_name => null, line_num => 0);
  begin
    if file_name /= "" then
      write(result.file_name, file_name);
      result.line_num := line_num;
      return result;
    end if;

    if call_path'high >= path_offset + 1 then
      if call_path(path_offset + 1).file_line /= -1 then
        result.file_name := call_path(path_offset + 1).file_name;
        result.line_num := call_path(path_offset + 1).file_line;
        return result;
      end if;
    end if;

    swrite(result.file_name, "");
    return result;
  end;

  procedure deallocate(variable location : inout location_t) is
  begin
    deallocate(location.file_name);
  end;
end package body;
