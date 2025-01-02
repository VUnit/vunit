-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

-- Defines bus master verification component interface

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

use work.com_pkg.all;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.queue_pkg.all;
use work.sync_pkg.all;

package bus_master_pkg is

  -- Handle to VC instance with bus master VCI
  type bus_master_t is record
    -- These fields are private, do not use directly
    p_actor : actor_t;
    p_data_length : natural;
    p_address_length : natural;
    p_byte_length : natural;
    p_logger : logger_t;
  end record;

  -- Reference to non-blocking bus command
  alias bus_reference_t is msg_t;

  -- Default logger object for bus master instances
  constant bus_logger : logger_t := get_logger("vunit_lib:bus_master_pkg");

  -- Create new handle for bus master VC
  impure function new_bus(data_length : natural;
                          address_length : natural;
                          byte_length : natural := 8;
                          logger : logger_t := bus_logger;
                          actor : actor_t := null_actor) return bus_master_t;

  -- Return the logger used by the bus master
  function get_logger(bus_handle : bus_master_t) return logger_t;

  -- Return the length of the data on this bus
  impure function data_length(bus_handle : bus_master_t) return natural;

  -- Return the length of the address on this bus
  impure function address_length(bus_handle : bus_master_t) return natural;

  -- Return the length of a byte on this bus
  impure function byte_length(bus_handle : bus_master_t) return natural;

  -- Return the length of the byte enable signal on this bus
  impure function byte_enable_length(bus_handle : bus_master_t) return natural;

  -- Convert natural address to std_logic_vector using the correct number of bits
  impure function to_address(constant bus_handle :
                             bus_master_t; address : natural) return std_logic_vector;

  -- Blocking: Write the bus
  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : std_logic_vector;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "");
  procedure write_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : natural;
                      constant data : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable : std_logic_vector := "");
  -- Procedures for burst bus write: Caller is responsible for allocation and
  -- deallocation of data queue. Procedure cunsumes burst_length data words
  -- from data queue. If data queue has less data words, all data
  -- words are consumed and pop from empty queue error is raised.
  procedure burst_write_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : std_logic_vector;
                      constant burst_length : positive;
                      constant data : queue_t);
  procedure burst_write_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : natural;
                      constant burst_length : positive;
                      constant data : queue_t);

  -- Non blocking: Read the bus returning a reference to the future reply
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : bus_master_t;
                     constant address : std_logic_vector;
                     variable reference : inout bus_reference_t);
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : bus_master_t;
                     constant address : natural;
                     variable reference : inout bus_reference_t);
  procedure burst_read_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : std_logic_vector;
                      constant burst_length : positive;
                      variable reference : inout bus_reference_t);
  procedure burst_read_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : natural;
                      constant burst_length : positive;
                      variable reference : inout bus_reference_t);

  -- Blocking: Await read bus reply data
  procedure await_read_bus_reply(signal net : inout network_t;
                                 variable reference : inout bus_reference_t;
                                 variable data : inout std_logic_vector);
  -- Procedure for burst read reply: Caller is responsible for allocation and
  -- deallocation of data queue. Procedure pushes burst_length data words
  -- into data queue.
  procedure await_burst_read_bus_reply(signal net : inout network_t;
                                 constant bus_handle : bus_master_t;
                                 constant data : queue_t;
                                 variable reference : inout bus_reference_t);

  -- Blocking: Read bus and check result against expected data
  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : std_logic_vector;
                      constant expected : std_logic_vector;
                      constant msg : string := "");
  procedure check_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : natural;
                      constant expected : std_logic_vector;
                      constant msg : string := "");

  -- Blocking: read bus with immediate reply
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : bus_master_t;
                     constant address : std_logic_vector;
                     variable data : inout std_logic_vector);
  procedure read_bus(signal net : inout network_t;
                     constant bus_handle : bus_master_t;
                     constant address : natural;
                     variable data : inout std_logic_vector);
  -- Procedure for burst bus read: Caller is responsible for allocation and
  -- deallocation of data queue. Procedure pushes burst_length data words
  -- into data queue.
  procedure burst_read_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : std_logic_vector;
                      constant burst_length : positive;
                      constant data : queue_t);
  procedure burst_read_bus(signal net : inout network_t;
                      constant bus_handle : bus_master_t;
                      constant address : natural;
                      constant burst_length : positive;
                      constant data : queue_t);

  -- Blocking: Wait until a read from address equals the value using
  -- std_match If timeout is reached error with msg
  procedure wait_until_read_equals(
    signal net : inout network_t;
    bus_handle   : bus_master_t;
    addr         : std_logic_vector;
    value        : std_logic_vector;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "");

  -- Blocking: Wait until a read from address has the bit with this
  -- index set to value If timeout is reached error with msg
  procedure wait_until_read_bit_equals(
    signal net : inout network_t;
    bus_handle   : bus_master_t;
    addr         : std_logic_vector;
    idx          : natural;
    value        : std_logic;
    timeout      : delay_length := delay_length'high;
    msg    : string       := "");

  -- Convert a bus master to a sync handle
  impure function as_sync(bus_master : bus_master_t) return sync_handle_t;

  -- Wait until all operations scheduled before this command has finished
  procedure wait_until_idle(signal net : inout network_t;
                            bus_handle : bus_master_t);

  -- Message type definitions, used by VC-instances
  constant bus_write_msg : msg_type_t := new_msg_type("write bus");
  constant bus_read_msg : msg_type_t := new_msg_type("read bus");
  constant bus_burst_write_msg : msg_type_t := new_msg_type("burst write bus");
  constant bus_burst_read_msg : msg_type_t := new_msg_type("burst read bus");
end package;
