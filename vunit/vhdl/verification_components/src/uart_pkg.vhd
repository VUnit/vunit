-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.com_context;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;
use work.sync_pkg.all;
use work.vc_pkg.all;
use work.integer_vector_ptr_pkg.all;
use work.queue_pkg.all;
use work.logger_pkg.all;
use work.checker_pkg.all;
use work.check_pkg.all;

package uart_pkg is
  type uart_master_t is record
    p_std_cfg : std_cfg_t;
    p_baud_rate  : natural;
    p_idle_state : std_logic;
  end record;

  type uart_slave_t is record
    p_std_cfg  : std_cfg_t;
    p_baud_rate   : natural;
    p_idle_state  : std_logic;
    p_data_length : positive;
  end record;

  -- Set the baud rate [bits/s]
  procedure set_baud_rate(signal net : inout network_t;
                          uart_master : uart_master_t;
                          baud_rate : natural);

  procedure set_baud_rate(signal net : inout network_t;
                          uart_slave : uart_slave_t;
                          baud_rate : natural);
  constant uart_logger  : logger_t  := get_logger("vunit_lib:uart_pkg");
  constant uart_checker : checker_t := new_checker(uart_logger);

  constant default_baud_rate : natural := 115200;
  constant default_idle_state : std_logic := '1';
  constant default_data_length : positive := 8;
  impure function new_uart_master(initial_baud_rate          : natural                      := default_baud_rate;
                                  idle_state                 : std_logic                    := default_idle_state;
                                  logger                     : logger_t                     := uart_logger;
                                  actor                      : actor_t                      := null_actor;
                                  checker                    : checker_t                    := null_checker;
                                  unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
                                 ) return uart_master_t;
  impure function new_uart_slave(initial_baud_rate          : natural                      := default_baud_rate;
                                 idle_state                 : std_logic                    := default_idle_state;
                                 data_length                : positive                     := default_data_length;
                                 logger                     : logger_t                     := uart_logger;
                                 actor                      : actor_t                      := null_actor;
                                 checker                    : checker_t                    := null_checker;
                                 unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail) return uart_slave_t;

  impure function as_stream(uart_master : uart_master_t) return stream_master_t;
  impure function as_stream(uart_slave : uart_slave_t) return stream_slave_t;
  impure function as_sync(uart_master : uart_master_t) return sync_handle_t;
  impure function as_sync(uart_slave : uart_slave_t) return sync_handle_t;
  function get_std_cfg(uart_master : uart_master_t) return std_cfg_t;
  function get_std_cfg(uart_slave : uart_slave_t) return std_cfg_t;

  constant uart_set_baud_rate_msg : msg_type_t := new_msg_type("uart set baud rate");
end package;

package body uart_pkg is

  impure function new_uart_master(initial_baud_rate          : natural                      := default_baud_rate;
                                  idle_state                 : std_logic                    := default_idle_state;
                                  logger                     : logger_t                     := uart_logger;
                                  actor                      : actor_t                      := null_actor;
                                  checker                    : checker_t                    := null_checker;
                                  unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
                                 ) return uart_master_t is
    constant p_std_cfg : std_cfg_t := create_std_cfg(
      uart_logger, uart_checker, actor, logger, checker, unexpected_msg_type_policy
    );

  begin
    return (p_std_cfg => p_std_cfg,
            p_baud_rate  => initial_baud_rate,
            p_idle_state => idle_state);
  end;

  impure function new_uart_slave(initial_baud_rate          : natural                      := default_baud_rate;
                                 idle_state                 : std_logic                    := default_idle_state;
                                 data_length                : positive                     := default_data_length;
                                 logger                     : logger_t                     := uart_logger;
                                 actor                      : actor_t                      := null_actor;
                                 checker                    : checker_t                    := null_checker;
                                 unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail) return uart_slave_t is
    constant p_std_cfg : std_cfg_t := create_std_cfg(
      uart_logger, uart_checker, actor, logger, checker, unexpected_msg_type_policy
    );
  begin
    return (p_std_cfg  => p_std_cfg,
            p_baud_rate   => initial_baud_rate,
            p_idle_state  => idle_state,
            p_data_length => data_length);
  end;

  impure function as_stream(uart_master : uart_master_t) return stream_master_t is
  begin
    return stream_master_t'(p_std_cfg => uart_master.p_std_cfg);
  end;

  impure function as_stream(uart_slave : uart_slave_t) return stream_slave_t is
  begin
    return (p_std_cfg => uart_slave.p_std_cfg);
  end;

  impure function as_sync(uart_master : uart_master_t) return sync_handle_t is
  begin
    return get_actor(uart_master.p_std_cfg);
  end;

  impure function as_sync(uart_slave : uart_slave_t) return sync_handle_t is
  begin
    return get_actor(uart_slave.p_std_cfg);
  end;

  function get_std_cfg(uart_master : uart_master_t) return std_cfg_t is
  begin
    return uart_master.p_std_cfg;
  end;

  function get_std_cfg(uart_slave : uart_slave_t) return std_cfg_t is
  begin
    return uart_slave.p_std_cfg;
  end;

  procedure set_baud_rate(signal net : inout network_t;
                          actor : actor_t;
                          baud_rate : natural) is
    variable msg : msg_t := new_msg(uart_set_baud_rate_msg);
  begin
    push(msg, baud_rate);
    send(net, actor, msg);
  end;

  procedure set_baud_rate(signal net : inout network_t;
                          uart_master : uart_master_t;
                          baud_rate : natural) is
  begin
    set_baud_rate(net, get_actor(uart_master.p_std_cfg), baud_rate);
  end;

  procedure set_baud_rate(signal net : inout network_t;
                          uart_slave : uart_slave_t;
                          baud_rate : natural) is
  begin
    set_baud_rate(net, get_actor(uart_slave.p_std_cfg), baud_rate);
  end;
end package body;
