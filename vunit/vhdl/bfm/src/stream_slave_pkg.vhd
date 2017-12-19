-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

-- Stream slave verification component interface

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;

package stream_slave_pkg is
  -- Stream slave handle
  type stream_slave_t is record
    p_actor : actor_t;
  end record;

  -- Reference to future stream result
  alias stream_reference_t is msg_t;

  -- Blocking: pop a value from the stream
  procedure pop_stream(signal event : inout event_t;
                       stream : stream_slave_t;
                       variable data : out std_logic_vector);

  -- Non-blocking: pop a value from the stream to be read in the future
  procedure pop_stream(signal event : inout event_t;
                       stream : stream_slave_t;
                       variable reference : inout stream_reference_t);

  -- Blocking: Wait for reply to non-blocking pop
  procedure await_pop_stream_reply(signal event : inout event_t;
                                   variable reference : inout stream_reference_t;
                                   variable data : out std_logic_vector);

  -- Blocking: read stream and check result against expected value
  procedure check_stream(signal event : inout event_t;
                         stream : stream_slave_t;
                         expected : std_logic_vector;
                         msg : string := "");

  -- Message type definitions used by VC implementing stream slave VCI
  constant stream_pop_msg : msg_type_t := new_msg_type("stream pop");
end package;
