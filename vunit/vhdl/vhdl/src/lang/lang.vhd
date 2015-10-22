-- This package provides procedure and function equivalents to some VHDL
-- constructs such that they can be mocked during testing
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

use std.textio.all;

package lang is
  procedure lang_report (
    constant msg     : in string;
    constant level : in severity_level);

  procedure lang_write (
    file f : text;
    constant msg : in string);
end lang;

package body lang is
    procedure lang_report (
      constant msg     : in string;
      constant level : in severity_level) is
    begin
      report msg severity level;
    end lang_report;

  procedure lang_write (
    file f : text;
    constant msg : in string) is
  begin
      write(f, msg);
  end lang_write;
end lang;
