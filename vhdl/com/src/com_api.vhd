-- Com API package provides the common API for all
-- implementations of the com functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015, Lars Asplund lars.anders.asplund@gmail.com

library com_lib;
use com_lib.com_types_pkg.all;

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
    impure function num_of_deferred_creations
      return natural;
    procedure send (
      signal net        : inout network_t;
      constant sender   : in    actor_t;
      constant receiver : in    actor_t;
      constant payload  : in    string;
      variable status   : out   send_status_t);
    impure function get_payload (
      constant msg : message_t)
      return string;
    impure function get_status (
      constant msg : message_t)
      return message_status_t;
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
    constant payload  : in    string;
    variable status   : out   send_status_t);
  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant payload  : in    string;
    variable status   : out   send_status_t);
  procedure receive (
    constant receiver : actor_t;
    variable msg : out message_t);
  impure function get_payload (
    constant msg : message_t)
    return string;
  impure function get_status (
    constant msg : message_t)
    return message_status_t;
end package;

  
