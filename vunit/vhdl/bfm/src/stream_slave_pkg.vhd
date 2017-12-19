-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.queue_pkg.all;
use work.msg_types_pkg.all;
use work.sync_pkg.all;

package stream_slave_pkg is
  type stream_slave_t is record
    p_actor : actor_t;
  end record;

  impure function new_stream_slave return stream_slave_t;

  alias stream_reference_t is msg_t;

  procedure pop_stream(signal event : inout event_t;
                       stream : stream_slave_t;
                       variable data : out std_logic_vector);

  procedure pop_stream(signal event : inout event_t;
                       stream : stream_slave_t;
                       variable reference : inout stream_reference_t);

  procedure await_pop_stream_reply(signal event : inout event_t;
                                   variable reference : inout stream_reference_t;
                                   variable data : out std_logic_vector);

  procedure check_stream(signal event : inout event_t;
                         stream : stream_slave_t;
                         expected : std_logic_vector;
                         msg : string := "");

  constant stream_pop_msg : msg_type_t := new_msg_type("stream pop");
end package;
