-- Common com types.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_complex.all;
use ieee.numeric_bit.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;
use ieee.float_pkg.all;

use std.textio.all;

use work.integer_vector_ptr_pkg.all;
use work.integer_array_pkg.all;
use work.string_ptr_pkg.all;
use work.logger_pkg.all;
use work.queue_pkg.all;
use work.queue_2008p_pkg.all;
use work.queue_pool_pkg.all;
use work.dict_pkg.all;
use work.event_private_pkg.basic_event_t;

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
                        duplicate_actor_name_error,
                        new_actor_from_root_id_error);

  subtype com_error_t is com_status_t range timeout to new_actor_from_root_id_error;

  -- All fields of the actor type are private
  type actor_t is record
    p_id_number : natural;
  end record actor_t;
  type actor_vec_t is array (integer range <>) of actor_t;
  constant null_actor : actor_t := (p_id_number => 0);

  -- Mailboxes owned by an actor
  type mailbox_id_t is (inbox, outbox);

  -- A message type (of type msg_type_t) can be used identify the type of a message
  -- (of type msg_t) such that it can be parsed correctly.
  type msg_type_t is record
    p_code : integer;
  end record;
  constant null_msg_type : msg_type_t := (p_code => -1);


  -- Storage for all registered message types
  type msg_types_t is record
    p_name_ptrs : integer_vector_ptr_t;
  end record;

  constant p_msg_types : msg_types_t := (
    p_name_ptrs => new_integer_vector_ptr);


  -- Every message has a unique ID unless its a message from an inbound or
  -- outbound traffic subscription. These messages will have the same ID as
  -- the original message
  subtype message_id_t is natural;
  constant no_message_id : message_id_t := 0;

  -- Deprecated message type
  type message_t is record
    id : message_id_t;
    msg_type : msg_type_t;
    status : com_status_t;
    sender : actor_t;
    receiver : actor_t;
    request_id : message_id_t;
    payload : line;
  end record message_t;
  type message_ptr_t is access message_t;

  -- Message type. All fields of the record are private and should not be
  -- referenced directly by the user.
  subtype msg_data_t is queue_t;
  type msg_t is record
    id : message_id_t;
    msg_type : msg_type_t;
    status : com_status_t;
    sender : actor_t;
    receiver : actor_t;

    -- ID for the request message if this is a reply
    request_id : message_id_t;

    data : msg_data_t;
  end record msg_t;
  type msg_vec_t is array (natural range <>) of msg_t;
  type msg_vec_ptr_t is access msg_vec_t;

  constant null_msg : msg_t := (
    id => no_message_id,
    msg_type => null_msg_type,
    status => null_message_error,
    sender => null_actor,
    receiver => null_actor,
    request_id => no_message_id,
    data => null_queue);

  -- A subscriber can subscribe on three different types of traffic:
  --
  -- published - Messages published by publisher
  -- outbound - All non-anonymous outbound messages from publisher
  -- inbound - All inbound messages to publisher. Replies anonymous requests are excluded.
  type subscription_traffic_type_t is (published, outbound, inbound);

  type subscription_t is record
    subscriber : actor_t;
    publisher : actor_t;
    traffic_type : subscription_traffic_type_t;
  end record subscription_t;
  type subscription_vec_t is array (natural range <>) of subscription_t;
  type subscription_vec_ptr_t is access subscription_vec_t;

  -- Deprecated
  type receipt_t is record
    status : com_status_t;
    id : message_id_t;
  end record receipt_t;

  -- An event type representing the network over which actors communicate. An event in
  -- the network notifies connected actors which can determine the cause of the
  -- event by consulting the com messenger (com_messenger.vhd). Actors can be
  -- connected to different networks but there's only one global messenger.
  alias network_t is basic_event_t;

  -- Default value for timeout parameters. ModelSim can't handle time'high
  constant max_timeout : time := 1 hr;

  -- Captures the state of a mailbox
  type mailbox_state_t is record
    id : mailbox_id_t;
    size : natural;
    messages : msg_vec_ptr_t;
  end record mailbox_state_t;

  -- Captures the state of an actor
  type actor_state_t is record
    name : line;
    is_deferred : boolean;
    inbox : mailbox_state_t;
    outbox : mailbox_state_t;
    subscriptions : subscription_vec_ptr_t;
    subscribers : subscription_vec_ptr_t;
  end record actor_state_t;
  type actor_state_vec_t is array (natural range <>) of actor_state_t;
  type actor_state_vec_ptr_t is access actor_state_vec_t;

  -- Captures the state of the messenger
  type messenger_state_t is record
    active_actors : actor_state_vec_ptr_t;
    deferred_actors : actor_state_vec_ptr_t;
  end record messenger_state_t;

  constant com_logger : logger_t := get_logger("vunit_lib:com");
  constant queue_pool : queue_pool_t := new_queue_pool;

  -----------------------------------------------------------------------------
  -- Handling of message types
  -----------------------------------------------------------------------------
  impure function new_msg_type(name : string) return msg_type_t;
  impure function name(msg_type : msg_type_t) return string;

  procedure unexpected_msg_type(msg_type : msg_type_t;
                                logger : logger_t := com_logger);

  procedure push_msg_type(msg : msg_t; msg_type : msg_type_t; logger : logger_t := com_logger);
  alias push is push_msg_type [msg_t, msg_type_t, logger_t];

  impure function pop_msg_type(msg : msg_t;
                               logger : logger_t := com_logger) return msg_type_t;
  alias pop is pop_msg_type [msg_t, logger_t return msg_type_t];

  procedure handle_message(variable msg_type : inout msg_type_t);
  impure function is_already_handled(msg_type : msg_type_t) return boolean;

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------

  -- Create a new empty message. The message has an optional type and can anonymous
  -- or signed with the sending actor
  impure function new_msg(
    msg_type : msg_type_t := null_msg_type;
    sender : actor_t := null_actor) return msg_t;

  impure function copy(msg : msg_t) return msg_t;

  -- Delete message. Memory allocated by the message is deallocated.
  procedure delete(msg : inout msg_t);

  -- Return sending actor of message if defined, null_actor otherwise
  function sender(msg : msg_t) return actor_t;

  -- Return sending actor of message if defined, null_actor otherwise
  function receiver(msg : msg_t) return actor_t;

  -- Return message type of message without consuming it as pop_msg_type would
  function message_type(msg : msg_t) return msg_type_t;

  -- Check if message is empty
  impure function is_empty(msg : msg_t) return boolean;

  -- Push message into a queue.
  -- The message is set to null to avoid duplicate ownership
  procedure push(queue : queue_t; variable value : inout msg_t);

  -- Pop a message from a queue.
  impure function pop(queue : queue_t) return msg_t;

  -----------------------------------------------------------------------------
  -- Subprograms for pushing/popping data to/from a message. Data is popped
  -- from a message in the same order they were pushed (FIFO)
  -----------------------------------------------------------------------------
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

  -- The value is set to null to avoid duplicate ownership
  procedure push(msg : msg_t; variable value : inout integer_vector_ptr_t);
  impure function pop(msg : msg_t) return integer_vector_ptr_t;
  alias push_integer_vector_ptr_ref is push[msg_t, integer_vector_ptr_t];
  alias pop_integer_vector_ptr_ref is pop[msg_t return integer_vector_ptr_t];

  -- The value is set to null to avoid duplicate ownership
  procedure push(msg : msg_t; variable value : inout string_ptr_t);
  impure function pop(msg : msg_t) return string_ptr_t;
  alias push_string_ptr_ref is push[msg_t, string_ptr_t];
  alias pop_string_ptr_ref is pop[msg_t return string_ptr_t];

  -- The value is set to null to avoid duplicate ownership
  procedure push(msg : msg_t; variable value : inout queue_t);
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

  procedure push(msg : msg_t; variable value : inout msg_t);
  impure function pop(msg : msg_t) return msg_t;
  alias push_msg_t is push[msg_t, msg_t];
  alias pop_msg_t is pop[msg_t return msg_t];

  procedure push_ref(constant msg : msg_t; value : inout integer_array_t);
  impure function pop_ref(msg : msg_t) return integer_array_t;
  alias push_integer_array_t_ref is push_ref[msg_t, integer_array_t];
  alias pop_integer_array_t_ref is pop_ref[msg_t return integer_array_t];

  procedure push_ref(constant msg : msg_t; value : inout dict_t);
  impure function pop_ref(msg : msg_t) return dict_t;
  alias push_dict_t_ref is push_ref[msg_t, dict_t];
  alias pop_dict_t_ref is pop_ref[msg_t return dict_t];

  -- Misc
  impure function to_integer(actor : actor_t) return integer;
  impure function to_actor(value : integer) return actor_t;

  -- Private
  impure function is_valid(code : integer) return boolean;
end package;

package body com_types_pkg is

  -----------------------------------------------------------------------------
  -- Handling of message types
  -----------------------------------------------------------------------------

  impure function new_msg_type(name : string) return msg_type_t is
    constant code : integer := length(p_msg_types.p_name_ptrs);
  begin
    resize(p_msg_types.p_name_ptrs, code + 1);
    set(p_msg_types.p_name_ptrs, code, to_integer(new_string_ptr(name)));
    return (p_code => code);
  end function;

  impure function name(msg_type : msg_type_t) return string is
  begin
    return to_string(to_string_ptr(get(p_msg_types.p_name_ptrs, msg_type.p_code)));
  end;

  constant message_handled : msg_type_t := new_msg_type("message handled");

  impure function is_valid(code : integer) return boolean is
  begin
    return 0 <= code and code < length(p_msg_types.p_name_ptrs);
  end;

  procedure handle_message(variable msg_type : inout msg_type_t) is
  begin
    msg_type := message_handled;
  end;

  impure function is_already_handled(msg_type : msg_type_t) return boolean is
  begin
    return msg_type = message_handled;
  end;

  procedure unexpected_msg_type(msg_type : msg_type_t;
                                logger : logger_t := com_logger) is
    constant code : integer := msg_type.p_code;
  begin
    if is_already_handled(msg_type) then
      null;
    elsif is_valid(code) then
      failure(logger, "Got unexpected message " & to_string(to_string_ptr(get(p_msg_types.p_name_ptrs, code))));
    else
      failure(logger, "Got invalid message with code " & to_string(code));
    end if;
  end procedure;

  procedure push_msg_type(msg : msg_t; msg_type : msg_type_t; logger : logger_t := com_logger) is
  begin
    push(msg, msg_type.p_code);
  end;

  impure function pop_msg_type(msg : msg_t; logger : logger_t := com_logger) return msg_type_t is
    constant code : integer := pop(msg);
  begin
    if not is_valid(code) then
      failure(logger, "Got invalid message with code " & to_string(code));
    end if;
    return (p_code => code);
  end;

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------
  impure function new_msg(
    msg_type : msg_type_t := null_msg_type;
    sender : actor_t := null_actor) return msg_t is
    variable msg : msg_t;
  begin
    msg.sender := sender;
    msg.data := new_queue(queue_pool);
    msg.msg_type := msg_type;
    return msg;
  end;

  procedure delete(msg : inout msg_t) is
  begin
    recycle(queue_pool, msg.data);
    msg := null_msg;
  end procedure delete;

  impure function copy(msg : msg_t) return msg_t is
    variable result : msg_t := msg;
  begin
    result.data := new_queue(queue_pool);
    for i in 0 to length(msg.data) - 1 loop
      unsafe_push(result.data, get(msg.data.data, 1 + i));
    end loop;

    return result;
  end;

  function sender(msg : msg_t) return actor_t is
  begin
    return msg.sender;
  end;

  function receiver(msg : msg_t) return actor_t is
  begin
    return msg.receiver;
  end;

  function message_type(msg : msg_t) return msg_type_t is
  begin
    return msg.msg_type;
  end;

  impure function is_empty(msg : msg_t) return boolean is
  begin
    if msg.data = null_queue then
      return true;
    end if;

    return length(msg.data) = 0;
  end;

  procedure push(queue : queue_t; variable value : inout msg_t) is
  begin
    push(queue, value.id);
    push(queue, value.msg_type.p_code);
    push(queue, com_status_t'pos(value.status));
    push(queue, value.sender.p_id_number);
    push(queue, value.receiver.p_id_number);
    push(queue, value.request_id);
    push_queue_ref(queue, value.data);
    value := null_msg;
  end;

  impure function pop(queue : queue_t) return msg_t is
    variable ret_val : msg_t;
  begin
    ret_val.id := pop(queue);
    ret_val.msg_type := (p_code => pop(queue));
    ret_val.status := com_status_t'val(integer'(pop(queue)));
    ret_val.sender.p_id_number := pop(queue);
    ret_val.receiver.p_id_number := pop(queue);
    ret_val.request_id := pop(queue);
    ret_val.data := pop_queue_ref(queue);

    return ret_val;
  end;

  -----------------------------------------------------------------------------
  -- Subprograms for pushing/popping data to/from a message. Data is popped
  -- from a message in the same order they were pushed (FIFO)
  -----------------------------------------------------------------------------
  procedure push(msg : msg_t; value : integer) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return integer is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : character) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return character is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : boolean) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return boolean is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : real) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return real is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : bit) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return bit is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : std_ulogic) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return std_ulogic is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : severity_level) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return severity_level is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : file_open_status) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return file_open_status is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : file_open_kind) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return file_open_kind is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : bit_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return bit_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : std_ulogic_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return std_ulogic_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : complex) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return complex is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : complex_polar) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return complex_polar is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_bit.unsigned) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_bit.unsigned is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_bit.signed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_bit.signed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_std.unsigned) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_std.unsigned is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ieee.numeric_std.signed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ieee.numeric_std.signed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : string) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return string is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : time) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return time is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; variable value : inout integer_vector_ptr_t) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return integer_vector_ptr_t is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; variable value : inout string_ptr_t) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return string_ptr_t is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; variable value : inout queue_t) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return queue_t is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : boolean_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return boolean_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : integer_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return integer_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : real_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return real_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : time_vector) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return time_vector is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : ufixed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return ufixed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : sfixed) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return sfixed is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; value : float) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return float is
  begin
    return pop(msg.data);
  end;

  procedure push(msg : msg_t; variable value : inout msg_t) is
  begin
    push(msg.data, value);
  end;

  impure function pop(msg : msg_t) return msg_t is
  begin
    return pop(msg.data);
  end;

  procedure push_ref(constant msg : msg_t; value : inout integer_array_t) is
  begin
    push_ref(msg.data, value);
  end;

  impure function pop_ref(msg : msg_t) return integer_array_t is
  begin
    return pop_ref(msg.data);
  end;

  procedure push_ref(constant msg : msg_t; value : inout dict_t) is
  begin
    push_ref(msg.data, value);
  end;

  impure function pop_ref(msg : msg_t) return dict_t is
  begin
    return pop_ref(msg.data);
  end;

  -----------------------------------------------------------------------------
  -- Misc
  -----------------------------------------------------------------------------
  impure function to_integer(actor : actor_t) return integer is
  begin
    return actor.p_id_number;
  end;

  impure function to_actor(value : integer) return actor_t is
  begin
    return (p_id_number => value);
  end;

end package body com_types_pkg;
