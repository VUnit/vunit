-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.logger_pkg.all;
use work.checker_pkg.all;
use work.check_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;
use work.sync_pkg.all;
context work.com_context;
context work.data_types_context;

package axi_stream_pkg is

  type axi_stream_component_type_t is (null_component, default_component, custom_component);

  type axi_stream_protocol_checker_t is record
    p_type        : axi_stream_component_type_t;
    p_actor       : actor_t;
    p_data_length : natural;
    p_logger      : logger_t;
    p_max_waits   : natural;
  end record;

  constant null_axi_stream_protocol_checker : axi_stream_protocol_checker_t := (
    p_type        => null_component,
    p_actor       => null_actor,
    p_data_length => 0,
    p_logger      => null_logger,
    p_max_waits   => 0
  );

  -- The default protocol checker is used to specify that the checker
  -- configuration is defined by the parent component into which the checker is
  -- instantiated.
  constant default_axi_stream_protocol_checker : axi_stream_protocol_checker_t := (
    p_type        => default_component,
    p_actor       => null_actor,
    p_data_length => 0,
    p_logger      => null_logger,
    p_max_waits   => 0
  );

  type axi_stream_monitor_t is record
    p_type             : axi_stream_component_type_t;
    p_actor            : actor_t;
    p_data_length      : natural;
    p_logger           : logger_t;
    p_protocol_checker : axi_stream_protocol_checker_t;
  end record;

  constant null_axi_stream_monitor : axi_stream_monitor_t := (
    p_type             => null_component,
    p_actor            => null_actor,
    p_data_length      => 0,
    p_logger           => null_logger,
    p_protocol_checker => null_axi_stream_protocol_checker
  );

  -- The default monitor is used to specify that the monitor
  -- configuration is defined by the parent component into which the monitor is
  -- instantiated.
  constant default_axi_stream_monitor : axi_stream_monitor_t := (
    p_type             => default_component,
    p_actor            => null_actor,
    p_data_length      => 0,
    p_logger           => null_logger,
    p_protocol_checker => null_axi_stream_protocol_checker
  );

  type axi_stream_master_t is record
    p_actor            : actor_t;
    p_data_length      : natural;
    p_logger           : logger_t;
    p_monitor          : axi_stream_monitor_t;
    p_protocol_checker : axi_stream_protocol_checker_t;
  end record;

  type axi_stream_slave_t is record
    p_actor            : actor_t;
    p_data_length      : natural;
    p_logger           : logger_t;
    p_monitor          : axi_stream_monitor_t;
    p_protocol_checker : axi_stream_protocol_checker_t;
  end record;

  constant axi_stream_logger  : logger_t  := get_logger("vunit_lib:axi_stream_pkg");
  constant axi_stream_checker : checker_t := new_checker(axi_stream_logger);

  impure function new_axi_stream_master(
    data_length      : natural;
    logger           : logger_t                      := axi_stream_logger;
    actor            : actor_t                       := null_actor;
    monitor          : axi_stream_monitor_t          := null_axi_stream_monitor;
    protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
  ) return axi_stream_master_t;

  impure function new_axi_stream_slave(
    data_length      : natural;
    logger           : logger_t                      := axi_stream_logger;
    actor            : actor_t                       := null_actor;
    monitor          : axi_stream_monitor_t          := null_axi_stream_monitor;
    protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
  ) return axi_stream_slave_t;

  impure function new_axi_stream_monitor(
    data_length      : natural;
    logger           : logger_t                      := axi_stream_logger;
    actor            : actor_t;
    protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
  ) return axi_stream_monitor_t;

  impure function new_axi_stream_protocol_checker(data_length : natural;
                                                  logger      : logger_t := axi_stream_logger;
                                                  actor       : actor_t  := null_actor;
                                                  max_waits   : natural  := 16) return axi_stream_protocol_checker_t;
  impure function data_length(master : axi_stream_master_t) return natural;
  impure function data_length(slave : axi_stream_slave_t) return natural;
  impure function data_length(monitor : axi_stream_monitor_t) return natural;
  impure function data_length(protocol_checker : axi_stream_protocol_checker_t) return natural;
  impure function as_stream(master : axi_stream_master_t) return stream_master_t;
  impure function as_stream(slave : axi_stream_slave_t) return stream_slave_t;
  impure function as_sync(master : axi_stream_master_t) return sync_handle_t;
  impure function as_sync(slave : axi_stream_slave_t) return sync_handle_t;

  constant push_axi_stream_msg        : msg_type_t := new_msg_type("push axi stream");
  constant axi_stream_transaction_msg : msg_type_t := new_msg_type("axi stream transaction");

  procedure push_axi_stream(signal net : inout network_t;
                            axi_stream : axi_stream_master_t;
                            tdata      : std_logic_vector;
                            tlast      : std_logic := '1');

  type axi_stream_transaction_t is record
    tdata : std_logic_vector;
    tlast : boolean;
  end record;

  procedure push_axi_stream_transaction(msg : msg_t; axi_stream_transaction : axi_stream_transaction_t);
  procedure pop_axi_stream_transaction(
    constant msg                    : in msg_t;
    variable axi_stream_transaction : out axi_stream_transaction_t
  );

  impure function new_axi_stream_transaction_msg(
    axi_stream_transaction : axi_stream_transaction_t
  ) return msg_t;

  procedure handle_axi_stream_transaction(
    variable msg_type        : inout msg_type_t;
    variable msg             : inout msg_t;
    variable axi_transaction : out axi_stream_transaction_t);

end package;

package body axi_stream_pkg is

  impure function get_valid_monitor(
    data_length      : natural;
    logger           : logger_t;
    actor            : actor_t;
    monitor          : axi_stream_monitor_t;
    parent_component : string
  ) return axi_stream_monitor_t is
  begin
    if monitor = null_axi_stream_monitor then
      return monitor;
    elsif monitor = default_axi_stream_monitor then
      check(actor /= null_actor, "A valid actor is needed to create a default monitor");
      return new_axi_stream_monitor(data_length, logger, actor);
    else
      check_equal(axi_stream_checker, monitor.p_data_length, data_length,
                  "Data length of monitor doesn't match that of the " & parent_component
                 );
      return monitor;
    end if;
  end;

  impure function get_valid_protocol_checker(
    data_length      : natural;
    logger           : logger_t;
    actor            : actor_t;
    protocol_checker : axi_stream_protocol_checker_t;
    parent_component : string
  ) return axi_stream_protocol_checker_t is
  begin
    if protocol_checker = null_axi_stream_protocol_checker then
      return protocol_checker;
    elsif protocol_checker = default_axi_stream_protocol_checker then
      return new_axi_stream_protocol_checker(data_length, logger, actor);
    else
      check_equal(axi_stream_checker, protocol_checker.p_data_length, data_length,
                  "Data length of protocol checker doesn't match that of the " & parent_component
                 );
      return protocol_checker;
    end if;
  end;

  impure function new_axi_stream_master(
    data_length      : natural;
    logger           : logger_t := axi_stream_logger;
    actor            : actor_t := null_actor;
    monitor          : axi_stream_monitor_t := null_axi_stream_monitor;
    protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
  ) return axi_stream_master_t is
    variable p_actor            : actor_t;
    variable p_monitor          : axi_stream_monitor_t;
    variable p_protocol_checker : axi_stream_protocol_checker_t;
  begin
    p_monitor          := get_valid_monitor(data_length, logger, actor, monitor, "master");
    p_actor            := actor when actor /= null_actor else new_actor;
    p_protocol_checker := get_valid_protocol_checker(data_length, logger, actor, protocol_checker, "master");

    return (p_actor            => p_actor,
            p_data_length      => data_length,
            p_logger           => logger,
            p_monitor          => p_monitor,
            p_protocol_checker => p_protocol_checker);
  end;

  impure function new_axi_stream_slave(
    data_length      : natural;
    logger           : logger_t := axi_stream_logger;
    actor            : actor_t := null_actor;
    monitor          : axi_stream_monitor_t := null_axi_stream_monitor;
    protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
  ) return axi_stream_slave_t is
    variable p_actor            : actor_t;
    variable p_monitor          : axi_stream_monitor_t;
    variable p_protocol_checker : axi_stream_protocol_checker_t;
  begin
    p_monitor          := get_valid_monitor(data_length, logger, actor, monitor, "slave");
    p_actor            := actor when actor /= null_actor else new_actor;
    p_protocol_checker := get_valid_protocol_checker(data_length, logger, actor, protocol_checker, "slave");

    return (p_actor            => p_actor,
            p_data_length      => data_length,
            p_logger           => logger,
            p_monitor          => p_monitor,
            p_protocol_checker => p_protocol_checker);
  end;

  impure function new_axi_stream_monitor(
    data_length      : natural;
    logger           : logger_t := axi_stream_logger;
    actor            : actor_t;
    protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
  ) return axi_stream_monitor_t is
    constant p_protocol_checker : axi_stream_protocol_checker_t := get_valid_protocol_checker(
      data_length, logger, actor, protocol_checker, "monitor"
    );
  begin
    return (
      p_type             => custom_component,
      p_actor            => actor,
      p_data_length      => data_length,
      p_logger           => logger,
      p_protocol_checker => p_protocol_checker);
  end;

  impure function new_axi_stream_protocol_checker(data_length : natural;
                                                  logger      : logger_t := axi_stream_logger;
                                                  actor       : actor_t := null_actor;
                                                  max_waits   : natural := 16) return axi_stream_protocol_checker_t is
  begin
    return (
      p_type        => custom_component,
      p_actor       => actor,
      p_data_length => data_length,
      p_logger      => logger,
      p_max_waits   => max_waits);
  end;

  impure function data_length(master : axi_stream_master_t) return natural is
  begin
    return master.p_data_length;
  end;

  impure function data_length(slave : axi_stream_slave_t) return natural is
  begin
    return slave.p_data_length;
  end;

  impure function data_length(monitor : axi_stream_monitor_t) return natural is
  begin
    return monitor.p_data_length;
  end;

  impure function data_length(protocol_checker : axi_stream_protocol_checker_t) return natural is
  begin
    return protocol_checker.p_data_length;
  end;

  impure function as_stream(master : axi_stream_master_t) return stream_master_t is
  begin
    return (p_actor => master.p_actor);
  end;

  impure function as_stream(slave : axi_stream_slave_t) return stream_slave_t is
  begin
    return (p_actor => slave.p_actor);
  end;

  impure function as_sync(master : axi_stream_master_t) return sync_handle_t is
  begin
    return master.p_actor;
  end;

  impure function as_sync(slave : axi_stream_slave_t) return sync_handle_t is
  begin
    return slave.p_actor;
  end;

  procedure push_axi_stream(signal net : inout network_t;
                            axi_stream : axi_stream_master_t;
                            tdata      : std_logic_vector;
                            tlast      : std_logic := '1') is
    variable msg             : msg_t                                       := new_msg(push_axi_stream_msg);
    constant normalized_data : std_logic_vector(tdata'length - 1 downto 0) := tdata;
  begin
    push_std_ulogic_vector(msg, normalized_data);
    push_std_ulogic(msg, tlast);
    send(net, axi_stream.p_actor, msg);
  end;

  procedure push_axi_stream_transaction(msg : msg_t; axi_stream_transaction : axi_stream_transaction_t) is
  begin
    push_std_ulogic_vector(msg, axi_stream_transaction.tdata);
    push_boolean(msg, axi_stream_transaction.tlast);
  end;

  procedure pop_axi_stream_transaction(
    constant msg                    : in msg_t;
    variable axi_stream_transaction : out axi_stream_transaction_t
  ) is
  begin
    axi_stream_transaction.tdata := pop_std_ulogic_vector(msg);
    axi_stream_transaction.tlast := pop_boolean(msg);
  end;

  impure function new_axi_stream_transaction_msg(
    axi_stream_transaction : axi_stream_transaction_t
  ) return msg_t is
    variable msg : msg_t;
  begin
    msg := new_msg(axi_stream_transaction_msg);
    push_axi_stream_transaction(msg, axi_stream_transaction);

    return msg;
  end;

  procedure handle_axi_stream_transaction(
    variable msg_type        : inout msg_type_t;
    variable msg             : inout msg_t;
    variable axi_transaction : out axi_stream_transaction_t) is
  begin
    if msg_type = axi_stream_transaction_msg then
      handle_message(msg_type);

      pop_axi_stream_transaction(msg, axi_transaction);
    end if;
  end;

end package body;
