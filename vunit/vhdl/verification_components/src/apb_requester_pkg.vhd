-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.bus_master_pkg.all;
use work.com_pkg.all;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.sync_pkg.all;
use work.memory_pkg.memory_t;
use work.memory_pkg.to_vc_interface;

package apb_requester_pkg is

  type apb_requester_t is record
    -- Private
    p_bus_handle : bus_master_t;
    p_drive_invalid     : boolean;
    p_drive_invalid_val : std_logic;
  end record;

  impure function new_apb_requester(
    data_length : natural;
    address_length : natural;
    logger : logger_t := null_logger;
    actor : actor_t := null_actor;
    drive_invalid : boolean := true;
    drive_invalid_val : std_logic := 'X'
  ) return apb_requester_t;

  function get_logger(bus_handle : apb_requester_t) return logger_t;

  impure function byte_enable_length(bus_handle : apb_requester_t) return natural;

  -- Blocking: Write the bus
  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : apb_requester_t;
                      constant address : std_logic_vector;
                      constant data : std_logic_vector;
                      constant expected_error : std_logic := '0';
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "");
  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : apb_requester_t;
                      constant address : natural;
                      constant data : std_logic_vector;
                      constant expected_error : std_logic := '0';
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "");

  -- Non blocking: Read the bus returning a reference to the future reply
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_requester_t;
                     constant address : std_logic_vector;
                     variable reference : inout bus_reference_t;
                     constant expected_error : std_logic := '0');

  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_requester_t;
                     constant address : natural;
                     variable reference : inout bus_reference_t;
                     constant expected_error : std_logic := '0');

  -- Blocking: read bus with immediate reply
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_requester_t;
                     constant address : std_logic_vector;
                     variable data : inout std_logic_vector;
                     constant expected_error : std_logic := '0');

  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_requester_t;
                     constant address : natural;
                     variable data : inout std_logic_vector;
                     constant expected_error : std_logic := '0');

  -- Blocking: Read bus and check result against expected data
  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : apb_requester_t;
                      constant address : std_logic_vector;
                      constant expected : std_logic_vector;
                      constant msg : string := "");

  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : apb_requester_t;
                      constant address : natural;
                      constant expected : std_logic_vector;
                      constant msg : string := "");

  -- Blocking: Wait until a read from address equals the value using
  -- std_match If timeout is reached error with msg
  procedure wait_until_read_equals(
    signal net : inout network_t;
    bus_handle   : apb_requester_t;
    addr         : std_logic_vector;
    value        : std_logic_vector;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "");

  -- Blocking: Wait until a read from address has the bit with this
  -- index set to value If timeout is reached error with msg
  procedure wait_until_read_bit_equals(
    signal net : inout network_t;
    bus_handle   : apb_requester_t;
    addr         : std_logic_vector;
    idx          : natural;
    value        : std_logic;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "");

  procedure wait_until_idle(signal net : inout network_t;
                            handle     :       apb_requester_t;
                            timeout    :       delay_length := max_timeout);

  procedure wait_for_time(signal net : inout network_t;
                            handle     :       apb_requester_t;
                            delay      :       delay_length);

  constant apb_write_msg : msg_type_t := new_msg_type("write apb bus");
  constant apb_read_msg : msg_type_t := new_msg_type("read apb bus");
end package;

package body apb_requester_pkg is

  impure function new_apb_requester(
    data_length : natural;
    address_length : natural;
    logger : logger_t := null_logger;
    actor : actor_t := null_actor;
    drive_invalid : boolean := true;
    drive_invalid_val : std_logic := 'X'
  ) return apb_requester_t is
    impure function create_bus (logger : logger_t) return bus_master_t is
    begin
      return new_bus(
        data_length => data_length,
        address_length => address_length,
        logger => logger,
        actor => actor
      );
    end function;
    variable logger_tmp : logger_t := null_logger;
  begin
    if logger = null_logger then
      logger_tmp := bus_logger;
    else
      logger_tmp := logger;
    end if;
    return (
      p_bus_handle => create_bus(logger_tmp),
      p_drive_invalid => drive_invalid,
      p_drive_invalid_val => drive_invalid_val
    );
  end;

  function get_logger(bus_handle : apb_requester_t) return logger_t is
  begin
    return get_logger(bus_handle.p_bus_handle);
  end function;

  impure function address_length(bus_handle : apb_requester_t) return natural is
  begin
    return bus_handle.p_bus_handle.p_address_length;
  end;

  impure function byte_enable_length(bus_handle : apb_requester_t) return natural is
  begin
    return (bus_handle.p_bus_handle.p_data_length + bus_handle.p_bus_handle.p_byte_length - 1)
           / bus_handle.p_bus_handle.p_byte_length;
  end;

  impure function to_address(constant bus_handle : apb_requester_t; address : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(address, address_length(bus_handle)));
  end;

  -- Blocking: Write the bus
  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : apb_requester_t;
                      constant address : std_logic_vector;
                      constant data : std_logic_vector;
                      constant expected_error : std_logic := '0';
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "") is
    variable request_msg : msg_t := new_msg(apb_write_msg);
    variable full_data : std_logic_vector(bus_handle.p_bus_handle.p_data_length-1 downto 0) := (others => '0');
    variable full_address : std_logic_vector(bus_handle.p_bus_handle.p_address_length-1 downto 0) := (others => '0');
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
    push_std_ulogic(request_msg, expected_error);

    send(net, bus_handle.p_bus_handle.p_actor, request_msg);
  end procedure;

  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : apb_requester_t;
                      constant address : natural;
                      constant data : std_logic_vector;
                      constant expected_error : std_logic := '0';
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "") is
  begin
    write_bus(net, bus_handle, to_address(bus_handle, address), data, expected_error, byte_enable);
  end procedure;

  -- Blocking: read bus with immediate reply
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_requester_t;
                     constant address : std_logic_vector;
                     variable data : inout std_logic_vector;
                     constant expected_error : std_logic := '0') is
    variable reference : bus_reference_t;
  begin
    read_bus(net, bus_handle, address, reference, expected_error);
    await_read_bus_reply(net, reference, data);
  end procedure;

  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_requester_t;
                     constant address : natural;
                     variable data : inout std_logic_vector;
                     constant expected_error : std_logic := '0') is
    variable reference : bus_reference_t;
  begin
    read_bus(net, bus_handle, to_address(bus_handle, address), reference, expected_error);
    await_read_bus_reply(net, reference, data);
  end procedure;

   -- Non blocking read with delayed reply
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_requester_t;
                     constant address : natural;
                     variable reference : inout bus_reference_t;
                     constant expected_error : std_logic := '0') is
  begin
    read_bus(net, bus_handle, to_address(bus_handle, address), reference, expected_error);
  end procedure;

  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_requester_t;
                     constant address : std_logic_vector;
                     variable reference : inout bus_reference_t;
                     constant expected_error : std_logic := '0') is
    variable full_address : std_logic_vector(bus_handle.p_bus_handle.p_address_length-1 downto 0) := (others => '0');
    alias request_msg : msg_t is reference;
  begin
    request_msg := new_msg(apb_read_msg);
    full_address(address'length-1 downto 0) := address;
    push_std_ulogic_vector(request_msg, full_address);
    push_std_ulogic(request_msg, expected_error);
    send(net, bus_handle.p_bus_handle.p_actor, request_msg);
  end procedure;

  -- Blocking: Read bus and check result against expected data
  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : apb_requester_t;
                      constant address : std_logic_vector;
                      constant expected : std_logic_vector;
                      constant msg : string := "") is
  begin
    check_bus(net, bus_handle.p_bus_handle, address, expected, msg);
  end procedure;

  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : apb_requester_t;
                      constant address : natural;
                      constant expected : std_logic_vector;
                      constant msg : string := "") is
  begin
    check_bus(net, bus_handle.p_bus_handle, address, expected, msg);
  end procedure;

  -- Blocking: Wait until a read from address equals the value using
  -- std_match If timeout is reached error with msg
  procedure wait_until_read_equals(
    signal net : inout network_t;
    bus_handle   : apb_requester_t;
    addr         : std_logic_vector;
    value        : std_logic_vector;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "") is
  begin
    wait_until_read_equals(net, bus_handle.p_bus_handle, addr, value, timeout, msg);
  end procedure;

  -- Blocking: Wait until a read from address has the bit with this
  -- index set to value If timeout is reached error with msg
  procedure wait_until_read_bit_equals(
    signal net : inout network_t;
    bus_handle   : apb_requester_t;
    addr         : std_logic_vector;
    idx          : natural;
    value        : std_logic;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "") is
  begin
    wait_until_read_bit_equals(net, bus_handle.p_bus_handle, addr, idx, value, timeout, msg);
  end procedure;

  procedure wait_until_idle(signal net : inout network_t;
                            handle     :       apb_requester_t;
                            timeout    :       delay_length := max_timeout) is
  begin
    wait_until_idle(net, handle.p_bus_handle.p_actor, timeout);
  end procedure;

  procedure wait_for_time(signal net : inout network_t;
                          handle     :       apb_requester_t;
                          delay      :       delay_length) is
  begin
    wait_for_time(net, handle.p_bus_handle.p_actor, delay);
  end procedure;
end package body;