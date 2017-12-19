-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

-- Defines synchronization verification component interface VCI

context work.vunit_context;
context work.com_context;

package sync_pkg is

  -- Blocking: Wait until all operations requested from the VC have been finished
  procedure await_completion(signal event : inout event_t;
                             actor : actor_t);

  -- Non-blocking: Make VC wait for a delay before starting the next operation
  procedure wait_for_time(signal event : inout event_t;
                          actor : actor_t;
                          delay : delay_length);

  -- Message type definitions used by VC implementing the synchronization VCI
  constant await_completion_msg : msg_type_t := new_msg_type("await completion");
  constant wait_for_time_msg : msg_type_t := new_msg_type("wait for time");

  -- Standard implementation of synchronization VCI which may be used by VC
  procedure handle_sync_message(signal event : inout event_t;
                                variable msg_type : inout msg_type_t;
                                variable msg : inout msg_t);
end package;
