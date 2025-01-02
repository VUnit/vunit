-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.com_pkg.new_actor;
use work.com_pkg.send;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.sync_pkg.wait_until_idle;

package signal_checker_pkg is
  type signal_checker_t is record
    -- Private
    p_actor : actor_t;
    p_logger : logger_t;
  end record;

  impure function new_signal_checker(
    logger : logger_t := null_logger)
    return signal_checker_t;

  -- Add one value to the expect queue
  -- Allow event to occur within event_time += margin including end points
  procedure expect(signal net : inout network_t;
                   signal_checker : signal_checker_t;
                   value : std_logic_vector;
                   event_time : delay_length;
                   margin : delay_length := 0 ns);

  -- Wait until all expected values have been checked
  procedure wait_until_idle(signal net : inout network_t;
                            signal_checker : signal_checker_t);

  -- Private message type definitions
  constant expect_msg : msg_type_t := new_msg_type("expect");

end package;


package body signal_checker_pkg is
  impure function new_signal_checker(logger : logger_t := null_logger) return signal_checker_t is
    variable result : signal_checker_t;
  begin
    result := (p_actor => new_actor,
               p_logger => logger);
    if logger = null_logger then
      result.p_logger := default_logger;
    end if;
    return result;
  end;

  procedure expect(signal net : inout network_t;
                   signal_checker : signal_checker_t;
                   value : std_logic_vector;
                   event_time : delay_length;
                   margin : delay_length := 0 ns) is
    variable request_msg : msg_t := new_msg(expect_msg);
  begin
    push_std_ulogic_vector(request_msg, value);
    push_time(request_msg, event_time);
    push_time(request_msg, margin);
    send(net, signal_checker.p_actor, request_msg);
  end;

  procedure wait_until_idle(signal net : inout network_t;
                            signal_checker : signal_checker_t) is
  begin
    wait_until_idle(net, signal_checker.p_actor);
  end;

end package body;
