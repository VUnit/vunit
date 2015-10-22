-- This package provides special types used by the lang mocks under VHDL 93
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;
use work.lang_mock_types_pkg.all;

package lang_mock_special_types_pkg is
  subtype shared_report_call_args_t is report_call_args_t;
  subtype shared_write_call_args_t is write_call_args_t;

  procedure set (
    variable shared_report_call_args : inout shared_report_call_args_t;
    constant value                   : in    report_call_args_t);
  procedure get (
    variable shared_report_call_args : inout shared_report_call_args_t;
    variable value                   : out   report_call_args_t);

  procedure set (
    variable shared_write_call_args : inout shared_write_call_args_t;
    constant value                   : in   write_call_args_t);
  procedure get (
    variable shared_write_call_args : inout shared_write_call_args_t;
    variable value                   : out  write_call_args_t);

end package lang_mock_special_types_pkg;

package body lang_mock_special_types_pkg is
  procedure set (
    variable shared_report_call_args : inout shared_report_call_args_t;
    constant value                   : in    report_call_args_t) is
  begin
    shared_report_call_args := value;
  end;

  procedure get (
    variable shared_report_call_args : inout shared_report_call_args_t;
    variable value                   : out   report_call_args_t) is
  begin
    value := shared_report_call_args;
  end;

  procedure set (
    variable shared_write_call_args : inout shared_write_call_args_t;
    constant value                   : in    write_call_args_t) is
  begin
    shared_write_call_args := value;
  end;

  procedure get (
    variable shared_write_call_args : inout shared_write_call_args_t;
    variable value                   : out   write_call_args_t) is
  begin
    value := shared_write_call_args;
  end;

end package body lang_mock_special_types_pkg;
