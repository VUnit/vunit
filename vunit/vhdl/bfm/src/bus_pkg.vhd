-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.message_pkg.all;
use work.queue_pkg.all;

package bus_pkg is
  type bus_t is record
    inbox : inbox_t;
  end record;

  impure function new_bus return bus_t;

  type bus_access_type_t is (read_access, write_access);

  procedure write_bus(signal event : inout event_t;
                      constant bus_handle : bus_t;
                      constant address : std_logic_vector;
                      constant data : std_logic_vector);

  -- Non blocking read with delayed reply
  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : std_logic_vector;
                     variable reply : inout reply_t);

  -- Await read bus reply
  procedure await_read_bus_reply(signal event : inout event_t;
                                 variable reply : inout reply_t;
                                 variable data : inout std_logic_vector);

  -- Blocking read with immediate reply
  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : std_logic_vector;
                     variable data : inout std_logic_vector);
end package;

package body bus_pkg is

  impure function new_bus return bus_t is
  begin
    return (inbox => new_inbox);
  end;

  procedure write_bus(signal event : inout event_t;
                      constant bus_handle : bus_t;
                      constant address : std_logic_vector;
                      constant data : std_logic_vector) is
    variable msg : msg_t;
  begin
    msg := allocate;
    push(msg.data, bus_access_type_t'pos(write_access));
    push_std_ulogic_vector(msg.data, address);
    push_std_ulogic_vector(msg.data, data);
    send(event, bus_handle.inbox, msg);
  end procedure;

  -- Non blocking read with delayed reply
  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : std_logic_vector;
                     variable reply : inout reply_t) is
    variable msg : msg_t;
  begin
    msg := allocate;
    push(msg.data, bus_access_type_t'pos(read_access));
    push_std_ulogic_vector(msg.data, address);
    send(event, bus_handle.inbox, msg, reply);
  end procedure;

  -- Await read bus reply
  procedure await_read_bus_reply(signal event : inout event_t;
                                 variable reply : inout reply_t;
                                 variable data : inout std_logic_vector) is
  begin
    recv_reply(event, reply);
    data := pop_std_ulogic_vector(reply.data);
    recycle(reply);
  end procedure;

  -- Blocking read with immediate reply
  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : std_logic_vector;
                     variable data : inout std_logic_vector) is
    variable reply : reply_t;
  begin
    read_bus(event, bus_handle, address, reply);
    await_read_bus_reply(event, reply, data);
  end procedure;
end package body;
