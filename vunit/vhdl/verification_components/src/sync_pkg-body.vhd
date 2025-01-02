-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body sync_pkg is
  procedure wait_until_idle(signal net : inout network_t;
                            handle     :       sync_handle_t;
                            timeout    :       delay_length := max_timeout) is
    variable msg, reply_msg : msg_t;
  begin
    msg := new_msg(wait_until_idle_msg);
    request(net, handle, msg, reply_msg, timeout);
    delete(reply_msg);
  end;

  procedure wait_for_time(signal net : inout network_t;
                          handle     :       sync_handle_t;
                          delay      :       delay_length) is
    variable msg : msg_t;
  begin
    msg := new_msg(wait_for_time_msg);
    push_time(msg, delay);
    send(net, handle, msg);
  end;

  procedure handle_wait_until_idle(signal net        : inout network_t;
                                   variable msg_type : inout msg_type_t;
                                   variable msg      : inout msg_t) is
    variable reply_msg : msg_t;
  begin
    if msg_type = wait_until_idle_msg then
      handle_message(msg_type);
      reply_msg := new_msg(wait_until_idle_reply_msg);
      reply(net, msg, reply_msg);
    end if;
  end;

  procedure handle_wait_for_time(signal net        : inout network_t;
                                 variable msg_type : inout msg_type_t;
                                 variable msg      : inout msg_t) is
    variable delay : delay_length;
  begin
    if msg_type = wait_for_time_msg then
      handle_message(msg_type);
      delay := pop_time(msg);
      wait for delay;
    end if;
  end;

  procedure handle_sync_message(signal net        : inout network_t;
                                variable msg_type : inout msg_type_t;
                                variable msg      : inout msg_t) is
  begin
    handle_wait_until_idle(net, msg_type, msg);
    handle_wait_for_time(net, msg_type, msg);
  end;

end package body;
