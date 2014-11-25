-- This package provides mocks for the procedures and functions in lang.vhd
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

package lang is
  type report_call_args_t is record
    valid : boolean;
    msg     : line;
    level : severity_level;
  end record;
  
  type write_call_args_t is record
    valid : boolean;
    msg     : line;
  end record;
  
  procedure lang_report (
    constant msg     : in string;
    constant level : in severity_level);

  procedure get_report_call_args (
    variable args : out report_call_args_t);

  impure function get_report_call_count
    return natural;

  procedure lang_write (
    file f : text;
    constant msg : in string);
  
  procedure get_write_call_args (
    variable args : out write_call_args_t);

  impure function get_write_call_count
    return natural;
end lang;

package body lang is
  shared variable report_call_args : report_call_args_t := (false, null, note);
  shared variable report_call_count : natural := 0;
  shared variable write_call_args : write_call_args_t := (false, null);
  shared variable write_call_count : natural := 0;

  impure function get_report_call_count
    return natural is
  begin
    return report_call_count;
  end;

  procedure get_report_call_args (
    variable args : out report_call_args_t) is
    variable ret_val : report_call_args_t;
  begin
    write(ret_val.msg, report_call_args.msg.all);
    ret_val.level := report_call_args.level;
    ret_val.valid := report_call_args.valid;
    args := ret_val;
  end;
  
  procedure lang_report (
    constant msg     : in string;
    constant level : in severity_level) is
  begin  -- report_mock
    report_call_count := report_call_count + 1;
    if report_call_args.msg /= null then
      deallocate(report_call_args.msg);
    end if;
    write(report_call_args.msg, msg);
    report_call_args.level := level;
    report_call_args.valid := true;
  end lang_report;

  impure function get_write_call_count
    return natural is
  begin
    return write_call_count;
  end;

  procedure get_write_call_args (
    variable args : out write_call_args_t) is
    variable ret_val : write_call_args_t;
  begin
    write(ret_val.msg, write_call_args.msg.all);
    ret_val.valid := write_call_args.valid;
    args := ret_val;
  end;
  
  procedure lang_write (
    file f : text;
    constant msg     : in string) is
  begin  -- write_mock
    write_call_count := write_call_count + 1;
    if write_call_args.msg /= null then
      deallocate(write_call_args.msg);
    end if;
    write(write_call_args.msg, msg);
    write_call_args.valid := true;
  end lang_write;

end lang;
