-- Com package provides a generic communication mechanism for testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.com_codec_pkg.all;

use std.textio.all;

package body com_pkg is
  type envelope_t;
  type envelope_ptr_t is access envelope_t;

  type envelope_t is record
    message       : message_t;
    next_envelope : envelope_ptr_t;
  end record envelope_t;
  type envelope_ptr_array is array (positive range <>) of envelope_ptr_t;

  type inbox_t is record
    num_of_messages : natural;
    first_envelope  : envelope_ptr_t;
    last_envelope   : envelope_ptr_t;
  end record inbox_t;

  type subscriber_item_t;
  type subscriber_item_ptr_t is access subscriber_item_t;

  type subscriber_item_t is record
    actor     : actor_t;
    next_item : subscriber_item_ptr_t;
  end record subscriber_item_t;

  type actor_item_t is record
    actor                  : actor_t;
    name                   : line;
    deferred_creation      : boolean;
    max_num_of_messages    : natural;
    num_of_missed_messages : natural;
    inbox                  : inbox_t;
    reply_stash            : envelope_ptr_t;
    subscribers            : subscriber_item_ptr_t;
  end record actor_item_t;

  type actor_item_array_t is array (natural range <>) of actor_item_t;
  type actor_item_array_ptr_t is access actor_item_array_t;

  type messenger_t is protected body
  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  variable empty_inbox_c : inbox_t := (0, null, null);
  variable null_actor_item_c    : actor_item_t := (null_actor_c, null, false, 0, 0, empty_inbox_c, null, null);
  variable envelope_recycle_bin : envelope_ptr_array(1 to 1000);
  variable n_recycled_envelopes : natural      := 0;
  variable null_message         : message_t    := (0, ok, null_actor_c, no_message_id_c, null);

  impure function new_envelope
    return envelope_ptr_t is
  begin
    if n_recycled_envelopes > 0 then
      n_recycled_envelopes                                         := n_recycled_envelopes - 1;
      envelope_recycle_bin(n_recycled_envelopes + 1).message       := null_message;
      envelope_recycle_bin(n_recycled_envelopes + 1).next_envelope := null;
      return envelope_recycle_bin(n_recycled_envelopes + 1);
    else
      return new envelope_t;
    end if;
  end new_envelope;

  procedure deallocate_envelope (
    variable ptr : inout envelope_ptr_t) is
  begin
    if (n_recycled_envelopes < envelope_recycle_bin'length) and (ptr /= null) then
      n_recycled_envelopes                       := n_recycled_envelopes + 1;
      envelope_recycle_bin(n_recycled_envelopes) := ptr;
      ptr                                        := null;
    else
      deallocate(ptr);
    end if;
  end deallocate_envelope;

  impure function init_actors
    return actor_item_array_ptr_t is
    variable ret_val : actor_item_array_ptr_t;
  begin
    ret_val    := new actor_item_array_t(0 to 0);
    ret_val(0) := null_actor_item_c;

    return ret_val;
  end function init_actors;

  variable actors          : actor_item_array_ptr_t := init_actors;
  variable next_message_id : message_id_t           := no_message_id_c + 1;

  impure function find_actor (
    constant name : string)
    return actor_t is
    variable ret_val : actor_t;
  begin
    for i in actors'reverse_range loop
      ret_val := actors(i).actor;
      if actors(i).name /= null then
        exit when actors(i).name.all = name;
      end if;
    end loop;

    return ret_val;
  end;

  impure function create_actor (
    constant name              :    string  := "";
    constant deferred_creation : in boolean := false;
    constant inbox_size        : in natural := natural'high)
    return actor_t is
    variable old_actors : actor_item_array_ptr_t;
  begin
    old_actors := actors;
    actors     := new actor_item_array_t(0 to actors'length);
    actors(0)  := null_actor_item_c;
    for i in old_actors'range loop
      actors(i) := old_actors(i);
    end loop;
    deallocate(old_actors);
    actors(actors'length - 1) := ((id => actors'length - 1), new string'(name),
                                  deferred_creation, inbox_size, 0, empty_inbox_c, null, null);

    return actors(actors'length - 1).actor;
  end function;

  impure function find (
    constant name                     : string;
    constant enable_deferred_creation : boolean := true)
    return actor_t is
    variable actor : actor_t := find_actor(name);
  begin
    if (actor = null_actor_c) and enable_deferred_creation then
      return create_actor(name, true, 1);
    else
      return actor;
    end if;
  end;

  impure function create (
    constant name       :    string   := "";
    constant inbox_size : in positive := positive'high)
    return actor_t is
    variable actor : actor_t := find_actor(name);
  begin
    if actor = null_actor_c then
      actor := create_actor(name, false, inbox_size);
    elsif actors(actor.id).deferred_creation then
      actors(actor.id).deferred_creation   := false;
      actors(actor.id).max_num_of_messages := inbox_size;
    else
      actor := null_actor_c;
    end if;

    return actor;
  end;

  procedure destroy (
    variable actor  : inout actor_t;
    variable status : out   com_status_t) is
    variable envelope           : envelope_ptr_t;
    variable item               : subscriber_item_ptr_t;
    variable unsubscribe_status : com_status_t;
  begin
    if unknown_actor(actor) then
      status := unknown_actor_error;
      return;
    end if;

    while actors(actor.id).inbox.first_envelope /= null loop
      envelope                              := actors(actor.id).inbox.first_envelope;
      actors(actor.id).inbox.first_envelope := envelope.next_envelope;
      deallocate(envelope.message.payload);
      deallocate_envelope(envelope);
    end loop;

    while actors(actor.id).subscribers /= null loop
      item                         := actors(actor.id).subscribers;
      actors(actor.id).subscribers := item.next_item;
      deallocate(item);
    end loop;

    for i in actors'range loop
      unsubscribe(actor, actors(i).actor, unsubscribe_status);
    end loop;

    deallocate(actors(actor.id).name);
    actors(actor.id) := null_actor_item_c;
    actor            := null_actor_c;
  end;

  procedure reset_messenger is
    variable status : com_status_t;
  begin
    for i in actors'range loop
      if actors(i).actor /= null_actor_c then
        destroy(actors(i).actor, status);
      end if;
    end loop;
    deallocate(actors);
    actors          := init_actors;
    next_message_id := no_message_id_c + 1;
  end;

  impure function num_of_actors
    return natural is
    variable n_actors : natural := 0;
  begin
    for i in actors'range loop
      if actors(i).actor /= null_actor_c then
        n_actors := n_actors + 1;
      end if;
    end loop;

    return n_actors;
  end;

  impure function num_of_deferred_creations
    return natural is
    variable n_deferred_actors : natural := 0;
  begin
    for i in actors'range loop
      if actors(i).deferred_creation then
        n_deferred_actors := n_deferred_actors + 1;
      end if;
    end loop;

    return n_deferred_actors;
  end;

  impure function unknown_actor (
    constant actor : actor_t)
    return boolean is
  begin
    if (actor.id = 0) or (actor.id > actors'length - 1) then
      return true;
    elsif actors(actor.id).actor = null_actor_c then
      return true;
    end if;

    return false;
  end function unknown_actor;

  impure function deferred (
    constant actor : actor_t)
    return boolean is
  begin
    return actors(actor.id).deferred_creation;
  end function deferred;

  impure function inbox_is_full (
    constant actor : actor_t)
    return boolean is
  begin
    return actors(actor.id).inbox.num_of_messages >= actors(actor.id).max_num_of_messages;
  end function inbox_is_full;

  impure function inbox_size (
    constant actor : actor_t)
    return natural is
  begin
    return actors(actor.id).max_num_of_messages;
  end function;
  -----------------------------------------------------------------------------
  -- Send related subprograms
  -----------------------------------------------------------------------------
  procedure send (
    constant sender     : in  actor_t;
    constant receiver   : in  actor_t;
    constant request_id : in  message_id_t;
    constant payload    : in  string;
    variable receipt    : out receipt_t) is
    variable envelope : envelope_ptr_t;
  begin
    receipt.status := ok;
    receipt.id     := no_message_id_c;
    if not inbox_is_full(receiver) then
      receipt.id                  := next_message_id;
      envelope                    := new_envelope;
      envelope.message.sender     := sender;
      envelope.message.id         := next_message_id;
      envelope.message.request_id := request_id;
      write(envelope.message.payload, payload);
      next_message_id             := next_message_id + 1;

      actors(receiver.id).inbox.num_of_messages := actors(receiver.id).inbox.num_of_messages + 1;

      if actors(receiver.id).inbox.last_envelope /= null then
        actors(receiver.id).inbox.last_envelope.next_envelope := envelope;
      else
        actors(receiver.id).inbox.first_envelope := envelope;
      end if;
      actors(receiver.id).inbox.last_envelope := envelope;
    else
      actors(receiver.id).num_of_missed_messages := actors(receiver.id).num_of_missed_messages + 1;
      receipt.status := full_inbox_error;
    end if;
  end;

  procedure publish (
    constant sender  : in  actor_t;
    constant payload : in  string;
    variable status  : out com_status_t) is
    variable receipt         : receipt_t;
    variable subscriber_item : subscriber_item_ptr_t;
  begin
    status := ok;
    if unknown_actor(sender) then
      status := unknown_publisher_error;
      return;
    end if;

    subscriber_item := actors(sender.id).subscribers;
    while subscriber_item /= null loop
      send(sender, subscriber_item.actor, no_message_id_c, payload, receipt);
      if receipt.status /= ok then
        status := receipt.status;
      end if;
      subscriber_item := subscriber_item.next_item;
    end loop;
  end;

  -----------------------------------------------------------------------------
  -- Receive related subprograms
  -----------------------------------------------------------------------------
  impure function has_messages (
    constant actor : actor_t)
    return boolean is
  begin
    return actors(actor.id).inbox.first_envelope /= null;
  end function has_messages;

  impure function get_first_message_payload (
    constant actor : actor_t)
    return string is
  begin
    if actors(actor.id).inbox.first_envelope /= null then
      return actors(actor.id).inbox.first_envelope.message.payload.all;
    else
      return "";
    end if;
  end;

  impure function get_first_message_sender (
    constant actor : actor_t)
    return actor_t is
  begin
    if actors(actor.id).inbox.first_envelope /= null then
      return actors(actor.id).inbox.first_envelope.message.sender;
    else
      return null_actor_c;
    end if;
  end;

  impure function get_first_message_id (
    constant actor : actor_t)
    return message_id_t is
  begin
    if actors(actor.id).inbox.first_envelope /= null then
      return actors(actor.id).inbox.first_envelope.message.id;
    else
      return no_message_id_c;
    end if;
  end;

  impure function get_first_message_request_id (
    constant actor : actor_t)
    return message_id_t is
  begin
    if actors(actor.id).inbox.first_envelope /= null then
      return actors(actor.id).inbox.first_envelope.message.request_id;
    else
      return no_message_id_c;
    end if;
  end;

  procedure delete_first_envelope (
    constant actor : in actor_t) is
    variable first_envelope : envelope_ptr_t := actors(actor.id).inbox.first_envelope;
  begin
    if first_envelope /= null then
      deallocate(first_envelope.message.payload);
      actors(actor.id).inbox.first_envelope := first_envelope.next_envelope;
      deallocate_envelope(first_envelope);
      if actors(actor.id).inbox.first_envelope = null then
        actors(actor.id).inbox.last_envelope := null;
      end if;
      actors(actor.id).inbox.num_of_messages := actors(actor.id).inbox.num_of_messages - 1;
    end if;
  end;

  impure function has_reply_stash_message (
    constant actor      : actor_t;
    constant request_id : message_id_t := no_message_id_c)
    return boolean is
  begin
    if request_id = no_message_id_c then
      return actors(actor.id).reply_stash /= null;
    elsif actors(actor.id).reply_stash /= null then
      return actors(actor.id).reply_stash.message.request_id = request_id;
    else
      return false;
    end if;
  end function has_reply_stash_message;

  impure function get_reply_stash_message_payload (
    constant actor : actor_t)
    return string is
    variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
  begin
    if envelope /= null then
      return envelope.message.payload.all;
    else
      return "";
    end if;
  end;

  impure function get_reply_stash_message_sender (
    constant actor : actor_t)
    return actor_t is
    variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
  begin
    if envelope /= null then
      return envelope.message.sender;
    else
      return null_actor_c;
    end if;
  end;

  impure function get_reply_stash_message_id (
    constant actor : actor_t)
    return message_id_t is
    variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
  begin
    if envelope /= null then
      return envelope.message.id;
    else
      return no_message_id_c;
    end if;
  end;

  impure function get_reply_stash_message_request_id (
    constant actor : actor_t)
    return message_id_t is
    variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
  begin
    if envelope /= null then
      return envelope.message.request_id;
    else
      return no_message_id_c;
    end if;
  end;

  impure function find_and_stash_reply_message (
    constant actor      : actor_t;
    constant request_id : message_id_t)
    return boolean is
    variable envelope          : envelope_ptr_t := actors(actor.id).inbox.first_envelope;
    variable previous_envelope : envelope_ptr_t := null;
  begin
    while envelope /= null loop
      if envelope.message.request_id = request_id then
        actors(actor.id).reply_stash := envelope;
        if previous_envelope /= null then
          previous_envelope.next_envelope := envelope.next_envelope;
        else
          actors(actor.id).inbox.first_envelope := envelope.next_envelope;
        end if;
        if actors(actor.id).inbox.first_envelope = null then
          actors(actor.id).inbox.last_envelope := null;
        end if;
        actors(actor.id).inbox.num_of_messages := actors(actor.id).inbox.num_of_messages - 1;
        return true;
      end if;
      previous_envelope := envelope;
      envelope          := envelope.next_envelope;
    end loop;

    return false;
  end function find_and_stash_reply_message;

  procedure clear_reply_stash (
    constant actor : actor_t) is
  begin
    deallocate(actors(actor.id).reply_stash.message.payload);
    deallocate(actors(actor.id).reply_stash);
  end procedure clear_reply_stash;

  procedure subscribe (
    constant subscriber : in  actor_t;
    constant publisher  : in  actor_t;
    variable status     : out com_status_t) is
    variable new_subscriber, item : subscriber_item_ptr_t;
  begin
    if unknown_actor(subscriber) then
      status := unknown_subscriber_error;
    elsif unknown_actor(publisher) then
      status := unknown_publisher_error;
    end if;

    item := actors(publisher.id).subscribers;
    while item /= null loop
      exit when item.actor = subscriber;
      item := item.next_item;
    end loop;
    if item /= null then
      status := already_a_subscriber_error;
      return;
    end if;

    new_subscriber                   := new subscriber_item_t'(subscriber, actors(publisher.id).subscribers);
    actors(publisher.id).subscribers := new_subscriber;
    status                           := ok;
  end procedure subscribe;

  procedure unsubscribe (
    constant subscriber : in  actor_t;
    constant publisher  : in  actor_t;
    variable status     : out com_status_t) is
    variable item, previous_item : subscriber_item_ptr_t;
  begin
    if unknown_actor(subscriber) then
      status := unknown_subscriber_error;
    elsif unknown_actor(publisher) then
      status := unknown_publisher_error;
    end if;

    status        := not_a_subscriber_error;
    item          := actors(publisher.id).subscribers;
    previous_item := null;
    while item /= null loop
      if item.actor = subscriber then
        status := ok;
        if previous_item = null then
          actors(publisher.id).subscribers := item.next_item;
        else
          previous_item.next_item := item.next_item;
        end if;
        deallocate(item);
        exit;
      end if;
      previous_item := item;
      item          := item.next_item;
    end loop;
  end procedure unsubscribe;

  impure function num_of_missed_messages (
    constant actor : actor_t)
    return natural is
  begin
    return actors(actor.id).num_of_missed_messages;
  end function num_of_missed_messages;

end protected body;

-----------------------------------------------------------------------------
-- Handling of actors
-----------------------------------------------------------------------------
shared variable messenger : messenger_t;

impure function create (
  constant name       :    string   := "";
  constant inbox_size : in positive := positive'high)
  return actor_t is
begin
  return messenger.create(name, inbox_size);
end;

impure function find (
  constant name                     : string;
  constant enable_deferred_creation : boolean := true)
  return actor_t is
begin
  return messenger.find(name, enable_deferred_creation);
end;

procedure destroy (
  variable actor  : inout actor_t;
  variable status : out   com_status_t) is
begin
  messenger.destroy(actor, status);
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

impure function inbox_size (
  constant actor : actor_t)
  return natural is
begin
  return messenger.inbox_size(actor);
end;


-----------------------------------------------------------------------------
-- Network related
-----------------------------------------------------------------------------
procedure notify (
  signal net : inout network_t) is
begin
  if net /= network_event then
    net <= network_event;
    wait until net = network_event;
    net <= idle_network;
  end if;
end procedure notify;

-----------------------------------------------------------------------------
-- Send related subprograms
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
  message := compose(payload, sender);
  send(net, receiver, message, receipt, timeout);
end;

procedure send (
  signal net        : inout network_t;
  constant receiver : in    actor_t;
  constant payload  : in    string := "";
  variable receipt  : out   receipt_t;
  constant timeout  : in    time   := max_timeout_c) is
  variable message : message_ptr_t;
begin
  message := compose(payload);
  send(net, receiver, message, receipt, timeout);
end;

procedure send (
  signal net            : inout network_t;
  constant receiver     : in    actor_t;
  variable message      : inout message_ptr_t;
  variable receipt      : out   receipt_t;
  constant timeout      : in    time    := max_timeout_c;
  constant keep_message : in    boolean := false) is
  variable send_message : boolean := true;
begin
  if message = null then
    receipt.status := null_message_error;
    return;
  end if;

  receipt.status := ok;
  receipt.id     := no_message_id_c;
  if messenger.unknown_actor(receiver) then
    receipt.status := unknown_receiver_error;
    return;
  end if;

  if messenger.inbox_is_full(receiver) then
    wait on net until not messenger.inbox_is_full(receiver) for timeout;
    if messenger.inbox_is_full(receiver) then
      receipt.status := full_inbox_error;
      send_message   := false;
    end if;
  end if;

  if send_message then
    messenger.send(message.sender, receiver, message.request_id, message.payload.all, receipt);
    notify(net);
  end if;

  if not keep_message then
    delete(message);
  end if;
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
  variable receipt : receipt_t;
  variable start   : time;
  variable sender  : actor_t := request_message.sender;
begin
  start := now;
  send(net, receiver, request_message, receipt, timeout, keep_message);
  if receipt.status = ok then
    receive_reply(net, sender, receipt.id, reply_message, timeout - (now - start));
  else
    reply_message.status := receipt.status;
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
  variable receipt : receipt_t;
  variable start   : time;
  variable sender  : actor_t := request_message.sender;
begin
  start := now;
  send(net, receiver, request_message, receipt, timeout, keep_message);
  if receipt.status = ok then
    receive_reply(net, sender, receipt.id, positive_ack, status, timeout - (now - start));
  else
    status       := receipt.status;
    positive_ack := false;
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
  message := compose(payload, sender, request_id);
  reply(net, receiver, message, receipt, timeout);
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
  message := compose(payload, request_id => request_id);
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
  if message.request_id = no_message_id_c then
    receipt.status := reply_missing_request_id_error;
    return;
  end if;

  send(net, receiver, message, receipt, timeout, keep_message);
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
  acknowledge(net, null_actor_c, receiver, request_id, positive_ack, receipt, timeout);
end;


procedure publish (
  signal net       : inout network_t;
  constant sender  : in    actor_t;
  constant payload : in    string := "";
  variable status  : out   com_status_t) is
  variable message : message_ptr_t;
begin
  message := compose(payload, sender);
  publish(net, message, status);
end;

procedure publish (
  signal net            : inout network_t;
  variable message      : inout message_ptr_t;
  variable status       : out   com_status_t;
  constant keep_message : in    boolean := false) is
begin
  if message = null then
    status := null_message_error;
    return;
  end if;
  messenger.publish(message.sender, message.payload.all, status);
  notify(net);
  if not keep_message then
    delete(message);
  end if;
end;

-----------------------------------------------------------------------------
-- Receive related subprograms
-----------------------------------------------------------------------------
procedure wait_for_messages (
  signal net               : in  network_t;
  constant receiver        : in  actor_t;
  variable status          : out com_status_t;
  constant receive_timeout : in  time := max_timeout_c) is
begin
  if messenger.deferred(receiver) then
    status := deferred_receiver_error;
  else
    status := ok;
    if not messenger.has_messages(receiver) then
      wait on net until messenger.has_messages(receiver) for receive_timeout;
      if not messenger.has_messages(receiver) then
        status := timeout;
      end if;
    end if;
  end if;
end procedure wait_for_messages;

impure function has_messages (
  constant actor : actor_t)
  return boolean is
begin
  return messenger.has_messages(actor);
end function has_messages;

impure function get_message (
  constant receiver          :    actor_t;
  constant delete_from_inbox : in boolean := true)
  return message_ptr_t is
  variable message : message_ptr_t;
begin
  message        := new message_t;
  message.status := null_message_error;
  if messenger.has_messages(receiver) then
    message.status     := ok;
    message.id         := messenger.get_first_message_id(receiver);
    message.request_id := messenger.get_first_message_request_id(receiver);
    message.sender     := messenger.get_first_message_sender(receiver);
    write(message.payload, messenger.get_first_message_payload(receiver));
    if delete_from_inbox then
      messenger.delete_first_envelope(receiver);
    end if;
  end if;

  return message;
end function get_message;

procedure receive (
  signal net        : inout network_t;
  constant receiver :       actor_t;
  variable message  : inout message_ptr_t;
  constant timeout  : in    time := max_timeout_c) is
  variable status                  : com_status_t;
  variable started_with_full_inbox : boolean;
begin
  if message /= null then
    delete(message);
  end if;
  wait_for_messages(net, receiver, status, timeout);
  if status = ok then
    started_with_full_inbox := messenger.inbox_is_full(receiver);
    message                 := get_message(receiver);
    if started_with_full_inbox then
      notify(net);
    end if;
  else
    message        := new message_t;
    message.status := status;
  end if;
end;

procedure wait_for_reply_stash_message (
  signal net               : inout network_t;
  constant receiver        : in    actor_t;
  constant request_id      : in    message_id_t;
  variable status          : out   com_status_t;
  constant receive_timeout : in    time := max_timeout_c) is
  variable started_with_full_inbox : boolean;
begin
  if messenger.deferred(receiver) then
    status := deferred_receiver_error;
  else
    status                  := ok;
    started_with_full_inbox := messenger.inbox_is_full(receiver);
    if messenger.has_reply_stash_message(receiver, request_id) then
      return;
    elsif messenger.find_and_stash_reply_message(receiver, request_id) then
      if started_with_full_inbox then
        notify(net);
      end if;
      return;
    else
      wait on net until messenger.find_and_stash_reply_message(receiver, request_id) for receive_timeout;
      if not messenger.has_reply_stash_message(receiver, request_id) then
        status := timeout;
      elsif started_with_full_inbox then
        notify(net);
      end if;
    end if;
  end if;
end procedure wait_for_reply_stash_message;

impure function get_reply_stash_message (
  constant receiver          :    actor_t;
  constant clear_reply_stash : in boolean := true)
  return message_ptr_t is
  variable message : message_ptr_t;
begin
  message        := new message_t;
  message.status := null_message_error;
  if messenger.has_reply_stash_message(receiver) then
    message.status     := ok;
    message.id         := messenger.get_reply_stash_message_id(receiver);
    message.request_id := messenger.get_reply_stash_message_request_id(receiver);
    message.sender     := messenger.get_reply_stash_message_sender(receiver);
    write(message.payload, messenger.get_reply_stash_message_payload(receiver));
    if clear_reply_stash then
      messenger.clear_reply_stash(receiver);
    end if;
  end if;

  return message;
end function get_reply_stash_message;

procedure receive_reply (
  signal net          : inout network_t;
  constant receiver   :       actor_t;
  constant request_id : in    message_id_t;
  variable message    : inout message_ptr_t;
  constant timeout    : in    time := max_timeout_c) is
  variable status : com_status_t;
begin
  if message /= null then
    delete(message);
  end if;
  wait_for_reply_stash_message(net, receiver, request_id, status, timeout);
  if status = ok then
    message := get_reply_stash_message(receiver);
  else
    message        := new message_t;
    message.status := status;
  end if;
end;

procedure receive_reply (
  signal net            : inout network_t;
  constant receiver     :       actor_t;
  constant request_id   : in    message_id_t;
  variable positive_ack : out   boolean;
  variable status       : out   com_status_t;
  constant timeout      : in    time := max_timeout_c) is
  variable message : message_ptr_t;
begin
  receive_reply(net, receiver, request_id, message, timeout);
  if message.status = ok then
    positive_ack := decode(message.payload.all);
  else
    positive_ack := false;
  end if;
  status := message.status;
end;

procedure subscribe (
  constant subscriber : in  actor_t;
  constant publisher  : in  actor_t;
  variable status     : out com_status_t) is
begin
  messenger.subscribe(subscriber, publisher, status);
end procedure subscribe;

procedure unsubscribe (
  constant subscriber : in  actor_t;
  constant publisher  : in  actor_t;
  variable status     : out com_status_t) is
begin
  messenger.unsubscribe(subscriber, publisher, status);
end procedure unsubscribe;

impure function num_of_missed_messages (
  constant actor : actor_t)
  return natural is
begin
  return messenger.num_of_missed_messages(actor);
end num_of_missed_messages;


-----------------------------------------------------------------------------
-- Message related subprograms
-----------------------------------------------------------------------------
impure function compose (
  constant payload    :    string       := "";
  constant sender     :    actor_t      := null_actor_c;
  constant request_id : in message_id_t := no_message_id_c)
  return message_ptr_t is
  variable message : message_ptr_t;
begin
  message            := new message_t;
  message.sender     := sender;
  message.request_id := request_id;
  write(message.payload, payload);
  return message;
end function compose;

procedure delete (
  variable message : inout message_ptr_t) is
begin
  if message /= null then
    deallocate(message.payload);
    deallocate(message);
  end if;
end procedure delete;

end package body com_pkg;
