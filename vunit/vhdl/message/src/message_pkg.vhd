-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
use work.integer_vector_ptr_pkg.all;
use work.integer_vector_ptr_pool_pkg.all;
use work.queue_pkg.all;
use work.queue_pool_pkg.all;

package message_pkg is
  subtype event_t is std_logic;
  constant no_event : event_t := 'Z';
  signal event : event_t := no_event;

  constant int_pool : integer_vector_ptr_pool_t := allocate;
  constant queue_pool : queue_pool_t := allocate;

  type inbox_t is record
    meta_data : integer_vector_ptr_t; -- private
    msg_queue : queue_t; -- private
  end record;
  type inbox_vec_t is array (natural range <>) of inbox_t;
  constant null_inbox : inbox_t := (meta_data => null_ptr,
                                  msg_queue => null_queue);

  type reply_t is record
    meta_data : integer_vector_ptr_t; -- private
    return_queue : queue_t; -- private
    data : queue_t;
  end record;
  constant null_reply : reply_t := (meta_data => null_ptr,
                                    return_queue => null_queue,
                                    data => null_queue);

  type msg_t is record
    data : queue_t;
  end record;
  constant null_msg : msg_t := (data => null_queue);

  impure function pop(queue : queue_t) return reply_t;
  impure function pop(queue : queue_t) return msg_t;
  procedure push(queue : queue_t; reply : reply_t);
  procedure push(queue : queue_t; msg : msg_t);

  impure function allocate return msg_t;
  procedure recycle(variable msg : inout msg_t);
  procedure recycle(variable reply : inout reply_t);

  constant num_words_per_message : integer := 3*num_words_per_queue + 1;
  constant infinite_inbox_length : positive := integer'high/num_words_per_message;

  impure function new_inbox(max_length : positive := 1) return inbox_t;

  procedure set_max_length(constant inbox : inbox_t; constant max_length : positive);
  impure function get_max_length(inbox : inbox_t) return positive;
  impure function get_length(inbox : inbox_t) return natural;

  constant max_timeout : time := 1 hr;

  procedure wait_until_not_full(signal event : inout event_t;
                                constant inbox : inbox_t;
                                constant timeout : time := max_timeout);

  procedure wait_until_not_empty(signal event : inout event_t;
                                 constant inbox : inbox_t;
                                 constant timeout : time := max_timeout);

  -- Send message to inbox without expecting reply
  procedure send(signal event : inout event_t; constant inbox : inbox_t;
                 variable msg : inout msg_t;
                 constant timeout : time := max_timeout);

  -- Send message to inbox expecting a reply
  procedure send(signal event : inout event_t; constant inbox : inbox_t;
                 variable msg : inout msg_t;
                 variable reply : inout reply_t;
                 constant timeout : time := max_timeout);

  -- Receive message from any of multiple inboxes intending to send a reply
  procedure recv(signal event : inout event_t; constant inbox : inbox_t;
                 variable msg : inout msg_t;
                 variable reply : inout reply_t;
                 constant timeout : time := max_timeout);

  -- Receive message from inbox without intending to send a reply
  procedure recv(signal event : inout event_t; constant inbox : inbox_t;
                 variable msg : inout msg_t;
                 constant timeout : time := max_timeout);

  -- Receive message from inbox intending to send a reply
  procedure recv(signal event : inout event_t; constant inboxes : inbox_vec_t;
                 variable msg : inout msg_t;
                 variable reply : inout reply_t;
                 constant timeout : time := max_timeout);

  -- Receive message from any of multiple inboxes without intending to send a reply
  procedure recv(signal event : inout event_t; constant inboxes : inbox_vec_t;
                 variable msg : inout msg_t;
                 constant timeout : time := max_timeout);

  -- Send the reply
  procedure send_reply(signal event : inout event_t;
                       variable reply : inout reply_t);

  -- Receive a reply
  procedure recv_reply(signal event : inout event_t;
                       variable reply : inout reply_t;
                       constant timeout : time := max_timeout);
end package;

package body message_pkg is
  constant max_length_idx : natural := 0;
  constant no_selected_count_idx : natural := 1;
  constant meta_data_len : natural := 2;

  impure function new_inbox(max_length : positive := 1) return inbox_t is
    variable inbox : inbox_t;
  begin
    inbox := (meta_data => allocate(meta_data_len),
             msg_queue => allocate(queue_pool));
    set_max_length(inbox, max_length);
    set(inbox.meta_data, no_selected_count_idx, 0);
    return inbox;
  end;

  procedure set_max_length(constant inbox : inbox_t; constant max_length : positive) is
  begin
    set(inbox.meta_data, max_length_idx, max_length);
  end;

  impure function get_max_length(inbox : inbox_t) return positive is
  begin
    return get(inbox.meta_data, max_length_idx);
  end;

  impure function get_length(inbox : inbox_t) return natural is
  begin
    return length(inbox.msg_queue) / num_words_per_message;
  end;

  impure function is_empty(inbox : inbox_t) return boolean is
  begin
    return get_length(inbox) = 0;
  end;

  impure function is_full(inbox : inbox_t) return boolean is
  begin
    return get_length(inbox) = get_max_length(inbox);
  end;

  impure function all_empty(inboxes : inbox_vec_t) return boolean is
  begin
    for i in inboxes'range loop
      if not is_empty(inboxes(i)) then
        return false;
      end if;
    end loop;
    return true;
  end;

  impure function select_inbox(inboxes : inbox_vec_t) return inbox_t is
    -- Use counter for the number of times this inbox was not selected
    -- This is to ensure that no inbox can block out the others infinetly
    variable count, max_count : integer := -1;
    variable inbox : inbox_t := null_inbox;
  begin
    for i in inboxes'range loop
      if not is_empty(inboxes(i)) then
        count := get(inboxes(i).meta_data, no_selected_count_idx);
        if count > max_count then
          max_count := count;
          inbox := inboxes(i);
        end if;
      end if;
    end loop;

    -- Reset count of selected inbox
    if inbox /= null_inbox then
      set(inbox.meta_data, no_selected_count_idx, 0);
    end if;

    return inbox;
  end function;

  procedure notify(signal event : inout event_t) is
  begin
    if event = '1' then
      wait until event = 'Z';
    end if;

    event <= '1';
    wait until event = '1';
    event <= 'Z';
  end procedure;


  procedure set_reply_not_sent_yet(constant reply : reply_t) is
  begin
    set(reply.meta_data, 0, 0);
  end;

  procedure set_reply_sent(constant reply : reply_t) is
  begin
    set(reply.meta_data, 0, 1);
  end;

  procedure set_reply_received(constant reply : reply_t) is
  begin
    set(reply.meta_data, 0, 2);
  end;

  impure function reply_is_not_sent_yet(reply : reply_t) return boolean is
  begin
    return get(reply.meta_data, 0) = 0;
  end;

  impure function reply_is_sent(reply : reply_t) return boolean is
  begin
    return get(reply.meta_data, 0) = 1;
  end;

  impure function reply_is_received(reply : reply_t) return boolean is
  begin
    return get(reply.meta_data, 0) = 2;
  end;

  impure function allocate return reply_t is
    variable reply : reply_t;
  begin
    reply.meta_data := allocate(int_pool, 1);
    reply.return_queue := allocate(queue_pool);
    reply.data := allocate(queue_pool);
    set_reply_not_sent_yet(reply);
    return reply;
  end;

  impure function allocate return msg_t is
    variable msg : msg_t;
  begin
    msg.data := allocate(queue_pool);
    return msg;
  end;

  procedure recycle(variable msg : inout msg_t) is
  begin
    recycle(queue_pool, msg.data);
  end;

  procedure recycle(variable reply : inout reply_t) is
  begin
    recycle(int_pool, reply.meta_data);
    recycle(queue_pool, reply.return_queue);
    recycle(queue_pool, reply.data);
  end;

  procedure push(queue : queue_t; reply : reply_t) is
  begin
    push_integer_vector_ptr_ref(queue, reply.meta_data);
    push_queue_ref(queue, reply.data);
    push_queue_ref(queue, reply.return_queue);
  end;

  impure function pop(queue : queue_t) return reply_t is
    variable reply : reply_t;
  begin
    reply.meta_data := pop_integer_vector_ptr_ref(queue);
    reply.data := pop_queue_ref(queue);
    reply.return_queue := pop_queue_ref(queue);
    return reply;
  end;

  procedure push(queue : queue_t; msg : msg_t) is
  begin
    push_queue_ref(queue, msg.data);
  end;

  impure function pop(queue : queue_t) return msg_t is
    variable msg : msg_t;
  begin
    msg.data := pop_queue_ref(queue);
    return msg;
  end;

  procedure wait_until_not_full(signal event : inout event_t;
                                constant inbox : inbox_t;
                                constant timeout : time := max_timeout) is
  begin
    if is_full(inbox) then
      wait on event until not is_full(inbox) for timeout;
    end if;
    assert not is_full(inbox) report "Send timeout after " & to_string(timeout) & " due to full inbox";
  end;

  procedure wait_until_not_empty(signal event : inout event_t;
                                 constant inbox : inbox_t;
                                 constant timeout : time := max_timeout) is
  begin
    if is_empty(inbox) then
      wait on event until not is_empty(inbox) for timeout;
    end if;
    assert not is_empty(inbox) report "Recv timeout after " & to_string(timeout) & " due to empty inbox";
  end;

  procedure send_helper(signal event : inout event_t; constant inbox : inbox_t;
                        variable msg : inout msg_t;
                        variable reply : inout reply_t;
                        constant timeout : time := max_timeout) is
  begin
    wait_until_not_full(event, inbox, timeout);

    push(inbox.msg_queue, msg);
    -- Ownership of data is transfered to other side
    msg.data := null_queue;

    push(inbox.msg_queue, reply);
    -- Ownership of data is transfered to other side
    reply.data := null_queue;

    notify(event);
  end procedure;

  procedure send(signal event : inout event_t; constant inbox : inbox_t;
                 variable msg : inout msg_t;
                 variable reply : inout reply_t;
                 constant timeout : time := max_timeout) is
  begin
    reply := allocate;
    send_helper(event, inbox, msg, reply, timeout);
  end procedure;

  procedure send(signal event : inout event_t; constant inbox : inbox_t;
                 variable msg : inout msg_t;
                 constant timeout : time := max_timeout) is
    variable reply : reply_t := null_reply;
  begin
    send_helper(event, inbox, msg, reply, timeout);
  end procedure;

  procedure recv(signal event : inout event_t; constant inbox : inbox_t;
                 variable msg : inout msg_t;
                 variable reply : inout reply_t;
                 constant timeout : time := max_timeout) is
  begin
    wait_until_not_empty(event, inbox, timeout);
    msg := pop(inbox.msg_queue);
    reply := pop(inbox.msg_queue);
    notify(event);
  end procedure;

  procedure recv(signal event : inout event_t; constant inbox : inbox_t;
                 variable msg : inout msg_t;
                 constant timeout : time := max_timeout) is
    variable reply : reply_t;
  begin
    recv(event, inbox, msg, reply, timeout);
    recycle(reply);
  end procedure;

  procedure recv(signal event : inout event_t; constant inboxes : inbox_vec_t;
                 variable msg : inout msg_t;
                 variable reply : inout reply_t;
                 constant timeout : time := max_timeout) is
    variable inbox : inbox_t;
  begin
    if all_empty(inboxes) then
      wait on event until not all_empty(inboxes) for timeout;
    end if;
    assert not all_empty(inboxes) report "Recv timeout after " & to_string(timeout) & " due to empty inboxes";

    inbox := select_inbox(inboxes);
    msg := pop(inbox.msg_queue);
    reply := pop(inbox.msg_queue);
    notify(event);
  end procedure;

  procedure recv(signal event : inout event_t; constant inboxes : inbox_vec_t;
                 variable msg : inout msg_t;
                 constant timeout : time := max_timeout) is
    variable reply : reply_t;
  begin
    recv(event, inboxes, msg, reply, timeout);
    recycle(reply);
  end procedure;

  procedure send_reply(signal event : inout event_t;
                       variable reply : inout reply_t) is
  begin
    assert reply_is_not_sent_yet(reply) report "Reply should not be sent or received at this point";

    push_queue_ref(reply.return_queue, reply.data);
    set_reply_sent(reply);
    -- Ownership of data is transfered to other side
    reply := null_reply;
    notify(event);
  end procedure;

  procedure recv_reply(signal event : inout event_t;
                       variable reply : inout reply_t;
                       constant timeout : time := max_timeout) is
  begin
    assert not reply_is_received(reply) report "Reply should not already be received at this point";

    if not reply_is_sent(reply) then
      wait on event until reply_is_sent(reply) for timeout;
    end if;
    assert reply_is_sent(reply) report "Recv reply timeout after " & to_string(timeout) & " due to reply not send yet";

    reply.data := pop_queue_ref(reply.return_queue);
    reply.return_queue := null_queue;
    set_reply_received(reply);
  end procedure;

end package body;
