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

package apb_slave_pkg is

  type apb_slave_t is record
    -- Private
    p_actor : actor_t;
    p_memory : memory_t;
    p_logger : logger_t;
    p_drive_invalid     : boolean;
    p_drive_invalid_val : std_logic;
    p_ready_high_probability : real range 0.0 to 1.0;
  end record;

  constant apb_slave_logger : logger_t := get_logger("vunit_lib:apb_slave_pkg");
  impure function new_apb_slave(
    memory : memory_t;
    logger : logger_t := bus_logger;
    actor : actor_t := null_actor;
    drive_invalid : boolean := true;
    drive_invalid_val : std_logic := 'X';
    ready_high_probability : real := 1.0)
    return apb_slave_t;

    constant slave_write_msg  : msg_type_t := new_msg_type("apb slave write");
    constant slave_read_msg   : msg_type_t := new_msg_type("apb slave read");
end package;

package body apb_slave_pkg is

  impure function new_apb_slave(
    memory : memory_t;
    logger : logger_t := bus_logger;
    actor : actor_t := null_actor;
    drive_invalid : boolean := true;
    drive_invalid_val : std_logic := 'X';
    ready_high_probability : real := 1.0)
    return apb_slave_t is
  begin
    return (
      p_memory => to_vc_interface(memory, logger),
      p_logger => logger,
      p_actor => new_actor,
      p_drive_invalid => drive_invalid,
      p_drive_invalid_val => drive_invalid_val,
      p_ready_high_probability => ready_high_probability
    );
  end;
  
end package body;