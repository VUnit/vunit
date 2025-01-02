-- This package contains useful operation for manipulate path names
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.string_ops.all;
use std.textio.all;

package path is
  function join (
    constant p1 : string;
    constant p2 : string := "";
    constant p3 : string := "";
    constant p4 : string := "";
    constant p5 : string := "";
    constant p6 : string := "";
    constant p7 : string := "";
    constant p8 : string := "";
    constant p9 : string := "";
    constant p10 : string := "")
    return string;
end package;

package body path is
  function join (
    constant p1 : string;
    constant p2 : string := "";
    constant p3 : string := "";
    constant p4 : string := "";
    constant p5 : string := "";
    constant p6 : string := "";
    constant p7 : string := "";
    constant p8 : string := "";
    constant p9 : string := "";
    constant p10 : string := "")
    return string is
    variable inputs : work.string_ops.line_vector(1 to 10);
    variable result : line;
  begin
    write(inputs(1), p1);
    write(inputs(2), p2);
    write(inputs(3), p3);
    write(inputs(4), p4);
    write(inputs(5), p5);
    write(inputs(6), p6);
    write(inputs(7), p7);
    write(inputs(8), p8);
    write(inputs(9), p9);
    write(inputs(10), p10);

    write(result, string'(""));
    for i in 1 to 10 loop
      if rstrip(inputs(i).all, "/\") /= "" then
        write(result, rstrip(inputs(i).all, "/\") & "/");
      end if;
      deallocate(inputs(i));
    end loop;

    return rstrip(result.all, "/");
  end;
end package body;
