-- Com API package provides the common API for all
-- implementations of the com functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

use work.com_types_pkg.all;
use work.queue_pkg.all;

package com_pkg is
  signal net : network_t := idle_network;
  alias event is net;

  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  impure function create (name : string := ""; inbox_size : positive := positive'high) return actor_t;  --
  impure function find (name  : string; enable_deferred_creation : boolean := true) return actor_t;
  impure function name (actor : actor_t) return string;

  procedure destroy (actor : inout actor_t);
  procedure reset_messenger;

  impure function num_of_actors return natural;
  impure function num_of_deferred_creations return natural;
  impure function inbox_size (actor      : actor_t) return natural;
  -- Think more about the use cases for this API
  impure function num_of_messages (actor : actor_t) return natural;
  procedure resize_inbox (actor          : actor_t; new_size : natural);

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------
  impure function new_message (sender : actor_t := null_actor_c) return message_ptr_t;
  impure function compose (
    payload    : string       := "";
    sender     : actor_t      := null_actor_c;
    request_id : message_id_t := no_message_id_c)
    return message_ptr_t;
  procedure copy (src       : inout message_ptr_t; dst : inout message_ptr_t);
  procedure delete (message : inout message_ptr_t);

  impure function create (sender :       actor_t := null_actor_c) return msg_t;
  procedure delete (msg          : inout msg_t);

  -----------------------------------------------------------------------------
  -- Primary send and receive related subprograms
  -----------------------------------------------------------------------------
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
  procedure publish (
    signal net            : inout network_t;
    constant sender       : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true);

  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable msg      : inout msg_t;
    constant timeout  : in    time := max_timeout_c);
  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable msg      : inout msg_t;
    constant timeout  : in    time := max_timeout_c);
  procedure reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout_c);
  procedure receive_reply (
    signal net           : inout network_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout     : in    time := max_timeout_c);
  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    variable msg     : inout msg_t;
    constant timeout : in    time := max_timeout_c);

  -----------------------------------------------------------------------------
  -- Secondary send and receive related subprograms
  -----------------------------------------------------------------------------
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
  procedure acknowledge (
    signal net            : inout network_t;
    variable request      : inout message_ptr_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c);
  procedure receive_reply (
    signal net            : inout network_t;
    variable request      : inout message_ptr_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c);


  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_msg : inout msg_t;
    variable reply_msg   : inout msg_t;
    constant timeout         : in    time    := max_timeout_c);
  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_msg : inout msg_t;
    variable positive_ack    : out   boolean;
    constant timeout         : in    time    := max_timeout_c);
  procedure acknowledge (
    signal net            : inout network_t;
    variable request_msg      : inout msg_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c);
  procedure receive_reply (
    signal net            : inout network_t;
    variable request_msg      : inout msg_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c);

  -----------------------------------------------------------------------------
  -- Low-level subprograms primarily used for handling timeout wihout error
  -----------------------------------------------------------------------------
  procedure wait_for_message (
    signal net        : in  network_t;
    constant receiver : in  actor_t;
    variable status   : out com_status_t;
    constant timeout  : in  time := max_timeout_c);
  procedure wait_for_reply (
    signal net       : inout network_t;
    variable request : inout message_ptr_t;
    variable status  : out   com_status_t;
    constant timeout : in    time := max_timeout_c);
  procedure wait_for_reply (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant receipt  : in    receipt_t;
    variable status   : out   com_status_t;
    constant timeout  : in    time := max_timeout_c);
  impure function has_message (actor    : actor_t) return boolean;
  impure function get_message (receiver : actor_t; delete_from_inbox : boolean := true) return message_ptr_t;
  impure function get_reply (
    receiver          : actor_t;
    receipt           : receipt_t;
    delete_from_inbox : boolean := true)
    return message_ptr_t;
  procedure get_reply (
    variable request           : inout message_ptr_t;
    variable reply             : inout message_ptr_t;
    constant delete_from_inbox : in    boolean := true);


  procedure wait_for_reply (
    signal net       : inout network_t;
    variable request_msg : inout msg_t;
    variable status  : out   com_status_t;
    constant timeout : in    time := max_timeout_c);
  impure function get_message (receiver : actor_t) return msg_t;
  procedure get_reply (variable request_msg : inout msg_t; variable reply_msg : inout msg_t);



  -----------------------------------------------------------------------------
  -- Subscriptions
  -----------------------------------------------------------------------------
  procedure subscribe (
    subscriber : actor_t;
    publisher : actor_t;
    traffic_type : subscription_traffic_type_t := published);
  procedure unsubscribe (
    subscriber : actor_t;
    publisher : actor_t;
    traffic_type : subscription_traffic_type_t := published);


  -----------------------------------------------------------------------------
  -- Misc
  -----------------------------------------------------------------------------

  procedure allow_timeout;
  procedure allow_deprecated;
  procedure deprecated (msg : string);
  procedure push(queue : queue_t; variable value : inout msg_t);
  impure function pop(queue : queue_t) return msg_t;
end package;
