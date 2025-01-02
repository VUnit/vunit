-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.string_ops.all;

package com_support_pkg is

  procedure check (
    expr        : boolean;
    err         : com_status_t;
    msg         : string  := "";
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string  := "");
  procedure check_failed (
    err         : com_error_t;
    msg         : string  := "";
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string  := "");
  impure function check (
    expr        : boolean;
    err         : com_status_t;
    msg         : string  := "";
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string  := "") return boolean;
end package com_support_pkg;

package body com_support_pkg is

  procedure check_failed (
    err         : com_error_t;
    msg         : string  := "";
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string  := "") is
    constant err_msg             : string := replace(com_error_t'image(err), '_', ' ');
    alias err_msg_aligned        : string(1 to err_msg'length) is err_msg;
    constant err_msg_capitalized : string := upper(err_msg_aligned) & ".";
  begin
    if msg /= "" then
      failure(com_logger, err_msg_capitalized & " " & msg, path_offset + 1, line_num => line_num, file_name => file_name);
    else
      failure(com_logger, err_msg_capitalized, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  procedure check (
    expr        : boolean;
    err         : com_status_t;
    msg         : string  := "";
    path_offset : natural := 0;
    line_num    : natural := 0;
    file_name   : string  := "") is
  begin
    if not expr then
      check_failed(err, msg, path_offset + 1, line_num => line_num, file_name => file_name);
    end if;
  end;

  impure function check (
    expr      : boolean;
    err       : com_status_t;
    msg       : string  := "";
    path_offset : natural := 0;
    line_num  : natural := 0;
    file_name : string  := "") return boolean is
  begin
    check(expr, err, msg, path_offset + 1, line_num => line_num, file_name => file_name);
    return expr;
  end;
end package body com_support_pkg;
