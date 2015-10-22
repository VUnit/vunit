-- Functions for formatting of log entries.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ops.all;
use work.log_types_pkg.all;
use std.textio.all;

package log_formatting_pkg is
  function format (
    constant log_format        : log_format_t;
    constant msg           : string;
    constant seq_num       : natural := 0;
    constant log_separator : character := ',';
    constant t             : time := 0 ns;
    constant log_level     : string := "info";
    constant line_num      : natural := 0;
    constant file_name     : string := "";
    constant src           : string := "")
    return string;

end package log_formatting_pkg;

package body log_formatting_pkg is
  function raw_format (
    constant msg           : string;
    constant seq_num       : natural     := 0;
    constant log_separator : character   := ',';
    constant t             : time        := 0 ns;
    constant level         : string := "info";
    constant line_num      : natural     := 0;
    constant file_name     : string      := "";
    constant src           : string      := "")
    return string is
  begin
    return msg;
  end function raw_format;

  function level_format (
    constant msg           : string;
    constant seq_num       : natural     := 0;
    constant log_separator : character   := ',';
    constant t             : time        := 0 ns;
    constant level         : string := "info";
    constant line_num      : natural     := 0;
    constant file_name     : string      := "";
    constant src           : string      := "")
    return string is
  begin
    return upper(level) & ": " & msg;
  end function level_format;

  function verbose_csv_format (
    constant msg           : string;
    constant seq_num       : natural     := 0;
    constant log_separator : character   := ',';
    constant t             : time        := 0 ns;
    constant level         : string := "info";
    constant line_num      : natural     := 0;
    constant file_name     : string      := "";
    constant src           : string      := "")
    return string is
  begin
    if line_num = 0 then
     return natural'image(seq_num) & log_separator & time'image(t) & log_separator & level & log_separator & log_separator & log_separator & replace(src, ':', '.') & log_separator & msg;
    else
      return natural'image(seq_num) & log_separator & time'image(t) & log_separator & level & log_separator & file_name & log_separator & natural'image(line_num) & log_separator & replace(src, ':', '.') & log_separator & msg;
    end if;
  end function verbose_csv_format;

  function verbose_format (
    constant msg           : string;
    constant seq_num       : natural     := 0;
    constant log_separator : character   := ',';
    constant t             : time        := 0 ns;
    constant level         : string := "info";
    constant line_num      : natural     := 0;
    constant file_name     : string      := "";
    constant src           : string      := "")
    return string is
    variable location : line;
  begin
    if location /= null then
      deallocate(location);
    end if;
    write(location, string'(""));
    if src /= "" or (file_name /= "" and line_num /= 0) then
      write(location, string'(" in"));
    end if;
    if src /= "" then
      write(location, " " & replace(src, ':', '.'));
    end if;
    if file_name /= "" and line_num /= 0 then
      write(location, " (" & file_name & ":" & natural'image(line_num) & ")");
    end if;
    return time'image(t) & ": " & upper(level) & location.all & ": " & msg;
  end function verbose_format;

  function format (
    constant log_format        : log_format_t;
    constant msg           : string;
    constant seq_num       : natural := 0;
    constant log_separator : character := ',';
    constant t             : time := 0 ns;
    constant log_level     : string := "info";
    constant line_num      : natural := 0;
    constant file_name     : string := "";
    constant src           : string := "")
    return string is
  begin
    if (log_format = raw) or (log_format = dflt) then
      return raw_format(msg, seq_num, log_separator, t, log_level, line_num, file_name, src);
    elsif (log_format = level) then
      return level_format(msg, seq_num, log_separator, t, log_level, line_num, file_name, src);
    elsif (log_format = verbose_csv) then
      return verbose_csv_format(msg, seq_num, log_separator, t, log_level, line_num, file_name, src);
    elsif (log_format = verbose) then
      return verbose_format(msg, seq_num, log_separator, t, log_level, line_num, file_name, src);
    else
      return "";
    end if;
  end;

end package body log_formatting_pkg;
