-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl

library ieee;
use ieee.std_logic_1164.all;

use work.com_pkg.new_actor;
use work.com_types_pkg.actor_t;
use work.logger_pkg.all;
use work.memory_pkg.memory_t;
use work.memory_pkg.to_vc_interface;

package avalon_pkg is

  type avalon_slave_t is record
    readdatavalid_high_probability : real range 0.0 to 1.0;
    waitrequest_high_probability : real range 0.0 to 1.0;
    -- Private
    p_actor : actor_t;
    p_ack_actor : actor_t;
    p_memory : memory_t;
    p_logger : logger_t;
  end record;

  constant avalon_slave_logger : logger_t := get_logger("vunit_lib:avalon_pkg");
  impure function new_avalon_slave(
    memory : memory_t;
    readdatavalid_high_probability : real := 1.0;
    waitrequest_high_probability : real := 0.0;
	name : string := "";
    logger : logger_t := avalon_slave_logger)
    return avalon_slave_t;

end package;
package body avalon_pkg is

  impure function new_avalon_slave(
    memory : memory_t;
    readdatavalid_high_probability : real := 1.0;
    waitrequest_high_probability : real := 0.0;
	name : string := "";
    logger : logger_t := avalon_slave_logger)
    return avalon_slave_t is
  begin
    return (p_actor => new_actor(name),
            p_ack_actor => new_actor(name&" read-ack"),
            p_memory => to_vc_interface(memory, logger),
            p_logger => logger,
            readdatavalid_high_probability => readdatavalid_high_probability,
            waitrequest_high_probability => waitrequest_high_probability
        );
  end;

end package body;
