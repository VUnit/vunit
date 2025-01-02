-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

package body bus_master_pkg is

  impure function new_bus(data_length : natural;
                          address_length : natural;
                          byte_length : natural := 8;
                          logger : logger_t := bus_logger;
                          actor : actor_t := null_actor) return bus_master_t is
    variable p_actor : actor_t;
  begin
    p_actor := actor when actor /= null_actor else new_actor;

    return (p_actor => p_actor,
            p_data_length => data_length,
            p_address_length => address_length,
            p_byte_length => byte_length,
            p_logger => logger);
  end;

  function get_logger(bus_handle : bus_master_t) return logger_t is
  begin
    return bus_handle.p_logger;
  end;

  impure function data_length(bus_handle : bus_master_t) return natural is
  begin
    return bus_handle.p_data_length;
  end;

  impure function address_length(bus_handle : bus_master_t) return natural is
  begin
    return bus_handle.p_address_length;
  end;

  impure function byte_length(bus_handle : bus_master_t) return natural is
  begin
    return bus_handle.p_byte_length;
  end;

  impure function byte_enable_length(bus_handle : bus_master_t) return natural is
  begin
    return (bus_handle.p_data_length + bus_handle.p_byte_length - 1) / bus_handle.p_byte_length;
  end;

  impure function to_address(constant bus_handle : bus_master_t; address : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(address, address_length(bus_handle)));
  end;

  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : std_logic_vector;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "") is
    variable request_msg : msg_t := new_msg(bus_write_msg);
    variable full_data : std_logic_vector(bus_handle.p_data_length-1 downto 0) := (others => '0');
    variable full_address : std_logic_vector(bus_handle.p_address_length-1 downto 0) := (others => '0');
    variable full_byte_enable : std_logic_vector(byte_enable_length(bus_handle)-1 downto 0);
  begin
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

    send(net, bus_handle.p_actor, request_msg);
  end procedure;

  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : natural;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "") is
  begin
    write_bus(net, bus_handle, to_address(bus_handle, address), data, byte_enable);
  end;

  procedure burst_write_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : std_logic_vector;
                      constant burst_length : positive;
                      constant data : queue_t) is
    variable request_msg : msg_t := new_msg(bus_burst_write_msg);
    variable full_address : std_logic_vector(bus_handle.p_address_length-1 downto 0) := (others => '0');
    variable full_data : std_logic_vector(bus_handle.p_data_length-1 downto 0) := (others => '0');
  begin
    full_address(address'length-1 downto 0) := address;
    push_std_ulogic_vector(request_msg, full_address);
    push_integer(request_msg, burst_length);
    for i in 0 to burst_length-1 loop
      full_data(bus_handle.p_data_length-1 downto 0) := pop(data);
      push_std_ulogic_vector(request_msg, full_data);
    end loop;
    send(net, bus_handle.p_actor, request_msg);
  end procedure;

  procedure burst_write_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : natural;
                      constant burst_length : positive;
                      constant data : queue_t) is
  begin
    burst_write_bus(net, bus_handle, to_address(bus_handle, address), burst_length, data);
  end procedure;

  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
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

    read_bus(net, bus_handle, address, data);
    if not std_match(data, edata) then
      failure(bus_handle.p_logger, base_error);
    end if;
  end procedure;

  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : natural;
                      constant expected : std_logic_vector;
                      constant msg : string := "") is
  begin
    check_bus(net, bus_handle, to_address(bus_handle, address), expected, msg);
  end;

  -- Non blocking read with delayed reply
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : bus_master_t;
                     constant address : std_logic_vector;
                     variable reference : inout bus_reference_t) is
    variable full_address : std_logic_vector(bus_handle.p_address_length-1 downto 0) := (others => '0');
    alias request_msg : msg_t is reference;
  begin
    request_msg := new_msg(bus_read_msg);
    full_address(address'length-1 downto 0) := address;
    push_std_ulogic_vector(request_msg, full_address);
    send(net, bus_handle.p_actor, request_msg);
  end procedure;

  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : bus_master_t;
                     constant address : natural;
                     variable reference : inout bus_reference_t) is
  begin
    read_bus(net, bus_handle, to_address(bus_handle, address), reference);
  end;

  procedure burst_read_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : std_logic_vector;
                      constant burst_length : positive;
                      variable reference : inout bus_reference_t) is
    variable full_address : std_logic_vector(bus_handle.p_address_length-1 downto 0) := (others => '0');
    alias request_msg : msg_t is reference;
  begin
    request_msg := new_msg(bus_burst_read_msg);
    full_address(address'length-1 downto 0) := address;
    push_std_ulogic_vector(request_msg, full_address);
    push_integer(request_msg, burst_length);
    send(net, bus_handle.p_actor, request_msg);
  end procedure;

  procedure burst_read_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : natural;
                      constant burst_length : positive;
                      variable reference : inout bus_reference_t) is
  begin
    burst_read_bus(net, bus_handle, to_address(bus_handle, address), burst_length, reference);
  end procedure;

  -- Await read bus reply
  procedure await_read_bus_reply(signal net : inout network_t;
                                 variable reference : inout bus_reference_t;
                                 variable data : inout std_logic_vector) is
    variable reply_msg : msg_t;
    alias request_msg : msg_t is reference;
  begin
    receive_reply(net, request_msg, reply_msg);
    data := pop_std_ulogic_vector(reply_msg)(data'range);
    delete(request_msg);
    delete(reply_msg);
  end procedure;

  procedure await_burst_read_bus_reply(signal net : inout network_t;
                                 constant bus_handle : bus_master_t;
                                 constant data : queue_t;
                                 variable reference : inout bus_reference_t) is
    variable reply_msg : msg_t;
    alias request_msg : msg_t is reference;
    variable d : std_logic_vector(bus_handle.p_data_length-1 downto 0);
    variable burst_length : positive;
  begin
    receive_reply(net, request_msg, reply_msg);
    burst_length := pop_integer(reply_msg);
    for i in 0 to burst_length-1 loop
      d := pop_std_ulogic_vector(reply_msg)(d'range);
      push(data, d);
    end loop;
    delete(request_msg);
    delete(reply_msg);
  end procedure;

  -- Blocking read with immediate reply
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : bus_master_t;
                     constant address : std_logic_vector;
                     variable data : inout std_logic_vector) is
    variable reference : bus_reference_t;
  begin
    read_bus(net, bus_handle, address, reference);
    await_read_bus_reply(net, reference, data);
  end procedure;


  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : bus_master_t;
                     constant address : natural;
                     variable data : inout std_logic_vector) is
  begin
    read_bus(net, bus_handle, to_address(bus_handle, address), data);
  end;

  procedure burst_read_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : std_logic_vector;
                      constant burst_length : positive;
                      constant data : queue_t) is
    variable reference : bus_reference_t;
  begin
    burst_read_bus(net, bus_handle, address, burst_length, reference);
    await_burst_read_bus_reply(net, bus_handle, data, reference);
  end procedure;

  procedure burst_read_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : natural;
                      constant burst_length : positive;
                      constant data : queue_t) is
  begin
    burst_read_bus(net, bus_handle, to_address(bus_handle, address), burst_length, data);
  end procedure;

  procedure wait_until_read_equals(
    signal net : inout network_t;
    bus_handle   : bus_master_t;
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
      read_bus(net, bus_handle, addr, data);
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
    signal net : inout network_t;
    bus_handle   : bus_master_t;
    addr         : std_logic_vector;
    idx          : natural;
    value        : std_logic;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "") is
    variable data : std_logic_vector(bus_handle.p_data_length-1 downto 0);
  begin
    data      := (others => '-');
    data(idx) := value;
    wait_until_read_equals(net, bus_handle, addr, data, timeout, msg);
  end;

  impure function as_sync(bus_master : bus_master_t) return sync_handle_t is
  begin
    return bus_master.p_actor;
  end;

  procedure wait_until_idle(signal net : inout network_t;
                            bus_handle : bus_master_t) is
  begin
    wait_until_idle(net, bus_handle.p_actor);
  end;

end package body;
