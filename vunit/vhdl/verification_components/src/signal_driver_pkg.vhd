
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

package signal_driver_pkg is
  type signal_driver_t is record
    p_actor  : actor_t;
    p_logger : logger_t;
    initial  : std_logic_vector;
  end record;

  impure function new_signal_driver(
    initial : std_logic_vector;
    logger  : logger_t := null_logger)
    return signal_driver_t;

  procedure drive(signal net    : inout network_t;
                  signal_driver :       signal_driver_t;
                  value         :       std_logic_vector
                  );

  procedure wait_until_idle(signal net    : inout network_t;
                            signal_driver :       signal_driver_t);

  constant drive_msg : msg_type_t := new_msg_type("drive");

end package signal_driver_pkg;

package body signal_driver_pkg is
  impure function new_signal_driver(initial : std_logic_vector; logger : logger_t := null_logger) return signal_driver_t is
    variable result : signal_driver_t(initial (initial'range));
  begin
    result := (p_actor  => new_actor,
               p_logger => logger,
               initial  => initial);
    if logger = null_logger then
      result.p_logger := default_logger;
    end if;
    return result;
  end;

  procedure drive(signal net    : inout network_t;
                  signal_driver :       signal_driver_t;
                  value         :       std_logic_vector
                  ) is
    variable msg : msg_t := new_msg(drive_msg);
  begin
    push_std_ulogic_vector(msg, value);
    send(net, signal_driver.p_actor, msg);
  end;

  procedure wait_until_idle(signal net    : inout network_t;
                            signal_driver :       signal_driver_t) is
  begin
    wait_until_idle(net, signal_driver.p_actor);
  end;

end package body signal_driver_pkg;
