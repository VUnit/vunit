-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

package assert_pkg is
  procedure assert_true(value : boolean; msg : string := "");
  procedure assert_false(value : boolean; msg : string := "");
  procedure assert_equal(got, expected, msg : string := "");
  procedure assert_equal(got, expected : integer; msg : string := "");
end package;

package body assert_pkg is
  impure function msg_suffix(msg : string) return string is
  begin
    if msg = "" then
      return "";
    else
      return " - " & msg;
    end if;
  end;

  procedure assert_true(value : boolean; msg : string := "") is
  begin
    assert value report "assert_true failed" & msg_suffix(msg) severity failure;
  end;

  procedure assert_false(value : boolean; msg : string := "") is
  begin
    assert not value report "assert_false failed" & msg_suffix(msg) severity failure;
  end;

  procedure assert_equal(got, expected, msg : string := "") is
  begin
    assert got = expected report "Got " & got & " expected " & expected & msg_suffix(msg) severity failure;
  end;

  procedure assert_equal(got, expected : integer; msg : string := "") is
  begin
    assert_equal(integer'image(got), integer'image(expected), msg);
  end;
end package body;
