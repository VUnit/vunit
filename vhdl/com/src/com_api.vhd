-- Com API package provides the common API for all
-- implementations of the com functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

use work.com_types_pkg.all;

package com_pkg is
  signal net : network_t := idle_network;
  
  type messenger_t is protected
    impure function find (
      constant name : string;
      constant enable_deferred_creation : boolean := true)    
      return actor_t;
    impure function create (
      constant name : string := "")
      return actor_t;
    procedure destroy (
      variable actor : inout actor_t;
      variable status  : out   actor_destroy_status_t);
    procedure reset_messenger;    
    impure function num_of_actors
      return natural;
    impure function deferred (
      constant actor : actor_t)
      return boolean;  
    impure function num_of_deferred_creations
      return natural;
    procedure send (
      constant sender   : in    actor_t;
      constant receiver : in    actor_t;
      constant payload  : in    string;
      variable status   : out   send_status_t);
    impure function has_messages (
      constant actor : actor_t)
      return boolean;
    impure function get_first_message_payload (
      constant actor : actor_t)
      return string;
    impure function get_first_message_sender (
      constant actor : actor_t)
      return actor_t;
    procedure delete_first_envelope (
      constant actor : in actor_t);
    procedure subscribe (
      constant subscriber : in  actor_t;
      constant publisher : in  actor_t;
      variable status    : out subscribe_status_t);
    procedure unsubscribe (
      constant subscriber : in  actor_t;
      constant publisher : in  actor_t;
      variable status    : out unsubscribe_status_t);
    procedure publish (
      constant sender   : in    actor_t;
      constant payload  : in    string;
      variable status   : out   publish_status_t);
  end protected;
  
  impure function create (
    constant name : string := "")
    return actor_t;
  impure function find (
    constant name : string;
    constant enable_deferred_creation : boolean := true)
    return actor_t;
  procedure destroy (
    variable actor : inout actor_t;
    variable status  : out   actor_destroy_status_t);
  procedure reset_messenger;
  impure function num_of_actors
    return natural;
  impure function num_of_deferred_creations
    return natural;
  procedure send (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable status   : out   send_status_t);
  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable status   : out   send_status_t);
  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable message  : inout message_ptr_t;
    variable status   : out   send_status_t;
    constant keep_message : in boolean := false);  
  procedure wait_for_messages (
    signal net        : in network_t;
    constant receiver : in actor_t;
    variable status : out receive_status_t;
    constant receive_timeout : in time := max_timeout_c);
  impure function has_messages (
    constant actor : actor_t)
    return boolean;
  impure function get_message (
    constant receiver : actor_t;
    constant delete_from_inbox : in boolean := true)
    return message_ptr_t;
  procedure receive (
    signal net        : in network_t;
    constant receiver : actor_t;
    variable message : inout message_ptr_t;
    variable status : out receive_status_t;
    constant timeout : in time := max_timeout_c);  
  function compose (
    constant payload : string := "";
    constant sender  : actor_t := null_actor_c)
    return message_ptr_t;  
  procedure delete (
    variable message : inout message_ptr_t);  
  procedure subscribe (
    constant subscriber : in  actor_t;
    constant publisher : in  actor_t;
    variable status    : out subscribe_status_t);
  procedure unsubscribe (
    constant subscriber : in  actor_t;
    constant publisher : in  actor_t;
    variable status    : out unsubscribe_status_t);
  procedure publish (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant payload  : in    string := "";
    variable status   : out   publish_status_t);
  procedure publish (
    signal net        : inout network_t;
    variable message  : inout message_ptr_t;
    variable status   : out   publish_status_t;
    constant keep_message : in boolean := false);
end package;

  
