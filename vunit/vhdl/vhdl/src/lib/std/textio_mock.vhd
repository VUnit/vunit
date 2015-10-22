-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

package textio is
  type file_open_call_args_t is record
    valid : boolean;
    external_name : string(1 to 256);
    open_kind : file_open_kind;
  end record;

  type writeline_call_args_t is record
    valid : boolean;
    l     : line;
  end record;

  impure function get_file_open_call_count
    return natural;

  procedure get_file_open_call_args (
    variable args : out file_open_call_args_t);

  procedure std_file_open (
    variable status        : out file_open_status;
    file f                 : text;
    constant external_name : in  string;
    constant open_kind     : in  file_open_kind := read_mode);

  impure function get_file_close_call_count
    return natural;

  procedure get_file_close_call_args (
    file f : text;
    variable valid : out boolean);

  procedure std_file_close (
    file f : text);

  impure function get_writeline_call_count
    return natural;

  procedure get_writeline_call_args (
    variable args : out writeline_call_args_t);

  procedure std_writeline (
    file f : text;
    variable l : inout line);
end textio;

package body textio is
  type file_open_call_args_internal_t is record
    valid : boolean;
    external_name : line;
    open_kind : file_open_kind;
  end record;

  shared variable file_open_call_args : file_open_call_args_internal_t := (false, null, read_mode);
  shared variable file_open_call_count : natural := 0;
  shared variable file_close_call_valid : boolean := false;
  shared variable file_close_call_count : natural := 0;
  shared variable writeline_call_args : writeline_call_args_t := (false, null);
  shared variable writeline_call_count : natural := 0;

  impure function get_file_open_call_count
    return natural is
  begin
    return file_open_call_count;
  end;

  procedure get_file_open_call_args (
    variable args : out file_open_call_args_t) is
  begin
    args.external_name(file_open_call_args.external_name.all'range) := file_open_call_args.external_name.all;
    args.open_kind := file_open_call_args.open_kind;
    args.valid := file_open_call_args.valid;
  end;

  procedure std_file_open (
    variable status        : out file_open_status;
    file f                 : text;
    constant external_name : in  string;
    constant open_kind     : in  file_open_kind := read_mode) is
  begin
    file_open_call_count := file_open_call_count + 1;
    if file_open_call_args.external_name /= null then
      deallocate(file_open_call_args.external_name);
    end if;
    write(file_open_call_args.external_name, external_name);
    file_open_call_args.open_kind := open_kind;
    file_open_call_args.valid := true;
    status := open_ok;
  end std_file_open;

  impure function get_file_close_call_count
    return natural is
  begin
    return file_close_call_count;
  end;

  procedure get_file_close_call_args (
    file f : text;
    variable valid : out boolean) is
  begin
    valid := file_close_call_valid;
  end;

  procedure std_file_close (
    file f : text) is
  begin
    file_close_call_count := file_close_call_count + 1;
    file_close_call_valid := true;
  end std_file_close;

  impure function get_writeline_call_count
    return natural is
  begin
    return writeline_call_count;
  end;

  procedure get_writeline_call_args (
    variable args : out writeline_call_args_t) is
  begin
    args := writeline_call_args;
  end;

  procedure std_writeline (
    file f : text;
    variable l : inout line) is
  begin
    writeline_call_count := writeline_call_count + 1;
    writeline_call_args.l := l;
    writeline_call_args.valid := true;
  end std_writeline;

end textio;
