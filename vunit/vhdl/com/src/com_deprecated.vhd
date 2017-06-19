-- Com deprecated package provides deprecated functionality and APIs. These
-- will eventually be removed
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.com_codec_pkg.all;
use work.com_support_pkg.all;
use work.com_messenger_pkg.all;
use work.com_types_pkg.all;
use work.com_pkg.all;
use work.com_common_pkg.all;

use std.textio.all;

package com_deprecated_pkg is
  procedure destroy (actor : inout actor_t; status : out com_status_t);

  procedure wait_for_messages (
    signal net               : in  network_t;
    constant receiver        : in  actor_t;
    variable status          : out com_status_t;
    constant receive_timeout : in  time := max_timeout_c);
  impure function has_messages (actor   : actor_t) return boolean;
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
    constant sender     : in    actor_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    constant timeout    : in    time   := max_timeout_c);
  procedure reply (
    signal net          : inout network_t;
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
    constant timeout    : in    time   := max_timeout_c);
  procedure reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
  procedure reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
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
  procedure acknowledge (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c);
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
  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c);
  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant receipt    : in    receipt_t;
    variable positive_ack : out   boolean;
    variable status       : out   com_status_t;
    constant timeout      : in    time := max_timeout_c);
  procedure receive_reply (
    signal net            : inout network_t;
    variable request    : inout    message_ptr_t;
    variable positive_ack : out   boolean;
    variable status       : out   com_status_t;
    constant timeout      : in    time := max_timeout_c);
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
  procedure destroy (actor : inout actor_t; status : out com_status_t) is
  begin
    deprecated("destroy() with status output");
    status := ok;
    messenger.destroy(actor);
  end;

  procedure wait_for_messages (
    signal net               : in  network_t;
    constant receiver        : in  actor_t;
    variable status          : out com_status_t;
    constant receive_timeout : in  time := max_timeout_c) is
  begin
    deprecated("wait_for_messages() with old naming. Use wait_for_message() instead");
    wait_for_message(net, receiver, status, receive_timeout);
  end procedure wait_for_messages;

  impure function has_messages (actor : actor_t) return boolean is
  begin
    deprecated("has_messages() with old naming. Use has_message() instead");
    return has_message(actor);
  end function has_messages;

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
    message.id := receipt.id;
    message.receiver := receiver;
    notify(net);

    if not keep_message then
      delete(message);
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
    variable start   : time;
  begin
    deprecated("request() with status. use request() without status or send + wait_for_reply for polling requests");
    start := now;
    send(net, receiver, request_message, timeout, keep_message => true);
    receive_reply(net, request_message, positive_ack, status, timeout - (now - start));
    if not keep_message then
      delete(request_message);
    end if;
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
    signal net          : inout network_t;
    constant sender     : in    actor_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    constant timeout    : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("reply() with sender (already known by requestor)");
    message := compose(payload, sender, request_id);
    reply(net, receiver, message, timeout);
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

  procedure reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    constant timeout    : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("reply() with receiver and request_id. Input request message instead");
    message := compose(payload, request_id => request_id);
    reply(net, receiver, message, timeout);
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
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false) is
    variable receipt : receipt_t;
  begin
    deprecated("reply() with receiver. Input request message instead");
    reply(net, receiver, message, receipt, timeout, keep_message);
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

  procedure acknowledge (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c) is
    variable receipt      : receipt_t;
  begin
    deprecated("acknowledge() with receiver and request_id. Input request message instead");
    acknowledge(net, null_actor_c, receiver, request_id, positive_ack, receipt, timeout);
  end;

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
    notify(net);

    if not keep_message then
      delete(message);
    end if;
  end;

  -----------------------------------------------------------------------------
  -- Receive related subprograms
  -----------------------------------------------------------------------------
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

  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c) is
    variable message : message_ptr_t;
    variable status  : com_status_t;
  begin
    deprecated("receive_reply() with request ID input. Use send receipt o message input instead");
    receive_reply(net, receiver, request_id, positive_ack, status, timeout);
  end;

  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant receipt    : in    receipt_t;
    variable positive_ack : out   boolean;
    variable status       : out   com_status_t;
    constant timeout      : in    time := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("receive_reply() with status output. Use without or wait_for_reply() if accepting timeout");
    wait_for_reply_stash_message(net, receiver, inbox, receipt.id, status, timeout);
    check(no_error_status(status, true), status);
    if status = ok then
      message := get_reply_stash_message(receiver);
      status := message.status;
      positive_ack := decode(message.payload.all);
      delete(message);
    else
      positive_ack := false;
    end if;
  end;

  procedure receive_reply (
    signal net            : inout network_t;
    variable request    : inout    message_ptr_t;
    variable positive_ack : out   boolean;
    variable status       : out   com_status_t;
    constant timeout      : in    time := max_timeout_c) is
    constant receipt : receipt_t := (status => ok, id => request.id);
  begin
    receive_reply(net, request.sender, receipt, positive_ack, status, timeout);
  end;

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
