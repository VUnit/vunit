-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2016, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

package vunit_core_pkg is
  procedure setup(file_name : string);
  procedure test_start(test_name : string);
  procedure test_suite_done;
end package;

package body vunit_core_pkg is
  file test_results : text;

  procedure setup(file_name : string) is
  begin
    file_open(test_results, file_name, write_mode);
  end procedure;

  procedure test_start(test_name : string) is
    variable l : line;
  begin
    write(l, string'("test_start:"));
    write(l,  test_name);
    writeline(test_results, l);
  end procedure;

  procedure test_suite_done is
    variable l : line;
  begin
    write(l, string'("test_suite_done"));
    writeline(test_results, l);
    file_close(test_results);
  end procedure;

end package body;
