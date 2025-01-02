-- Com API package provides the common API for all
-- implementations of the com functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.com_types_pkg.all;
use work.id_pkg.id_t;
use work.event_private_pkg.new_basic_event;
use work.event_private_pkg.com_net_event;

package com_pkg is
  -- Global predefined network. See network_t description in com_types.vhd for
  -- more information.
  signal net : network_t := new_basic_event(com_net_event);

  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  -- Create a new actor from name. Names must be unique and if no name is given
  -- (name = "") the actor will be assigned a unique name internally. For each
  -- new actor an identity for that name will be created if it doesn't already
  -- exist.
  impure function new_actor (
    name : string := "";
    inbox_size : positive := positive'high;
    outbox_size : positive := positive'high
  ) return actor_t;

  -- Create a new actor an identity. Only one actor can be created for each
  -- identity.
  impure function new_actor (
    id : id_t;
    inbox_size : positive := positive'high;
    outbox_size : positive := positive'high
  ) return actor_t;

  -- Find named actor by name. Enable deferred creation to create a deferred
  -- actor when no actor is found
  impure function find (name : string; enable_deferred_creation : boolean := true) return actor_t;

  -- Find named actor by identity. Enable deferred creation to create a deferred
  -- actor when no actor is found
  impure function find (id : id_t; enable_deferred_creation : boolean := true) return actor_t;

  -- Name of actor
  impure function name (actor : actor_t) return string;

  -- Return identity of actor
  impure function get_id(actor : actor_t) return id_t;

  -- Destroy actor. Mailboxes are deallocated and dependent subscriptions are
  -- removed. Returns null_actor.
  procedure destroy (actor : inout actor_t);

  -- Reset communication system. All actors are destroyed.
  procedure reset_messenger;

  -- Check if an actor's creation is deferred
  impure function is_deferred(actor : actor_t) return boolean;

  -- Total number of actors with deferred creation
  impure function num_of_deferred_creations return natural;

  -- Total number of actors
  impure function num_of_actors return natural;

  -- Number of messages in actor mailbox
  impure function num_of_messages (actor : actor_t; mailbox_id : mailbox_id_t := inbox) return natural;

  -- Return the maximum number of messages that can be stored in an inbox
  impure function mailbox_size (actor : actor_t; mailbox_id : mailbox_id_t := inbox) return natural;

  -- Resize actor mailbox. Reducing size below the number of messages in the
  -- mailbox in runtime error
  procedure resize_mailbox (actor : actor_t; new_size : natural; mailbox_id : mailbox_id_t := inbox);

  -----------------------------------------------------------------------------
  -- Primary send and receive related subprograms
  --
  -- All timeouts will result in a runtime error unless otherwise noted.
  -----------------------------------------------------------------------------

  -- Send message to receiver. Blocking if reciever or any subscriber inbox is
  -- full.
  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable msg      : inout msg_t;
    constant timeout  : in    time := max_timeout);

  -- Send message to an array of receivers. Blocking if any reciever or any subscriber inbox is
  -- full.
  procedure send (
    signal net         : inout network_t;
    constant receivers : in    actor_vec_t;
    variable msg       : inout msg_t;
    constant timeout   : in    time := max_timeout);

  -- Receive message sent to receiver. Returns oldest message or the first
  -- incoming if the inbox is empty. msg is initially deleted.
  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable msg      : inout msg_t;
    constant timeout  : in    time := max_timeout);

  -- Receive message sent to any of the receivers. Returns oldest message or the first
  -- incoming if the inboxes are empty. Receiver inboxes are emptied from left
  -- to right. msg is initially deleted.
  procedure receive (
    signal net         : inout network_t;
    constant receivers : in    actor_vec_t;
    variable msg       : inout msg_t;
    constant timeout   : in    time := max_timeout);

  -- Reply to request_msg with reply_msg. request_msg may be anonymous. Blocking if reciever
  -- or any subscriber inbox is full.
  procedure reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout);

  -- Receive a reply_msg to request_msg. request_msg may be anonymous. reply_msg is initially deleted.
  procedure receive_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout);

  -- Publish a message from sender to all its subscribers. Blocking if reciever or any subscriber inbox is
  -- full.
  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    variable msg     : inout msg_t;
    constant timeout : in    time := max_timeout);

  -- Peek at message in actor mailbox but don't remove it. Position 0 is the oldest message. Runtime error if
  -- position doesn't exist.
  impure function peek_message(
    actor : actor_t;
    position : natural := 0;
    mailbox_id : mailbox_id_t := inbox) return msg_t;

  -----------------------------------------------------------------------------
  -- Secondary send and receive related subprograms
  --
  -- All timeouts will result in a runtime error unless otherwise noted.
  -----------------------------------------------------------------------------

  -- Positive or negative acknowledge of a request_msg. Same as a reply with a
  -- boolean reply message.
  procedure acknowledge (
    signal net            : inout network_t;
    variable request_msg  : inout msg_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout);

  -- Receive positive or negative acknowledge for a request_msg. request_msg
  -- may be anonymous. reply_msg is initially deleted.
  procedure receive_reply (
    signal net            : inout network_t;
    variable request_msg  : inout msg_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout);

  -- This request is the same as send of request_msg to receiver followed by a
  -- receive_reply of a reply_msg
  procedure request (
    signal net           : inout network_t;
    constant receiver    : in    actor_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout);

  -- This request is the same as send of request_msg to receiver followed by a
  -- receive_reply of a positive or negative acknowledge.
  procedure request (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable request_msg  : inout msg_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout);

  -----------------------------------------------------------------------------
  -- Low-level subprograms primarily used for handling timeout wihout error
  -----------------------------------------------------------------------------

  -- Wait for message sent to receiver. status = ok if message is
  -- received before the timeout, status = timeout otherwise.
  procedure wait_for_message (
    signal net        : in  network_t;
    constant receiver : in  actor_t;
    variable status   : out com_status_t;
    constant timeout  : in  time := max_timeout);

  -- Wait for message sent to any of the listed receivers. status = ok
  -- if message is received before the timeout, status = timeout otherwise.
  procedure wait_for_message (
    signal net         : in  network_t;
    constant receivers : in  actor_vec_t;
    variable status    : out com_status_t;
    constant timeout   : in  time := max_timeout);

  -- Returns true if there is at least one message in the actor's inbox.
  impure function has_message (actor : actor_t) return boolean;

  -- Wait for reply to request_msg. status = ok
  -- if message is received before the timeout, status = timeout otherwise.
  procedure wait_for_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable status      : out   com_status_t;
    constant timeout     : in    time := max_timeout);

  -- Get oldest message from receiver inbox. Runtime error if inbox is empty.
  procedure get_message (signal net : inout network_t; receiver : actor_t; variable msg : inout msg_t);

  -- Get reply message to request_msg. Runtime error if reply message isn't available.
  procedure get_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg : inout msg_t);

  -----------------------------------------------------------------------------
  -- Subscriptions
  -----------------------------------------------------------------------------

  -- Make subscriber subscribe on the specified publisher and traffic type. For
  -- a description of the traffic types see com_types.vhd
  procedure subscribe (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t := published);

  -- Remove subscription on the given publisher and traffic type.
  procedure unsubscribe (
    subscriber   : actor_t;
    publisher    : actor_t;
    traffic_type : subscription_traffic_type_t := published);

  -----------------------------------------------------------------------------
  -- Debugging
  -----------------------------------------------------------------------------

  -- Return string representation of a message
  impure function to_string(msg : msg_t) return string;

  -- Get current state for actor mailbox
  impure function get_mailbox_state(actor : actor_t; mailbox_id : mailbox_id_t := inbox) return mailbox_state_t;

  -- Deallocate memory allocated to a mailbox state variable
  procedure deallocate(variable mailbox_state : inout mailbox_state_t);

  -- Return string representation of a mailbox state
  impure function get_mailbox_state_string (
    actor : actor_t;
    mailbox_id : mailbox_id_t := inbox;
    indent : string := "") return string;

  -- Get current state of actor
  impure function get_actor_state(actor : actor_t) return actor_state_t;

  -- Deallocate memory allocated to a actor state variable
  procedure deallocate(variable actor_state : inout actor_state_t);

  -- Return string representation of an actor state
  impure function get_actor_state_string (actor : actor_t; indent : string := "") return string;

  -- Get current state of messenger
  impure function get_messenger_state return messenger_state_t;

  -- Deallocate memory allocated to a messenger state variable
  procedure deallocate(variable messenger_state : inout messenger_state_t);

  -- Return string representation of the messenger state
  impure function get_messenger_state_string(indent : string := "") return string;

  -----------------------------------------------------------------------------
  -- Misc
  -----------------------------------------------------------------------------

  -- Allow deprecated APIs
  procedure allow_deprecated;

  -- Allow timeout in deprecated functionality. If not allowed timeouts will
  -- cause a runtime error.
  procedure allow_timeout;

end package;
