-- This file defines the com messenger which is responsible for housing the
-- messages in the system.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_bit.all;

use work.com_types_pkg.all;
use work.com_support_pkg.all;
use work.queue_pkg.all;
use work.queue_pool_pkg.all;
use work.string_ptr_pkg.all;
use work.codec_pkg.all;
--use work.logger_pkg.all;
--use work.log_levels_pkg.all;

use std.textio.all;

package com_messenger_pkg is
  type subscription_traffic_types_t is array (natural range <>) of subscription_traffic_type_t;

    -----------------------------------------------------------------------------
    -- Handling of actors
    -----------------------------------------------------------------------------
    impure function m_create (
      name : string := "";
      inbox_size : positive := 2**C_MAX_MSGS_L2-1;
      outbox_size : positive := 2**C_MAX_MSGS_L2-1
      ) return actor_t;
    impure function m_find (name  : string; enable_deferred_creation : boolean := true) return actor_t;
    impure function m_name (actor : actor_t) return string;

    procedure m_destroy (actor : inout actor_t);
    procedure m_reset_messenger;

    impure function m_num_of_actors return natural;
    impure function m_get_all_actors return actor_vec_t;
    impure function m_is_deferred(actor : actor_t) return boolean;
    impure function m_num_of_deferred_creations return natural;
    impure function m_unknown_actor (actor   : actor_t) return boolean;
    impure function m_deferred (actor        : actor_t) return boolean;
    impure function m_is_full (actor         : actor_t; mailbox_id : mailbox_id_t) return boolean;
    impure function m_num_of_messages (actor : actor_t; mailbox_id : mailbox_id_t) return natural;
    impure function m_mailbox_size (actor : actor_t; mailbox_id : mailbox_id_t) return natural;
    procedure m_resize_mailbox (actor : actor_t; new_size : natural; mailbox_id : mailbox_id_t);
    impure function m_subscriber_inbox_is_full (
      publisher                  : actor_t;
      subscription_traffic_types : subscription_traffic_types_t) return boolean;
    impure function m_has_subscribers (
      actor                     : actor_t;
      subscription_traffic_type : subscription_traffic_type_t := published) return boolean;

    -----------------------------------------------------------------------------
    -- Send related subprograms
    -----------------------------------------------------------------------------
    procedure m_send (
      constant sender     : in  actor_t;
      constant receiver   : in  actor_t;
      constant mailbox_id : in  mailbox_id_t;
      constant request_id : in  message_id_t;
      constant payload    : in  string;
      variable receipt    : out receipt_t);
    procedure m_send (
      constant receiver   : in    actor_t;
      constant mailbox_id : in    mailbox_id_t;
      variable msg        : inout msg_t);
    procedure m_publish (sender : actor_t; payload : string);
    procedure m_publish (
      constant sender                   : in    actor_t;
      variable msg                      : inout msg_t;
      constant subscriber_traffic_types : in    subscription_traffic_types_t);
    procedure m_internal_publish (
      constant sender                   : in    actor_t;
      variable msg                      : inout msg_t;
      constant subscriber_traffic_types : in    subscription_traffic_types_t);

    -----------------------------------------------------------------------------
    -- Receive related subprograms
    -----------------------------------------------------------------------------
    impure function m_has_messages (actor     : actor_t) return boolean;
    impure function m_has_messages (actor_vec : actor_vec_t) return boolean;
    impure function m_get_payload (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return string;
    impure function m_get_sender (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return actor_t;
    impure function m_get_receiver (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return actor_t;
    impure function m_get_id (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return message_id_t;
    impure function m_get_request_id (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return message_id_t;
    impure function m_get_all_but_payload (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox) return msg_t;

    procedure m_delete_envelope (
      actor      : actor_t;
      position   : natural      := 0;
      mailbox_id : mailbox_id_t := inbox);

--    impure function m_has_reply_stash_message (
--      actor      : actor_t;
--      request_id : message_id_t := no_message_id)
--      return boolean;                   --
--    impure function m_get_reply_stash_message_payload (actor    : actor_t) return string;
--    impure function m_get_reply_stash_message_sender (actor     : actor_t) return actor_t;
--    impure function m_get_reply_stash_message_receiver (actor     : actor_t) return actor_t;
--    impure function m_get_reply_stash_message_id (actor         : actor_t) return message_id_t;
--    impure function m_get_reply_stash_message_request_id (actor : actor_t) return message_id_t;
    impure function m_find_reply_message (
      actor      : actor_t;
      request_id : message_id_t;
      mailbox_id : mailbox_id_t := inbox)
      return integer;
--    impure function m_find_and_stash_reply_message (
--      actor      : actor_t;
--      request_id : message_id_t;
--      mailbox_id : mailbox_id_t := inbox)
--      return boolean;
--    procedure m_clear_reply_stash (actor : actor_t);

    procedure m_subscribe (
      subscriber   : actor_t;
      publisher    : actor_t;
      traffic_type : subscription_traffic_type_t := published);
    procedure m_unsubscribe (
      subscriber   : actor_t;
      publisher    : actor_t;
      traffic_type : subscription_traffic_type_t := published);

    ---------------------------------------------------------------------------
    -- Debugging
    ---------------------------------------------------------------------------
    impure function m_to_string(msg : msg_t) return string;
    impure function m_get_subscriptions(subscriber : actor_t) return subscription_vec_t;
    impure function m_get_subscribers(publisher : actor_t) return subscription_vec_t;

    ---------------------------------------------------------------------------
    -- Misc
    ---------------------------------------------------------------------------
    procedure m_allow_timeout;
    impure function m_timeout_is_allowed return boolean;
    procedure m_allow_deprecated;
    procedure m_deprecated (msg : string);

end package com_messenger_pkg;

package body com_messenger_pkg is

  constant null_message : message_t := (no_message_id, null_msg_type, ok, null_actor,
                                        null_actor, no_message_id, (others => nul));

  type message_array_t is array (natural range <>) of message_t;

  type mailbox_t is record
    size      : natural;
    head      : unsigned(C_MAX_MSGS_L2-1 downto 0);
    tail      : unsigned(C_MAX_MSGS_L2-1 downto 0);
    messages  : message_array_t(0 to 2**C_MAX_MSGS_L2-1);
  end record mailbox_t;

  constant null_mailbox : mailbox_t := (0, (others => '0'), (others => '0'), (others => null_message));

  function m_new_mailbox (size : natural := 2**C_MAX_MSGS_L2-1)
    return mailbox_t is
  begin
    return (size, (others => '0'), (others => '0'), (others => null_message));
  end;

  function m_count_messages (mbox : mailbox_t)
    return natural is
  begin
    return to_integer(mbox.head - mbox.tail);
  end;

  type subscriber_item_t is record
    actors    : actor_vec_t(0 to 2**C_MAX_ACTORS_L2-1);
    head      : unsigned(C_MAX_ACTORS_L2-1 downto 0);
    tail      : unsigned(C_MAX_ACTORS_L2-1 downto 0);
  end record subscriber_item_t;

  constant null_subscribers : subscriber_item_t := ((others => null_actor), (others => '0'), (others => '0'));

  function m_count_subscribers (subs : subscriber_item_t)
    return natural is
  begin
    return to_integer(subs.head - subs.tail);
  end;

  type actor_item_t is record
    actor             : actor_t;
    name              : line;
    deferred_creation : boolean;
    inbox             : mailbox_t;
    outbox            : mailbox_t;
--    reply_stash       : envelope_ptr_t;
    subscribers_p     : subscriber_item_t;
    subscribers_o     : subscriber_item_t;
    subscribers_i     : subscriber_item_t;
  end record actor_item_t;

  type actor_item_array_t is array (natural range <>) of actor_item_t;

  shared variable null_actor_item : actor_item_t := (
    actor             => null_actor,
    name              => null,
    deferred_creation => false,
    inbox             => null_mailbox,
    outbox            => null_mailbox,
--        reply_stash       => null,
    subscribers_p     => null_subscribers,
    subscribers_o     => null_subscribers,
    subscribers_i     => null_subscribers
  );

  shared variable next_message_id      : message_id_t := no_message_id + 1;
  shared variable timeout_allowed      : boolean      := false;
  shared variable deprecated_allowed   : boolean      := false;

  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------

  shared variable actors : actor_item_array_t(0 to 2**C_MAX_ACTORS_L2-1) := (others => null_actor_item);
  shared variable num_actors : natural := 1;

  impure function m_find_actor (name : string) return actor_t is
    variable ret_val : actor_t;
  begin
    for i in num_actors-1 downto 0 loop
      ret_val := actors(i).actor;
      if actors(i).name /= null then
        exit when actors(i).name.all = name;
      end if;
    end loop;

    return ret_val;
  end;

  impure function m_create_actor (
    name              :    string  := "";
    deferred_creation : in boolean := false;
    inbox_size        : in natural := 2**C_MAX_MSGS_L2-1;
    outbox_size       : in natural := 2**C_MAX_MSGS_L2-1)
    return actor_t is
  begin
    actors(num_actors) := ((id => num_actors), new string'(name), deferred_creation,
                           m_new_mailbox(inbox_size), m_new_mailbox(outbox_size),
                           null_subscribers, null_subscribers, null_subscribers);

    num_actors := num_actors + 1;
    return actors(num_actors - 1).actor;
  end function;

  impure function m_find (name : string; enable_deferred_creation : boolean := true) return actor_t is
    constant actor : actor_t := m_find_actor(name);
  begin
    if name = "" then
      return null_actor;
    elsif (actor = null_actor) and enable_deferred_creation then
      return m_create_actor(name, true, 1);
    else
      return actor;
    end if;
  end;

  impure function m_name (actor : actor_t) return string is
  begin
    if actors(actor.id).name /= null then
      return actors(actor.id).name.all;
    else
      return "";
    end if;
  end;


  impure function m_create (
    name : string := "";
    inbox_size : positive := 2**C_MAX_MSGS_L2-1;
    outbox_size : positive := 2**C_MAX_MSGS_L2-1
    ) return actor_t is
    variable actor : actor_t := m_find_actor(name);
  begin
    if (actor = null_actor) or (name = "") then
      actor := m_create_actor(name, false, inbox_size, outbox_size);
    elsif actors(actor.id).deferred_creation then
      actors(actor.id).deferred_creation := false;
      actors(actor.id).inbox.size        := inbox_size;
      actors(actor.id).outbox.size       := outbox_size;
    else
      check_failed(duplicate_actor_name_error);
    end if;

    return actor;
  end;

  impure function m_is_subscriber (
    subscribers  : subscriber_item_t;
    subscriber   : actor_t) return boolean is
    variable n_subs : natural := m_count_subscribers(subscribers);
    variable ptr    : natural := to_integer(subscribers.tail);
  begin
    for i in 0 to n_subs-1 loop
      if subscribers.actors(ptr) = subscriber then
        return true;
      end if;
      ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
    end loop;
    return false;
  end;

  impure function m_is_subscriber (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t) return boolean is
  begin
    case traffic_type is
      when published =>
        if m_is_subscriber(actors(publisher.id).subscribers_p, subscriber) then
          return true;
        end if;
      when outbound =>
        if m_is_subscriber(actors(publisher.id).subscribers_o, subscriber) then
          return true;
        end if;
      when inbound =>
        if m_is_subscriber(actors(publisher.id).subscribers_i, subscriber) then
          return true;
        end if;
    end case;

    return false;
  end;

  procedure m_remove_subscriber (subscribers : inout subscriber_item_t; subscriber : actor_t; found : inout boolean) is
    variable n_subs : natural := m_count_subscribers(subscribers);
    variable ptr    : natural := to_integer(subscribers.tail);
    variable ptr_m1 : natural;
  begin
    for i in 0 to n_subs-1 loop
      found := subscribers.actors(ptr) = subscriber;
      exit when found;
      ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
    end loop;
    if not found then
      return;
    end if;
    while ptr /= subscribers.tail loop  
      ptr_m1 := (ptr + 2**C_MAX_MSGS_L2-1) mod 2**C_MAX_MSGS_L2;
      subscribers.actors(ptr) := subscribers.actors(ptr_m1);
      ptr := ptr_m1;
    end loop;
    subscribers.tail := subscribers.tail + 1;
  end;

  procedure m_remove_subscriber (subscriber : actor_t; publisher : actor_t; traffic_type : subscription_traffic_type_t) is
    variable found : boolean;
  begin
    case traffic_type is
      when published =>
        m_remove_subscriber(actors(publisher.id).subscribers_p, subscriber, found);
      when outbound =>
        m_remove_subscriber(actors(publisher.id).subscribers_o, subscriber, found);
      when inbound =>
        m_remove_subscriber(actors(publisher.id).subscribers_i, subscriber, found);
    end case;

    if not found then
      check_failed(not_a_subscriber_error);
    end if;
  end;

  procedure m_destroy (actor : inout actor_t) is
  begin
    check(not m_unknown_actor(actor), unknown_actor_error);

    for i in 1 to num_actors-1 loop
      for t in subscription_traffic_type_t'left to subscription_traffic_type_t'right loop
        if m_is_subscriber(actor, actors(i).actor, t) then
          m_remove_subscriber(actor, actors(i).actor, t);
        end if;
      end loop;
    end loop;

    deallocate(actors(actor.id).name);
    actors(actor.id) := null_actor_item;
    actor            := null_actor;
  end;

  procedure m_reset_messenger is
  begin
    for i in 0 to 2**C_MAX_ACTORS_L2-1 loop
      actors(i) := null_actor_item;
    end loop;
    num_actors      := 1;
    next_message_id := no_message_id + 1;
  end;

  impure function m_num_of_actors return natural is
    variable n_actors : natural := 0;
  begin
    for i in 1 to num_actors-1 loop
      if actors(i).actor /= null_actor then
        n_actors := n_actors + 1;
      end if;
    end loop;

    return n_actors;
  end;

  impure function m_get_all_actors return actor_vec_t is
    constant n_actors : natural := m_num_of_actors;
    variable result : actor_vec_t(0 to n_actors - 1);
    variable idx : natural := 0;
  begin
    for i in 1 to num_actors-1 loop
      if actors(i).actor /= null_actor then
        result(idx) := actors(i).actor;
        idx := idx + 1;
      end if;
    end loop;

    return result;
  end;


  impure function m_is_deferred(actor : actor_t) return boolean is
  begin
    return actors(actor.id).deferred_creation;
  end;

  impure function m_num_of_deferred_creations return natural is
    variable n_deferred_actors : natural := 0;
  begin
    for i in 1 to num_actors-1 loop
      if actors(i).deferred_creation then
        n_deferred_actors := n_deferred_actors + 1;
      end if;
    end loop;

    return n_deferred_actors;
  end;

  impure function m_unknown_actor (actor : actor_t) return boolean is
  begin
    if (actor.id = 0) or (actor.id > num_actors - 1) then
      return true;
    elsif actors(actor.id).actor = null_actor then
      return true;
    end if;

    return false;
  end function m_unknown_actor;

  impure function m_deferred (actor : actor_t) return boolean is
  begin
    return actors(actor.id).deferred_creation;
  end function m_deferred;

  impure function m_is_full (actor : actor_t; mailbox_id : mailbox_id_t) return boolean is
  begin
    if mailbox_id = inbox then
      return m_count_messages(actors(actor.id).inbox) >= actors(actor.id).inbox.size;
    else
      return m_count_messages(actors(actor.id).outbox) >= actors(actor.id).outbox.size;
    end if;
  end function;

  impure function m_num_of_messages (actor : actor_t; mailbox_id : mailbox_id_t) return natural is
  begin
    if mailbox_id = inbox then
      return m_count_messages(actors(actor.id).inbox);
    else
      return m_count_messages(actors(actor.id).outbox);
    end if;
  end function;

  procedure m_resize_mailbox (actor : actor_t; new_size : natural; mailbox_id : mailbox_id_t) is
  begin
    if mailbox_id = inbox then
      check(m_count_messages(actors(actor.id).inbox) <= new_size, insufficient_size_error);
      actors(actor.id).inbox.size         := new_size;
    else
      check(m_count_messages(actors(actor.id).outbox) <= new_size, insufficient_size_error);
      actors(actor.id).outbox.size         := new_size;
    end if;
  end;

  impure function m_subscriber_inbox_is_full (
    publisher                  : actor_t;
    subscription_traffic_types : subscription_traffic_types_t) return boolean is
    variable result : boolean_vector(subscription_traffic_types'range) := (others => false);
    procedure m_has_full_inboxes (
      variable subscribers : in  subscriber_item_t;
      variable result      : out boolean) is
      variable n_subs : natural := m_count_subscribers(subscribers);
      variable ptr    : natural := to_integer(subscribers.tail);
    begin
      result := false;
      for i in 0 to n_subs-1 loop
        result := m_is_full(subscribers.actors(ptr), inbox);
        exit when result;
        m_has_full_inboxes(actors(subscribers.actors(ptr).id).subscribers_i, result);
        exit when result;
        ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
      end loop;
    end;
  begin
    for t in subscription_traffic_types'range loop
      case subscription_traffic_types(t) is
        when published =>
          m_has_full_inboxes(actors(publisher.id).subscribers_p, result(t));
        when outbound =>
          m_has_full_inboxes(actors(publisher.id).subscribers_o, result(t));
        when inbound =>
          m_has_full_inboxes(actors(publisher.id).subscribers_i, result(t));
      end case;
    end loop;

    return or result;
  end function;

  impure function m_has_subscribers (
    actor                     : actor_t;
    subscription_traffic_type : subscription_traffic_type_t := published) return boolean is
  begin
    case subscription_traffic_type is
      when published =>
        return m_count_subscribers(actors(actor.id).subscribers_p) /= 0;
      when outbound =>
        return m_count_subscribers(actors(actor.id).subscribers_o) /= 0;
      when inbound =>
        return m_count_subscribers(actors(actor.id).subscribers_i) /= 0;
    end case;
  end;

  impure function m_mailbox_size (actor : actor_t; mailbox_id : mailbox_id_t) return natural is
  begin
    if mailbox_id = inbox then
      return actors(actor.id).inbox.size;
    else
      return actors(actor.id).outbox.size;
    end if;
  end function;

  -----------------------------------------------------------------------------
  -- Send related subprograms
  -----------------------------------------------------------------------------
  procedure m_send (
    constant sender     : in  actor_t;
    constant receiver   : in  actor_t;
    constant mailbox_id : in  mailbox_id_t;
    constant request_id : in  message_id_t;
    constant payload    : in  string;
    variable receipt    : out receipt_t) is
    variable head : natural;
  begin
    check(not m_is_full(receiver, mailbox_id), full_inbox_error);

    receipt.status              := ok;
    receipt.id                  := next_message_id;

    if mailbox_id = inbox then
      head := to_integer(actors(receiver.id).inbox.head);
      actors(receiver.id).inbox.messages(head).sender     := sender;
      actors(receiver.id).inbox.messages(head).receiver   := receiver;
      actors(receiver.id).inbox.messages(head).id         := next_message_id;
      actors(receiver.id).inbox.messages(head).request_id := request_id;
      actors(receiver.id).inbox.messages(head).payload    := payload;
      actors(receiver.id).inbox.head := actors(receiver.id).inbox.head + 1;
    else
      head := to_integer(actors(receiver.id).outbox.head);
      actors(receiver.id).outbox.messages(head).sender     := sender;
      actors(receiver.id).outbox.messages(head).receiver   := receiver;
      actors(receiver.id).outbox.messages(head).id         := next_message_id;
      actors(receiver.id).outbox.messages(head).request_id := request_id;
      actors(receiver.id).outbox.messages(head).payload    := payload;
      actors(receiver.id).outbox.head := actors(receiver.id).outbox.head + 1;
    end if;
  end;

  procedure m_publish (sender : actor_t; payload : string) is
    variable receipt         : receipt_t;
    variable n_subs : natural := m_count_subscribers(actors(sender.id).subscribers_p);
    variable ptr    : natural := to_integer(actors(sender.id).subscribers_p.tail);
  begin
    check(not m_unknown_actor(sender), unknown_publisher_error);

    for i in 0 to n_subs-1 loop
      m_send(sender, actors(sender.id).subscribers_p.actors(ptr), inbox, no_message_id, payload, receipt);
      ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
    end loop;
  end;

  impure function m_to_string(msg : msg_t) return string is
    function m_id_to_string(id : message_id_t) return string is
    begin
      if id = no_message_id then
        return "-";
      else
        return to_string(id);
      end if;
    end function;

    impure function m_actor_to_string(actor : actor_t) return string is
    begin
      if actor = null_actor then
        return "-";
      else
        return m_name(actor);
      end if;
    end function;

    impure function m_msg_type_to_string (msg_type : msg_type_t) return string is
    begin
      if msg_type = null_msg_type then
        return "-";
      else
        return name(msg_type);
      end if;
    end;

  begin
    return m_id_to_string(msg.id) & ":" & m_id_to_string(msg.request_id) & " " &
      m_actor_to_string(msg.sender) & " -> " & m_actor_to_string(msg.receiver) &
      " (" & m_msg_type_to_string(msg.msg_type) & ")";
  end;

  procedure m_put_message (
    receiver   : actor_t;
    msg        : msg_t;
    mailbox_id : mailbox_id_t;
    copy_msg : boolean) is
    variable data     : msg_data_t := msg.data;
    variable head : natural;

  begin
    if copy_msg then
      data := new_queue(queue_pool);
      for i in 0 to length(msg.data) - 1 loop
        unsafe_push(data, get(msg.data.data, 1+i));
      end loop;
    end if;

--    if is_visible(com_logger, trace) then
--      trace(com_logger, "[" & m_to_string(msg) & "] => " & m_name(receiver) & " " & mailbox_id_t'image(mailbox_id));
--    end if;

    if mailbox_id = inbox then
      head := to_integer(actors(receiver.id).inbox.head);
      actors(receiver.id).inbox.messages(head).id         := msg.id;
      actors(receiver.id).inbox.messages(head).msg_type   := msg.msg_type;
      actors(receiver.id).inbox.messages(head).sender     := msg.sender;
      actors(receiver.id).inbox.messages(head).receiver   := msg.receiver;
      actors(receiver.id).inbox.messages(head).request_id := msg.request_id;
      actors(receiver.id).inbox.messages(head).payload    := encode(data);
      actors(receiver.id).inbox.head := actors(receiver.id).inbox.head + 1;
    else
      head := to_integer(actors(receiver.id).outbox.head);
      actors(receiver.id).outbox.messages(head).id         := msg.id;
      actors(receiver.id).outbox.messages(head).msg_type   := msg.msg_type;
      actors(receiver.id).outbox.messages(head).sender     := msg.sender;
      actors(receiver.id).outbox.messages(head).receiver   := msg.receiver;
      actors(receiver.id).outbox.messages(head).request_id := msg.request_id;
      actors(receiver.id).outbox.messages(head).payload    := encode(data);
      actors(receiver.id).outbox.head := actors(receiver.id).outbox.head + 1;
    end if;
  end procedure;

  procedure m_put_subscriber_messages (
    variable subscribers      : inout subscriber_item_t;
    variable msg              : inout msg_t;
    constant set_msg_receiver : in    boolean) is
    variable n_subs : natural := m_count_subscribers(subscribers);
    variable ptr    : natural := to_integer(subscribers.tail);
  begin
    for i in 0 to n_subs-1 loop
      if set_msg_receiver then
        msg.receiver := subscribers.actors(ptr);
      end if;
      m_put_message(subscribers.actors(ptr), msg, inbox, true);
      m_internal_publish(subscribers.actors(ptr), msg, (0 => inbound));
      ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
    end loop;
  end;

  procedure m_publish (
    constant sender                   : in    actor_t;
    variable msg                      : inout msg_t;
    constant subscriber_traffic_types : in    subscription_traffic_types_t) is
  begin
    check(not m_unknown_actor(sender), unknown_publisher_error);
    check(msg.data /= null_queue, null_message_error);

    msg.id     := next_message_id;
    next_message_id := next_message_id + 1;
    msg.status := ok;
    msg.sender := sender;

    for t in subscriber_traffic_types'range loop
      case subscriber_traffic_types(t) is
        when published =>
          m_put_subscriber_messages(actors(sender.id).subscribers_p,
                                    msg, set_msg_receiver => true);
        when outbound =>
          m_put_subscriber_messages(actors(sender.id).subscribers_o,
                                    msg, set_msg_receiver => true);
        when inbound =>
          m_put_subscriber_messages(actors(sender.id).subscribers_i,
                                    msg, set_msg_receiver => true);
      end case;
    end loop;

    msg.receiver := null_actor;
  end;

  procedure m_internal_publish (
    constant sender                   : in    actor_t;
    variable msg                      : inout msg_t;
    constant subscriber_traffic_types : in    subscription_traffic_types_t) is
  begin
    for t in subscriber_traffic_types'range loop
      case subscriber_traffic_types(t) is
        when published =>
          m_put_subscriber_messages(actors(sender.id).subscribers_p,
                                    msg, set_msg_receiver => false);
        when outbound =>
          m_put_subscriber_messages(actors(sender.id).subscribers_o,
                                    msg, set_msg_receiver => false);
        when inbound =>
          m_put_subscriber_messages(actors(sender.id).subscribers_i,
                                    msg, set_msg_receiver => false);
      end case;
    end loop;
  end;

  procedure m_send (
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


    m_put_message(receiver, msg, mailbox_id, false);
  end;

  -----------------------------------------------------------------------------
  -- Receive related subprograms
  -----------------------------------------------------------------------------
  impure function m_has_messages (actor : actor_t) return boolean is
  begin
    return m_count_messages(actors(actor.id).inbox) /= 0;
  end function m_has_messages;

  impure function m_has_messages (actor_vec : actor_vec_t) return boolean is
  begin
    for i in actor_vec'range loop
      if m_has_messages(actor_vec(i)) then
        return true;
      end if;
    end loop;
    return false;
  end function m_has_messages;

  procedure m_get_message (
    mailbox    : mailbox_t;
    position   : natural;
    msg        : out message_t;
    found      : out boolean) is
    variable idx : natural := to_integer(mailbox.tail + position);
  begin
    if m_count_messages(mailbox) <= position then
      found := false;
    else
      found := true;
      msg   := mailbox.messages(idx);
    end if;
  end;

  impure function m_get_payload (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return string is
    variable msg : message_t;
    variable found : boolean;
  begin
    if mailbox_id = inbox then
      m_get_message(actors(actor.id).inbox, position, msg, found);
    else
      m_get_message(actors(actor.id).outbox, position, msg, found);
    end if;
    if found then
      return msg.payload;
    else
      return "";
    end if;
  end;

  impure function m_get_sender (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return actor_t is
    variable msg : message_t;
    variable found : boolean;
  begin
    if mailbox_id = inbox then
      m_get_message(actors(actor.id).inbox, position, msg, found);
    else
      m_get_message(actors(actor.id).outbox, position, msg, found);
    end if;
    if found then
      return msg.sender;
    else
      return null_actor;
    end if;
  end;

  impure function m_get_receiver (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return actor_t is
    variable msg : message_t;
    variable found : boolean;
  begin
    if mailbox_id = inbox then
      m_get_message(actors(actor.id).inbox, position, msg, found);
    else
      m_get_message(actors(actor.id).outbox, position, msg, found);
    end if;
    if found then
      return msg.receiver;
    else
      return null_actor;
    end if;
  end;

  impure function m_get_id (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return message_id_t is
    variable msg : message_t;
    variable found : boolean;
  begin
    if mailbox_id = inbox then
      m_get_message(actors(actor.id).inbox, position, msg, found);
    else
      m_get_message(actors(actor.id).outbox, position, msg, found);
    end if;
    if found then
      return msg.id;
    else
      return no_message_id;
    end if;
  end;

  impure function m_get_request_id (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return message_id_t is
    variable msg : message_t;
    variable found : boolean;
  begin
    if mailbox_id = inbox then
      m_get_message(actors(actor.id).inbox, position, msg, found);
    else
      m_get_message(actors(actor.id).outbox, position, msg, found);
    end if;
    if found then
      return msg.request_id;
    else
      return no_message_id;
    end if;
  end;

  impure function m_get_all_but_payload (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) return msg_t is
    variable msg : msg_t;
    variable message : message_t;
    variable found : boolean;
  begin
    if mailbox_id = inbox then
      m_get_message(actors(actor.id).inbox, position, message, found);
    else
      m_get_message(actors(actor.id).outbox, position, message, found);
    end if;

    if found then
      msg.id          := message.id;
      msg.msg_type    := message.msg_type;
      msg.status      := message.status;
      msg.sender      := message.sender;
      msg.receiver    := message.receiver;
      msg.request_id  := message.request_id;
      msg.data        := null_queue;
    else
      msg := null_msg;
    end if;

    return msg;
  end;

  procedure m_delete_envelope (
    position   : natural      := 0;
    mailbox    : inout mailbox_t) is
    variable n_msgs : natural := m_count_messages(mailbox);
    variable ptr    : natural := to_integer(mailbox.tail + position);
    variable ptr_m1 : natural;
  begin
    if n_msgs <= position then
      return;
    end if;
    for i in 0 to position-1 loop
      ptr_m1 := (ptr + 2**C_MAX_MSGS_L2-1) mod 2**C_MAX_MSGS_L2;
      mailbox.messages(ptr) := mailbox.messages(ptr_m1);
      ptr := ptr_m1;
    end loop;
    mailbox.tail := mailbox.tail + 1;
  end;

  procedure m_delete_envelope (
    actor      : actor_t;
    position   : natural      := 0;
    mailbox_id : mailbox_id_t := inbox) is
  begin
    if mailbox_id = inbox then
      m_delete_envelope(position, actors(actor.id).inbox);
    else
      m_delete_envelope(position, actors(actor.id).outbox);
    end if;
  end;

--  impure function m_has_reply_stash_message (
--    actor      : actor_t;
--    request_id : message_id_t := no_message_id)
--    return boolean is
--  begin
--    if request_id = no_message_id then
--      return actors(actor.id).reply_stash /= null;
--    elsif actors(actor.id).reply_stash /= null then
--      return actors(actor.id).reply_stash.message.request_id = request_id;
--    else
--      return false;
--    end if;
--  end function m_has_reply_stash_message;
--
--  impure function m_get_reply_stash_message_payload (actor : actor_t) return string is
--    variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
--  begin
--    if envelope /= null then
--      return envelope.message.payload.all;
--    else
--      return "";
--    end if;
--  end;
--
--  impure function m_get_reply_stash_message_sender (actor : actor_t) return actor_t is
--    variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
--  begin
--    if envelope /= null then
--      return envelope.message.sender;
--    else
--      return null_actor;
--    end if;
--  end;
--
--  impure function m_get_reply_stash_message_receiver (actor     : actor_t) return actor_t is
--    variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
--  begin
--    if envelope /= null then
--      return envelope.message.receiver;
--    else
--      return null_actor;
--    end if;
--  end;
--
--  impure function m_get_reply_stash_message_id (actor : actor_t) return message_id_t is
--    variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
--  begin
--    if envelope /= null then
--      return envelope.message.id;
--    else
--      return no_message_id;
--    end if;
--  end;
--
--  impure function m_get_reply_stash_message_request_id (actor : actor_t) return message_id_t is
--    variable envelope : envelope_ptr_t := actors(actor.id).reply_stash;
--  begin
--    if envelope /= null then
--      return envelope.message.request_id;
--    else
--      return no_message_id;
--    end if;
--  end;

  procedure m_find_reply_message (
    mailbox    : mailbox_t;
    request_id : message_id_t;
    variable position : out integer) is
    variable n_msgs : natural := m_count_messages(mailbox);
    variable ptr    : natural := to_integer(mailbox.tail);
  begin
    for i in 0 to n_msgs-1 loop
      if mailbox.messages(ptr).request_id = request_id then
        position := i;
        return;
      end if;
      ptr := (ptr + 1) mod 2**C_MAX_MSGS_L2;
    end loop;

    position := -1;
  end;

  impure function m_find_reply_message (
    actor      : actor_t;
    request_id : message_id_t;
    mailbox_id : mailbox_id_t := inbox)
    return integer is
    variable position : integer;
  begin
    if mailbox_id = inbox then
      m_find_reply_message(actors(actor.id).inbox, request_id, position);
    else
      m_find_reply_message(actors(actor.id).outbox, request_id, position);
    end if;

    return position;
  end;

--  impure function m_find_and_stash_reply_message (
--    actor      : actor_t;
--    request_id : message_id_t;
--    mailbox_id : mailbox_id_t := inbox)
--    return boolean is
--    variable envelope          : envelope_ptr_t;
--    variable previous_envelope : envelope_ptr_t := null;
--    variable mailbox           : mailbox_ptr_t;
--    variable position : natural;
--  begin
--    m_find_reply_message(actor, request_id, mailbox_id, mailbox, envelope, previous_envelope, position);
--
--    if envelope /= null then
--      actors(actor.id).reply_stash := envelope;
--
--      if previous_envelope /= null then
--        previous_envelope.next_envelope := envelope.next_envelope;
--      else
--        mailbox.first_envelope := envelope.next_envelope;
--      end if;
--
--      if mailbox.first_envelope = null then
--        mailbox.last_envelope := null;
--      end if;
--
--      mailbox.num_of_messages := mailbox.num_of_messages - 1;
--
--      return true;
--    end if;
--
--    return false;
--  end function m_find_and_stash_reply_message;
--
--  procedure m_clear_reply_stash (actor : actor_t) is
--  begin
--    deallocate(actors(actor.id).reply_stash.message.payload);
--    deallocate(actors(actor.id).reply_stash);
--  end procedure m_clear_reply_stash;

  procedure m_add_subscriber (subscribers : inout subscriber_item_t; subscriber : actor_t) is
  begin
    subscribers.actors(to_integer(subscribers.head)) := subscriber;
    subscribers.head := subscribers.head + 1;
  end;

  procedure m_subscribe (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t := published) is
  begin
    check(not m_unknown_actor(subscriber), unknown_subscriber_error);
    check(not m_unknown_actor(publisher), unknown_publisher_error);
    check(not m_is_subscriber(subscriber, publisher, traffic_type), already_a_subscriber_error);
    if traffic_type = published then
      check(not m_is_subscriber(subscriber, publisher, outbound), already_a_subscriber_error);
    elsif traffic_type = outbound then
      check(not m_is_subscriber(subscriber, publisher, published), already_a_subscriber_error);
    end if;

    case traffic_type is
      when published =>
        m_add_subscriber(actors(publisher.id).subscribers_p, subscriber);
      when outbound =>
        m_add_subscriber(actors(publisher.id).subscribers_o, subscriber);
      when inbound =>
        m_add_subscriber(actors(publisher.id).subscribers_i, subscriber);
    end case;
  end procedure m_subscribe;

  procedure m_unsubscribe (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t := published) is
  begin
    check(not m_unknown_actor(subscriber), unknown_subscriber_error);
    check(not m_unknown_actor(publisher), unknown_publisher_error);
    check(m_is_subscriber(subscriber, publisher, traffic_type), not_a_subscriber_error);

    m_remove_subscriber(subscriber, publisher, traffic_type);
  end procedure m_unsubscribe;

  ---------------------------------------------------------------------------
  -- Debugging
  ---------------------------------------------------------------------------
  impure function m_get_subscriptions(subscriber : actor_t) return subscription_vec_t is
    impure function m_num_of_subscriptions return natural is
      variable n_subscriptions  : natural := 0;
      variable ptr              : natural;
    begin
      for a in 1 to num_actors-1 loop
        for t in subscription_traffic_type_t'left to subscription_traffic_type_t'right loop
          case t is
            when published =>
              ptr := to_integer(actors(a).subscribers_p.tail);
              for i in 0 to m_count_subscribers(actors(a).subscribers_p)-1 loop
                if actors(a).subscribers_p.actors(ptr) = subscriber then
                  n_subscriptions := n_subscriptions + 1;
                end if;
                ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
              end loop;
            when outbound =>
              ptr := to_integer(actors(a).subscribers_o.tail);
              for i in 0 to m_count_subscribers(actors(a).subscribers_o)-1 loop
                if actors(a).subscribers_o.actors(ptr) = subscriber then
                  n_subscriptions := n_subscriptions + 1;
                end if;
                ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
              end loop;
            when inbound =>
              ptr := to_integer(actors(a).subscribers_i.tail);
              for i in 0 to m_count_subscribers(actors(a).subscribers_i)-1 loop
                if actors(a).subscribers_i.actors(ptr) = subscriber then
                  n_subscriptions := n_subscriptions + 1;
                end if;
                ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
              end loop;
          end case;
        end loop;
      end loop;

      return n_subscriptions;
    end;

    constant n_subscriptions : natural := m_num_of_subscriptions;
    variable subscriptions : subscription_vec_t(0 to n_subscriptions-1);
    variable idx : natural := 0;
    variable ptr : natural;
  begin
    for a in 1 to num_actors-1 loop
      for t in subscription_traffic_type_t'left to subscription_traffic_type_t'right loop
        case t is
          when published =>
            ptr := to_integer(actors(a).subscribers_p.tail);
            for i in 0 to m_count_subscribers(actors(a).subscribers_p)-1 loop
              if actors(a).subscribers_p.actors(ptr) = subscriber then
                subscriptions(idx).subscriber := subscriber;
                subscriptions(idx).publisher := actors(a).actor;
                subscriptions(idx).traffic_type := t;
                idx := idx + 1;
              end if;
              ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
            end loop;
          when outbound =>
            ptr := to_integer(actors(a).subscribers_o.tail);
            for i in 0 to m_count_subscribers(actors(a).subscribers_o)-1 loop
              if actors(a).subscribers_o.actors(ptr) = subscriber then
                subscriptions(idx).subscriber := subscriber;
                subscriptions(idx).publisher := actors(a).actor;
                subscriptions(idx).traffic_type := t;
                idx := idx + 1;
              end if;
              ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
            end loop;
          when inbound =>
            ptr := to_integer(actors(a).subscribers_i.tail);
            for i in 0 to m_count_subscribers(actors(a).subscribers_i)-1 loop
              if actors(a).subscribers_i.actors(ptr) = subscriber then
                subscriptions(idx).subscriber := subscriber;
                subscriptions(idx).publisher := actors(a).actor;
                subscriptions(idx).traffic_type := t;
                idx := idx + 1;
              end if;
              ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
            end loop;
        end case;
      end loop;
    end loop;

    return subscriptions;
  end;

  impure function m_get_subscribers(publisher : actor_t) return subscription_vec_t is
    impure function m_num_of_subscriptions return natural is
      variable n_subscriptions : natural := 0;
    begin
      for t in subscription_traffic_type_t'left to subscription_traffic_type_t'right loop
        case t is
          when published =>
            n_subscriptions := n_subscriptions + m_count_subscribers(actors(publisher.id).subscribers_p);
          when outbound =>
            n_subscriptions := n_subscriptions + m_count_subscribers(actors(publisher.id).subscribers_o);
          when inbound =>
            n_subscriptions := n_subscriptions + m_count_subscribers(actors(publisher.id).subscribers_i);
        end case;
      end loop;

      return n_subscriptions;
    end;
    constant n_subscriptions : natural := m_num_of_subscriptions;
    variable subscriptions : subscription_vec_t(0 to n_subscriptions-1);
    variable idx : natural := 0;
    variable ptr : natural;
  begin
    for t in subscription_traffic_type_t'left to subscription_traffic_type_t'right loop
      case t is
        when published =>
          ptr := to_integer(actors(publisher.id).subscribers_p.tail);
          for i in 0 to m_count_subscribers(actors(publisher.id).subscribers_p)-1 loop
            subscriptions(idx).subscriber := actors(publisher.id).subscribers_p.actors(ptr);
            subscriptions(idx).publisher := publisher;
            subscriptions(idx).traffic_type := t;
            idx := idx + 1;
            ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
          end loop;
        when outbound =>
          ptr := to_integer(actors(publisher.id).subscribers_o.tail);
          for i in 0 to m_count_subscribers(actors(publisher.id).subscribers_o)-1 loop
            subscriptions(idx).subscriber := actors(publisher.id).subscribers_o.actors(ptr);
            subscriptions(idx).publisher := publisher;
            subscriptions(idx).traffic_type := t;
            idx := idx + 1;
            ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
          end loop;
        when inbound =>
          ptr := to_integer(actors(publisher.id).subscribers_i.tail);
          for i in 0 to m_count_subscribers(actors(publisher.id).subscribers_i)-1 loop
            subscriptions(idx).subscriber := actors(publisher.id).subscribers_i.actors(ptr);
            subscriptions(idx).publisher := publisher;
            subscriptions(idx).traffic_type := t;
            idx := idx + 1;
            ptr := (ptr + 1) mod 2**C_MAX_ACTORS_L2;
          end loop;
      end case;
    end loop;

    return subscriptions;
  end;


  -----------------------------------------------------------------------------
  -- Misc
  -----------------------------------------------------------------------------
  procedure m_allow_timeout is
  begin
    timeout_allowed := true;
  end procedure m_allow_timeout;

  impure function m_timeout_is_allowed return boolean is
  begin
    return timeout_allowed;
  end function m_timeout_is_allowed;

  procedure m_allow_deprecated is
  begin
    deprecated_allowed := true;
  end procedure m_allow_deprecated;

  procedure m_deprecated (msg : string) is
  begin
    check(deprecated_allowed, deprecated_interface_error, msg);
  end;

end package body com_messenger_pkg;
