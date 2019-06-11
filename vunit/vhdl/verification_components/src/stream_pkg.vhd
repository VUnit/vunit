-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2019, Lars Asplund lars.anders.asplund@gmail.com

-- Stream master verification component interface

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;

package stream_master_pkg is

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

  -- Message type definitions used by VC implementing stream master VCI
  constant stream_push_msg : msg_type_t := new_msg_type("stream push");

  -- Message type definitions used by VC implementing stream slave VCI
  constant stream_pop_msg : msg_type_t := new_msg_type("stream pop");

  -- Reference to future stream result
  alias stream_reference_t is msg_t;

  -- Push a data value to the stream
  procedure push_stream(signal net : inout network_t;
                        stream : stream_master_t;
                        data : std_logic_vector;
                        last : boolean := false);

  -- Blocking: pop a value from the stream
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
                                   variable data : out std_logic_vector;
                                   variable last : out boolean);

  procedure await_pop_stream_reply(signal net : inout network_t;
                                   variable reference : inout stream_reference_t;
                                   variable data : out std_logic_vector);

  -- Blocking: read stream and check result against expected value
  procedure check_stream(signal net : inout network_t;
                         stream : stream_slave_t;
                         expected : std_logic_vector;
                         last : boolean := false;
                         msg : string := "");

end package;
