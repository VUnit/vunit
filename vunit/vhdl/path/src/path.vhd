-- This package contains useful operation for manipulate path names
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2015, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ops.all;

package path is
  function join (
    constant p1 : string;
    constant p2 : string := "")
    return string;
end package;

package body path is
  function join (
    constant p1 : string;
    constant p2 : string := "")
    return string is
  begin
    if p1 = "" then
      return p2;
    elsif p2 = "" then
      return rstrip(p1, "/\");
    else
      return rstrip(p1, "/\") & "/" & p2;
    end if;
  end;
end package body;
