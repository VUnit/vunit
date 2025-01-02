-- Com deprecated package provides deprecated functionality and APIs. These
-- will eventually be removed
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.codec_pkg.all;
use work.com_support_pkg.all;
use work.com_messenger_pkg.all;
use work.com_types_pkg.all;
use work.com_pkg.all;
use work.com_common_pkg.all;
use work.event_common_pkg.all;

use std.textio.all;

package com_deprecated_pkg is
  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  constant null_actor_c : actor_t := null_actor;
  impure function create (name :       string := ""; inbox_size : positive := positive'high) return actor_t;
  procedure destroy (actor     : inout actor_t; status : out com_status_t);
  impure function inbox_size (actor      : actor_t) return natural;

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------
  constant no_message_id_c : message_id_t := no_message_id;
  impure function new_message (sender : actor_t := null_actor_c) return message_ptr_t;
  impure function compose (
    payload    : string       := "";
    sender     : actor_t      := null_actor_c;
    request_id : message_id_t := no_message_id_c)
    return message_ptr_t;
  procedure copy (src : inout message_ptr_t; dst : inout message_ptr_t);
  procedure delete (message : inout message_ptr_t);

  -----------------------------------------------------------------------------
  -- Primary send and receive related subprograms
  -----------------------------------------------------------------------------
  constant max_timeout_c : time := max_timeout;
  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true);
  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable message  : inout message_ptr_t;
    constant timeout  : in    time := max_timeout_c);
  procedure reply (
    signal net            : inout network_t;
    variable request      : inout message_ptr_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true);
  procedure receive_reply (
    signal net       : inout network_t;
    variable request : inout message_ptr_t;
    variable message : inout message_ptr_t;
    constant timeout : in    time := max_timeout_c);
  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true);
  procedure reply (
    signal net          : inout network_t;
    constant sender     : in    actor_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    variable receipt    : out   receipt_t;
    constant timeout    : in    time   := max_timeout_c);
  procedure reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    variable receipt    : out   receipt_t;
    constant timeout    : in    time   := max_timeout_c);
  procedure reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
  procedure receive_reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    variable message    : inout message_ptr_t;
    constant timeout    : in    time := max_timeout_c);
  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    variable positive_ack : out   boolean;
    variable status       : out   com_status_t;
    constant timeout      : in    time := max_timeout_c);

  -----------------------------------------------------------------------------
  -- Secondary send and receive related subprograms
  -----------------------------------------------------------------------------
  procedure send (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable receipt  : out   receipt_t;
    constant timeout  : in    time   := max_timeout_c);
  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable receipt  : out   receipt_t;
    constant timeout  : in    time   := max_timeout_c);
  procedure request (
    signal net               : inout network_t;
    constant sender          : in    actor_t;
    constant receiver        : in    actor_t;
    constant request_payload : in    string := "";
    variable reply_message   : inout message_ptr_t;
    constant timeout         : in    time   := max_timeout_c);
  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable reply_message   : inout message_ptr_t;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false);
  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable positive_ack    : out   boolean;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false);
  procedure publish (
    signal net            : inout network_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
  procedure request (
    signal net               : inout network_t;
    constant sender          : in    actor_t;
    constant receiver        : in    actor_t;
    constant request_payload : in    string := "";
    variable positive_ack    : out   boolean;
    variable status          : out   com_status_t;
    constant timeout         : in    time   := max_timeout_c);
  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable positive_ack    : out   boolean;
    variable status          : out   com_status_t;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false);
  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    constant payload : in    string := "";
    variable status  : out   com_status_t;
    constant timeout : in    time   := max_timeout_c);
  procedure publish (
    signal net            : inout network_t;
    variable message      : inout message_ptr_t;
    variable status       : out   com_status_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
  procedure acknowledge (
    signal net            : inout network_t;
    constant sender       : in    actor_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c);
  procedure acknowledge (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c);

  -----------------------------------------------------------------------------
  -- Low-level subprograms primarily used for handling timeout wihout error
  -----------------------------------------------------------------------------
  impure function has_messages (actor   : actor_t) return boolean;
  impure function get_message (receiver : actor_t; delete_from_inbox : boolean := true) return message_ptr_t;

  procedure wait_for_messages (
    signal net               : in  network_t;
    constant receiver        : in  actor_t;
    variable status          : out com_status_t;
    constant receive_timeout : in  time := max_timeout_c);

  -----------------------------------------------------------------------------
  -- Receive related subprograms
  -----------------------------------------------------------------------------
  procedure subscribe (
    constant subscriber : in  actor_t;
    constant publisher  : in  actor_t;
    variable status     : out com_status_t);
  procedure unsubscribe (
    constant subscriber : in  actor_t;
    constant publisher  : in  actor_t;
    variable status     : out com_status_t);
  impure function num_of_missed_messages (actor : actor_t) return natural;

end package;

package body com_deprecated_pkg is
  procedure deprecated (msg : string) is
  begin
    messenger.deprecated(msg);
  end;

  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  impure function create (name : string := ""; inbox_size : positive := positive'high) return actor_t is
  begin
    deprecated("create() instead of new_actor()");
    return new_actor(name, inbox_size);
  end;

  procedure destroy (actor : inout actor_t; status : out com_status_t) is
  begin
    deprecated("destroy() with status output");
    status := ok;
    messenger.destroy(actor);
  end;

  impure function inbox_size (actor : actor_t) return natural is
  begin
    deprecated("inbox_size() instead of mailbox_size()");
    return messenger.mailbox_size(actor, inbox);
  end;

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------
  impure function new_message (sender : actor_t := null_actor_c) return message_ptr_t is
    variable message : message_ptr_t;
  begin
    deprecated("new_message()");
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
    deprecated("compose()");
    message            := new message_t;
    message.sender     := sender;
    message.request_id := request_id;
    write(message.payload, payload);
    return message;
  end function compose;

  procedure copy (src : inout message_ptr_t; dst : inout message_ptr_t) is
  begin
    deprecated("copy() based on message_ptr_t");
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
    deprecated("delete() based on message_ptr_t");
    if message /= null then
      deallocate(message.payload);
      deallocate(message);
    end if;
  end procedure delete;

  -----------------------------------------------------------------------------
  -- Primary send and receive related subprograms
  -----------------------------------------------------------------------------
  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant mailbox_id : in    mailbox_id_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true) is
    variable receipt : receipt_t;
  begin
    deprecated("send() based on message_ptr_t");
    check(message /= null, null_message_error);
    check(not messenger.unknown_actor(receiver), unknown_receiver_error);

    if messenger.is_full(receiver, mailbox_id) then
      wait on net until not messenger.is_full(receiver, mailbox_id) for timeout;
      check(not messenger.is_full(receiver, mailbox_id), full_inbox_error);
    end if;

    messenger.send(message.sender, receiver, mailbox_id, message.request_id, message.payload.all, receipt);
    message.id       := receipt.id;
    message.receiver := receiver;
    notify_net(net);

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
    deprecated("receive() based on message_ptr_t");
    delete(message);
    wait_for_message(net, receiver, status, timeout);

    if not check(no_error_status(status, true), status) then
      return;
    end if;

    if status = ok then
      started_with_full_inbox := messenger.is_full(receiver, inbox);
      message                 := get_message(receiver);
      if started_with_full_inbox then
        notify_net(net);
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
    deprecated("reply() based on message_ptr_t");
    check(request.id /= no_message_id_c, reply_missing_request_id_error);
    message.request_id := request.id;
    message.sender     := request.receiver;

    if request.sender /= null_actor_c then
      send(net, request.sender, inbox, message, timeout, keep_message);
    else
      send(net, request.receiver, outbox, message, timeout, keep_message);
    end if;
  end;

  procedure wait_for_reply_stash_message (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant mailbox_id : in    mailbox_id_t := inbox;
    constant request_id : in    message_id_t;
    variable status     : out   com_status_t;
    constant timeout    : in    time         := max_timeout_c) is
    variable started_with_full_inbox : boolean := false;
  begin
    check(not messenger.deferred(receiver), deferred_receiver_error);

    status := ok;
    if mailbox_id = inbox then
      started_with_full_inbox := messenger.is_full(receiver, inbox);
    end if;

    if messenger.has_reply_stash_message(receiver, request_id) then
      return;
    elsif messenger.find_and_stash_reply_message(receiver, request_id, mailbox_id) then
      if started_with_full_inbox then
        notify_net(net);
      end if;
      return;
    else
      wait on net until messenger.find_and_stash_reply_message(receiver, request_id, mailbox_id) for timeout;
      if not messenger.has_reply_stash_message(receiver, request_id) then
        status := work.com_types_pkg.timeout;
      elsif started_with_full_inbox then
        notify_net(net);
      end if;
    end if;
  end procedure wait_for_reply_stash_message;

  impure function get_reply_stash_message (
    receiver          : actor_t;
    clear_reply_stash : boolean := true)
    return message_ptr_t is
    variable message : message_ptr_t;
  begin
    check(messenger.has_reply_stash_message(receiver), null_message_error);

    message            := new message_t;
    message.status     := ok;
    message.id         := messenger.get_reply_stash_message_id(receiver);
    message.request_id := messenger.get_reply_stash_message_request_id(receiver);
    message.sender     := messenger.get_reply_stash_message_sender(receiver);
    message.receiver   := messenger.get_reply_stash_message_receiver(receiver);
    write(message.payload, messenger.get_reply_stash_message_payload(receiver));
    if clear_reply_stash then
      messenger.clear_reply_stash(receiver);
    end if;

    return message;
  end function get_reply_stash_message;

  procedure receive_reply (
    signal net       : inout network_t;
    variable request : inout message_ptr_t;
    variable message : inout message_ptr_t;
    constant timeout : in    time := max_timeout_c) is
    variable status       : com_status_t;
    variable source_actor : actor_t;
    variable mailbox      : mailbox_id_t;
  begin
    deprecated("receive_reply() based on message_ptr_t");
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

  --
  procedure publish (
    signal net            : inout network_t;
    constant sender       : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true) is
  begin
    deprecated("publish() based on message_ptr_t");
    check(message /= null, null_message_error);
    message.sender   := sender;
    message.receiver := null_actor_c;

    if messenger.subscriber_inbox_is_full(message.sender, (published, outbound)) then
      wait on net until not messenger.subscriber_inbox_is_full(sender, (published, outbound)) for timeout;
      check(not messenger.subscriber_inbox_is_full(message.sender, (published, outbound)), full_inbox_error);
    end if;

    messenger.publish(message.sender, message.payload.all);
    notify_net(net);

    if not keep_message then
      delete(message);
    end if;
  end;
  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true) is
  begin
    deprecated("send() with message and receipt. Use send() without receipt and look at message.id instead");
    check(message /= null, null_message_error);
    check(not messenger.unknown_actor(receiver), unknown_receiver_error);

    if messenger.is_full(receiver, inbox) then
      wait on net until not messenger.is_full(receiver, inbox) for timeout;
      check(not messenger.is_full(receiver, inbox), full_inbox_error);
    end if;

    messenger.send(message.sender, receiver, inbox, message.request_id, message.payload.all, receipt);
    message.id       := receipt.id;
    message.receiver := receiver;
    notify_net(net);

    if not keep_message then
      delete(message);
    end if;
  end;

  --
  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant receipt      : in    receipt_t;
    variable positive_ack : out   boolean;
    variable status       : out   com_status_t;
    constant timeout      : in    time := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("receive_reply() with status output. Use without or wait_for_reply() if accepting timeout");
    wait_for_reply_stash_message(net, receiver, inbox, receipt.id, status, timeout);
    check(no_error_status(status, true), status);
    if status = ok then
      message      := get_reply_stash_message(receiver);
      status       := message.status;
      positive_ack := decode(message.payload.all);
      delete(message);
    else
      positive_ack := false;
    end if;
  end;

  --
  procedure receive_reply (
    signal net            : inout network_t;
    variable request      : inout message_ptr_t;
    variable positive_ack : out   boolean;
    variable status       : out   com_status_t;
    constant timeout      : in    time := max_timeout_c) is
    constant receipt : receipt_t := (status => ok, id => request.id);
  begin
    receive_reply(net, request.sender, receipt, positive_ack, status, timeout);
  end;

  procedure receive_reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    variable message    : inout message_ptr_t;
    constant timeout    : in    time := max_timeout_c) is
    variable status : com_status_t;
  begin
    deprecated("receive_reply() with request ID input. Use send receipt or message input instead");
    delete(message);
    wait_for_reply_stash_message(net, receiver, inbox, request_id, status, timeout);
    if status = ok then
      message := get_reply_stash_message(receiver);
    else
      message        := new message_t;
      message.status := status;
    end if;
  end;

  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    variable positive_ack : out   boolean;
    variable status       : out   com_status_t;
    constant timeout      : in    time := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("receive_reply() with request ID input. Use send receipt or message input instead");
    receive_reply(net, receiver, request_id, message, timeout);
    if message.status = ok then
      positive_ack := decode(message.payload.all);
    else
      positive_ack := false;
    end if;

    status := message.status;
  end;

  procedure reply (
    signal net          : inout network_t;
    constant sender     : in    actor_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    variable receipt    : out   receipt_t;
    constant timeout    : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("reply() with sender (already known by requestor)");
    deprecated("reply() with receipt. A reply being a request for which a reply is expected is not common ");
    message := compose(payload, sender, request_id);
    reply(net, receiver, message, receipt, timeout);
  end;

  procedure reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false) is
  begin
    deprecated("reply() with receipt. A reply being a request for which a reply is expected is not common ");
    check(message.request_id /= no_message_id_c, reply_missing_request_id_error);

    send(net, receiver, message, receipt, timeout, keep_message);
  end;

  procedure reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    variable receipt    : out   receipt_t;
    constant timeout    : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("reply() with receipt. A reply being a request for which a reply is expected is not common ");
    message := compose(payload, request_id => request_id);
    reply(net, receiver, message, receipt, timeout);
  end;

  -----------------------------------------------------------------------------
  -- Secondary send and receive related subprograms
  -----------------------------------------------------------------------------
  procedure send (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable receipt  : out   receipt_t;
    constant timeout  : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("send() with string payload");
    message := compose(payload, sender);
    send(net, receiver, message, timeout, keep_message => true);
    receipt := (status                                 => ok, id => message.id);
    delete(message);
  end;
  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable receipt  : out   receipt_t;
    constant timeout  : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("send() with string payload");
    message := compose(payload);
    send(net, receiver, message, timeout, keep_message => true);
    receipt := (status                                 => ok, id => message.id);
    delete(message);
  end;

  procedure request (
    signal net               : inout network_t;
    constant sender          : in    actor_t;
    constant receiver        : in    actor_t;
    constant request_payload : in    string := "";
    variable reply_message   : inout message_ptr_t;
    constant timeout         : in    time   := max_timeout_c) is
    variable request_message : message_ptr_t;
  begin
    deprecated("request() with string payload");
    request_message := compose(request_payload, sender);
    request(net, receiver, request_message, reply_message, timeout);
  end;

  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable reply_message   : inout message_ptr_t;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false) is
    variable start : time;
  begin
    deprecated("request() based on message_ptr_t");
    start := now;
    send(net, receiver, request_message, timeout, keep_message => true);
    receive_reply(net, request_message, reply_message, timeout - (now - start));
    if not keep_message then
      delete(request_message);
    end if;
  end;

  procedure request (
    signal net               : inout network_t;
    constant sender          : in    actor_t;
    constant receiver        : in    actor_t;
    constant request_payload : in    string := "";
    variable positive_ack    : out   boolean;
    variable status          : out   com_status_t;
    constant timeout         : in    time   := max_timeout_c) is
    variable request_message : message_ptr_t;
  begin
    deprecated("request() with status. use request() without status or send + wait_for_reply for polling requests");
    request_message := compose(request_payload, sender);
    request(net, receiver, request_message, positive_ack, status, timeout);
  end;

  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable positive_ack    : out   boolean;
    variable status          : out   com_status_t;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false) is
    variable start : time;
  begin
    deprecated("request() with status. use request() without status or send + wait_for_reply for polling requests");
    start := now;
    send(net, receiver, request_message, timeout, keep_message => true);
    receive_reply(net, request_message, positive_ack, status, timeout - (now - start));
    if not keep_message then
      delete(request_message);
    end if;
  end;

  --
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
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable positive_ack    : out   boolean;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false) is
    variable start : time;
  begin
    deprecated("request() based on message_ptr_t");
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
    constant sender       : in    actor_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("acknowledge() with sender (already known by requestor)");
    deprecated("acknowledge() with receipt. An acknowledge being a request for which a reply is expected is not common ");
    message := compose(encode(positive_ack), sender, request_id);
    send(net, receiver, message, receipt, timeout);
  end;

  procedure acknowledge (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c) is
  begin
    deprecated("acknowledge() with receipt. An acknowledge being a request for which a reply is expected is not common ");
    acknowledge(net, null_actor_c, receiver, request_id, positive_ack, receipt, timeout);
  end;


  -----------------------------------------------------------------------------
  -- Low-level subprograms primarily used for handling timeout wihout error
  -----------------------------------------------------------------------------
  impure function has_messages (actor : actor_t) return boolean is
  begin
    deprecated("has_messages() with old naming. Use has_message() instead");
    return has_message(actor);
  end function has_messages;

  impure function get_message (receiver : actor_t; delete_from_inbox : boolean := true) return message_ptr_t is
    variable message : message_ptr_t;
  begin
    deprecated("get_message() based on message_ptr_t");
    check(messenger.has_messages(receiver), null_message_error);

    message            := new message_t;
    message.status     := ok;
    message.id         := messenger.get_id(receiver);
    message.request_id := messenger.get_request_id(receiver);
    message.sender     := messenger.get_sender(receiver);
    message.receiver   := receiver;
    write(message.payload, messenger.get_payload(receiver));
    if delete_from_inbox then
      messenger.delete_envelope(receiver);
    end if;

    return message;
  end function get_message;

  procedure wait_for_messages (
    signal net               : in  network_t;
    constant receiver        : in  actor_t;
    variable status          : out com_status_t;
    constant receive_timeout : in  time := max_timeout_c) is
  begin
    deprecated("wait_for_messages() with old naming. Use wait_for_message() instead");
    wait_for_message(net, receiver, status, receive_timeout);
  end procedure wait_for_messages;


  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    constant payload : in    string := "";
    variable status  : out   com_status_t;
    constant timeout : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("publish() with status output");
    status  := ok;
    message := compose(payload, sender);
    publish(net, message, status, timeout);
  end;

  procedure publish (
    signal net            : inout network_t;
    variable message      : inout message_ptr_t;
    variable status       : out   com_status_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false) is
  begin
    deprecated("publish() with status output");
    check(message /= null, null_message_error);

    status := ok;
    if messenger.subscriber_inbox_is_full(message.sender, (published, outbound)) then
      wait on net until not messenger.subscriber_inbox_is_full(message.sender, (published, outbound)) for timeout;
      check(not messenger.subscriber_inbox_is_full(message.sender, (published, outbound)), full_inbox_error);
    end if;

    messenger.publish(message.sender, message.payload.all);
    notify_net(net);

    if not keep_message then
      delete(message);
    end if;
  end;

  -----------------------------------------------------------------------------
  -- Receive related subprograms
  -----------------------------------------------------------------------------
  procedure subscribe (
    constant subscriber : in  actor_t;
    constant publisher  : in  actor_t;
    variable status     : out com_status_t) is
  begin
    deprecated("subscribe() with status output");
    status := ok;
    messenger.subscribe(subscriber, publisher);
  end procedure subscribe;

  procedure unsubscribe (
    constant subscriber : in  actor_t;
    constant publisher  : in  actor_t;
    variable status     : out com_status_t) is
  begin
    deprecated("subscribe() with status output");
    status := ok;
    messenger.unsubscribe(subscriber, publisher);
  end procedure unsubscribe;

  impure function num_of_missed_messages (actor : actor_t) return natural is
  begin
    deprecated("num_of_missed_messages(). Missed messages not allowed.");
    return 0;
  end num_of_missed_messages;

end package body com_deprecated_pkg;
