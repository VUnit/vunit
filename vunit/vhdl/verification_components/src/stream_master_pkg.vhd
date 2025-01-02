-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- Stream master verification component interface

library ieee;
use ieee.std_logic_1164.all;

use work.com_pkg.new_actor;
use work.com_pkg.send;
use work.com_types_pkg.all;

package stream_master_pkg is
  -- Stream master handle
  type stream_master_t is record
    p_actor : actor_t;
  end record;

  -- Create a new stream master object
  impure function new_stream_master return stream_master_t;

  -- Push a data value to the stream
  procedure push_stream(signal net : inout network_t;
                        stream : stream_master_t;
                        data : std_logic_vector;
                        last : boolean := false);

  -- Message type definitions used by VC implementing stream master VCI
  constant stream_push_msg : msg_type_t := new_msg_type("stream push");
end package;
