-- Com package provides a generic communication mechanism for testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.com_common_pkg.all;
use work.com_messenger_pkg.all;
use work.com_support_pkg.all;
use work.logger_pkg.all;
use work.queue_pkg.all;
use work.queue_pool_pkg.all;

use std.textio.all;

package body com_pkg is
  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  impure function new_actor (
    name        : string   := "";
    inbox_size  : positive := positive'high;
    outbox_size : positive := positive'high
    ) return actor_t is
  begin
    return messenger.create(name, inbox_size, outbox_size);
  end;

  impure function new_actor (
    id : id_t;
    inbox_size : positive := positive'high;
    outbox_size : positive := positive'high
  ) return actor_t is
  begin
    return messenger.create(id, inbox_size, outbox_size);
  end;

  impure function find (name : string; enable_deferred_creation : boolean := true) return actor_t is
  begin
    return messenger.find(name, enable_deferred_creation);
  end;

  impure function find (id : id_t; enable_deferred_creation : boolean := true) return actor_t is
  begin
    return messenger.find(id, enable_deferred_creation);
  end;

  impure function name (actor : actor_t) return string is
  begin
    return messenger.name(actor);
  end;

  impure function get_id(actor : actor_t) return id_t is
  begin
    return messenger.get_id(actor);
  end;

  procedure destroy (actor : inout actor_t) is
  begin
    messenger.destroy(actor);
  end;

  procedure reset_messenger is
  begin
    messenger.reset_messenger;
  end;

  impure function num_of_actors
    return natural is
  begin
    return messenger.num_of_actors;
  end;

  impure function is_deferred(actor : actor_t) return boolean is
  begin
    return messenger.is_deferred(actor);
  end;

  impure function num_of_deferred_creations
    return natural is
  begin
    return messenger.num_of_deferred_creations;
  end;

  impure function num_of_messages (actor : actor_t; mailbox_id : mailbox_id_t := inbox) return natural is
  begin
    return messenger.num_of_messages(actor, mailbox_id);
  end;

  impure function mailbox_size (actor : actor_t; mailbox_id : mailbox_id_t := inbox) return natural is
  begin
    return messenger.mailbox_size(actor, mailbox_id);
  end;

  procedure resize_mailbox (actor : actor_t; new_size : natural; mailbox_id : mailbox_id_t := inbox) is
  begin
    messenger.resize_mailbox(actor, new_size, mailbox_id);
  end;

  -----------------------------------------------------------------------------
  -- Primary send and receive related subprograms
  -----------------------------------------------------------------------------
  procedure wait_on_subscribers (
    publisher                  : actor_t;
    subscription_traffic_types : subscription_traffic_types_t;
    timeout                    : time) is
  begin
    if messenger.subscriber_inbox_is_full(publisher, subscription_traffic_types) then
      wait on net until not messenger.subscriber_inbox_is_full(publisher, subscription_traffic_types) for timeout;
      check(not messenger.subscriber_inbox_is_full(publisher, subscription_traffic_types), full_inbox_error);
    end if;
  end procedure wait_on_subscribers;

  procedure send (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant mailbox_id : in    mailbox_id_t;
    variable msg        : inout msg_t;
    constant timeout    : in    time := max_timeout) is
    variable t_start : time;
  begin
    if not check(msg.data /= null_queue, null_message_error) then
      return;
    end if;

    if not check(not messenger.unknown_actor(receiver), unknown_receiver_error) then
      return;
    end if;

    t_start := now;
    if messenger.is_full(receiver, mailbox_id) then
      wait on net until not messenger.is_full(receiver, mailbox_id) for timeout;
      check(not messenger.is_full(receiver, mailbox_id), full_inbox_error);
    end if;

    messenger.send(receiver, mailbox_id, msg);

    if msg.sender /= null_actor then
      if messenger.has_subscribers(msg.sender, outbound) then
        wait_on_subscribers(msg.sender, (0 => outbound), timeout - (now - t_start));
        messenger.internal_publish(msg.sender, msg, (0 => outbound));
      end if;
    end if;

    if (mailbox_id = inbox) and messenger.has_subscribers(receiver, inbound) then
      wait_on_subscribers(receiver, (0 => inbound), timeout - (now - t_start));
      messenger.internal_publish(receiver, msg, (0 => inbound));
    end if;

    notify_net(net);
    msg.data := null_queue;
  end;

  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable msg      : inout msg_t;
    constant timeout  : in    time := max_timeout) is
  begin
    send(net, receiver, inbox, msg, timeout);
  end;

  procedure send (
    signal net         : inout network_t;
    constant receivers : in    actor_vec_t;
    variable msg       : inout msg_t;
    constant timeout   : in    time := max_timeout) is
    variable msg_to_send : msg_t;
    variable t_start     : time;
  begin
    if receivers'length = 0 then
      delete(msg);
      return;
    end if;

    t_start := now;
    for i in receivers'range loop
      if i = receivers'right then
        send(net, receivers(i), msg, timeout - (now - t_start));
      else
        msg_to_send := copy(msg);
        send(net, receivers(i), msg_to_send, timeout - (now - t_start));
      end if;
    end loop;
  end;

  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable msg      : inout msg_t;
    constant timeout  : in    time := max_timeout) is
  begin
    receive(net, actor_vec_t'(0 => receiver), msg, timeout);
  end;

  procedure receive (
    signal net         : inout network_t;
    constant receivers : in    actor_vec_t;
    variable msg       : inout msg_t;
    constant timeout   : in    time := max_timeout) is
    variable status   : com_status_t;
    variable receiver : actor_t;
  begin
    delete(msg);
    wait_for_message(net, receivers, status, timeout);
    if not check(no_error_status(status), status) then
      return;
    end if;

    for i in receivers'range loop
      receiver := receivers(i);
      if has_message(receiver) then
        get_message(net, receiver, msg);
        exit;
      end if;
    end loop;
  end;

  procedure reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout) is
  begin
    check(request_msg.id /= no_message_id, reply_missing_request_id_error);
    reply_msg.request_id := request_msg.id;
    reply_msg.sender     := request_msg.receiver;

    if request_msg.sender /= null_actor then
      send(net, request_msg.sender, inbox, reply_msg, timeout);
    else
      send(net, request_msg.receiver, outbox, reply_msg, timeout);
    end if;
  end;

  procedure receive_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout) is
    variable status       : com_status_t;
  begin
    delete(reply_msg);

    wait_for_reply(net, request_msg, status, timeout);
    check(no_error_status(status), status);

    get_reply(net, request_msg, reply_msg);
  end;

  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    variable msg     : inout msg_t;
    constant timeout : in    time := max_timeout) is
  begin
    wait_on_subscribers(sender, (published, outbound), timeout);
    messenger.publish(sender, msg, (published, outbound));
    notify_net(net);
    recycle(queue_pool, msg.data);
  end;

  impure function peek_message(
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return msg_t is
    variable msg : msg_t;
  begin
    if position > messenger.num_of_messages(actor, mailbox_id) - 1 then
      failure(com_logger, "Peeking non-existing position.");
      return msg;
    end if;

    msg      := messenger.get_all_but_payload(actor, position, mailbox_id);
    msg.data := decode(messenger.get_payload(actor, position, mailbox_id));

    return msg;
  end;

  -----------------------------------------------------------------------------
  -- Secondary send and receive related subprograms
  -----------------------------------------------------------------------------
  procedure request (
    signal net           : inout network_t;
    constant receiver    : in    actor_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout) is
    variable start : time;
  begin
    start := now;
    send(net, receiver, request_msg, timeout);
    receive_reply(net, request_msg, reply_msg, timeout - (now - start));
  end;

  procedure request (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable request_msg  : inout msg_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout) is
    variable start : time;
  begin
    start := now;
    send(net, receiver, request_msg, timeout);
    receive_reply(net, request_msg, positive_ack, timeout - (now - start));
  end;

  procedure acknowledge (
    signal net            : inout network_t;
    variable request_msg  : inout msg_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout) is
    variable reply_msg : msg_t;
  begin
    reply_msg := new_msg;
    push_boolean(reply_msg, positive_ack);
    reply(net, request_msg, reply_msg, timeout);
  end;

  procedure receive_reply (
    signal net            : inout network_t;
    variable request_msg  : inout msg_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout) is
    variable reply_msg : msg_t;
  begin
    receive_reply(net, request_msg, reply_msg, timeout);
    positive_ack := pop_boolean(reply_msg);
    delete(reply_msg);
  end;

  -----------------------------------------------------------------------------
  -- Low-level subprograms primarily used for handling timeout wihout error
  -----------------------------------------------------------------------------
  procedure wait_for_message (
    signal net        : in  network_t;
    constant receiver : in  actor_t;
    variable status   : out com_status_t;
    constant timeout  : in  time := max_timeout) is
  begin
    wait_for_message(net, actor_vec_t'(0 => receiver), status, timeout);
  end procedure wait_for_message;

  procedure wait_for_message (
    signal net         : in  network_t;
    constant receivers : in  actor_vec_t;
    variable status    : out com_status_t;
    constant timeout   : in  time := max_timeout) is
  begin
    for i in receivers'range loop
      if not check(not messenger.deferred(receivers(i)), deferred_receiver_error) then
        status := deferred_receiver_error;
        return;
      end if;
    end loop;

    status := ok;
    if not messenger.has_messages(receivers) then
      wait on net until messenger.has_messages(receivers) for timeout;
      if not messenger.has_messages(receivers) then
        status := work.com_types_pkg.timeout;
      end if;
    end if;
  end procedure wait_for_message;

  impure function has_message (actor : actor_t) return boolean is
  begin
    return messenger.has_messages(actor);
  end function has_message;

  procedure get_message (
    signal net   : inout network_t;
    actor        :       actor_t;
    position     :       natural;
    mailbox_id   :       mailbox_id_t;
    variable msg : inout msg_t) is
    variable started_with_full_mailbox : boolean;
  begin
    started_with_full_mailbox := messenger.is_full(actor, mailbox_id);

    msg      := messenger.get_all_but_payload(actor, position, mailbox_id);
    msg.data := decode(messenger.get_payload(actor, position, mailbox_id));
    messenger.delete_envelope(actor, position, mailbox_id);

    if started_with_full_mailbox then
      notify_net(net);
    end if;
  end;

  procedure get_message (signal net : inout network_t; receiver : actor_t; variable msg : inout msg_t) is
  begin
    check(messenger.has_messages(receiver), null_message_error);
    get_message(net, receiver, 0, inbox, msg);
  end;

  procedure wait_for_reply_message (
    signal net          : inout network_t;
    constant actor      : in    actor_t;
    constant mailbox_id : in    mailbox_id_t := inbox;
    constant request_id : in    message_id_t;
    variable status     : out   com_status_t;
    constant timeout    : in    time         := max_timeout) is

  begin
    check(not messenger.deferred(actor), deferred_receiver_error);

    status := ok;
    if messenger.find_reply_message(actor, request_id, mailbox_id) = -1 then
      wait on net until messenger.find_reply_message(actor, request_id, mailbox_id) /= -1 for timeout;
      if messenger.find_reply_message(actor, request_id, mailbox_id) = -1 then
        status := work.com_types_pkg.timeout;
      end if;
    end if;
  end procedure;

  procedure wait_for_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable status      : out   com_status_t;
    constant timeout     : in    time := max_timeout) is
    variable source_actor : actor_t;
    variable mailbox      : mailbox_id_t;
  begin
    source_actor := request_msg.sender when request_msg.sender /= null_actor else request_msg.receiver;
    mailbox      := inbox              when request_msg.sender /= null_actor else outbox;

    wait_for_reply_message(net, source_actor, mailbox, request_msg.id, status, timeout);
  end;

  procedure get_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t) is
    variable source_actor : actor_t;
    variable mailbox_id   : mailbox_id_t;
    variable position     : integer;
  begin
    source_actor := request_msg.sender when request_msg.sender /= null_actor else request_msg.receiver;
    mailbox_id   := inbox              when request_msg.sender /= null_actor else outbox;
    position     := messenger.find_reply_message(source_actor, request_msg.id, mailbox_id);

    check(position /= -1, null_message_error);

    -- For testing purposes when logger is mocked and the check procedure returns
    if position = -1 then
      return;
    end if;

    get_message(net, source_actor, position, mailbox_id, reply_msg);
  end;

  -----------------------------------------------------------------------------
  -- Subscriptions
  -----------------------------------------------------------------------------
  procedure subscribe (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t := published) is
  begin
    messenger.subscribe(subscriber, publisher, traffic_type);
  end procedure subscribe;

  procedure unsubscribe (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t := published) is
  begin
    messenger.unsubscribe(subscriber, publisher, traffic_type);
  end procedure unsubscribe;

  -----------------------------------------------------------------------------
  -- Debugging
  -----------------------------------------------------------------------------
  impure function to_string(msg : msg_t) return string is
  begin
    return messenger.to_string(msg);
  end;

  impure function peek_all_messages(actor : actor_t; mailbox_id : mailbox_id_t := inbox) return msg_vec_ptr_t is
    variable msg_vec_ptr : msg_vec_ptr_t;
    constant n_messages  : natural := messenger.num_of_messages(actor, mailbox_id);
  begin
    if n_messages = 0 then
      return null;
    end if;

    msg_vec_ptr := new msg_vec_t(0 to n_messages - 1);
    for i in msg_vec_ptr'range loop
      msg_vec_ptr(i) := peek_message(actor, i, mailbox_id);
    end loop;

    return msg_vec_ptr;
  end;

  impure function get_mailbox_state(actor : actor_t; mailbox_id : mailbox_id_t := inbox) return mailbox_state_t is
    variable state : mailbox_state_t;
  begin
    state.id       := mailbox_id;
    state.size     := mailbox_size(actor, mailbox_id);
    state.messages := peek_all_messages(actor, mailbox_id);

    return state;
  end;

  procedure deallocate(variable mailbox_state : inout mailbox_state_t) is
  begin
    mailbox_state.id := inbox;
    mailbox_state.size := 0;
    deallocate(mailbox_state.messages);
  end;

  impure function get_mailbox_state_string (
    actor      : actor_t;
    mailbox_id : mailbox_id_t := inbox;
    indent     : string       := "") return string is
    variable messages : msg_vec_ptr_t := peek_all_messages(actor, mailbox_id);
    variable l        : line;
  begin
    write(l, indent & "Mailbox: " & mailbox_id_t'image(mailbox_id) & LF);
    write(l, indent & "  Size: " & to_string(mailbox_size(actor, mailbox_id)) & LF);
    write(l, indent & "  Messages:");
    if messages /= null then
      for i in messages'range loop
        write(l, LF & indent & "    " & to_string(i) & ". " & messenger.to_string(messages(i)));
      end loop;
    end if;

    deallocate(messages);

    return l.all;
  end;

  impure function get_subscriptions(subscriber : actor_t) return subscription_vec_ptr_t is
    constant subscriptions : subscription_vec_t := messenger.get_subscriptions(subscriber);
  begin
    if subscriptions'length = 0 then
      return null;
    else
      return new subscription_vec_t'(subscriptions);
    end if;
  end;

  impure function get_subscribers(publisher : actor_t) return subscription_vec_ptr_t is
    constant subscriptions : subscription_vec_t := messenger.get_subscribers(publisher);
  begin
    if subscriptions'length = 0 then
      return null;
    else
      return new subscription_vec_t'(subscriptions);
    end if;
  end;

  impure function get_actor_state(actor : actor_t) return actor_state_t is
    variable state : actor_state_t;
  begin
    write(state.name, name(actor));
    state.is_deferred   := is_deferred(actor);
    state.inbox         := get_mailbox_state(actor, inbox);
    state.outbox        := get_mailbox_state(actor, outbox);
    state.subscriptions := get_subscriptions(actor);
    state.subscribers   := get_subscribers(actor);

    return state;
  end;

  procedure deallocate(variable actor_state : inout actor_state_t) is
  begin
    deallocate(actor_state.name);
    actor_state.is_deferred := false;
    deallocate(actor_state.inbox);
    deallocate(actor_state.outbox);
    deallocate(actor_state.subscriptions);
    deallocate(actor_state.subscribers);
  end;

  impure function get_actor_state_string (actor : actor_t; indent : string := "") return string is
    variable state        : actor_state_t := get_actor_state(actor);
    variable l            : line;
    variable traffic_type : subscription_traffic_type_t;
  begin
    write(l, indent & "Name: " & state.name.all & LF);

    write(l, indent & "  Is deferred: ");
    if state.is_deferred then
      write(l, "yes" & LF);
    else
      write(l, "no" & LF);
    end if;

    write(l, get_mailbox_state_string(actor, inbox, indent & "  ") & LF);
    write(l, get_mailbox_state_string(actor, outbox, indent & "  ") & LF);

    write(l, indent & "  Subscriptions:");
    if state.subscriptions /= null then
      for i in state.subscriptions'range loop
        traffic_type := state.subscriptions(i).traffic_type;
        write(l, LF & indent & "    " & subscription_traffic_type_t'image(traffic_type) & " traffic ");
        if state.subscriptions(i).traffic_type = inbound then
          write(l, indent & "to ");
        else
          write(l, indent & "from ");
        end if;
        write(l, name(state.subscriptions(i).publisher));
      end loop;
    end if;

    write(l, LF & indent & "  Subscribers:");
    if state.Subscribers /= null then
      for i in state.subscribers'range loop
        write(l, LF & indent & "    " & name(state.subscribers(i).subscriber) & " subscribes to ");
        write(l, subscription_traffic_type_t'image(state.subscribers(i).traffic_type) & " traffic");
      end loop;
    end if;

    return l.all;
  end;

  impure function get_messenger_state return messenger_state_t is
    variable state                    : messenger_state_t;
    constant actors                   : actor_vec_t := messenger.get_all_actors;
    constant n_deferred               : natural     := messenger.num_of_deferred_creations;
    constant n_active                 : natural     := actors'length - n_deferred;
    variable active_idx, deferred_idx : natural     := 0;
  begin
    if n_active > 0 then
      state.active_actors := new actor_state_vec_t(0 to n_active - 1);
    end if;

    if n_deferred > 0 then
      state.deferred_actors := new actor_state_vec_t(0 to n_deferred - 1);
    end if;

    for i in actors'range loop
      if is_deferred(actors(i)) then
        state.deferred_actors(deferred_idx) := get_actor_state(actors(i));
        deferred_idx                        := deferred_idx + 1;
      else
        state.active_actors(active_idx) := get_actor_state(actors(i));
        active_idx                      := active_idx + 1;
      end if;
    end loop;

    return state;
  end;

  procedure deallocate(variable messenger_state : inout messenger_state_t) is
  begin
    if messenger_state.active_actors /= null then
      for a in messenger_state.active_actors'range loop
        deallocate(messenger_state.active_actors(a));
      end loop;
      deallocate(messenger_state.active_actors);
    end if;

    if messenger_state.deferred_actors /= null then
      for a in messenger_state.deferred_actors'range loop
        deallocate(messenger_state.deferred_actors(a));
      end loop;
      deallocate(messenger_state.deferred_actors);
    end if;
  end;

  impure function get_messenger_state_string(indent : string := "") return string is
    constant actors                            : actor_vec_t := messenger.get_all_actors;
    variable l, active_actors, deferred_actors : line;
    variable first_deferred                    : boolean     := true;
  begin
    for i in actors'range loop
      if is_deferred(actors(i)) then
        if first_deferred then
          first_deferred := false;
        else
          write(deferred_actors, LF & LF);
        end if;
        write(deferred_actors, get_actor_state_string(actors(i), indent & "  "));
      else
        write(active_actors, get_actor_state_string(actors(i), indent & "  ") & LF & LF);
      end if;
    end loop;


    write(l, indent & "Active actors:" & LF);
    if active_actors /= null then
      write(l, active_actors.all);
    end if;

    write(l, indent & "Deferred actors:");
    if deferred_actors /= null then
      write(l, LF & deferred_actors.all);
    end if;

    return l.all;
  end;

  -----------------------------------------------------------------------------
  -- Misc
  -----------------------------------------------------------------------------
  procedure allow_timeout is
  begin
    messenger.allow_timeout;
  end;

  procedure allow_deprecated is
  begin
    messenger.allow_deprecated;
  end;

end package body com_pkg;
