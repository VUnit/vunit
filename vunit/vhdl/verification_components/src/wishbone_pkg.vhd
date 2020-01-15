-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
library ieee;
use ieee.std_logic_1164.all;

use work.queue_pkg.all;
use work.logger_pkg.all;
use work.memory_pkg.all;
context work.com_context;

package wishbone_pkg is

  type wishbone_slave_t is record
    ack_high_probability : real range 0.0 to 1.0;
    stall_high_probability : real range 0.0 to 1.0;
    -- Private
    p_actor : actor_t;
    p_ack_actor : actor_t;
    p_memory : memory_t;
    p_logger : logger_t;
  end record;

  constant wishbone_slave_logger : logger_t := get_logger("vunit_lib:wishbone_slave_pkg");
  impure function new_wishbone_slave(
    memory : memory_t;
    ack_high_probability : real := 1.0;
    stall_high_probability : real := 0.0;
    logger : logger_t := wishbone_slave_logger)
    return wishbone_slave_t;

end package;
package body wishbone_pkg is

  impure function new_wishbone_slave(
    memory : memory_t;
    ack_high_probability : real := 1.0;
    stall_high_probability : real := 0.0;
    logger : logger_t := wishbone_slave_logger)
    return wishbone_slave_t is
  begin
    return (p_actor => new_actor,
            p_ack_actor => new_actor,
            p_memory => to_vc_interface(memory, logger),
            p_logger => logger,
            ack_high_probability => ack_high_probability,
            stall_high_probability => stall_high_probability
        );
  end;

end package body;
