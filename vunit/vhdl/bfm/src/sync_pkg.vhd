-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

-- Defines synchronization verification component interface VCI

context work.vunit_context;
context work.com_context;

package sync_pkg is

  -- Handle to talk to a VC implementing the sync VCI
  alias sync_handle_t is actor_t;

  -- Blocking: Wait until all operations requested from the VC have been finished
  procedure wait_for_idle(signal event : inout event_t;
                          handle : sync_handle_t);

  -- Non-blocking: Make VC wait for a delay before starting the next operation
  procedure wait_for_time(signal event : inout event_t;
                          handle : sync_handle_t;
                          delay : delay_length);

  -- Message type definitions used by VC implementing the synchronization VCI
  constant wait_for_idle_msg : msg_type_t := new_msg_type("wait for idle");
  constant wait_for_time_msg : msg_type_t := new_msg_type("wait for time");

  -- Standard implementation of synchronization VCI which may be used by VC
  procedure handle_sync_message(signal event : inout event_t;
                                variable msg_type : inout msg_type_t;
                                variable msg : inout msg_t);
end package;
