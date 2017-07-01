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
    data_length : natural;
    address_length : natural;
  end record;

  impure function new_bus(data_length, address_length : natural) return bus_t;

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

  -- Wait until a read from address equals the value in the positions defined by the mask bit
  -- If timeout is reached error with error_msg
  procedure wait_until_read_equals(
    signal event : inout event_t;
    bus_handle   : bus_t;
    addr         : std_logic_vector;
    value        : std_logic_vector;
    mask         : std_logic_vector;
    timeout      : delay_length := delay_length'high;
    error_msg    : string       := "");

  -- Wait until a read from address has the bit with this index set to value
  -- If timeout is reached error with error_msg
  procedure wait_until_read_bit_equals(
    signal event : inout event_t;
    bus_handle   : bus_t;
    addr         : std_logic_vector;
    idx          : natural;
    value        : std_logic;
    timeout      : delay_length := delay_length'high;
    error_msg    : string       := "");

end package;

package body bus_pkg is

  impure function new_bus(data_length, address_length : natural) return bus_t is
  begin
    return (inbox => new_inbox, data_length => data_length, address_length => address_length);
  end;

  procedure write_bus(signal event : inout event_t;
                      constant bus_handle : bus_t;
                      constant address : std_logic_vector;
                      constant data : std_logic_vector) is
    variable msg : msg_t;
    variable full_data : std_logic_vector(bus_handle.data_length-1 downto 0) := (others => '0');
  begin
    msg := allocate;
    push(msg.data, bus_access_type_t'pos(write_access));
    push_std_ulogic_vector(msg.data, address);
    full_data(data'length-1 downto 0) := data;
    push_std_ulogic_vector(msg.data, full_data);
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
    data := pop_std_ulogic_vector(reply.data)(data'range);
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


  procedure wait_until_read_equals(
    signal event : inout event_t;
    bus_handle   : bus_t;
    addr         : std_logic_vector;
    value        : std_logic_vector;
    mask         : std_logic_vector;
    timeout      : delay_length := delay_length'high;
    error_msg    : string       := "") is
    constant start_time : time         := now;
    variable waited     : delay_length := delay_length'low;
    variable data       : std_logic_vector(bus_handle.data_length-1 downto 0);
  begin
    while waited <= timeout loop
      -- Do the waited calculation here so that a read delay is allowed when
      -- timeout is set to zero.
      waited := now - start_time;
      read_bus(event, bus_handle, addr, data);
      if (data and mask) = (value and mask) then
        return;
      end if;
    end loop;

    if error_msg = "" then
      report "Timeout" severity failure;
    else
      report error_msg severity failure;
    end if;
  end;

  procedure wait_until_read_bit_equals(
    signal event : inout event_t;
    bus_handle   : bus_t;
    addr         : std_logic_vector;
    idx          : natural;
    value        : std_logic;
    timeout      : delay_length := delay_length'high;
    error_msg    : string       := ""
  ) is
    variable data, mask : std_logic_vector(bus_handle.data_length-1 downto 0);
  begin
    data      := (others => '0');
    mask      := (others => '0');
    data(idx) := value;
    mask(idx) := '1';
    wait_until_read_equals(event, bus_handle, addr, data, mask, timeout, error_msg);
  end;

end package body;
