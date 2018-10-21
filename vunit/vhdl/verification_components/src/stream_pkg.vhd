-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

-- Stream master & slave verification component interfaces

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;

package stream_pkg is

  -- Stream master handle
  type stream_master_t is record
    p_actor : actor_t;
  end record;

  -- Stream slave handle
  type stream_slave_t is record
    p_actor : actor_t;
  end record;

  -- Create a new stream master object
  impure function new_stream_master return stream_master_t;

  -- Create a new stream slave object
  impure function new_stream_slave return stream_slave_t;

  -- Encapsulate a stream transaction
  type stream_transaction_t is record
    data : std_ulogic_vector;
    last : boolean;
  end record;

  -- Push a stream transaction into a message
  procedure push(msg : msg_t; transaction : stream_transaction_t);

  -- Pop a stream transaction from a message
  impure function pop(msg : msg_t) return stream_transaction_t;

  -- Aliases for breaking type ambiguity
  alias push_stream_transaction is push[msg_t, stream_transaction_t];
  alias pop_stream_transaction is pop[msg_t return stream_transaction_t];

  -- Message type definitions used by VC implementing stream VCI
  constant stream_push_msg : msg_type_t := new_msg_type("stream push");
  constant stream_pop_msg : msg_type_t := new_msg_type("stream pop");

  -- Reference to future stream result
  alias stream_reference_t is msg_t;

  -- Push a data value to the stream
  procedure push_stream(signal net : inout network_t;
                        stream : stream_master_t;
                        transaction : stream_transaction_t);

  procedure push_stream(signal net : inout network_t;
                        stream : stream_master_t;
                        data : std_logic_vector;
                        last : boolean := false);

  -- Blocking: pop a value from the stream
  procedure pop_stream(signal net : inout network_t;
                       stream : stream_slave_t;
                       variable transaction : out stream_transaction_t);

  procedure pop_stream(signal net : inout network_t;
                       stream : stream_slave_t;
                       variable data : out std_logic_vector;
                       variable last : out boolean);

  procedure pop_stream(signal net : inout network_t;
                       stream : stream_slave_t;
                       variable data : out std_logic_vector);

  -- Non-blocking: pop a value from the stream to be read in the future
  procedure pop_stream(signal net : inout network_t;
                       stream : stream_slave_t;
                       variable reference : inout stream_reference_t);

  -- Blocking: Wait for reply to non-blocking pop
  procedure await_pop_stream_reply(signal net : inout network_t;
                                   variable reference : inout stream_reference_t;
                                   variable transaction : out stream_transaction_t);

  procedure await_pop_stream_reply(signal net : inout network_t;
                                   variable reference : inout stream_reference_t;
                                   variable data : out std_logic_vector;
                                   variable last : out boolean);

  procedure await_pop_stream_reply(signal net : inout network_t;
                                   variable reference : inout stream_reference_t;
                                   variable data : out std_logic_vector);

  -- Blocking: read stream and check result against expected value
  procedure check_stream(signal net : inout network_t;
                         stream : stream_slave_t;
                         expected : stream_transaction_t;
                         msg : string := "");

  procedure check_stream(signal net : inout network_t;
                         stream : stream_slave_t;
                         expected_data : std_logic_vector;
                         expected_last : boolean := false;
                         msg : string := "");

  -- Overload sync functions
  procedure wait_until_idle(signal net : inout network_t;
                            stream : stream_master_t);

  procedure wait_until_idle(signal net : inout network_t;
                            stream : stream_slave_t);

  procedure wait_for_time(signal net : inout network_t;
                          stream : stream_master_t;
                          delay : delay_length);

  procedure wait_for_time(signal net : inout network_t;
                          stream : stream_slave_t;
                          delay : delay_length);

  -- Overload com funtions
  procedure receive(signal net : inout network_t;
                    stream : stream_master_t;
                    variable msg : out msg_t);

  procedure receive(signal net : inout network_t;
                    stream : stream_slave_t;
                    variable msg : out msg_t);

  -- Receive a value pushed to a stream with syncing
  procedure receive_stream(signal net : inout network_t;
                           stream : stream_master_t;
                           variable transaction : out stream_transaction_t);

  procedure receive_stream(signal net : inout network_t;
                           stream : stream_master_t;
                           variable data : out std_ulogic_vector;
                           variable last : out boolean);

  procedure receive_stream(signal net : inout network_t;
                           stream : stream_master_t;
                           variable data : out std_ulogic_vector);

  -- Receive a stream pop request with syncing
  procedure receive_stream(signal net : inout network_t;
                           stream : stream_slave_t;
                           variable msg : out msg_t);

  -- Reply to a stream pop request
  procedure reply_stream(signal net : inout network_t;
                         variable msg : inout msg_t;
                         transaction : stream_transaction_t);

  procedure reply_stream(signal net : inout network_t;
                         variable msg : inout msg_t;
                         data : std_ulogic_vector;
                         last : boolean);

  procedure reply_stream(signal net : inout network_t;
                         variable msg : inout msg_t;
                         data : std_ulogic_vector);

end package;

