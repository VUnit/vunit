-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.queue_pkg.all;
use work.msg_types_pkg.all;

package sync_pkg is
  constant await_completion_msg : msg_type_t := new_msg_type("await completion");
  constant wait_for_time_msg : msg_type_t := new_msg_type("wait for time");

  procedure await_completion(signal event : inout event_t;
                             actor : actor_t);
  procedure wait_for_time(signal event : inout event_t;
                          actor : actor_t;
                          delay : delay_length);

  procedure handle_sync_message(signal event : inout event_t;
                                variable msg_type : inout msg_type_t;
                                variable msg : inout msg_t);
end package;

package body sync_pkg is
  procedure await_completion(signal event : inout event_t;
                             actor : actor_t) is
    variable msg, reply_msg : msg_t;
  begin
    msg := create;
    push_msg_type(msg, await_completion_msg);
    send(event, actor, msg);
    receive_reply(event, msg, reply_msg);
    delete(reply_msg);
  end;

  procedure wait_for_time(signal event : inout event_t;
                          actor : actor_t;
                          delay : delay_length) is
    variable msg : msg_t;
  begin
    msg := create;
    push_msg_type(msg, wait_for_time_msg);
    push_time(msg, delay);
    send(event, actor, msg);
  end;

  procedure handle_sync_message(signal event : inout event_t;
                                variable msg_type : inout msg_type_t;
                                variable msg : inout msg_t) is
    variable reply_msg : msg_t;
    variable delay : delay_length;
  begin
    if msg_type = await_completion_msg then
      handle_message(msg_type);
      reply_msg := create;
      reply(event, msg, reply_msg);

    elsif msg_type = wait_for_time_msg then
      handle_message(msg_type);
      delay := pop_time(msg);
      wait for delay;
    end if;
  end;

end package body;
