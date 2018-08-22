-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

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

  -- Push a data value to the stream
  procedure push_stream(signal net : inout network_t;
                        stream : stream_master_t;
                        data : std_logic_vector;
                        first : boolean := false;
                        last : boolean := false);

  -- Message type definitions used by VC implementing stream master VCI
  constant stream_push_msg : msg_type_t := new_msg_type("stream push");
end package;
