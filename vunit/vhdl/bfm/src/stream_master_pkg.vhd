-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;

package stream_master_pkg is
  type stream_master_t is record
    p_actor : actor_t;
  end record;

  impure function new_stream_master return stream_master_t;

  procedure push_stream(signal event : inout event_t;
                        stream : stream_master_t;
                        data : std_logic_vector);

  procedure await_completion(signal event : inout event_t;
                             stream : stream_master_t);


  constant stream_push_msg : msg_type_t := new_msg_type("stream push");
end package;
