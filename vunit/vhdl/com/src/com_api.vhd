-- Com API package provides the common API for all
-- implementations of the com functionality (VHDL 2002+ and VHDL 1993)
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

use work.com_types_pkg.all;
use work.queue_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.string_ptr_pkg.all;

package com_pkg is
  -- Global predefined network. See network_t description in com_types.vhd for
  -- more information.
  signal net : network_t := idle_network;

  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  -- Create a new actor. Any number of unnamed actors (name = "") can be
  -- created. Named actors must be unique
  impure function new_actor (name : string := ""; inbox_size : positive := positive'high) return actor_t;

  -- Find named actor by name. Enable deferred creation to create a deferred
  -- actor when no actor is found
  impure function find (name : string; enable_deferred_creation : boolean := true) return actor_t;

  impure function name (actor : actor_t) return string;

  -- Destroy actor. Mailboxes are deallocated and dependent subscriptions are
  -- removed. Returns null_actor_c.
  procedure destroy (actor : inout actor_t);

  -- Reset communication system. All actors are destroyed.
  procedure reset_messenger;

  impure function num_of_actors return natural;
  impure function num_of_deferred_creations return natural;
  impure function inbox_size (actor      : actor_t) return natural;

  -- Resize actor inbox. Reducing size below the number of messages in the
  -- inbox in runtime error
  procedure resize_inbox (actor : actor_t; new_size : natural);

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------

  -- Create a new empty message. The message can be anonymous or signed with
  -- the sending actor
  impure function new_msg (sender : actor_t := null_actor_c) return msg_t;

  impure function copy(msg : msg_t) return msg_t;

  -- Delete message. Memory allocated by the message is deallocated.
  procedure delete (msg : inout msg_t);

  -- Return sending actor of message if defined, null_actor_c otherwise
  function sender(msg : msg_t) return actor_t;

  -- Return sending actor of message if defined, null_actor_c otherwise
  function receiver(msg : msg_t) return actor_t;

  -- Return string representation of message on the following format
  --
  -- <message id>:<request message id> <sender name> -> <receiver name>
  --
  -- <request message id> is the message id for the request message if the
  -- message is a reply to a request. Any undefined field is marked with "-"
  impure function to_string(msg : msg_t) return string;

  -----------------------------------------------------------------------------
  -- Subprograms for pushing/popping data to/from a message. Data is popped
  -- from a message in the same order they were pushed (FIFO)
  -----------------------------------------------------------------------------
  procedure push(msg      : msg_t; value : integer);
  impure function pop(msg : msg_t) return integer;
  alias push_integer is push[msg_t, integer];
  alias pop_integer is pop[msg_t return integer];

  procedure push(msg      : msg_t; value : character);
  impure function pop(msg : msg_t) return character;
  alias push_character is push[msg_t, character];
  alias pop_character is pop[msg_t return character];

  procedure push(msg      : msg_t; value : boolean);
  impure function pop(msg : msg_t) return boolean;
  alias push_boolean is push[msg_t, boolean];
  alias pop_boolean is pop[msg_t return boolean];

  procedure push(msg      : msg_t; value : real);
  impure function pop(msg : msg_t) return real;
  alias push_real is push[msg_t, real];
  alias pop_real is pop[msg_t return real];

  procedure push(msg      : msg_t; value : bit);
  impure function pop(msg : msg_t) return bit;
  alias push_bit is push[msg_t, bit];
  alias pop_bit is pop[msg_t return bit];

  procedure push(msg      : msg_t; value : std_ulogic);
  impure function pop(msg : msg_t) return std_ulogic;
  alias push_std_ulogic is push[msg_t, std_ulogic];
  alias pop_std_ulogic is pop[msg_t return std_ulogic];

  procedure push(msg      : msg_t; value : severity_level);
  impure function pop(msg : msg_t) return severity_level;
  alias push_severity_level is push[msg_t, severity_level];
  alias pop_severity_level is pop[msg_t return severity_level];

  procedure push(msg      : msg_t; value : file_open_status);
  impure function pop(msg : msg_t) return file_open_status;
  alias push_file_open_status is push[msg_t, file_open_status];
  alias pop_file_open_status is pop[msg_t return file_open_status];

  procedure push(msg      : msg_t; value : file_open_kind);
  impure function pop(msg : msg_t) return file_open_kind;
  alias push_file_open_kind is push[msg_t, file_open_kind];
  alias pop_file_open_kind is pop[msg_t return file_open_kind];

  procedure push(msg      : msg_t; value : bit_vector);
  impure function pop(msg : msg_t) return bit_vector;
  alias push_bit_vector is push[msg_t, bit_vector];
  alias pop_bit_vector is pop[msg_t return bit_vector];

  procedure push(msg      : msg_t; value : std_ulogic_vector);
  impure function pop(msg : msg_t) return std_ulogic_vector;
  alias push_std_ulogic_vector is push[msg_t, std_ulogic_vector];
  alias pop_std_ulogic_vector is pop[msg_t return std_ulogic_vector];

  procedure push(msg      : msg_t; value : complex);
  impure function pop(msg : msg_t) return complex;
  alias push_complex is push[msg_t, complex];
  alias pop_complex is pop[msg_t return complex];

  procedure push(msg      : msg_t; value : complex_polar);
  impure function pop(msg : msg_t) return complex_polar;
  alias push_complex_polar is push[msg_t, complex_polar];
  alias pop_complex_polar is pop[msg_t return complex_polar];

  procedure push(msg      : msg_t; value : ieee.numeric_bit.unsigned);
  impure function pop(msg : msg_t) return ieee.numeric_bit.unsigned;
  alias push_numeric_bit_unsigned is push[msg_t, ieee.numeric_bit.unsigned];
  alias pop_numeric_bit_unsigned is pop[msg_t return ieee.numeric_bit.unsigned];

  procedure push(msg      : msg_t; value : ieee.numeric_bit.signed);
  impure function pop(msg : msg_t) return ieee.numeric_bit.signed;
  alias push_numeric_bit_signed is push[msg_t, ieee.numeric_bit.signed];
  alias pop_numeric_bit_signed is pop[msg_t return ieee.numeric_bit.signed];

  procedure push(msg      : msg_t; value : ieee.numeric_std.unsigned);
  impure function pop(msg : msg_t) return ieee.numeric_std.unsigned;
  alias push_numeric_std_unsigned is push[msg_t, ieee.numeric_std.unsigned];
  alias pop_numeric_std_unsigned is pop[msg_t return ieee.numeric_std.unsigned];

  procedure push(msg      : msg_t; value : ieee.numeric_std.signed);
  impure function pop(msg : msg_t) return ieee.numeric_std.signed;
  alias push_numeric_std_signed is push[msg_t, ieee.numeric_std.signed];
  alias pop_numeric_std_signed is pop[msg_t return ieee.numeric_std.signed];

  procedure push(msg      : msg_t; value : string);
  impure function pop(msg : msg_t) return string;
  alias push_string is push[msg_t, string];
  alias pop_string is pop[msg_t return string];

  procedure push(msg      : msg_t; value : time);
  impure function pop(msg : msg_t) return time;
  alias push_time is push[msg_t, time];
  alias pop_time is pop[msg_t return time];

  procedure push(msg      : msg_t; value : integer_vector_ptr_t);
  impure function pop(msg : msg_t) return integer_vector_ptr_t;
  alias push_integer_vector_ptr_ref is push[msg_t, integer_vector_ptr_t];
  alias pop_integer_vector_ptr_ref is pop[msg_t return integer_vector_ptr_t];

  procedure push(msg      : msg_t; value : string_ptr_t);
  impure function pop(msg : msg_t) return string_ptr_t;
  alias push_string_ptr_ref is push[msg_t, string_ptr_t];
  alias pop_string_ptr_ref is pop[msg_t return string_ptr_t];

  procedure push(msg      : msg_t; value : queue_t);
  impure function pop(msg : msg_t) return queue_t;
  alias push_queue_ref is push[msg_t, queue_t];
  alias pop_queue_ref is pop[msg_t return queue_t];

  procedure push(msg      : msg_t; value : boolean_vector);
  impure function pop(msg : msg_t) return boolean_vector;
  alias push_boolean_vector is push[msg_t, boolean_vector];
  alias pop_boolean_vector is pop[msg_t return boolean_vector];

  procedure push(msg      : msg_t; value : integer_vector);
  impure function pop(msg : msg_t) return integer_vector;
  alias push_integer_vector is push[msg_t, integer_vector];
  alias pop_integer_vector is pop[msg_t return integer_vector];

  procedure push(msg      : msg_t; value : real_vector);
  impure function pop(msg : msg_t) return real_vector;
  alias push_real_vector is push[msg_t, real_vector];
  alias pop_real_vector is pop[msg_t return real_vector];

  procedure push(msg      : msg_t; value : time_vector);
  impure function pop(msg : msg_t) return time_vector;
  alias push_time_vector is push[msg_t, time_vector];
  alias pop_time_vector is pop[msg_t return time_vector];

  procedure push(msg      : msg_t; value : ufixed);
  impure function pop(msg : msg_t) return ufixed;
  alias push_ufixed is push[msg_t, ufixed];
  alias pop_ufixed is pop[msg_t return ufixed];

  procedure push(msg      : msg_t; value : sfixed);
  impure function pop(msg : msg_t) return sfixed;
  alias push_sfixed is push[msg_t, sfixed];
  alias pop_sfixed is pop[msg_t return sfixed];

  procedure push(msg      : msg_t; value : float);
  impure function pop(msg : msg_t) return float;
  alias push_float is push[msg_t, float];
  alias pop_float is pop[msg_t return float];

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
    constant timeout  : in    time := max_timeout_c);

  -- Send message to an array of receivers. Blocking if any reciever or any subscriber inbox is
  -- full.
  procedure send (
    signal net         : inout network_t;
    constant receivers : in    actor_vec_t;
    variable msg       : inout msg_t;
    constant timeout   : in    time := max_timeout_c);

  -- Receive message sent to receiver. Returns oldest message or the first
  -- incoming if the inbox is empty. msg is initially deleted.
  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable msg      : inout msg_t;
    constant timeout  : in    time := max_timeout_c);

  -- Receive message sent to any of the receivers. Returns oldest message or the first
  -- incoming if the inboxes are empty. Receiver inboxes are emptied from left
  -- to right. msg is initially deleted.
  procedure receive (
    signal net         : inout network_t;
    constant receivers : in    actor_vec_t;
    variable msg       : inout msg_t;
    constant timeout   : in    time := max_timeout_c);

  -- Reply to request_msg with reply_msg. request_msg may be anonymous. Blocking if reciever
  -- or any subscriber inbox is full.
  procedure reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout_c);

  -- Receive a reply_msg to request_msg. request_msg may be anonymous. reply_msg is initially deleted.
  procedure receive_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout_c);

  -- Publish a message from sender to all its subscribers. Blocking if reciever or any subscriber inbox is
  -- full.
  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    variable msg     : inout msg_t;
    constant timeout : in    time := max_timeout_c);

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
    constant timeout      : in    time    := max_timeout_c);

  -- Receive positive or negative acknowledge for a request_msg. request_msg
  -- may be anonymous. reply_msg is initially deleted.
  procedure receive_reply (
    signal net            : inout network_t;
    variable request_msg  : inout msg_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c);

  -- This request is the same as send of request_msg to receiver followed by a
  -- receive_reply of a reply_msg
  procedure request (
    signal net           : inout network_t;
    constant receiver    : in    actor_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout_c);

  -- This request is the same as send of request_msg to receiver followed by a
  -- receive_reply of a positive or negative acknowledge.
  procedure request (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable request_msg  : inout msg_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c);

  -----------------------------------------------------------------------------
  -- Low-level subprograms primarily used for handling timeout wihout error
  -----------------------------------------------------------------------------

  -- Wait for message sent to receiver. status = ok if message is
  -- received before the timeout, status = timeout otherwise.
  procedure wait_for_message (
    signal net        : in  network_t;
    constant receiver : in  actor_t;
    variable status   : out com_status_t;
    constant timeout  : in  time := max_timeout_c);

  -- Wait for message sent to any of the listed receivers. status = ok
  -- if message is received before the timeout, status = timeout otherwise.
  procedure wait_for_message (
    signal net         : in  network_t;
    constant receivers : in  actor_vec_t;
    variable status    : out com_status_t;
    constant timeout   : in  time := max_timeout_c);

  -- Returns true if there is at least one message in the actor's inbox.
  impure function has_message (actor : actor_t) return boolean;

  -- Wait for reply to request_msg. status = ok
  -- if message is received before the timeout, status = timeout otherwise.
  procedure wait_for_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable status      : out   com_status_t;
    constant timeout     : in    time := max_timeout_c);

  -- Get oldest message from receiver inbox. Runtime error if inbox is empty.
  impure function get_message (receiver : actor_t) return msg_t;

  -- Get reply message to request_msg. Runtime error if reply message isn't available.
  procedure get_reply (variable request_msg : inout msg_t; variable reply_msg : inout msg_t);

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

  -- Number of messages in actor mailbox
  impure function num_of_messages (actor : actor_t; mailbox_id : mailbox_id_t := inbox) return natural;

  -- Peek at message in actor mailbox but don't remove it. Position 0 is the oldest message. Runtime error if
  -- position doesn't exist.
  impure function peek_message(
    actor : actor_t;
    position : natural := 0;
    mailbox_id : mailbox_id_t := inbox) return msg_t;

  -----------------------------------------------------------------------------
  -- Misc
  -----------------------------------------------------------------------------

  -- Push message into a queue.
  procedure push(queue : queue_t; variable value : inout msg_t);

  -- Pop a message from a queue.
  impure function pop(queue : queue_t) return msg_t;

  -- Allow deprecated APIs
  procedure allow_deprecated;

  -- Allow timeout in deprecated functionality. If not allowed timeouts will
  -- cause a runtime error.
  procedure allow_timeout;

end package;
