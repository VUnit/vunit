-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

use work.log_handler_pkg.stdout_file_name;

package print_pkg is

  -- Print to an open file object. No internal flushing.
  procedure print(constant str : in string; file f : text);

  -- Print to stdout
  procedure print(str : string);

  -- Print to named file
  procedure print(str : string;
                  file_name : string;
                  mode : file_open_kind range write_mode to append_mode := append_mode);

end package print_pkg;
