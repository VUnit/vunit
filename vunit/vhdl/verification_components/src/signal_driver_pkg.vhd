-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2020, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
context work.data_types_context;
use work.vc_pkg.all;
use work.sync_pkg.all;
use work.stream_master_pkg.all;

package signal_driver_pkg is

  constant signal_driver_logger  : logger_t  := get_logger("vunit_lib:signal_driver_pkg");
  constant signal_driver_checker : checker_t := new_checker(signal_driver_logger);

  type signal_driver_t is record
    p_std_cfg : std_cfg_t;
    p_initial : std_logic_vector;
  end record;

  impure function new_signal_driver(
    initial                    : std_logic_vector;
    logger                     : logger_t                     := null_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail)
    return signal_driver_t;

  function get_std_cfg(signal_driver : signal_driver_t) return std_cfg_t;

  impure function as_sync(signal_driver : signal_driver_t) return sync_handle_t;

  impure function as_stream(driver : signal_driver_t) return stream_master_t;

  procedure drive(signal net    : inout network_t;
                  signal_driver :       signal_driver_t;
                  value         :       std_logic_vector
                  );

  constant drive_msg : msg_type_t := new_msg_type("drive");

end package signal_driver_pkg;

package body signal_driver_pkg is
  impure function new_signal_driver(
    initial                    : std_logic_vector;
    logger                     : logger_t                     := null_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
    ) return signal_driver_t is
    constant p_std_cfg : std_cfg_t := create_std_cfg(
      signal_driver_logger, signal_driver_checker, actor, logger, checker, unexpected_msg_type_policy
      );
  begin
    return (
      p_std_cfg => p_std_cfg,
      p_initial => initial);
  end;

  function get_std_cfg(signal_driver : signal_driver_t) return std_cfg_t is
  begin
    return signal_driver.p_std_cfg;
  end function;

  impure function as_sync(signal_driver : signal_driver_t) return sync_handle_t is
  begin
    return get_actor(signal_driver.p_std_cfg);
  end function;

  impure function as_stream(driver : signal_driver_t) return stream_master_t is
  begin
    return (p_std_cfg => get_std_cfg(driver));
  end function;

  procedure drive(signal net    : inout network_t;
                  signal_driver :       signal_driver_t;
                  value         :       std_logic_vector
                  ) is
    variable msg : msg_t := new_msg(drive_msg);
  begin
    push_std_ulogic_vector(msg, value);
    send(net, get_actor(signal_driver.p_std_cfg), msg);
  end;

end package body signal_driver_pkg;
