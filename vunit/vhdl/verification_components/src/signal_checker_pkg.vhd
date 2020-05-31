-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;

use work.sync_pkg.all;
use work.vc_pkg.all;

package signal_checker_pkg is
  type signal_checker_t is record
    -- Private
    p_std_cfg : std_cfg_t;
  end record;

  constant signal_checker_logger : logger_t := get_logger("vunit_lib:signal_checker_pkg");
  constant signal_checker_checker : checker_t := new_checker(signal_checker_logger);

  impure function new_signal_checker(
    logger                     : logger_t                     := signal_checker_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail)
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

  impure function as_sync(signal_checker : signal_checker_t) return sync_handle_t;
  function get_std_cfg(signal_checker : signal_checker_t) return std_cfg_t;

  -- Private message type definitions
  constant expect_msg : msg_type_t := new_msg_type("expect");

end package;


package body signal_checker_pkg is
  impure function new_signal_checker(
    logger                     : logger_t                     := signal_checker_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail)
  return signal_checker_t is
    constant p_std_cfg : std_cfg_t := create_std_cfg(
      signal_checker_logger, signal_checker_checker, actor, logger, checker, unexpected_msg_type_policy
    );

  begin
    return (p_std_cfg => p_std_cfg);
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
    send(net, get_actor(signal_checker.p_std_cfg), request_msg);
  end;

  procedure wait_until_idle(signal net : inout network_t;
                            signal_checker : signal_checker_t) is
  begin
    wait_until_idle(net, get_actor(signal_checker.p_std_cfg));
  end;

  impure function as_sync(signal_checker : signal_checker_t) return sync_handle_t is
  begin
    return get_actor(signal_checker.p_std_cfg);
  end;

  function get_std_cfg(signal_checker : signal_checker_t) return std_cfg_t is
  begin
    return signal_checker.p_std_cfg;
  end;



end package body;
