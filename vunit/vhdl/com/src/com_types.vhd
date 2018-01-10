-- Common com types.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

use work.queue_pkg.all;

package com_types_pkg is

  -- These status types are mostly internal to com and will cause runtime
  -- errors. Only ok and timeout will ever be returned to the user
  type com_status_t is (ok,
                        timeout,
                        null_message_error,
                        unknown_actor_error,
                        unknown_receiver_error,
                        unknown_subscriber_error,
                        unknown_publisher_error,
                        deferred_receiver_error,
                        already_a_subscriber_error,
                        not_a_subscriber_error,
                        full_inbox_error,
                        reply_missing_request_id_error,
                        unknown_request_id_error,
                        deprecated_interface_error,
                        insufficient_size_error,
                        duplicate_actor_name_error);

  subtype com_error_t is com_status_t range timeout to duplicate_actor_name_error;

  -- All fields of the actor type are private
  type actor_t is record
    id : natural;
  end record actor_t;
  type actor_vec_t is array(integer range <>) of actor_t;
  constant null_actor_c : actor_t := (id => 0);

  -- Mailboxes owned by an actor
  type mailbox_id_t is (inbox, outbox);

  -- Every message has a unique ID unless its a message from an inbound or
  -- outbound traffic subscription. These messages will have the same ID as
  -- the original message
  subtype message_id_t is natural;
  constant no_message_id_c : message_id_t := 0;

  -- Deprecated message type
  type message_t is record
    id         : message_id_t;
    status     : com_status_t;
    sender     : actor_t;
    receiver   : actor_t;
    request_id : message_id_t;
    payload    : line;
  end record message_t;
  type message_ptr_t is access message_t;

  subtype msg_data_t is queue_t;

  -- Message type. All fields of the record are private and should not be
  -- referenced directly by the user.
  type msg_t is record
    id         : message_id_t;
    status     : com_status_t;
    sender     : actor_t;
    receiver   : actor_t;

    -- ID for the request message if this is a reply
    request_id : message_id_t;

    data       : msg_data_t;
  end record msg_t;
  type msg_vec_t is array (natural range <>) of msg_t;
  type msg_vec_ptr_t is access msg_vec_t;

  -- Current state of mailbox
  type mailbox_state_t is record
    id       : mailbox_id_t;
    size     : natural;
    messages : msg_vec_ptr_t;
  end record mailbox_state_t;

  -- A subscriber can subscribe on three different types of traffic:
  --
  -- published - Messages published by publisher
  -- outbound - All non-anonymous outbound messages from publisher
  -- inbound - All inbound messages to publisher. Replies anonymous requests are excluded.
  type subscription_traffic_type_t is (published, outbound, inbound);

  type subscription_t is record
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t;
  end record subscription_t;
  type subscription_vec_t is array (natural range <>) of subscription_t;
  type subscription_vec_ptr_t is access subscription_vec_t;

  -- Deprecated
  type receipt_t is record
    status : com_status_t;
    id     : message_id_t;
  end record receipt_t;

  -- An event type representing the network over which actors communicate. An event in
  -- the network notifies connected actors which can determine the cause of the
  -- event by consulting the com messenger (com_messenger.vhd). Actors can be
  -- connected to different networks but there's only one global messenger.
  subtype network_t is std_logic;
  constant network_event : std_logic := '1';
  constant idle_network  : std_logic := 'Z';

  -- Default value for timeout parameters. ModelSim can't handle time'high
  constant max_timeout_c : time := 1 hr;

  -- Captures the state of an actor
  type actor_state_t is record
    name               : line;
    is_deferred        : boolean;
    inbox              : msg_vec_ptr_t;
    outbox             : msg_vec_ptr_t;
    subscriptions      : subscription_vec_ptr_t;
    subscribers        : subscription_vec_ptr_t;
  end record actor_state_t;
end package;
