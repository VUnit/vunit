-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.sync_pkg.all;
use work.vc_pkg.all;
use work.bus_master_pkg.all;
use work.memory_pkg.all;

package wishbone_pkg is

  type wishbone_master_t is record
    p_bus_handle : bus_master_t;
    p_strobe_high_probability : real range 0.0 to 1.0;
  end record;

  type wishbone_slave_t is record
    -- Private
    p_std_cfg             : std_cfg_t;
    p_ack_high_probability   : real range 0.0 to 1.0;
    p_stall_high_probability : real range 0.0 to 1.0;
    p_ack_actor              : actor_t;
    p_memory                 : memory_t;
  end record;

  constant wishbone_logger : logger_t := get_logger("vunit_lib:wishbone_pkg");
  constant wishbone_checker : checker_t := new_checker(wishbone_logger);

  impure function new_wishbone_master(
    data_length                : natural;
    address_length             : natural;
    strobe_high_probability    : real range 0.0 to 1.0        := 1.0;
    byte_length                : natural                      := 8;
    logger                     : logger_t                     := wishbone_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return wishbone_master_t;

  impure function new_wishbone_slave(
    memory                     : memory_t;
    ack_high_probability       : real                         := 1.0;
    stall_high_probability     : real                         := 0.0;
    logger                     : logger_t                     := wishbone_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return wishbone_slave_t;

  impure function as_sync(master : wishbone_master_t) return sync_handle_t;
  impure function as_bus_master(master : wishbone_master_t) return bus_master_t;
  impure function as_sync(slave : wishbone_slave_t) return sync_handle_t;

  -- Return the actor used by the Wishbone master
  impure function get_actor(wishbone_master : wishbone_master_t) return actor_t;

  -- Return the logger used by the Wishbone master
  impure function get_logger(wishbone_master : wishbone_master_t) return logger_t;

  -- Return the checker used by the Wishbone master
  impure function get_checker(wishbone_master : wishbone_master_t) return checker_t;

  -- Return policy for handling unexpected messages to the actor
  impure function unexpected_msg_type_policy(wishbone_master : wishbone_master_t) return unexpected_msg_type_policy_t;

  -- Return the length of the data on the Wishbone bus
  impure function data_length(wishbone_master : wishbone_master_t) return natural;

  -- Return the length of the address on the Wishbone bus
  impure function address_length(wishbone_master : wishbone_master_t) return natural;

  -- Return the length of a byte on the Wishbone bus
  impure function byte_length(wishbone_master : wishbone_master_t) return natural;

  -- Return the length of the byte enable signal on the Wishbone bus
  impure function byte_enable_length(wishbone_master : wishbone_master_t) return natural;

  -- Convert natural address to std_logic_vector using the correct number of bits
  impure function to_address(constant wishbone_master : wishbone_master_t; address : natural) return std_logic_vector;

  -- Blocking: Write the Wishbone bus
  procedure write_bus(signal net               : inout network_t;
                      constant wishbone_master : wishbone_master_t;
                      constant address         : std_logic_vector;
                      constant data            : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable     : std_logic_vector := "");
  procedure write_bus(signal net               : inout network_t;
                      constant wishbone_master : wishbone_master_t;
                      constant address         : natural;
                      constant data            : std_logic_vector;
                      -- default byte enable is all bytes
                      constant byte_enable     : std_logic_vector := "");

  -- Non blocking: Read the Wishbone bus returning a reference to the future reply
  procedure read_bus(signal net               : inout network_t;
                     constant wishbone_master : wishbone_master_t;
                     constant address         : std_logic_vector;
                     variable reference       : inout bus_reference_t);
  procedure read_bus(signal net               : inout network_t;
                     constant wishbone_master : wishbone_master_t;
                     constant address         : natural;
                     variable reference       : inout bus_reference_t);

  -- Blocking: Read the Wishbone bus and check result against expected data
  procedure check_bus(signal net               : inout network_t;
                      constant wishbone_master : wishbone_master_t;
                      constant address         : std_logic_vector;
                      constant expected        : std_logic_vector;
                      constant msg             : string := "");
  procedure check_bus(signal net               : inout network_t;
                      constant wishbone_master : wishbone_master_t;
                      constant address         : natural;
                      constant expected        : std_logic_vector;
                      constant msg             : string := "");

  -- Blocking: read the Wishbone bus with immediate reply
  procedure read_bus(signal net               : inout network_t;
                     constant wishbone_master : wishbone_master_t;
                     constant address         : std_logic_vector;
                     variable data            : inout std_logic_vector);
  procedure read_bus(signal net               : inout network_t;
                     constant wishbone_master : wishbone_master_t;
                     constant address         : natural;
                     variable data            : inout std_logic_vector);

  -- Blocking: Wait until a read from address equals the value using
  -- std_match If timeout is reached error with msg
  procedure wait_until_read_equals(
    signal net      : inout network_t;
    wishbone_master : wishbone_master_t;
    addr            : std_logic_vector;
    value           : std_logic_vector;
    timeout         : delay_length := delay_length'high;
    msg             : string       := "");

  -- Blocking: Wait until a read from address has the bit with this
  -- index set to value If timeout is reached error with msg
  procedure wait_until_read_bit_equals(
    signal net      : inout network_t;
    wishbone_master : wishbone_master_t;
    addr            : std_logic_vector;
    idx             : natural;
    value           : std_logic;
    timeout         : delay_length := delay_length'high;
    msg             : string       := "");

  -- Wait until all operations scheduled before this command has finished
  procedure wait_until_idle(signal net      : inout network_t;
    wishbone_master : wishbone_master_t);

  impure function get_std_cfg(wishbone_master : wishbone_master_t) return std_cfg_t;
  impure function get_std_cfg(wishbone_slave : wishbone_slave_t) return std_cfg_t;

end package;

package body wishbone_pkg is
  impure function new_wishbone_master(
    data_length                : natural;
    address_length             : natural;
    strobe_high_probability    : real range 0.0 to 1.0        := 1.0;
    byte_length                : natural                      := 8;
    logger                     : logger_t                     := wishbone_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return wishbone_master_t is
    constant p_bus_handle : bus_master_t := new_bus(data_length, address_length, byte_length, logger, actor, checker,
      unexpected_msg_type_policy
    );
  begin
    return (p_bus_handle => p_bus_handle,
      p_strobe_high_probability => strobe_high_probability);
  end;

  impure function new_wishbone_slave(
    memory                     : memory_t;
    ack_high_probability       : real                         := 1.0;
    stall_high_probability     : real                         := 0.0;
    logger                     : logger_t                     := wishbone_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return wishbone_slave_t is
    constant p_std_cfg : std_cfg_t := create_std_cfg(
      wishbone_logger, wishbone_checker, actor, logger, checker, unexpected_msg_type_policy
    );

  begin
    return (p_std_cfg => p_std_cfg,
            p_ack_actor => new_actor,
            p_memory => to_vc_interface(memory, logger),
            p_ack_high_probability => ack_high_probability,
            p_stall_high_probability => stall_high_probability
        );
  end;

  impure function as_sync(master : wishbone_master_t) return sync_handle_t is
  begin
    return as_sync(master.p_bus_handle);
  end;

  impure function as_bus_master(master : wishbone_master_t) return bus_master_t is
  begin
    return master.p_bus_handle;
  end;

  impure function as_sync(slave : wishbone_slave_t) return sync_handle_t is
  begin
    return get_actor(slave.p_std_cfg);
  end;

  impure function get_actor(wishbone_master : wishbone_master_t) return actor_t is
  begin
    return get_actor(wishbone_master.p_bus_handle);
  end;

  impure function get_logger(wishbone_master : wishbone_master_t) return logger_t is
  begin
    return get_logger(wishbone_master.p_bus_handle);
  end;

  impure function get_checker(wishbone_master : wishbone_master_t) return checker_t is
  begin
    return get_checker(wishbone_master.p_bus_handle);
  end;

  impure function unexpected_msg_type_policy(wishbone_master : wishbone_master_t) return unexpected_msg_type_policy_t is
  begin
    return unexpected_msg_type_policy(wishbone_master.p_bus_handle);
  end;

  impure function data_length(wishbone_master : wishbone_master_t) return natural is
  begin
    return data_length(wishbone_master.p_bus_handle);
  end;

  impure function address_length(wishbone_master : wishbone_master_t) return natural is
  begin
    return address_length(wishbone_master.p_bus_handle);
  end;

  impure function byte_length(wishbone_master : wishbone_master_t) return natural is
  begin
    return byte_length(wishbone_master.p_bus_handle);
  end;

  impure function byte_enable_length(wishbone_master : wishbone_master_t) return natural is
  begin
    return byte_enable_length(wishbone_master.p_bus_handle);
  end;

  impure function to_address(constant wishbone_master : wishbone_master_t; address : natural) return std_logic_vector is
  begin
    return to_address(wishbone_master.p_bus_handle, address);
  end;

  procedure write_bus(signal net               : inout network_t;
                      constant wishbone_master : wishbone_master_t;
                      constant address         : std_logic_vector;
                      constant data            : std_logic_vector;
                      constant byte_enable     : std_logic_vector := "") is
  begin
    write_bus(net, wishbone_master.p_bus_handle, address, data, byte_enable);
  end;

  procedure write_bus(signal net               : inout network_t;
                      constant wishbone_master : wishbone_master_t;
                      constant address         : natural;
                      constant data            : std_logic_vector;
                      constant byte_enable     : std_logic_vector := "") is
  begin
    write_bus(net, wishbone_master.p_bus_handle, address, data, byte_enable);
  end;

  procedure read_bus(signal net               : inout network_t;
                     constant wishbone_master : wishbone_master_t;
                     constant address         : std_logic_vector;
                     variable reference       : inout bus_reference_t) is
  begin
    read_bus(net, wishbone_master.p_bus_handle, address, reference);
  end;

  procedure read_bus(signal net               : inout network_t;
                     constant wishbone_master : wishbone_master_t;
                     constant address         : natural;
                     variable reference       : inout bus_reference_t) is
  begin
    read_bus(net, wishbone_master.p_bus_handle, address, reference);
  end;

  procedure check_bus(signal net               : inout network_t;
                      constant wishbone_master : wishbone_master_t;
                      constant address         : std_logic_vector;
                      constant expected        : std_logic_vector;
                      constant msg             : string := "") is
  begin
    check_bus(net, wishbone_master.p_bus_handle, address, expected, msg);
  end;

  procedure check_bus(signal net               : inout network_t;
                      constant wishbone_master : wishbone_master_t;
                      constant address         : natural;
                      constant expected        : std_logic_vector;
                      constant msg             : string := "") is
  begin
    check_bus(net, wishbone_master.p_bus_handle, address, expected, msg);
  end;

  procedure read_bus(signal net               : inout network_t;
                     constant wishbone_master : wishbone_master_t;
                     constant address         : std_logic_vector;
                     variable data            : inout std_logic_vector) is
  begin
    read_bus(net, wishbone_master.p_bus_handle, address, data);
  end;

  procedure read_bus(signal net               : inout network_t;
                     constant wishbone_master : wishbone_master_t;
                     constant address         : natural;
                     variable data            : inout std_logic_vector) is
  begin
    read_bus(net, wishbone_master.p_bus_handle, address, data);
  end;

  procedure wait_until_read_equals(
    signal net      : inout network_t;
    wishbone_master : wishbone_master_t;
    addr            : std_logic_vector;
    value           : std_logic_vector;
    timeout         : delay_length := delay_length'high;
    msg             : string       := "") is
  begin
    wait_until_read_equals(net, wishbone_master.p_bus_handle, addr, value, timeout, msg);
  end;

  procedure wait_until_read_bit_equals(
    signal net      : inout network_t;
    wishbone_master : wishbone_master_t;
    addr            : std_logic_vector;
    idx             : natural;
    value           : std_logic;
    timeout         : delay_length := delay_length'high;
    msg             : string       := "") is
  begin
    wait_until_read_bit_equals(net, wishbone_master.p_bus_handle, addr, idx, value, timeout, msg);
  end;

  procedure wait_until_idle(signal net      : inout network_t;
                            wishbone_master : wishbone_master_t) is
  begin
    wait_until_idle(net, wishbone_master.p_bus_handle);
  end;

  impure function get_std_cfg(wishbone_master : wishbone_master_t) return std_cfg_t is
  begin
    return get_std_cfg(wishbone_master.p_bus_handle);
  end;

  impure function get_std_cfg(wishbone_slave : wishbone_slave_t) return std_cfg_t is
  begin
    return wishbone_slave.p_std_cfg;
  end;



end package body;
