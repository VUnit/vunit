-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body print_pkg is

  procedure print(constant str : in string; file f : text) is
    variable l : line;
  begin
    write(l, str);
    writeline(f, l);
  end procedure;

  procedure print(str : string) is
  begin
    print(str, OUTPUT);
  end procedure;

  procedure print(str : string;
                  file_name : string;
                  mode : file_open_kind range write_mode to append_mode := append_mode) is
    variable status : file_open_status;
    file f : text;
  begin
    if file_name = stdout_file_name then
      print(str);
    else
      file_open(status, f, file_name, mode);

      if status /= open_ok then
        report "Failed to open file " & file_name & " - " & file_open_status'image(status) severity failure;
      end if;

      print(str, f);
      file_close(f);
    end if;
  end procedure;

end package body print_pkg;
