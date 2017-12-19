-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;

package body stream_master_pkg is
  impure function new_stream_master return stream_master_t is
  begin
    return (p_actor => create);
  end;

  procedure push_stream(signal event : inout event_t;
                        stream : stream_master_t;
                        data : std_logic_vector) is
    variable msg : msg_t := create;
    constant normalized_data : std_logic_vector(data'length-1 downto 0) := data;
  begin
    push_msg_type(msg, stream_push_msg);
    push_std_ulogic_vector(msg, normalized_data);
    send(event, stream.p_actor, msg);
  end;

end package body;
