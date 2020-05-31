-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.sync_pkg.all;
use work.vc_pkg.all;
use work.bus_master_pkg.all;
use work.memory_pkg.all;

package bus2memory_pkg is

  type bus2memory_t is record
    p_bus_handle : bus_master_t;
    p_memory     : memory_t;
  end record;

  constant bus2memory_logger  : logger_t  := get_logger("vunit_lib:bus_master_pkg");
  constant bus2memory_checker : checker_t := new_checker(bus2memory_logger);

  impure function new_bus2memory(
    data_length                : natural;
    address_length             : natural;
    memory                     : memory_t;
    byte_length                : natural                      := 8;
    logger                     : logger_t                     := bus2memory_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return bus2memory_t;

  impure function get_std_cfg(bus2memory : bus2memory_t) return std_cfg_t;
  impure function as_bus_master(bus2memory : bus2memory_t) return bus_master_t;
  impure function as_sync(bus2memory : bus2memory_t) return sync_handle_t;

end package;

package body bus2memory_pkg is
  impure function new_bus2memory(
    data_length                : natural;
    address_length             : natural;
    memory                     : memory_t;
    byte_length                : natural                      := 8;
    logger                     : logger_t                     := bus2memory_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return bus2memory_t is
    constant p_bus_handle : bus_master_t := new_bus(data_length, address_length, byte_length, logger, actor, checker,
      unexpected_msg_type_policy
    );
  begin
    return (p_bus_handle => p_bus_handle,
            p_memory     => memory);
  end;

  impure function get_std_cfg(bus2memory : bus2memory_t) return std_cfg_t is
  begin
    return get_std_cfg(bus2memory.p_bus_handle);
  end;

  impure function as_bus_master(bus2memory : bus2memory_t) return bus_master_t is
  begin
    return bus2memory.p_bus_handle;
  end;

  impure function as_sync(bus2memory : bus2memory_t) return sync_handle_t is
  begin
    return as_sync(bus2memory.p_bus_handle);
  end;



end package body;
