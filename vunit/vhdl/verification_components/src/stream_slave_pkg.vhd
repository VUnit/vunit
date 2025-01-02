-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- Stream slave verification component interface

library ieee;
use ieee.std_logic_1164.all;

use work.check_pkg.all;
use work.com_pkg.all;
use work.com_types_pkg.all;

package stream_slave_pkg is
  -- Stream slave handle
  type stream_slave_t is record
    p_actor : actor_t;
  end record;

  -- Create a new stream slave object
  impure function new_stream_slave return stream_slave_t;

  -- Reference to future stream result
  alias stream_reference_t is msg_t;

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

  -- Message type definitions used by VC implementing stream slave VCI
  constant stream_pop_msg : msg_type_t := new_msg_type("stream pop");
end package;
