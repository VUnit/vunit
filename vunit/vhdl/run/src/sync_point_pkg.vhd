-- Run base package provides fundamental run functionality.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

use work.run_pkg.all;
use work.id_pkg.all;
use work.sync_point_db_pkg.all;

package sync_point_pkg is
  procedure sync(signal sync_point : sync_point_t);
  procedure sync(signal sync_point : inout sync_point_t; id : id_t);
end package;

package body sync_point_pkg is
  procedure sync(signal sync_point : sync_point_t) is
  begin
    check(sync_point, "sync");

    wait_for_member_events_completion;

    if has_members(sync_point) then
      loop
        wait until timeout_notification(runner) or not has_members(sync_point);
        exit when not has_members(sync_point);
        show_timeout_debug_message(sync_point);
      end loop;
    end if;
  end;

  procedure sync(signal sync_point : inout sync_point_t; id : id_t) is
  begin
    leave(sync_point, id);
    sync(sync_point);
  end;

end package body;
