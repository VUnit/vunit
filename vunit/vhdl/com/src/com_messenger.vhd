-- This file defines the com messenger which is responsible for housing the
-- messages in the system.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

use work.com_types_pkg.all;
use work.com_support_pkg.all;
use work.queue_pkg.all;
use work.queue_pool_pkg.all;
use work.string_ptr_pkg.all;
use work.logger_pkg.all;
use work.log_levels_pkg.all;
use work.id_pkg.all;

use std.textio.all;

package com_messenger_pkg is
  type subscription_traffic_types_t is array (natural range <>) of subscription_traffic_type_t;

  type messenger_t is protected
    -----------------------------------------------------------------------------
    -- Handling of actors
    -----------------------------------------------------------------------------
    impure function create (
      id : id_t;
      inbox_size : positive := positive'high;
      outbox_size : positive := positive'high
      ) return actor_t;
    impure function create (
      name : string := "";
      inbox_size : positive := positive'high;
      outbox_size : positive := positive'high
      ) return actor_t;
    impure function find (name  : string; enable_deferred_creation : boolean := true) return actor_t;
    impure function find (id  : id_t; enable_deferred_creation : boolean := true) return actor_t;
    impure function name (actor : actor_t) return string;
    impure function get_id (actor : actor_t) return id_t;

    procedure destroy (actor : inout actor_t);
    procedure reset_messenger;

    impure function num_of_actors return natural;
    impure function get_all_actors return actor_vec_t;
    impure function is_deferred(actor : actor_t) return boolean;
    impure function num_of_deferred_creations return natural;
    impure function unknown_actor (actor   : actor_t) return boolean;
    impure function deferred (actor        : actor_t) return boolean;
    impure function is_full (actor         : actor_t; mailbox_id : mailbox_id_t) return boolean;
    impure function num_of_messages (actor : actor_t; mailbox_id : mailbox_id_t) return natural;
    impure function mailbox_size (actor : actor_t; mailbox_id : mailbox_id_t) return natural;
    procedure resize_mailbox (actor : actor_t; new_size : natural; mailbox_id : mailbox_id_t);
    impure function subscriber_inbox_is_full (
      publisher                  : actor_t;
      subscription_traffic_types : subscription_traffic_types_t) return boolean;
    impure function has_subscribers (
      actor                     : actor_t;
      subscription_traffic_type : subscription_traffic_type_t := published) return boolean;

    -----------------------------------------------------------------------------
    -- Send related subprograms
    -----------------------------------------------------------------------------
    procedure send (
      constant sender     : in  actor_t;
      constant receiver   : in  actor_t;
      constant mailbox_id : in  mailbox_id_t;
      constant request_id : in  message_id_t;
      constant payload    : in  string;
      variable receipt    : out receipt_t);
    procedure send (
      constant receiver   : in    actor_t;
      constant mailbox_id : in    mailbox_id_t;
      variable msg        : inout msg_t);
    procedure publish (sender : actor_t; payload : string);
    procedure publish (
      constant sender                   : in    actor_t;
      variable msg                      : inout msg_t;
      constant subscriber_traffic_types : in    subscription_traffic_types_t);
    procedure internal_publish (
      constant sender                   : in    actor_t;
      variable msg                      : inout msg_t;
      constant subscriber_traffic_types : in    subscription_traffic_types_t);

    -----------------------------------------------------------------------------
    -- Receive related subprograms
    -----------------------------------------------------------------------------
    impure function has_messages (actor     : actor_t) return boolean;
    impure function has_messages (actor_vec : actor_vec_t) return boolean;
    impure function get_payload (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return string;
    impure function get_sender (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return actor_t;
    impure function get_receiver (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return actor_t;
    impure function get_id (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return message_id_t;
    impure function get_request_id (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return message_id_t;
    impure function get_all_but_payload (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return msg_t;

    procedure delete_envelope (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox);

    impure function has_reply_stash_message (
      actor      : actor_t;
      request_id : message_id_t := no_message_id)
      return boolean;                   --
    impure function get_reply_stash_message_payload (actor    : actor_t) return string;
    impure function get_reply_stash_message_sender (actor     : actor_t) return actor_t;
    impure function get_reply_stash_message_receiver (actor     : actor_t) return actor_t;
    impure function get_reply_stash_message_id (actor         : actor_t) return message_id_t;
    impure function get_reply_stash_message_request_id (actor : actor_t) return message_id_t;
    impure function find_reply_message (
      actor      : actor_t;
      request_id : message_id_t;
      mailbox_id : mailbox_id_t := inbox)
      return integer;
    impure function find_and_stash_reply_message (
      actor      : actor_t;
      request_id : message_id_t;
      mailbox_id : mailbox_id_t := inbox)
      return boolean;
    procedure clear_reply_stash (actor : actor_t);

    procedure subscribe (
      subscriber   : actor_t;
      publisher    : actor_t;
      traffic_type : subscription_traffic_type_t := published);
    procedure unsubscribe (
      subscriber   : actor_t;
      publisher    : actor_t;
      traffic_type : subscription_traffic_type_t := published);

    ---------------------------------------------------------------------------
    -- Debugging
    ---------------------------------------------------------------------------
    impure function to_string(msg : msg_t) return string;
    impure function get_subscriptions(subscriber : actor_t) return subscription_vec_t;
    impure function get_subscribers(publisher : actor_t) return subscription_vec_t;

    ---------------------------------------------------------------------------
    -- Misc
    ---------------------------------------------------------------------------
    procedure allow_timeout;
    impure function timeout_is_allowed return boolean;
    procedure allow_deprecated;
    procedure deprecated (msg : string);

  end protected;
end package com_messenger_pkg;

package body com_messenger_pkg is
  type envelope_t;
  type envelope_ptr_t is access envelope_t;

  type envelope_t is record
    message       : message_t;
    next_envelope : envelope_ptr_t;
  end record envelope_t;
  type envelope_ptr_array is array (positive range <>) of envelope_ptr_t;

  type mailbox_t is record
    num_of_messages : natural;
    size            : natural;
    first_envelope  : envelope_ptr_t;
    last_envelope   : envelope_ptr_t;
  end record mailbox_t;
  type mailbox_ptr_t is access mailbox_t;

  impure function create(size : natural := natural'high)
    return mailbox_ptr_t is
  begin
    return new mailbox_t'(0, size, null, null);
  end function create;

  -- TODO: subscriber can be simplified to a pointer to an array.
  type subscriber_item_t;
  type subscriber_item_ptr_t is access subscriber_item_t;

  type subscriber_item_t is record
    actor     : actor_t;
    next_item : subscriber_item_ptr_t;
  end record subscriber_item_t;

  type subscribers_t is array (subscription_traffic_type_t range published to inbound) of subscriber_item_ptr_t;

  type actor_item_t is record
    actor             : actor_t;
    id                : id_t;
    deferred_creation : boolean;
    inbox             : mailbox_ptr_t;
    outbox            : mailbox_ptr_t;
    reply_stash       : envelope_ptr_t;
    subscribers       : subscribers_t;
  end record actor_item_t;

  type actor_item_array_t is array (natural range <>) of actor_item_t;
  type actor_item_array_ptr_t is access actor_item_array_t;

  type messenger_t is protected
    body
      variable null_actor_item : actor_item_t := (
        actor             => null_actor,
        id                => null_id,
        deferred_creation => false,
        inbox             => create(0),
        outbox            => create(0),
        reply_stash       => null,
        subscribers       => (null, null, null));  --
    variable envelope_recycle_bin : envelope_ptr_array(1 to 1000);
    variable n_recycled_envelopes : natural      := 0;
    variable null_message         : message_t    := (no_message_id, null_msg_type, ok, null_actor,
                                                     null_actor, no_message_id, null);
    variable next_message_id      : message_id_t := no_message_id + 1;
    variable timeout_allowed      : boolean      := false;
    variable deprecated_allowed   : boolean      := false;

    -----------------------------------------------------------------------------
    -- Handling of actors
    -----------------------------------------------------------------------------
    impure function new_envelope return envelope_ptr_t is
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

  procedure deallocate_envelope (ptr : inout envelope_ptr_t) is
  begin
    if (n_recycled_envelopes < envelope_recycle_bin'length) and (ptr /= null) then
      n_recycled_envelopes                       := n_recycled_envelopes + 1;
      envelope_recycle_bin(n_recycled_envelopes) := ptr;
      ptr                                        := null;
    else
      deallocate(ptr);
    end if;
  end deallocate_envelope;

  impure function init_actors return actor_item_array_ptr_t is
    variable ret_val : actor_item_array_ptr_t;
  begin
    ret_val    := new actor_item_array_t(0 to 0);
    ret_val(0) := null_actor_item;

    return ret_val;
  end function init_actors;

  variable actors : actor_item_array_ptr_t := init_actors;

  impure function find_actor (name : string) return actor_t is
    variable ret_val : actor_t;
  begin
    for i in actors'reverse_range loop
      ret_val := actors(i).actor;
      if actors(i).id /= null_id then
        exit when full_name(actors(i).id) = name;
      end if;
    end loop;

    return ret_val;
  end;

  impure function find_actor (id : id_t) return actor_t is
    variable ret_val : actor_t;
  begin
    for i in actors'reverse_range loop
      ret_val := actors(i).actor;
      if actors(i).id /= null_id then
        exit when actors(i).id = id;
      end if;
    end loop;

    return ret_val;
  end;

  impure function create_actor (
    id : id_t;
    deferred_creation : in boolean := false;
    inbox_size        : in natural := natural'high;
    outbox_size        : in natural := natural'high)
    return actor_t is
    variable old_actors : actor_item_array_ptr_t;
    variable actor_id_number : integer;
    variable resolved_id : id_t;
  begin
    old_actors := actors;
    actors     := new actor_item_array_t(0 to actors'length);
    actors(0)  := null_actor_item;
    for i in old_actors'range loop
      actors(i) := old_actors(i);
    end loop;
    deallocate(old_actors);
    actor_id_number := actors'length - 1;
    if id = null_id then
      resolved_id := get_id("_actor_" & to_string(actor_id_number));
    else
      resolved_id := id;
    end if;
    actors(actors'length - 1) := ((p_id_number => actor_id_number), resolved_id,
                                  deferred_creation, create(inbox_size), create(outbox_size), null, (null, null, null));

    return actors(actors'length - 1).actor;
  end function;

  impure function create_actor (
    name              :    string  := "";
    deferred_creation : in boolean := false;
    inbox_size        : in natural := natural'high;
    outbox_size        : in natural := natural'high)
    return actor_t is
    variable id : id_t;
  begin
    id := null_id when name = "" else get_id(name);

    return create_actor(id, deferred_creation, inbox_size, outbox_size);
  end function;

  impure function find (id : id_t; enable_deferred_creation : boolean := true) return actor_t is
    constant actor : actor_t := find_actor(id);
  begin
    if (id = null_id) or (id = root_id) then
      return null_actor;
    elsif (actor = null_actor) and enable_deferred_creation then
      return create_actor(id, true, 1);
    else
      return actor;
    end if;
  end;

  impure function find (name : string; enable_deferred_creation : boolean := true) return actor_t is
    constant actor : actor_t := find_actor(name);
  begin
    if name = "" then
      return null_actor;
    elsif (actor = null_actor) and enable_deferred_creation then
      return create_actor(name, true, 1);
    else
      return actor;
    end if;
  end;

  impure function name (actor : actor_t) return string is
  begin
    if actors(actor.p_id_number).id /= null_id then
      return full_name(actors(actor.p_id_number).id);
    else
      return "";
    end if;

  end;

  impure function get_id (actor : actor_t) return id_t is
  begin
    return actors(actor.p_id_number).id;
  end;

  impure function create (
    id : id_t;
    inbox_size : positive := positive'high;
    outbox_size : positive := positive'high
    ) return actor_t is
    variable actor : actor_t := find_actor(id);
  begin
    if id = root_id then
      check_failed(new_actor_from_root_id_error);
    elsif actor = null_actor then
      actor := create_actor(id, false, inbox_size, outbox_size);
    elsif actors(actor.p_id_number).deferred_creation then
      actors(actor.p_id_number).deferred_creation := false;
      actors(actor.p_id_number).inbox.size        := inbox_size;
      actors(actor.p_id_number).outbox.size       := outbox_size;
    else
      check_failed(duplicate_actor_name_error);
    end if;

    return actor;
  end;

  impure function create (
    name : string := "";
    inbox_size : positive := positive'high;
    outbox_size : positive := positive'high
    ) return actor_t is
    variable actor : actor_t := find_actor(name);
  begin
    if actor = null_actor then
      actor := create_actor(name, false, inbox_size, outbox_size);
    elsif actors(actor.p_id_number).deferred_creation then
      actors(actor.p_id_number).deferred_creation := false;
      actors(actor.p_id_number).inbox.size        := inbox_size;
      actors(actor.p_id_number).outbox.size       := outbox_size;
    else
      check_failed(duplicate_actor_name_error);
    end if;

    return actor;
  end;

  impure function is_subscriber (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t) return boolean is
    variable item : subscriber_item_ptr_t := actors(publisher.p_id_number).subscribers(traffic_type);
  begin
    while item /= null loop
      if item.actor = subscriber then
        return true;
      end if;
      item := item.next_item;
    end loop;

    return false;
  end;

  procedure remove_subscriber (subscriber : actor_t; publisher : actor_t; traffic_type : subscription_traffic_type_t) is
    variable item, previous_item : subscriber_item_ptr_t;
  begin
    item          := actors(publisher.p_id_number).subscribers(traffic_type);
    previous_item := null;
    while item /= null loop
      if item.actor = subscriber then
        if previous_item = null then
          actors(publisher.p_id_number).subscribers(traffic_type) := item.next_item;
        else
          previous_item.next_item := item.next_item;
        end if;
        deallocate(item);
        return;
      end if;
      previous_item := item;
      item          := item.next_item;
    end loop;

    check_failed(not_a_subscriber_error);
  end;

  procedure destroy (actor : inout actor_t) is
    variable envelope           : envelope_ptr_t;
    variable item               : subscriber_item_ptr_t;
  begin
    check(not unknown_actor(actor), unknown_actor_error);

    while actors(actor.p_id_number).inbox.first_envelope /= null loop
      envelope                              := actors(actor.p_id_number).inbox.first_envelope;
      actors(actor.p_id_number).inbox.first_envelope := envelope.next_envelope;
      deallocate(envelope.message.payload);
      deallocate_envelope(envelope);
    end loop;

    for t in subscription_traffic_type_t'left to subscription_traffic_type_t'right loop
      while actors(actor.p_id_number).subscribers(t) /= null loop
        item                            := actors(actor.p_id_number).subscribers(t);
        actors(actor.p_id_number).subscribers(t) := item.next_item;
        deallocate(item);
      end loop;
    end loop;

    for i in actors'range loop
      for t in subscription_traffic_type_t'left to subscription_traffic_type_t'right loop
        if is_subscriber(actor, actors(i).actor, t) then
          remove_subscriber(actor, actors(i).actor, t);
        end if;
      end loop;
    end loop;

    deallocate(actors(actor.p_id_number).inbox);
    deallocate(actors(actor.p_id_number).outbox);
    actors(actor.p_id_number) := null_actor_item;
    actor            := null_actor;
  end;

  procedure reset_messenger is
  begin
    for i in actors'range loop
      if actors(i).actor /= null_actor then
        destroy(actors(i).actor);
      end if;
    end loop;
    deallocate(actors);
    actors          := init_actors;
    next_message_id := no_message_id + 1;
  end;

  impure function num_of_actors return natural is
    variable n_actors : natural := 0;
  begin
    for i in actors'range loop
      if actors(i).actor /= null_actor then
        n_actors := n_actors + 1;
      end if;
    end loop;

    return n_actors;
  end;

  impure function get_all_actors return actor_vec_t is
    constant n_actors : natural := num_of_actors;
    variable result : actor_vec_t(0 to n_actors - 1);
    variable idx : natural := 0;
  begin
    for i in actors'range loop
      if actors(i).actor /= null_actor then
        result(idx) := actors(i).actor;
        idx := idx + 1;
      end if;
    end loop;

    return result;
  end;


  impure function is_deferred(actor : actor_t) return boolean is
  begin
    return actors(actor.p_id_number).deferred_creation;
  end;

  impure function num_of_deferred_creations return natural is
    variable n_deferred_actors : natural := 0;
  begin
    for i in actors'range loop
      if actors(i).deferred_creation then
        n_deferred_actors := n_deferred_actors + 1;
      end if;
    end loop;

    return n_deferred_actors;
  end;

  impure function unknown_actor (actor : actor_t) return boolean is
  begin
    if (actor.p_id_number = 0) or (actor.p_id_number > actors'length - 1) then
      return true;
    elsif actors(actor.p_id_number).actor = null_actor then
      return true;
    end if;

    return false;
  end function unknown_actor;

  impure function deferred (actor : actor_t) return boolean is
  begin
    return actors(actor.p_id_number).deferred_creation;
  end function deferred;

  impure function is_full (actor : actor_t; mailbox_id : mailbox_id_t) return boolean is
  begin
    if mailbox_id = inbox then
      return actors(actor.p_id_number).inbox.num_of_messages >= actors(actor.p_id_number).inbox.size;
    else
      return actors(actor.p_id_number).outbox.num_of_messages >= actors(actor.p_id_number).outbox.size;
    end if;
  end function;

  impure function num_of_messages (actor : actor_t; mailbox_id : mailbox_id_t) return natural is
  begin
    if mailbox_id = inbox then
      return actors(actor.p_id_number).inbox.num_of_messages;
    else
      return actors(actor.p_id_number).outbox.num_of_messages;
    end if;
  end function;

  procedure resize_mailbox (actor : actor_t; new_size : natural; mailbox_id : mailbox_id_t) is
  begin
    if mailbox_id = inbox then
      check(num_of_messages(actor, inbox) <= new_size, insufficient_size_error);
      actors(actor.p_id_number).inbox.size         := new_size;
    else
      check(num_of_messages(actor, outbox) <= new_size, insufficient_size_error);
      actors(actor.p_id_number).outbox.size         := new_size;
    end if;
  end;

  impure function subscriber_inbox_is_full (
    publisher                  : actor_t;
    subscription_traffic_types : subscription_traffic_types_t) return boolean is
    variable result : boolean_vector(subscription_traffic_types'range) := (others => false);
    procedure has_full_inboxes (
      variable subscribers : in  subscriber_item_ptr_t;
      variable result      : out boolean) is
      variable item : subscriber_item_ptr_t := subscribers;
    begin
      result := false;
      while item /= null loop
        result := is_full(item.actor, inbox);
        exit when result;
        has_full_inboxes(actors(item.actor.p_id_number).subscribers(inbound), result);
        exit when result;
        item   := item.next_item;
      end loop;
    end;
  begin
    for t in subscription_traffic_types'range loop
      has_full_inboxes(actors(publisher.p_id_number).subscribers(subscription_traffic_types(t)), result(t));
    end loop;

    return or result;
  end function;

  impure function has_subscribers (
    actor                     : actor_t;
    subscription_traffic_type : subscription_traffic_type_t := published) return boolean is
  begin
    return actors(actor.p_id_number).subscribers(subscription_traffic_type) /= null;
  end;

  impure function mailbox_size (actor : actor_t; mailbox_id : mailbox_id_t) return natural is
  begin
    if mailbox_id = inbox then
      return actors(actor.p_id_number).inbox.size;
    else
      return actors(actor.p_id_number).outbox.size;
    end if;
  end function;

  -----------------------------------------------------------------------------
  -- Send related subprograms
  -----------------------------------------------------------------------------
  procedure send (
    constant sender     : in  actor_t;
    constant receiver   : in  actor_t;
    constant mailbox_id : in  mailbox_id_t;
    constant request_id : in  message_id_t;
    constant payload    : in  string;
    variable receipt    : out receipt_t) is
    variable envelope : envelope_ptr_t;
    variable mailbox  : mailbox_ptr_t;
  begin
    check(not is_full(receiver, mailbox_id), full_inbox_error);

    receipt.status              := ok;
    receipt.id                  := next_message_id;
    envelope                    := new_envelope;
    envelope.message.sender     := sender;
    envelope.message.receiver   := receiver;
    envelope.message.id         := next_message_id;
    envelope.message.request_id := request_id;
    write(envelope.message.payload, payload);
    next_message_id             := next_message_id + 1;

    mailbox                 := actors(receiver.p_id_number).inbox when mailbox_id = inbox else actors(receiver.p_id_number).outbox;
    mailbox.num_of_messages := mailbox.num_of_messages + 1;
    if mailbox.last_envelope /= null then
      mailbox.last_envelope.next_envelope := envelope;
    else
      mailbox.first_envelope := envelope;
    end if;
    mailbox.last_envelope := envelope;
  end;

  procedure publish (sender : actor_t; payload : string) is
    variable receipt         : receipt_t;
    variable subscriber_item : subscriber_item_ptr_t;
  begin
    check(not unknown_actor(sender), unknown_publisher_error);

    subscriber_item := actors(sender.p_id_number).subscribers(published);
    while subscriber_item /= null loop
      send(sender, subscriber_item.actor, inbox, no_message_id, payload, receipt);
      subscriber_item := subscriber_item.next_item;
    end loop;
  end;

  impure function to_string(msg : msg_t) return string is
    function id_to_string(id : message_id_t) return string is
    begin
      if id = no_message_id then
        return "-";
      else
        return to_string(id);
      end if;
    end function;

    impure function actor_to_string(actor : actor_t) return string is
    begin
      if actor = null_actor then
        return "-";
      else
        return name(actor);
      end if;
    end function;

    impure function msg_type_to_string (msg_type : msg_type_t) return string is
    begin
      if msg_type = null_msg_type then
        return "-";
      else
        return name(msg_type);
      end if;
    end;

  begin
    return id_to_string(msg.id) & ":" & id_to_string(msg.request_id) & " " &
      actor_to_string(msg.sender) & " -> " & actor_to_string(msg.receiver) &
      " (" & msg_type_to_string(msg.msg_type) & ")";
  end;

  procedure put_message (
    receiver   : actor_t;
    msg        : msg_t;
    mailbox_id : mailbox_id_t;
    copy_msg : boolean) is
    variable envelope : envelope_ptr_t;
    variable data     : msg_data_t := msg.data;
    variable mailbox  : mailbox_ptr_t;

  begin
    if copy_msg then
      data := new_queue(queue_pool);
      for i in 0 to length(msg.data) - 1 loop
        unsafe_push(data, get(msg.data.data, 1+i));
      end loop;
    end if;

    if is_visible(com_logger, trace) then
      trace(com_logger, "[" & to_string(msg) & "] => " & name(receiver) & " " & mailbox_id_t'image(mailbox_id));
    end if;

    envelope                    := new_envelope;
    envelope.message.id         := msg.id;
    envelope.message.msg_type   := msg.msg_type;
    envelope.message.sender     := msg.sender;
    envelope.message.receiver   := msg.receiver;
    envelope.message.request_id := msg.request_id;
    write(envelope.message.payload, encode(data));

    mailbox                 := actors(receiver.p_id_number).inbox when mailbox_id = inbox else actors(receiver.p_id_number).outbox;
    mailbox.num_of_messages := mailbox.num_of_messages + 1;
    if mailbox.last_envelope /= null then
      mailbox.last_envelope.next_envelope := envelope;
    else
      mailbox.first_envelope := envelope;
    end if;
    mailbox.last_envelope := envelope;
  end procedure;

  procedure put_subscriber_messages (
    variable subscribers      : inout subscriber_item_ptr_t;
    variable msg              : inout msg_t;
    constant set_msg_receiver : in    boolean) is
    variable subscriber_item : subscriber_item_ptr_t := subscribers;
  begin
    while subscriber_item /= null loop
      if set_msg_receiver then
        msg.receiver := subscriber_item.actor;
      end if;
      put_message(subscriber_item.actor, msg, inbox, true);
      internal_publish(subscriber_item.actor, msg, (0 => inbound));
      subscriber_item := subscriber_item.next_item;
    end loop;
  end;

  procedure publish (
    constant sender                   : in    actor_t;
    variable msg                      : inout msg_t;
    constant subscriber_traffic_types : in    subscription_traffic_types_t) is
  begin
    check(not unknown_actor(sender), unknown_publisher_error);
    check(msg.data /= null_queue, null_message_error);

    msg.id     := next_message_id;
    next_message_id := next_message_id + 1;
    msg.status := ok;
    msg.sender := sender;

    for t in subscriber_traffic_types'range loop
      put_subscriber_messages(actors(sender.p_id_number).subscribers(subscriber_traffic_types(t)),
                              msg, set_msg_receiver => true);
    end loop;

    msg.receiver := null_actor;
  end;

  procedure internal_publish (
    constant sender                   : in    actor_t;
    variable msg                      : inout msg_t;
    constant subscriber_traffic_types : in    subscription_traffic_types_t) is
  begin
    for t in subscriber_traffic_types'range loop
      put_subscriber_messages(actors(sender.p_id_number).subscribers(subscriber_traffic_types(t)),
                              msg, set_msg_receiver => false);
    end loop;
  end;

  procedure send (
    constant receiver   : in    actor_t;
    constant mailbox_id : in    mailbox_id_t;
    variable msg        : inout msg_t) is
  begin
    msg.id          := next_message_id;
    next_message_id := next_message_id + 1;
    msg.status      := ok;
    if mailbox_id = inbox then
      msg.receiver    := receiver;
    else
      msg.sender    := receiver;
      msg.receiver    := null_actor;
    end if;


    put_message(receiver, msg, mailbox_id, false);
  end;

  -----------------------------------------------------------------------------
  -- Receive related subprograms
  -----------------------------------------------------------------------------
  impure function has_messages (actor : actor_t) return boolean is
  begin
    return actors(actor.p_id_number).inbox.first_envelope /= null;
  end function has_messages;

  impure function has_messages (actor_vec : actor_vec_t) return boolean is
  begin
    for i in actor_vec'range loop
      if has_messages(actor_vec(i)) then
        return true;
      end if;
    end loop;
    return false;
  end function has_messages;

  procedure get_envelope(
    actor      : actor_t;
    position   : natural;
    mailbox_id : mailbox_id_t;
    variable mailbox : inout mailbox_ptr_t;
    variable envelope : inout envelope_ptr_t;
    variable previous_envelope : inout envelope_ptr_t) is
  begin
    mailbox  := actors(actor.p_id_number).inbox when mailbox_id = inbox else actors(actor.p_id_number).outbox;
    envelope := mailbox.first_envelope;
    previous_envelope := null;

    for i in 1 to position loop
      exit when envelope = null;
      previous_envelope := envelope;
      envelope := envelope.next_envelope;
    end loop;
  end;

  impure function get_payload (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return string is
    variable envelope, previous_envelope : envelope_ptr_t;
    variable mailbox : mailbox_ptr_t;
  begin
    get_envelope(actor, position, mailbox_id, mailbox, envelope, previous_envelope);
    if envelope /= null then
      return envelope.message.payload.all;
    else
      return "";
    end if;
  end;

  impure function get_sender (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return actor_t is
    variable envelope, previous_envelope : envelope_ptr_t;
    variable mailbox : mailbox_ptr_t;
  begin
    get_envelope(actor, position, mailbox_id, mailbox, envelope, previous_envelope);
    if envelope /= null then
      return envelope.message.sender;
    else
      return null_actor;
    end if;
  end;

  impure function get_receiver (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return actor_t is
    variable envelope, previous_envelope : envelope_ptr_t;
    variable mailbox : mailbox_ptr_t;
  begin
    get_envelope(actor, position, mailbox_id, mailbox, envelope, previous_envelope);
    if envelope /= null then
      return envelope.message.receiver;
    else
      return null_actor;
    end if;
  end;

  impure function get_id (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return message_id_t is
    variable envelope, previous_envelope : envelope_ptr_t;
    variable mailbox : mailbox_ptr_t;
  begin
    get_envelope(actor, position, mailbox_id, mailbox, envelope, previous_envelope);
    if envelope /= null then
      return envelope.message.id;
    else
      return no_message_id;
    end if;
  end;

  impure function get_request_id (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return message_id_t is
    variable envelope, previous_envelope : envelope_ptr_t;
    variable mailbox : mailbox_ptr_t;
  begin
    get_envelope(actor, position, mailbox_id, mailbox, envelope, previous_envelope);
    if envelope /= null then
      return envelope.message.request_id;
    else
      return no_message_id;
    end if;
  end;

  impure function get_all_but_payload (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return msg_t is
    variable envelope, previous_envelope : envelope_ptr_t;
    variable mailbox : mailbox_ptr_t;
    variable msg : msg_t;
  begin
    get_envelope(actor, position, mailbox_id, mailbox, envelope, previous_envelope);
    if envelope /= null then
      msg.id := envelope.message.id;
      msg.msg_type := envelope.message.msg_type;
      msg.status := envelope.message.status;
      msg.sender := envelope.message.sender;
      msg.receiver := envelope.message.receiver;
      msg.request_id := envelope.message.request_id;
      msg.data := null_queue;
    else
      msg := null_msg;
    end if;

    return msg;
  end;

  procedure delete_envelope (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) is
    variable envelope, previous_envelope : envelope_ptr_t;
    variable mailbox : mailbox_ptr_t;
    variable msg : msg_t;
  begin
    get_envelope(actor, position, mailbox_id, mailbox, envelope, previous_envelope);

    if envelope /= null then
      if is_visible(com_logger, trace) then
        msg.id := envelope.message.id;
        msg.msg_type := envelope.message.msg_type;
        msg.sender := envelope.message.sender;
        msg.receiver := envelope.message.receiver;
        msg.request_id := envelope.message.request_id;
        trace(com_logger, name(actor) & " " & mailbox_id_t'image(mailbox_id) & " => [" & to_string(msg) & "]");
      end if;

      deallocate(envelope.message.payload);

      if previous_envelope /= null then
        previous_envelope.next_envelope := envelope.next_envelope;
      else
        mailbox.first_envelope := envelope.next_envelope;
      end if;

      if envelope.next_envelope = null then
        mailbox.last_envelope := previous_envelope;
      end if;

      deallocate_envelope(envelope);
      mailbox.num_of_messages := mailbox.num_of_messages - 1;
    end if;
  end;

  impure function has_reply_stash_message (
    actor      : actor_t;
    request_id : message_id_t := no_message_id)
    return boolean is
  begin
    if request_id = no_message_id then
      return actors(actor.p_id_number).reply_stash /= null;
    elsif actors(actor.p_id_number).reply_stash /= null then
      return actors(actor.p_id_number).reply_stash.message.request_id = request_id;
    else
      return false;
    end if;
  end function has_reply_stash_message;

  impure function get_reply_stash_message_payload (actor : actor_t) return string is
    variable envelope : envelope_ptr_t := actors(actor.p_id_number).reply_stash;
  begin
    if envelope /= null then
      return envelope.message.payload.all;
    else
      return "";
    end if;
  end;

  impure function get_reply_stash_message_sender (actor : actor_t) return actor_t is
    variable envelope : envelope_ptr_t := actors(actor.p_id_number).reply_stash;
  begin
    if envelope /= null then
      return envelope.message.sender;
    else
      return null_actor;
    end if;
  end;

  impure function get_reply_stash_message_receiver (actor     : actor_t) return actor_t is
    variable envelope : envelope_ptr_t := actors(actor.p_id_number).reply_stash;
  begin
    if envelope /= null then
      return envelope.message.receiver;
    else
      return null_actor;
    end if;
  end;

  impure function get_reply_stash_message_id (actor : actor_t) return message_id_t is
    variable envelope : envelope_ptr_t := actors(actor.p_id_number).reply_stash;
  begin
    if envelope /= null then
      return envelope.message.id;
    else
      return no_message_id;
    end if;
  end;

  impure function get_reply_stash_message_request_id (actor : actor_t) return message_id_t is
    variable envelope : envelope_ptr_t := actors(actor.p_id_number).reply_stash;
  begin
    if envelope /= null then
      return envelope.message.request_id;
    else
      return no_message_id;
    end if;
  end;

  procedure find_reply_message (
    actor      : actor_t;
    request_id : message_id_t;
    mailbox_id : mailbox_id_t;
    variable mailbox : inout mailbox_ptr_t;
    variable envelope : inout envelope_ptr_t;
    variable previous_envelope : out envelope_ptr_t;
    variable position : out natural) is
  begin
    mailbox  := actors(actor.p_id_number).inbox when mailbox_id = inbox else actors(actor.p_id_number).outbox;
    envelope := mailbox.first_envelope;
    previous_envelope := null;
    position := 0;

    while envelope /= null loop
      if envelope.message.request_id = request_id then
        return;
      end if;
      previous_envelope := envelope;
      envelope := envelope.next_envelope;
      position := position + 1;
    end loop;
  end;

  impure function find_reply_message (
    actor      : actor_t;
    request_id : message_id_t;
    mailbox_id : mailbox_id_t := inbox)
    return integer is
    variable envelope          : envelope_ptr_t;
    variable previous_envelope : envelope_ptr_t := null;
    variable mailbox           : mailbox_ptr_t;
    variable position : natural;
  begin
    find_reply_message(actor, request_id, mailbox_id, mailbox, envelope, previous_envelope, position);

    if envelope /= null then
      return position;
    else
      return -1;
    end if;
  end;

  impure function find_and_stash_reply_message (
    actor      : actor_t;
    request_id : message_id_t;
    mailbox_id : mailbox_id_t := inbox)
    return boolean is
    variable envelope          : envelope_ptr_t;
    variable previous_envelope : envelope_ptr_t := null;
    variable mailbox           : mailbox_ptr_t;
    variable position : natural;
  begin
    find_reply_message(actor, request_id, mailbox_id, mailbox, envelope, previous_envelope, position);

    if envelope /= null then
      actors(actor.p_id_number).reply_stash := envelope;

      if previous_envelope /= null then
        previous_envelope.next_envelope := envelope.next_envelope;
      else
        mailbox.first_envelope := envelope.next_envelope;
      end if;

      if mailbox.first_envelope = null then
        mailbox.last_envelope := null;
      end if;

      mailbox.num_of_messages := mailbox.num_of_messages - 1;

      return true;
    end if;

    return false;
  end function find_and_stash_reply_message;

  procedure clear_reply_stash (actor : actor_t) is
  begin
    deallocate(actors(actor.p_id_number).reply_stash.message.payload);
    deallocate(actors(actor.p_id_number).reply_stash);
  end procedure clear_reply_stash;

  procedure subscribe (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t := published) is
    variable new_subscriber : subscriber_item_ptr_t;
  begin
    check(not unknown_actor(subscriber), unknown_subscriber_error);
    check(not unknown_actor(publisher), unknown_publisher_error);
    check(not is_subscriber(subscriber, publisher, traffic_type), already_a_subscriber_error);
    if traffic_type = published then
      check(not is_subscriber(subscriber, publisher, outbound), already_a_subscriber_error);
    elsif traffic_type = outbound then
      check(not is_subscriber(subscriber, publisher, published), already_a_subscriber_error);
    end if;

    if traffic_type = published then
      new_subscriber                              := new subscriber_item_t'(subscriber, actors(publisher.p_id_number).subscribers(published));
      actors(publisher.p_id_number).subscribers(published) := new_subscriber;
    elsif traffic_type = outbound then
      new_subscriber                             := new subscriber_item_t'(subscriber, actors(publisher.p_id_number).subscribers(outbound));
      actors(publisher.p_id_number).subscribers(outbound) := new_subscriber;
    else
      new_subscriber                            := new subscriber_item_t'(subscriber, actors(publisher.p_id_number).subscribers(inbound));
      actors(publisher.p_id_number).subscribers(inbound) := new_subscriber;
    end if;
  end procedure subscribe;

  procedure unsubscribe (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t := published) is
  begin
    check(not unknown_actor(subscriber), unknown_subscriber_error);
    check(not unknown_actor(publisher), unknown_publisher_error);
    check(is_subscriber(subscriber, publisher, traffic_type), not_a_subscriber_error);

    remove_subscriber(subscriber, publisher, traffic_type);
  end procedure unsubscribe;

  ---------------------------------------------------------------------------
  -- Debugging
  ---------------------------------------------------------------------------
  impure function get_subscriptions(subscriber : actor_t) return subscription_vec_t is
    impure function num_of_subscriptions return natural is
      variable n_subscriptions : natural := 0;
      variable item : subscriber_item_ptr_t;
    begin
      for a in actors'range loop
        for t in subscription_traffic_type_t'left to subscription_traffic_type_t'right loop
          item := actors(a).subscribers(t);
          while item /= null loop
            if item.actor = subscriber then
              n_subscriptions := n_subscriptions + 1;
            end if;
            item := item.next_item;
          end loop;
        end loop;
      end loop;

      return n_subscriptions;
    end;

    constant n_subscriptions : natural := num_of_subscriptions;
    variable subscriptions : subscription_vec_t(0 to n_subscriptions - 1);
    variable item : subscriber_item_ptr_t;
    variable idx : natural := 0;
  begin
    for a in actors'range loop
      for t in subscription_traffic_type_t'left to subscription_traffic_type_t'right loop
        item := actors(a).subscribers(t);
        while item /= null loop
          if item.actor = subscriber then
            subscriptions(idx).subscriber := subscriber;
            subscriptions(idx).publisher := actors(a).actor;
            subscriptions(idx).traffic_type := t;
            idx := idx + 1;
          end if;
          item := item.next_item;
        end loop;
      end loop;
    end loop;

    return subscriptions;
  end;

  impure function get_subscribers(publisher : actor_t) return subscription_vec_t is
    impure function num_of_subscriptions return natural is
      variable n_subscriptions : natural := 0;
      variable item : subscriber_item_ptr_t;
    begin
      for t in subscription_traffic_type_t'left to subscription_traffic_type_t'right loop
        item := actors(publisher.p_id_number).subscribers(t);
        while item /= null loop
          n_subscriptions := n_subscriptions + 1;
          item := item.next_item;
        end loop;
      end loop;

      return n_subscriptions;
    end;
    constant n_subscriptions : natural := num_of_subscriptions;
    variable subscriptions : subscription_vec_t(0 to n_subscriptions - 1);
    variable item : subscriber_item_ptr_t;
    variable idx : natural := 0;
  begin
    for t in subscription_traffic_type_t'left to subscription_traffic_type_t'right loop
      item := actors(publisher.p_id_number).subscribers(t);
      while item /= null loop
        subscriptions(idx).subscriber := item.actor;
        subscriptions(idx).publisher := publisher;
        subscriptions(idx).traffic_type := t;
        idx := idx + 1;
        item := item.next_item;
      end loop;
    end loop;

    return subscriptions;
  end;


  -----------------------------------------------------------------------------
  -- Misc
  -----------------------------------------------------------------------------
  procedure allow_timeout is
  begin
    timeout_allowed := true;
  end procedure allow_timeout;

  impure function timeout_is_allowed return boolean is
  begin
    return timeout_allowed;
  end function timeout_is_allowed;

  procedure allow_deprecated is
  begin
    deprecated_allowed := true;
  end procedure allow_deprecated;

  procedure deprecated (msg : string) is
  begin
    check(deprecated_allowed, deprecated_interface_error, msg);
  end;
end protected body;

end package body com_messenger_pkg;
