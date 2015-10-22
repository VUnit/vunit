-- This package provides mocks for the procedures and functions in lang.vhd
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

use work.test_types.all;
use work.test_type_methods.all;
use work.lang_mock_types_pkg.all;
use work.lang_mock_special_types_pkg.all;

use std.textio.all;

package lang is
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
  shared variable report_call_args : shared_report_call_args_t;
  shared variable write_call_args : shared_write_call_args_t;
  shared variable report_call_counts : shared_natural;
  shared variable write_call_counts  : shared_natural;
  impure function get_report_call_count
    return natural is
    variable ret_val : integer;
  begin
    get(report_call_counts, ret_val);
    return natural(ret_val);
  end;

  procedure get_report_call_args (
    variable args : out report_call_args_t) is
  begin
    get(report_call_args, args);
  end;

  procedure lang_report (
    constant msg     : in string;
    constant level : in severity_level) is
    variable args : report_call_args_t;
  begin
    add(report_call_counts, 1);
    args.msg(1 to msg'length) := msg;
    args.msg_length := msg'length;
    args.level := level;
    args.valid := true;
    set(report_call_args, args);
  end lang_report;

  impure function get_write_call_count
    return natural is
    variable ret_val : integer;
  begin
    get(write_call_counts, ret_val);
    return natural(ret_val);
  end;

  procedure get_write_call_args (
    variable args : out write_call_args_t) is
  begin
    get(write_call_args, args);
  end;

  procedure lang_write (
    file f : text;
    constant msg     : in string) is
    variable args : write_call_args_t;
  begin
    add(write_call_counts, 1);
    args.msg(1 to msg'length) := msg;
    args.msg_length := msg'length;
    args.valid := true;
    set(write_call_args, args);
  end lang_write;

end lang;
