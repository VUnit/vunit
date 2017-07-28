-- Com package provides a generic communication mechanism for testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use work.queue_pkg.all;
use work.queue_2008_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;
use work.codec_pkg.all;
use work.com_support_pkg.all;
use work.com_messenger_pkg.all;
use work.com_common_pkg.all;
use work.queue_pool_pkg.all;

use std.textio.all;

package body com_pkg is
  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  impure function create (name : string := ""; inbox_size : positive := positive'high) return actor_t is
  begin
    return messenger.create(name, inbox_size);
  end;

  impure function find (name : string; enable_deferred_creation : boolean := true) return actor_t is
  begin
    return messenger.find(name, enable_deferred_creation);
  end;

  impure function name (actor : actor_t) return string is
  begin
    return messenger.name(actor);
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

  impure function num_of_deferred_creations
    return natural is
  begin
    return messenger.num_of_deferred_creations;
  end;

  impure function inbox_size (actor : actor_t) return natural is
  begin
    return messenger.inbox_size(actor);
  end;

  impure function num_of_messages (actor : actor_t) return natural is
  begin
    return messenger.num_of_messages(actor, inbox);
  end;

  procedure resize_inbox (actor : actor_t; new_size : natural) is
  begin
    messenger.resize_inbox(actor, new_size);
  end;

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------
  impure function new_message (sender : actor_t := null_actor_c) return message_ptr_t is
    variable message : message_ptr_t;
  begin
    message        := new message_t;
    message.sender := sender;
    return message;
  end function;

  impure function compose (
    payload    : string       := "";
    sender     : actor_t      := null_actor_c;
    request_id : message_id_t := no_message_id_c)
    return message_ptr_t is
    variable message : message_ptr_t;
  begin
    message            := new message_t;
    message.sender     := sender;
    message.request_id := request_id;
    write(message.payload, payload);
    return message;
  end function compose;

  procedure copy (src : inout message_ptr_t; dst : inout message_ptr_t) is
  begin
    dst            := new message_t;
    dst.id         := src.id;
    dst.status     := src.status;
    dst.receiver   := src.receiver;
    dst.sender     := src.sender;
    dst.request_id := src.request_id;
    write(dst.payload, src.payload.all);
  end procedure copy;

  procedure delete (message : inout message_ptr_t) is
  begin
    if message /= null then
      deallocate(message.payload);
      deallocate(message);
    end if;
  end procedure delete;

  impure function create (sender : actor_t := null_actor_c) return msg_t is
    variable msg : msg_t;
  begin
    msg.sender := sender;
    msg.data   := allocate(queue_pool);
    return msg;
  end;

  procedure delete (msg : inout msg_t) is
  begin
    msg.id         := no_message_id_c;
    msg.status     := ok;
    msg.sender     := null_actor_c;
    msg.receiver   := null_actor_c;
    msg.request_id := no_message_id_c;
    recycle(queue_pool, msg.data);
  end procedure delete;

  procedure push(msg : msg_t; value : integer) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return integer is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : character) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return character is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : boolean) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return boolean is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : real) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return real is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : bit) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return bit is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : std_ulogic) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return std_ulogic is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : severity_level) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return severity_level is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : file_open_status) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return file_open_status is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : file_open_kind) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return file_open_kind is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : bit_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return bit_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : std_ulogic_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return std_ulogic_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : complex) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return complex is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : complex_polar) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return complex_polar is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_bit.unsigned) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_bit.unsigned is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_bit.signed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_bit.signed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_std.unsigned) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_std.unsigned is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_std.signed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_std.signed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : string) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return string is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : time) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return time is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : integer_vector_ptr_t) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return integer_vector_ptr_t is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : string_ptr_t) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return string_ptr_t is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : queue_t) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return queue_t is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : boolean_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return boolean_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : integer_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return integer_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : real_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return real_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : time_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return time_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ufixed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ufixed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : sfixed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return sfixed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : float) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return float is
  begin
    return pop(msg.data);
  end;

  -----------------------------------------------------------------------------
  -- Primary send and receive related subprograms
  -----------------------------------------------------------------------------
  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant mailbox_name : in    mailbox_name_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true) is
    variable receipt : receipt_t;
  begin
    check(message /= null, null_message_error);
    check(not messenger.unknown_actor(receiver), unknown_receiver_error);

    if messenger.is_full(receiver, mailbox_name) then
      wait on net until not messenger.is_full(receiver, mailbox_name) for timeout;
      check(not messenger.is_full(receiver, mailbox_name), full_inbox_error);
    end if;

    messenger.send(message.sender, receiver, mailbox_name, message.request_id, message.payload.all, receipt);
    message.id       := receipt.id;
    message.receiver := receiver;
    notify(net);

    if not keep_message then
      delete(message);
    end if;
  end;

  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true) is
    variable receipt : receipt_t;
  begin
    send(net, receiver, inbox, message, timeout, keep_message);
  end;

  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable message  : inout message_ptr_t;
    constant timeout  : in    time := max_timeout_c) is
    variable status                  : com_status_t;
    variable started_with_full_inbox : boolean;
  begin
    delete(message);
    wait_for_message(net, receiver, status, timeout);

    if not check(no_error_status(status, true), status) then
      return;
    end if;

    if status = ok then
      started_with_full_inbox := messenger.is_full(receiver, inbox);
      message                 := get_message(receiver);
      if started_with_full_inbox then
        notify(net);
      end if;
    else
      message          := new message_t;
      message.receiver := receiver;
      message.status   := status;
    end if;
  end;

  procedure reply (
    signal net            : inout network_t;
    variable request      : inout message_ptr_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true) is
  begin
    check(request.id /= no_message_id_c, reply_missing_request_id_error);
    message.request_id := request.id;
    message.sender     := request.receiver;

    if request.sender /= null_actor_c then
      send(net, request.sender, inbox, message, timeout, keep_message);
    else
      send(net, request.receiver, outbox, message, timeout, keep_message);
    end if;
  end;

  procedure receive_reply (
    signal net       : inout network_t;
    variable request : inout message_ptr_t;
    variable message : inout message_ptr_t;
    constant timeout : in    time := max_timeout_c) is
    variable status       : com_status_t;
    variable source_actor : actor_t;
    variable mailbox      : mailbox_name_t;
  begin
    delete(message);

    source_actor := request.sender when request.sender /= null_actor_c else request.receiver;
    mailbox      := inbox          when request.sender /= null_actor_c else outbox;

    wait_for_reply_stash_message(net, source_actor, mailbox, request.id, status, timeout);
    check(no_error_status(status, true), status);
    if status = ok then
      message := get_reply_stash_message(source_actor);
    else
      message          := new message_t;
      message.receiver := request.sender;
      message.status   := status;
    end if;
  end;

  procedure publish (
    signal net            : inout network_t;
    constant sender       : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true) is
  begin
    check(message /= null, null_message_error);
    message.sender   := sender;
    message.receiver := null_actor_c;

    if messenger.subscriber_inbox_is_full(message.sender, (published, outbound)) then
      wait on net until not messenger.subscriber_inbox_is_full(sender, (published, outbound)) for timeout;
      check(not messenger.subscriber_inbox_is_full(message.sender, (published, outbound)), full_inbox_error);
    end if;

    messenger.publish(message.sender, message.payload.all);
    notify(net);

    if not keep_message then
      delete(message);
    end if;
  end;



  procedure wait_on_subscribers (
    publisher    : actor_t;
    subscription_traffic_types : subscription_traffic_types_t;
    timeout      : time) is
  begin
    if messenger.subscriber_inbox_is_full(publisher, subscription_traffic_types) then
      wait on net until not messenger.subscriber_inbox_is_full(publisher, subscription_traffic_types) for timeout;
      check(not messenger.subscriber_inbox_is_full(publisher, subscription_traffic_types), full_inbox_error);
    end if;
  end procedure wait_on_subscribers;

  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant mailbox_name : in    mailbox_name_t;
    variable msg          : inout msg_t;
    constant timeout      : in    time := max_timeout_c) is
    variable t_start : time;
  begin
    if not check(msg.data /= null_queue, null_message_error) then
      return;
    end if;

    if not check(not messenger.unknown_actor(receiver), unknown_receiver_error) then
      return;
    end if;

    t_start := now;
    if messenger.is_full(receiver, mailbox_name) then
      wait on net until not messenger.is_full(receiver, mailbox_name) for timeout;
      check(not messenger.is_full(receiver, mailbox_name), full_inbox_error);
    end if;

    messenger.send(receiver, mailbox_name, msg);

    if msg.sender /= null_actor_c then
      if messenger.has_subscribers(msg.sender, outbound) then
        wait_on_subscribers(msg.sender, (0 => outbound), timeout);
        messenger.publish(msg.sender, msg, (0 => outbound));
      end if;
    end if;

    notify(net);
    recycle(queue_pool, msg.data);
  end;

  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable msg      : inout msg_t;
    constant timeout  : in    time := max_timeout_c) is
  begin
    send(net, receiver, inbox, msg, timeout);
  end;

  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable msg      : inout msg_t;
    constant timeout  : in    time := max_timeout_c) is
    variable status                  : com_status_t;
    variable started_with_full_inbox : boolean;
  begin
    delete(msg);
    wait_for_message(net, receiver, status, timeout);
    if not check(no_error_status(status), status) then
      return;
    end if;
    started_with_full_inbox := messenger.is_full(receiver, inbox);
    msg                     := get_message(receiver);

    if messenger.has_subscribers(receiver, inbound) then
      wait_on_subscribers(receiver, (0 => inbound), timeout);
      messenger.publish(receiver, msg, (0 => inbound));
    end if;

    if started_with_full_inbox or messenger.has_subscribers(receiver, inbound) then
      notify(net);
    end if;
  end;

  procedure reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout_c) is
  begin
    check(request_msg.id /= no_message_id_c, reply_missing_request_id_error);
    reply_msg.request_id := request_msg.id;
    reply_msg.sender     := request_msg.receiver;

    if request_msg.sender /= null_actor_c then
      send(net, request_msg.sender, inbox, reply_msg, timeout);
    else
      send(net, request_msg.receiver, outbox, reply_msg, timeout);
    end if;
  end;

  procedure receive_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout_c) is
    variable status       : com_status_t;
    variable source_actor : actor_t;
    variable mailbox      : mailbox_name_t;
    variable message      : message_ptr_t;
  begin
    delete(reply_msg);

    source_actor := request_msg.sender when request_msg.sender /= null_actor_c else request_msg.receiver;
    mailbox      := inbox              when request_msg.sender /= null_actor_c else outbox;

    wait_for_reply_stash_message(net, source_actor, mailbox, request_msg.id, status, timeout);
    check(no_error_status(status), status);
    message              := get_reply_stash_message(source_actor);
    reply_msg.id         := message.id;
    reply_msg.status     := message.status;
    reply_msg.sender     := message.sender;
    reply_msg.receiver   := message.receiver;
    reply_msg.request_id := message.request_id;
    reply_msg.data       := decode(message.payload.all);
    delete(message);
  end;

  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    variable msg     : inout msg_t;
    constant timeout : in    time := max_timeout_c) is
  begin
    wait_on_subscribers(sender, (published, outbound), timeout);
    messenger.publish(sender, msg, (published, outbound));
    notify(net);
    recycle(queue_pool, msg.data);
  end;

  -----------------------------------------------------------------------------
  -- Secondary send and receive related subprograms
  -----------------------------------------------------------------------------

  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable reply_message   : inout message_ptr_t;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false) is
    variable start : time;
  begin
    start := now;
    send(net, receiver, request_message, timeout, keep_message => true);
    receive_reply(net, request_message, reply_message, timeout - (now - start));
    if not keep_message then
      delete(request_message);
    end if;
  end;

  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable positive_ack    : out   boolean;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false) is
    variable start : time;
  begin
    start := now;
    send(net, receiver, request_message, timeout, keep_message => true);
    receive_reply(net, request_message, positive_ack, timeout - (now - start));
    if not keep_message then
      delete(request_message);
    end if;
  end;

  procedure publish (
    signal net            : inout network_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false) is
  begin
    publish(net, message.sender, message, timeout, keep_message);
  end;

  procedure acknowledge (
    signal net            : inout network_t;
    variable request      : inout message_ptr_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    message := compose(encode(positive_ack));
    reply(net, request, message, timeout, keep_message => false);
  end;

  procedure receive_reply (
    signal net            : inout network_t;
    variable request      : inout message_ptr_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    receive_reply(net, request, message, timeout);
    positive_ack := decode(message.payload.all);
    delete(message);
  end;




  procedure request (
    signal net           : inout network_t;
    constant receiver    : in    actor_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout_c) is
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
    constant timeout      : in    time := max_timeout_c) is
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
    constant timeout      : in    time    := max_timeout_c) is
    variable reply_msg : msg_t;
  begin
    reply_msg := create;
    push_boolean(reply_msg.data, positive_ack);
    reply(net, request_msg, reply_msg, timeout);
  end;

  procedure receive_reply (
    signal net            : inout network_t;
    variable request_msg  : inout msg_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c) is
    variable reply_msg : msg_t;
  begin
    receive_reply(net, request_msg, reply_msg, timeout);
    positive_ack := pop_boolean(reply_msg.data);
    delete(reply_msg);
  end;

  -----------------------------------------------------------------------------
  -- Low-level subprograms primarily used for handling timeout wihout error
  -----------------------------------------------------------------------------
  procedure wait_for_message (
    signal net        : in  network_t;
    constant receiver : in  actor_t;
    variable status   : out com_status_t;
    constant timeout  : in  time := max_timeout_c) is
  begin
    if not check(not messenger.deferred(receiver), deferred_receiver_error) then
      status := deferred_receiver_error;
      return;
    end if;

    status := ok;
    if not messenger.has_messages(receiver) then
      wait on net until messenger.has_messages(receiver) for timeout;
      if not messenger.has_messages(receiver) then
        status := work.com_types_pkg.timeout;
      end if;
    end if;
  end procedure wait_for_message;

  procedure wait_for_reply (
    signal net       : inout network_t;
    variable request : inout message_ptr_t;
    variable status  : out   com_status_t;
    constant timeout : in    time := max_timeout_c) is
  begin
    wait_for_reply_stash_message(net, request.sender, inbox, request.id, status, timeout);
  end;

  procedure wait_for_reply (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant receipt  : in    receipt_t;
    variable status   : out   com_status_t;
    constant timeout  : in    time := max_timeout_c) is
  begin
    wait_for_reply_stash_message(net, receiver, inbox, receipt.id, status, timeout);
  end;

  impure function has_message (actor : actor_t) return boolean is
  begin
    return messenger.has_messages(actor);
  end function has_message;

  impure function get_message (receiver : actor_t; delete_from_inbox : boolean := true) return message_ptr_t is
    variable message : message_ptr_t;
  begin
    check(messenger.has_messages(receiver), null_message_error);

    message            := new message_t;
    message.status     := ok;
    message.id         := messenger.get_first_message_id(receiver);
    message.request_id := messenger.get_first_message_request_id(receiver);
    message.sender     := messenger.get_first_message_sender(receiver);
    message.receiver   := receiver;
    write(message.payload, messenger.get_first_message_payload(receiver));
    if delete_from_inbox then
      messenger.delete_first_envelope(receiver);
    end if;

    return message;
  end function get_message;

  impure function get_reply (
    receiver          : actor_t;
    receipt           : receipt_t;
    delete_from_inbox : boolean := true)
    return message_ptr_t is
  begin
    check(messenger.get_reply_stash_message_request_id(receiver) = receipt.id, unknown_request_id_error);

    return get_reply_stash_message(receiver, delete_from_inbox);
  end;

  procedure get_reply (
    variable request           : inout message_ptr_t;
    variable reply             : inout message_ptr_t;
    constant delete_from_inbox : in    boolean := true) is
  begin
    check(messenger.get_reply_stash_message_request_id(request.sender) = request.id, unknown_request_id_error);
    reply := get_reply_stash_message(request.sender, delete_from_inbox);
  end;





  procedure wait_for_reply (
    signal net       : inout network_t;
    variable request_msg : inout msg_t;
    variable status  : out   com_status_t;
    constant timeout : in    time := max_timeout_c) is
    variable source_actor : actor_t;
    variable mailbox      : mailbox_name_t;
  begin
    source_actor := request_msg.sender when request_msg.sender /= null_actor_c else request_msg.receiver;
    mailbox      := inbox              when request_msg.sender /= null_actor_c else outbox;

    wait_for_reply_stash_message(net, source_actor, mailbox, request_msg.id, status, timeout);
  end;

  impure function get_message (receiver : actor_t) return msg_t is
    variable msg : msg_t;
  begin
    check(messenger.has_messages(receiver), null_message_error);

    msg.status     := ok;
    msg.id         := messenger.get_first_message_id(receiver);
    msg.request_id := messenger.get_first_message_request_id(receiver);
    msg.sender     := messenger.get_first_message_sender(receiver);
    msg.receiver   := receiver;
    msg.data       := decode(messenger.get_first_message_payload(receiver));
    messenger.delete_first_envelope(receiver);

    return msg;
  end function get_message;

  procedure get_reply (variable request_msg : inout msg_t; variable reply_msg : inout msg_t) is
    variable source_actor : actor_t;
    variable message      : message_ptr_t;
  begin
    source_actor := request_msg.sender when request_msg.sender /= null_actor_c else request_msg.receiver;

    check(messenger.has_reply_stash_message(source_actor), null_message_error);
    message := get_reply_stash_message(source_actor);
    check(message.request_id = request_msg.id, unknown_request_id_error);
    reply_msg.id         := message.id;
    reply_msg.status     := message.status;
    reply_msg.sender     := message.sender;
    reply_msg.receiver   := message.receiver;
    reply_msg.request_id := message.request_id;
    reply_msg.data       := decode(message.payload.all);
    delete(message);
  end;

  -----------------------------------------------------------------------------
  -- Subscriptions
  -----------------------------------------------------------------------------
  procedure subscribe (
    subscriber : actor_t;
    publisher : actor_t;
    traffic_type : subscription_traffic_type_t := published) is
  begin
    messenger.subscribe(subscriber, publisher, traffic_type);
  end procedure subscribe;

  procedure unsubscribe (
    subscriber : actor_t;
    publisher : actor_t;
    traffic_type : subscription_traffic_type_t := published) is
  begin
    messenger.unsubscribe(subscriber, publisher, traffic_type);
  end procedure unsubscribe;

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

  procedure deprecated (msg : string) is
  begin
    messenger.deprecated(msg);
  end;

  procedure push(queue : queue_t; variable value : inout msg_t) is
  begin
    push(queue, value.id);
    push(queue, com_status_t'pos(value.status));
    push(queue, value.sender.id);
    push(queue, value.receiver.id);
    push(queue, value.request_id);
    push_queue_ref(queue, value.data);
  end;

  impure function pop(queue : queue_t) return msg_t is
    variable ret_val : msg_t := create;
  begin
    ret_val.id          := pop(queue);
    ret_val.status      := com_status_t'val(integer'(pop(queue)));
    ret_val.sender.id   := pop(queue);
    ret_val.receiver.id := pop(queue);
    ret_val.request_id  := pop(queue);
    ret_val.data        := pop_queue_ref(queue);

    return ret_val;
  end;
end package body com_pkg;
