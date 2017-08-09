-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.queue_pkg.all;
use work.logger_pkg.all;
use work.msg_types_pkg.all;
context work.com_context;

package bus_pkg is
  alias bus_reference_t is msg_t;

  type bus_t is record
    -- Private
    p_actor : actor_t;
    p_data_length : natural;
    p_address_length : natural;
    p_byte_length : natural;
    p_logger : logger_t;
  end record;

  constant bus_write_msg : msg_type_t := new_msg_type("write bus");
  constant bus_read_msg : msg_type_t := new_msg_type("read bus");

  constant bus_logger : logger_t := get_logger("vunit_lib.bus_pkg");
  impure function new_bus(data_length : natural;
                          address_length : natural;
                          byte_length : natural := 8;
                          logger : logger_t := bus_logger) return bus_t;
  impure function data_length(bus_handle : bus_t) return natural;
  impure function address_length(bus_handle : bus_t) return natural;
  impure function byte_length(bus_handle : bus_t) return natural;
  impure function byte_enable_length(bus_handle : bus_t) return natural;

  impure function to_address(constant bus_handle : bus_t; address : natural) return std_logic_vector;

  procedure write_bus(signal event : inout event_t;
                      constant bus_handle : bus_t;
                      constant address : std_logic_vector;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "");

  procedure write_bus(signal event : inout event_t;
                      constant bus_handle : bus_t;
                      constant address : natural;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "");

  -- Non blocking read with delayed reply
  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : std_logic_vector;
                     variable reference : inout bus_reference_t);

  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : natural;
                     variable reference : inout bus_reference_t);

  -- Await read bus reply
  procedure await_read_bus_reply(signal event : inout event_t;
                                 variable reference : inout bus_reference_t;
                                 variable data : inout std_logic_vector);

  -- Blocking read and check result
  procedure check_bus(signal event : inout event_t;
                      constant bus_handle : bus_t;
                      constant address : std_logic_vector;
                      constant expected : std_logic_vector;
                      constant msg : string := "");

  procedure check_bus(signal event : inout event_t;
                      constant bus_handle : bus_t;
                      constant address : natural;
                      constant expected : std_logic_vector;
                      constant msg : string := "");

  -- Blocking read with immediate reply
  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : std_logic_vector;
                     variable data : inout std_logic_vector);

  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : natural;
                     variable data : inout std_logic_vector);


  -- Wait until a read from address equals the value using std_match
  -- If timeout is reached error with msg
  procedure wait_until_read_equals(
    signal event : inout event_t;
    bus_handle   : bus_t;
    addr         : std_logic_vector;
    value        : std_logic_vector;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "");

  -- Wait until a read from address has the bit with this index set to value
  -- If timeout is reached error with msg
  procedure wait_until_read_bit_equals(
    signal event : inout event_t;
    bus_handle   : bus_t;
    addr         : std_logic_vector;
    idx          : natural;
    value        : std_logic;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "");

end package;

package body bus_pkg is

  impure function new_bus(data_length : natural;
                          address_length : natural;
                          byte_length : natural := 8;
                          logger : logger_t := bus_logger) return bus_t is
  begin
    return (p_actor => create,
            p_data_length => data_length,
            p_address_length => address_length,
            p_byte_length => byte_length,
            p_logger => logger);
  end;

  impure function data_length(bus_handle : bus_t) return natural is
  begin
    return bus_handle.p_data_length;
  end;

  impure function address_length(bus_handle : bus_t) return natural is
  begin
    return bus_handle.p_address_length;
  end;

  impure function byte_length(bus_handle : bus_t) return natural is
  begin
    return bus_handle.p_byte_length;
  end;

  impure function byte_enable_length(bus_handle : bus_t) return natural is
  begin
    return (bus_handle.p_data_length + bus_handle.p_byte_length - 1) / bus_handle.p_byte_length;
  end;

  impure function to_address(constant bus_handle : bus_t; address : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(address, address_length(bus_handle)));
  end;

  procedure write_bus(signal event : inout event_t;
                      constant bus_handle : bus_t;
                      constant address : std_logic_vector;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "") is
    variable request_msg : msg_t := create;
    variable full_data : std_logic_vector(bus_handle.p_data_length-1 downto 0) := (others => '0');
    variable full_address : std_logic_vector(bus_handle.p_address_length-1 downto 0) := (others => '0');
    variable full_byte_enable : std_logic_vector(byte_enable_length(bus_handle)-1 downto 0);
  begin
    push_msg_type(request_msg, bus_write_msg);

    full_address(address'length-1 downto 0) := address;
    push_std_ulogic_vector(request_msg, full_address);

    full_data(data'length-1 downto 0) := data;
    push_std_ulogic_vector(request_msg, full_data);

    if byte_enable = "" then
      full_byte_enable := (others => '1');
    else
      full_byte_enable(byte_enable'length-1 downto 0) := byte_enable;
    end if;
    push_std_ulogic_vector(request_msg, full_byte_enable);

    send(event, bus_handle.p_actor, request_msg);
  end procedure;

  procedure write_bus(signal event : inout event_t;
                      constant bus_handle : bus_t;
                      constant address : natural;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "") is
  begin
    write_bus(event, bus_handle, to_address(bus_handle, address), data, byte_enable);
  end;

  procedure check_bus(signal event : inout event_t;
                      constant bus_handle : bus_t;
                      constant address : std_logic_vector;
                      constant expected : std_logic_vector;
                      constant msg : string := "") is
    variable data : std_logic_vector(bus_handle.p_data_length-1 downto 0);
    variable edata : std_logic_vector(data'range) := (others => '0');

    impure function error_prefix return string is
    begin
      if msg = "" then
        return "check_bus(x""" & to_hstring(address) & """)";
      else
        return msg;
      end if;
    end;

    impure function base_error return string is
    begin
      return error_prefix & " - Got x""" & to_hstring(data) & """ expected x""" & to_hstring(edata) & """";
    end;
  begin

    edata(expected'length-1 downto 0) := expected;

    read_bus(event, bus_handle, address, data);
    if not std_match(data, edata) then
      failure(bus_handle.p_logger, base_error);
    end if;
  end procedure;

  procedure check_bus(signal event : inout event_t;
                      constant bus_handle : bus_t;
                      constant address : natural;
                      constant expected : std_logic_vector;
                      constant msg : string := "") is
  begin
    check_bus(event, bus_handle, to_address(bus_handle, address), expected, msg);
  end;

  -- Non blocking read with delayed reply
  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : std_logic_vector;
                     variable reference : inout bus_reference_t) is
    variable full_address : std_logic_vector(bus_handle.p_address_length-1 downto 0) := (others => '0');
    alias request_msg : msg_t is reference;
  begin
    request_msg := create;
    push_msg_type(request_msg, bus_read_msg);
    full_address(address'length-1 downto 0) := address;
    push_std_ulogic_vector(request_msg, full_address);
    send(event, bus_handle.p_actor, request_msg);
  end procedure;

  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : natural;
                     variable reference : inout bus_reference_t) is
  begin
    read_bus(event, bus_handle, to_address(bus_handle, address), reference);
  end;

  -- Await read bus reply
  procedure await_read_bus_reply(signal event : inout event_t;
                                 variable reference : inout bus_reference_t;
                                 variable data : inout std_logic_vector) is
    variable reply_msg : msg_t;
    alias request_msg : msg_t is reference;
  begin
    receive_reply(event, request_msg, reply_msg);
    data := pop_std_ulogic_vector(reply_msg)(data'range);
    delete(request_msg);
    delete(reply_msg);
  end procedure;

  -- Blocking read with immediate reply
  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : std_logic_vector;
                     variable data : inout std_logic_vector) is
    variable reference : bus_reference_t;
  begin
    read_bus(event, bus_handle, address, reference);
    await_read_bus_reply(event, reference, data);
  end procedure;


  procedure read_bus(signal event : inout event_t;
                     constant bus_handle : bus_t;
                     constant address : natural;
                     variable data : inout std_logic_vector) is
  begin
    read_bus(event, bus_handle, to_address(bus_handle, address), data);
  end;

  procedure wait_until_read_equals(
    signal event : inout event_t;
    bus_handle   : bus_t;
    addr         : std_logic_vector;
    value        : std_logic_vector;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "") is
    constant start_time : time         := now;
    variable waited     : delay_length := delay_length'low;
    variable data       : std_logic_vector(bus_handle.p_data_length-1 downto 0);
  begin
    while waited <= timeout loop
      -- Do the waited calculation here so that a read delay is allowed when
      -- timeout is set to zero.
      waited := now - start_time;
      read_bus(event, bus_handle, addr, data);
      if std_match(data(value'length-1 downto 0), value) then
        return;
      end if;
    end loop;

    if msg = "" then
      failure(bus_handle.p_logger, "Timeout");
    else
      failure(bus_handle.p_logger, msg);
    end if;
  end;

  procedure wait_until_read_bit_equals(
    signal event : inout event_t;
    bus_handle   : bus_t;
    addr         : std_logic_vector;
    idx          : natural;
    value        : std_logic;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "") is
    variable data : std_logic_vector(bus_handle.p_data_length-1 downto 0);
  begin
    data      := (others => '-');
    data(idx) := value;
    wait_until_read_equals(event, bus_handle, addr, data, timeout, msg);
  end;

end package body;
