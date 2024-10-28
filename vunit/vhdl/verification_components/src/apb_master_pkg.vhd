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
use work.memory_pkg.memory_t;
use work.memory_pkg.to_vc_interface;

package apb_master_pkg is

  type apb_master_t is record
    -- Private
    p_bus_handle : bus_master_t;
    p_drive_invalid     : boolean;
    p_drive_invalid_val : std_logic;
    p_ready_high_probability : real range 0.0 to 1.0;
  end record;

  impure function new_apb_master(
    data_length : natural;
    address_length : natural;
    logger : logger_t := bus_logger;
    actor : actor_t := null_actor;
    drive_invalid : boolean := true;
    drive_invalid_val : std_logic := 'X';
    ready_high_probability : real := 1.0
  ) return apb_master_t;

  function get_logger(bus_handle : apb_master_t) return logger_t;

  -- Blocking: Write the bus
  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : apb_master_t;
                      constant address : std_logic_vector;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "");
  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : apb_master_t;
                      constant address : natural;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "");

  procedure wait_until_idle(signal net : inout network_t;
                            bus_handle : apb_master_t);

  -- Non blocking: Read the bus returning a reference to the future reply
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_master_t;
                     constant address : std_logic_vector;
                     variable reference : inout bus_reference_t);

  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_master_t;
                     constant address : natural;
                     variable reference : inout bus_reference_t);

  -- Blocking: read bus with immediate reply
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_master_t;
                     constant address : std_logic_vector;
                     variable data : inout std_logic_vector);
                     
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_master_t;
                     constant address : natural;
                     variable data : inout std_logic_vector);

  -- Blocking: Read bus and check result against expected data
  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : apb_master_t;
                      constant address : std_logic_vector;
                      constant expected : std_logic_vector;
                      constant msg : string := "");
                      
  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : apb_master_t;
                      constant address : natural;
                      constant expected : std_logic_vector;
                      constant msg : string := "");

  -- Blocking: Wait until a read from address equals the value using
  -- std_match If timeout is reached error with msg
  procedure wait_until_read_equals(
    signal net : inout network_t;
    bus_handle   : apb_master_t;
    addr         : std_logic_vector;
    value        : std_logic_vector;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "");

  -- Blocking: Wait until a read from address has the bit with this
  -- index set to value If timeout is reached error with msg
  procedure wait_until_read_bit_equals(
    signal net : inout network_t;
    bus_handle   : apb_master_t;
    addr         : std_logic_vector;
    idx          : natural;
    value        : std_logic;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "");
end package;

package body apb_master_pkg is

  impure function new_apb_master(
    data_length : natural;
    address_length : natural;
    logger : logger_t := bus_logger;
    actor : actor_t := null_actor;
    drive_invalid : boolean := true;
    drive_invalid_val : std_logic := 'X';
    ready_high_probability : real := 1.0
  ) return apb_master_t is
    variable bus_handle : bus_master_t := new_bus(
      data_length => data_length,
      address_length => address_length,
      logger => logger,
      actor => actor
    );    
  begin
    return (
      p_bus_handle => bus_handle,
      p_drive_invalid => drive_invalid,
      p_drive_invalid_val => drive_invalid_val,
      p_ready_high_probability => ready_high_probability
    );
  end;

  function get_logger(bus_handle : apb_master_t) return logger_t is
  begin
    return get_logger(bus_handle.p_bus_handle);
  end function;

  -- Blocking: Write the bus
  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : apb_master_t;
                      constant address : std_logic_vector;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "") is
  begin
    write_bus(net, bus_handle.p_bus_handle, address, data, byte_enable);
  end procedure;

  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : apb_master_t;
                      constant address : natural;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "") is
  begin
    write_bus(net, bus_handle.p_bus_handle, address, data, byte_enable);
  end procedure;

  procedure wait_until_idle(signal net : inout network_t;
                            bus_handle : apb_master_t) is
  begin
    wait_until_idle(net, bus_handle.P_bus_handle);
  end procedure;

  -- Blocking: read bus with immediate reply
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_master_t;
                     constant address : std_logic_vector;
                     variable data : inout std_logic_vector) is
  begin
    read_bus(net, bus_handle.p_bus_handle, address, data);
  end procedure;

  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_master_t;
                     constant address : natural;
                     variable data : inout std_logic_vector) is
  begin
    read_bus(net, bus_handle.p_bus_handle, address, data);
  end procedure;

  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_master_t;
                     constant address : natural;
                     variable reference : inout bus_reference_t) is
  begin
    read_bus(net, bus_handle.p_bus_handle, address, reference);
  end procedure;

  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : apb_master_t;
                     constant address : std_logic_vector;
                     variable reference : inout bus_reference_t) is
  begin
    read_bus(net, bus_handle.p_bus_handle, address, reference);
  end procedure;

  -- Blocking: Read bus and check result against expected data
  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : apb_master_t;
                      constant address : std_logic_vector;
                      constant expected : std_logic_vector;
                      constant msg : string := "") is
  begin
    check_bus(net, bus_handle.p_bus_handle, address, expected, msg);
  end procedure;

  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : apb_master_t;
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
    bus_handle   : apb_master_t;
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
    bus_handle   : apb_master_t;
    addr         : std_logic_vector;
    idx          : natural;
    value        : std_logic;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "") is
  begin
    wait_until_read_bit_equals(net, bus_handle.p_bus_handle, addr, idx, value, timeout, msg);
  end procedure;
end package body;