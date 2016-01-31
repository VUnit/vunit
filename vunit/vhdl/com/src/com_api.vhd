-- Com API package provides the common API for all
-- implementations of the com functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2016, Lars Asplund lars.anders.asplund@gmail.com

use work.com_types_pkg.all;

package com_pkg is
  signal net : network_t := idle_network;

  type messenger_t is protected
    -----------------------------------------------------------------------------
    -- Handling of actors
    -----------------------------------------------------------------------------
    impure function create (
      constant name       :    string   := "";
      constant inbox_size : in positive := positive'high)
      return actor_t;
    impure function find (
      constant name                     : string;
      constant enable_deferred_creation : boolean := true)
      return actor_t;
    procedure destroy (
      variable actor  : inout actor_t;
      variable status : out   com_status_t);
    procedure reset_messenger;
    impure function num_of_actors
      return natural;
    impure function num_of_deferred_creations
      return natural;
    impure function unknown_actor (
      constant actor : actor_t)
      return boolean;
    impure function deferred (
      constant actor : actor_t)
      return boolean;
    impure function inbox_is_full (
      constant actor : actor_t)
      return boolean;
    impure function inbox_size (
      constant actor : actor_t)
      return natural;

    -----------------------------------------------------------------------------
    -- Send related subprograms
    -----------------------------------------------------------------------------
    procedure send (
      constant sender     : in  actor_t;
      constant receiver   : in  actor_t;
      constant request_id : in  message_id_t;
      constant payload    : in  string;
      variable receipt    : out receipt_t);
    procedure publish (
      constant sender  : in  actor_t;
      constant payload : in  string;
      variable status  : out com_status_t);

    -----------------------------------------------------------------------------
    -- Receive related subprograms
    -----------------------------------------------------------------------------
    impure function has_messages (
      constant actor : actor_t)
      return boolean;
    impure function get_first_message_payload (
      constant actor : actor_t)
      return string;
    impure function get_first_message_sender (
      constant actor : actor_t)
      return actor_t;
    impure function get_first_message_id (
      constant actor : actor_t)
      return message_id_t;
    impure function get_first_message_request_id (
      constant actor : actor_t)
      return message_id_t;
    procedure delete_first_envelope (
      constant actor : in actor_t);
    impure function has_reply_stash_message (
      constant actor      : actor_t;
      constant request_id : message_id_t := no_message_id_c)
      return boolean;
    impure function get_reply_stash_message_payload (
      constant actor : actor_t)
      return string;
    impure function get_reply_stash_message_sender (
      constant actor : actor_t)
      return actor_t;
    impure function get_reply_stash_message_id (
      constant actor : actor_t)
      return message_id_t;
    impure function get_reply_stash_message_request_id (
      constant actor : actor_t)
      return message_id_t;
    impure function find_and_stash_reply_message (
      constant actor      : actor_t;
      constant request_id : message_id_t)
      return boolean;
    procedure clear_reply_stash (
      constant actor : actor_t);
    procedure subscribe (
      constant subscriber : in  actor_t;
      constant publisher  : in  actor_t;
      variable status     : out com_status_t);
    procedure unsubscribe (
      constant subscriber : in  actor_t;
      constant publisher  : in  actor_t;
      variable status     : out com_status_t);
    impure function num_of_missed_messages (
      constant actor : actor_t)
      return natural;

  end protected;

  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  impure function create (
    constant name       :    string   := "";
    constant inbox_size : in positive := positive'high)
    return actor_t;
  impure function find (
    constant name                     : string;
    constant enable_deferred_creation : boolean := true)
    return actor_t;
  procedure destroy (
    variable actor  : inout actor_t;
    variable status : out   com_status_t);
  procedure reset_messenger;
  impure function num_of_actors
    return natural;
  impure function num_of_deferred_creations
    return natural;
  impure function inbox_size (
    constant actor : actor_t)
    return natural;

  -----------------------------------------------------------------------------
  -- Send related subprograms
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
  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
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
  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    constant payload : in    string := "";
    variable status  : out   com_status_t);
  procedure publish (
    signal net            : inout network_t;
    variable message      : inout message_ptr_t;
    variable status       : out   com_status_t;
    constant keep_message : in    boolean := false);

  -----------------------------------------------------------------------------
  -- Receive related subprograms
  -----------------------------------------------------------------------------
  procedure wait_for_messages (
    signal net               : in  network_t;
    constant receiver        : in  actor_t;
    variable status          : out com_status_t;
    constant receive_timeout : in  time := max_timeout_c);
  impure function has_messages (
    constant actor : actor_t)
    return boolean;
  impure function get_message (
    constant receiver          :    actor_t;
    constant delete_from_inbox : in boolean := true)
    return message_ptr_t;
  procedure receive (
    signal net        : inout network_t;
    constant receiver :       actor_t;
    variable message  : inout message_ptr_t;
    constant timeout  : in    time := max_timeout_c);
  procedure receive_reply (
    signal net          : inout network_t;
    constant receiver   :       actor_t;
    constant request_id : in    message_id_t;
    variable message    : inout message_ptr_t;
    constant timeout    : in    time := max_timeout_c);
  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     :       actor_t;
    constant request_id   : in    message_id_t;
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
  impure function num_of_missed_messages (
    constant actor : actor_t)
    return natural;

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------
  impure function compose (
    constant payload    :    string       := "";
    constant sender     :    actor_t      := null_actor_c;
    constant request_id : in message_id_t := no_message_id_c)
    return message_ptr_t;
  procedure delete (
    variable message : inout message_ptr_t);
end package;
