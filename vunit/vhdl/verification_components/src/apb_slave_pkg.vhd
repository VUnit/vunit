-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.com_pkg.all;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.memory_pkg.memory_t;
use work.memory_pkg.to_vc_interface;

package apb_slave_pkg is

  type apb_slave_t is record
    ready_high_probability : real range 0.0 to 1.0;
    -- Private
    p_actor : actor_t;
    p_memory : memory_t;
    p_logger : logger_t;
  end record;

  constant apb_slave_logger : logger_t := get_logger("vunit_lib:apb_slave_pkg");
  impure function new_apb_slave(
    memory : memory_t;
    ready_high_probability : real := 1.0;
    logger : logger_t := apb_slave_logger)
    return apb_slave_t;

    constant slave_write_msg  : msg_type_t := new_msg_type("apb slave write");
    constant slave_read_msg   : msg_type_t := new_msg_type("apb slave read");
end package;

package body apb_slave_pkg is

  impure function new_apb_slave(
    memory : memory_t;
    ready_high_probability : real := 1.0;
    logger : logger_t := apb_slave_logger)
    return apb_slave_t is
  begin
    return (p_actor => new_actor,
            p_memory => to_vc_interface(memory, logger),
            p_logger => logger,
            ready_high_probability => ready_high_probability
        );
  end;
  
end package body;