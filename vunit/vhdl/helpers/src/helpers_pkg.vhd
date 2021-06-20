-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

package helpers_pkg is
    function calc_width(d : positive) return natural;
end package;

package body helpers_pkg is
    function calc_width(d : positive) return natural is
      variable i : natural;
      variable v : natural := d-1;
    begin
      while v > 0 loop
        v := v/2;
        i := i + 1;
      end loop;
      return i;
    end;
end package body;
