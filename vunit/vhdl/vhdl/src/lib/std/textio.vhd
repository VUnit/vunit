-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

package textio is
  procedure std_file_open (
    variable status        : out file_open_status;
    file f                 : text;
    constant external_name : in  string;
    constant open_kind     : in  file_open_kind := read_mode);

  procedure std_file_close (
    file f : text);

  procedure std_writeline (
    file f : text;
    variable l : inout line);
end textio;

package body textio is
  procedure std_file_open (
    variable status        : out file_open_status;
    file f                 : text;
    constant external_name : in  string;
    constant open_kind     : in  file_open_kind := read_mode) is
  begin
    file_open(status, f, external_name, open_kind);
  end std_file_open;

  procedure std_file_close (
    file f : text) is
  begin
    file_close(f);
  end std_file_close;

  procedure std_writeline (
    file f : text;
    variable l : inout line) is
  begin
    writeline(f, l);
  end std_writeline;

end textio;
