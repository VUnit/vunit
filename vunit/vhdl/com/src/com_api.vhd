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

  procedure push(msg : msg_t; value : integer);
  impure function pop(msg : msg_t) return integer;
  alias push_integer is push[msg_t, integer];
  alias pop_integer is pop[msg_t return integer];

  procedure push(msg : msg_t; value : character);
  impure function pop(msg : msg_t) return character;
  alias push_character is push[msg_t, character];
  alias pop_character is pop[msg_t return character];

  procedure push(msg : msg_t; value : boolean);
  impure function pop(msg : msg_t) return boolean;
  alias push_boolean is push[msg_t, boolean];
  alias pop_boolean is pop[msg_t return boolean];

  procedure push(msg : msg_t; value : real);
  impure function pop(msg : msg_t) return real;
  alias push_real is push[msg_t, real];
  alias pop_real is pop[msg_t return real];

  procedure push(msg : msg_t; value : bit);
  impure function pop(msg : msg_t) return bit;
  alias push_bit is push[msg_t, bit];
  alias pop_bit is pop[msg_t return bit];

  procedure push(msg : msg_t; value : std_ulogic);
  impure function pop(msg : msg_t) return std_ulogic;
  alias push_std_ulogic is push[msg_t, std_ulogic];
  alias pop_std_ulogic is pop[msg_t return std_ulogic];

  procedure push(msg : msg_t; value : severity_level);
  impure function pop(msg : msg_t) return severity_level;
  alias push_severity_level is push[msg_t, severity_level];
  alias pop_severity_level is pop[msg_t return severity_level];

  procedure push(msg : msg_t; value : file_open_status);
  impure function pop(msg : msg_t) return file_open_status;
  alias push_file_open_status is push[msg_t, file_open_status];
  alias pop_file_open_status is pop[msg_t return file_open_status];

  procedure push(msg : msg_t; value : file_open_kind);
  impure function pop(msg : msg_t) return file_open_kind;
  alias push_file_open_kind is push[msg_t, file_open_kind];
  alias pop_file_open_kind is pop[msg_t return file_open_kind];

  procedure push(msg : msg_t; value : bit_vector);
  impure function pop(msg : msg_t) return bit_vector;
  alias push_bit_vector is push[msg_t, bit_vector];
  alias pop_bit_vector is pop[msg_t return bit_vector];

  procedure push(msg : msg_t; value : std_ulogic_vector);
  impure function pop(msg : msg_t) return std_ulogic_vector;
  alias push_std_ulogic_vector is push[msg_t, std_ulogic_vector];
  alias pop_std_ulogic_vector is pop[msg_t return std_ulogic_vector];

  procedure push(msg : msg_t; value : complex);
  impure function pop(msg : msg_t) return complex;
  alias push_complex is push[msg_t, complex];
  alias pop_complex is pop[msg_t return complex];

  procedure push(msg : msg_t; value : complex_polar);
  impure function pop(msg : msg_t) return complex_polar;
  alias push_complex_polar is push[msg_t, complex_polar];
  alias pop_complex_polar is pop[msg_t return complex_polar];

  procedure push(msg : msg_t; value : ieee.numeric_bit.unsigned);
  impure function pop(msg : msg_t) return ieee.numeric_bit.unsigned;
  alias push_numeric_bit_unsigned is push[msg_t, ieee.numeric_bit.unsigned];
  alias pop_numeric_bit_unsigned is pop[msg_t return ieee.numeric_bit.unsigned];

  procedure push(msg : msg_t; value : ieee.numeric_bit.signed);
  impure function pop(msg : msg_t) return ieee.numeric_bit.signed;
  alias push_numeric_bit_signed is push[msg_t, ieee.numeric_bit.signed];
  alias pop_numeric_bit_signed is pop[msg_t return ieee.numeric_bit.signed];

  procedure push(msg : msg_t; value : ieee.numeric_std.unsigned);
  impure function pop(msg : msg_t) return ieee.numeric_std.unsigned;
  alias push_numeric_std_unsigned is push[msg_t, ieee.numeric_std.unsigned];
  alias pop_numeric_std_unsigned is pop[msg_t return ieee.numeric_std.unsigned];

  procedure push(msg : msg_t; value : ieee.numeric_std.signed);
  impure function pop(msg : msg_t) return ieee.numeric_std.signed;
  alias push_numeric_std_signed is push[msg_t, ieee.numeric_std.signed];
  alias pop_numeric_std_signed is pop[msg_t return ieee.numeric_std.signed];

  procedure push(msg : msg_t; value : string);
  impure function pop(msg : msg_t) return string;
  alias push_string is push[msg_t, string];
  alias pop_string is pop[msg_t return string];

  procedure push(msg : msg_t; value : time);
  impure function pop(msg : msg_t) return time;
  alias push_time is push[msg_t, time];
  alias pop_time is pop[msg_t return time];

  procedure push(msg : msg_t; value : integer_vector_ptr_t);
  impure function pop(msg : msg_t) return integer_vector_ptr_t;
  alias push_integer_vector_ptr_ref is push[msg_t, integer_vector_ptr_t];
  alias pop_integer_vector_ptr_ref is pop[msg_t return integer_vector_ptr_t];

  procedure push(msg : msg_t; value : string_ptr_t);
  impure function pop(msg : msg_t) return string_ptr_t;
  alias push_string_ptr_ref is push[msg_t, string_ptr_t];
  alias pop_string_ptr_ref is pop[msg_t return string_ptr_t];

  procedure push(msg : msg_t; value : queue_t);
  impure function pop(msg : msg_t) return queue_t;
  alias push_queue_ref is push[msg_t, queue_t];
  alias pop_queue_ref is pop[msg_t return queue_t];

  procedure push(msg : msg_t; value : boolean_vector);
  impure function pop(msg : msg_t) return boolean_vector;
  alias push_boolean_vector is push[msg_t, boolean_vector];
  alias pop_boolean_vector is pop[msg_t return boolean_vector];

  procedure push(msg : msg_t; value : integer_vector);
  impure function pop(msg : msg_t) return integer_vector;
  alias push_integer_vector is push[msg_t, integer_vector];
  alias pop_integer_vector is pop[msg_t return integer_vector];

  procedure push(msg : msg_t; value : real_vector);
  impure function pop(msg : msg_t) return real_vector;
  alias push_real_vector is push[msg_t, real_vector];
  alias pop_real_vector is pop[msg_t return real_vector];

  procedure push(msg : msg_t; value : time_vector);
  impure function pop(msg : msg_t) return time_vector;
  alias push_time_vector is push[msg_t, time_vector];
  alias pop_time_vector is pop[msg_t return time_vector];

  procedure push(msg : msg_t; value : ufixed);
  impure function pop(msg : msg_t) return ufixed;
  alias push_ufixed is push[msg_t, ufixed];
  alias pop_ufixed is pop[msg_t return ufixed];

  procedure push(msg : msg_t; value : sfixed);
  impure function pop(msg : msg_t) return sfixed;
  alias push_sfixed is push[msg_t, sfixed];
  alias pop_sfixed is pop[msg_t return sfixed];

  procedure push(msg : msg_t; value : float);
  impure function pop(msg : msg_t) return float;
  alias push_float is push[msg_t, float];
  alias pop_float is pop[msg_t return float];

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
