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

package signal_checker_pkg is
  type signal_checker_t is record
    -- Private
    p_actor : actor_t;
    p_logger : logger_t;
    p_checker : checker_t;
    initial_monitor_enable : boolean;
  end record;

  impure function new_signal_checker(
    logger : logger_t := null_logger;
    checker: checker_t := null_checker;
    initial_monitor_enable : boolean := true)
    return signal_checker_t;

  -- Add one value to the expect queue
  -- Allow event to occur within event_time += margin including end points
  procedure expect(signal net : inout network_t;
                   signal_checker : signal_checker_t;
                   value : std_logic_vector;
                   event_time : delay_length;
                   margin : delay_length := 0 ns);

  -- Get the current value
  procedure get_value(signal net     : inout network_t;
                      signal_checker :       signal_checker_t;
                      variable value : out   std_logic_vector);

  -- Enable the monitor, i.e. each signal change must be expected
  procedure enable_monitor(signal net : inout network_t; signal_checker : signal_checker_t);
  -- Disable the monitor, i.e. all signal changes are accepted, checks only done if there is an expected
  procedure disable_monitor(signal net : inout network_t; signal_checker : signal_checker_t);

  -- Wait until all expected values have been checked
  procedure wait_until_idle(signal net : inout network_t;
                            signal_checker : signal_checker_t);

  -- Private message type definitions
  constant expect_msg : msg_type_t := new_msg_type("expect");
  constant get_value_msg       : msg_type_t := new_msg_type("get value");
  constant get_value_reply_msg : msg_type_t := new_msg_type("get value reply");
  constant monitor_change_msg : msg_type_t := new_msg_type("monitor change");

end package;


package body signal_checker_pkg is
  impure function new_signal_checker(logger : logger_t := null_logger;
                                     checker : checker_t := null_checker;
                                     initial_monitor_enable : boolean := true) return signal_checker_t is
    variable result : signal_checker_t;
  begin
    result := (p_actor => new_actor,
               p_logger => logger,
               p_checker => checker,
               initial_monitor_enable => initial_monitor_enable);
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

  procedure get_value(signal net     : inout network_t;
                      signal_checker :       signal_checker_t;
                      variable value : out   std_logic_vector) is
    variable get_msg : msg_t := new_msg(get_value_msg);
    variable reply   : msg_t;
  begin
    request(net, signal_checker.p_actor, get_msg, reply);
    value := pop_std_ulogic_vector(reply);
    delete(reply);
  end;

  procedure wait_until_idle(signal net : inout network_t;
                            signal_checker : signal_checker_t) is
  begin
    wait_until_idle(net, signal_checker.p_actor);
  end;

  procedure enable_monitor(signal net : inout network_t; signal_checker : signal_checker_t) is
    variable msg : msg_t := new_msg(monitor_change_msg);
  begin
    push(msg, true);
    send(net, signal_checker.p_actor, msg);
  end procedure;

  procedure disable_monitor(signal net : inout network_t; signal_checker : signal_checker_t) is
    variable msg : msg_t := new_msg(monitor_change_msg);
  begin
    push(msg, false);
    send(net, signal_checker.p_actor, msg);
  end procedure;

end package body;
