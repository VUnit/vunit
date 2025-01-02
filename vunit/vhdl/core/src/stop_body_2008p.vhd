-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body stop_pkg is
  procedure stop(status : integer) is
  begin
    if status /= 0 then
      report "Stopping simulation with status " & integer'image(status) severity failure;
    end if;
    std.env.stop(status);
  end procedure;
end package body;
