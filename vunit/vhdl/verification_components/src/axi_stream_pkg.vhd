-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.logger_pkg.all;
use work.checker_pkg.all;
use work.check_pkg.all;
use work.stream_master_pkg.stream_master_t;
use work.stream_slave_pkg.stream_slave_t;
use work.sync_pkg.all;
use work.com_pkg.all;
use work.com_types_pkg.all;

package axi_stream_pkg is

  type stall_config_t is record
    stall_probability : real range 0.0 to 1.0;
    min_stall_cycles  : natural;
    max_stall_cycles  : natural;
  end record;

  constant null_stall_config : stall_config_t := (
    stall_probability => 0.0,
    min_stall_cycles  => 0,
    max_stall_cycles  => 0
    );

  type axi_stream_component_type_t is (null_component, default_component, custom_component);

  type axi_stream_protocol_checker_t is record
    p_type                      : axi_stream_component_type_t;
    p_actor                     : actor_t;
    p_data_length               : natural;
    p_id_length                 : natural;
    p_dest_length               : natural;
    p_user_length               : natural;
    p_logger                    : logger_t;
    p_max_waits                 : natural;
    p_allow_x_in_non_data_bytes : boolean;
  end record;

  constant null_axi_stream_protocol_checker : axi_stream_protocol_checker_t := (
    p_type                      => null_component,
    p_actor                     => null_actor,
    p_data_length               => 0,
    p_id_length                 => 0,
    p_dest_length               => 0,
    p_user_length               => 0,
    p_logger                    => null_logger,
    p_max_waits                 => 0,
    p_allow_x_in_non_data_bytes => false
  );

  -- The default protocol checker is used to specify that the checker
  -- configuration is defined by the parent component into which the checker is
  -- instantiated.
  constant default_axi_stream_protocol_checker : axi_stream_protocol_checker_t := (
    p_type                      => default_component,
    p_actor                     => null_actor,
    p_data_length               => 0,
    p_id_length                 => 0,
    p_dest_length               => 0,
    p_user_length               => 0,
    p_logger                    => null_logger,
    p_max_waits                 => 0,
    p_allow_x_in_non_data_bytes => false
  );

  type axi_stream_monitor_t is record
    p_type             : axi_stream_component_type_t;
    p_actor            : actor_t;
    p_data_length      : natural;
    p_id_length        : natural;
    p_dest_length      : natural;
    p_user_length      : natural;
    p_logger           : logger_t;
    p_protocol_checker : axi_stream_protocol_checker_t;
  end record;

  constant null_axi_stream_monitor : axi_stream_monitor_t := (
    p_type             => null_component,
    p_actor            => null_actor,
    p_data_length      => 0,
    p_id_length        => 0,
    p_dest_length      => 0,
    p_user_length      => 0,
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
    p_id_length        => 0,
    p_dest_length      => 0,
    p_user_length      => 0,
    p_logger           => null_logger,
    p_protocol_checker => null_axi_stream_protocol_checker
  );

  type axi_stream_master_t is record
    p_actor            : actor_t;
    p_data_length      : natural;
    p_id_length        : natural;
    p_dest_length      : natural;
    p_user_length      : natural;
    p_stall_config     : stall_config_t;
    p_logger           : logger_t;
    p_monitor          : axi_stream_monitor_t;
    p_protocol_checker : axi_stream_protocol_checker_t;
  end record;

  constant null_axi_stream_master : axi_stream_master_t := (
    p_actor            => null_actor,
    p_data_length      => 0,
    p_id_length        => 0,
    p_dest_length      => 0,
    p_user_length      => 0,
    p_stall_config     => null_stall_config,
    p_logger           => null_logger,
    p_monitor          => null_axi_stream_monitor,
    p_protocol_checker => null_axi_stream_protocol_checker
    );

  type axi_stream_slave_t is record
    p_actor            : actor_t;
    p_data_length      : natural;
    p_id_length        : natural;
    p_dest_length      : natural;
    p_user_length      : natural;
    p_stall_config     : stall_config_t;
    p_logger           : logger_t;
    p_monitor          : axi_stream_monitor_t;
    p_protocol_checker : axi_stream_protocol_checker_t;
  end record;

  constant null_axi_stream_slave : axi_stream_slave_t := (
    p_actor            => null_actor,
    p_data_length      => 0,
    p_id_length        => 0,
    p_dest_length      => 0,
    p_user_length      => 0,
    p_stall_config     => null_stall_config,
    p_logger           => null_logger,
    p_monitor          => null_axi_stream_monitor,
    p_protocol_checker => null_axi_stream_protocol_checker
    );

  constant axi_stream_logger  : logger_t  := get_logger("vunit_lib:axi_stream_pkg");
  constant axi_stream_checker : checker_t := new_checker(axi_stream_logger);

  impure function new_axi_stream_master(
    data_length      : natural;
    id_length        : natural                       := 0;
    dest_length      : natural                       := 0;
    user_length      : natural                       := 0;
    stall_config     : stall_config_t                := null_stall_config;
    logger           : logger_t                      := axi_stream_logger;
    actor            : actor_t                       := null_actor;
    monitor          : axi_stream_monitor_t          := null_axi_stream_monitor;
    protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
  ) return axi_stream_master_t;

  impure function new_axi_stream_slave(
    data_length      : natural;
    id_length        : natural                       := 0;
    dest_length      : natural                       := 0;
    user_length      : natural                       := 0;
    stall_config     : stall_config_t                := null_stall_config;
    logger           : logger_t                      := axi_stream_logger;
    actor            : actor_t                       := null_actor;
    monitor          : axi_stream_monitor_t          := null_axi_stream_monitor;
    protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
  ) return axi_stream_slave_t;

  impure function new_axi_stream_monitor(
    data_length      : natural;
    id_length        : natural  := 0;
    dest_length      : natural  := 0;
    user_length      : natural  := 0;
    logger           : logger_t := axi_stream_logger;
    actor            : actor_t;
    protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
  ) return axi_stream_monitor_t;

  impure function new_axi_stream_protocol_checker(
    data_length               : natural;
    id_length                 : natural  := 0;
    dest_length               : natural  := 0;
    user_length               : natural  := 0;
    logger                    : logger_t := axi_stream_logger;
    actor                     : actor_t  := null_actor;
    max_waits                 : natural  := 16;
    allow_x_in_non_data_bytes : boolean  := false
  ) return axi_stream_protocol_checker_t;

  impure function data_length(master : axi_stream_master_t) return natural;
  impure function data_length(slave : axi_stream_slave_t) return natural;
  impure function data_length(monitor : axi_stream_monitor_t) return natural;
  impure function data_length(protocol_checker : axi_stream_protocol_checker_t) return natural;
  impure function id_length(master : axi_stream_master_t) return natural;
  impure function id_length(slave : axi_stream_slave_t) return natural;
  impure function id_length(monitor : axi_stream_monitor_t) return natural;
  impure function id_length(protocol_checker : axi_stream_protocol_checker_t) return natural;
  impure function dest_length(master : axi_stream_master_t) return natural;
  impure function dest_length(slave : axi_stream_slave_t) return natural;
  impure function dest_length(monitor : axi_stream_monitor_t) return natural;
  impure function dest_length(protocol_checker : axi_stream_protocol_checker_t) return natural;
  impure function user_length(master : axi_stream_master_t) return natural;
  impure function user_length(slave : axi_stream_slave_t) return natural;
  impure function user_length(monitor : axi_stream_monitor_t) return natural;
  impure function user_length(protocol_checker : axi_stream_protocol_checker_t) return natural;
  impure function as_stream(master : axi_stream_master_t) return stream_master_t;
  impure function as_stream(slave : axi_stream_slave_t) return stream_slave_t;
  impure function as_sync(master : axi_stream_master_t) return sync_handle_t;
  impure function as_sync(slave : axi_stream_slave_t) return sync_handle_t;

  constant push_axi_stream_msg : msg_type_t := new_msg_type("push axi stream");
  constant pop_axi_stream_msg : msg_type_t := new_msg_type("pop axi stream");
  constant check_axi_stream_msg : msg_type_t := new_msg_type("check axi stream");
  constant axi_stream_transaction_msg : msg_type_t := new_msg_type("axi stream transaction");

  alias axi_stream_reference_t is msg_t;

  procedure push_axi_stream(
      signal net : inout network_t;
      axi_stream : axi_stream_master_t;
      tdata      : std_logic_vector;
      tlast      : std_logic        := '1';
      tkeep      : std_logic_vector := "";
      tstrb      : std_logic_vector := "";
      tid        : std_logic_vector := "";
      tdest      : std_logic_vector := "";
      tuser      : std_logic_vector := ""
    );

  -- Blocking: pop a value from the axi stream
  procedure pop_axi_stream(
      signal net : inout network_t;
      axi_stream : axi_stream_slave_t;
      variable tdata : out std_logic_vector;
      variable tlast : out std_logic;
      variable tkeep : out std_logic_vector;
      variable tstrb : out std_logic_vector;
      variable tid   : out std_logic_vector;
      variable tdest : out std_logic_vector;
      variable tuser : out std_logic_vector
    );

  procedure pop_axi_stream(
      signal net : inout network_t;
      axi_stream : axi_stream_slave_t;
      variable tdata : out std_logic_vector;
      variable tlast : out std_logic
    );

  -- Non-blocking: pop a value from the axi stream to be read in the future
  procedure pop_axi_stream(signal net : inout network_t;
                           axi_stream : axi_stream_slave_t;
                           variable reference : inout axi_stream_reference_t);

  -- Blocking: Wait for reply to non-blocking pop
  procedure await_pop_axi_stream_reply(
      signal net : inout network_t;
      variable reference : inout axi_stream_reference_t;
      variable tdata     : out std_logic_vector;
      variable tlast     : out std_logic;
      variable tkeep     : out std_logic_vector;
      variable tstrb     : out std_logic_vector;
      variable tid       : out std_logic_vector;
      variable tdest     : out std_logic_vector;
      variable tuser     : out std_logic_vector
    );

  procedure await_pop_axi_stream_reply(
      signal net : inout network_t;
      variable reference : inout axi_stream_reference_t;
      variable tdata     : out std_logic_vector;
      variable tlast     : out std_logic
    );

  -- Blocking: read axi stream and check result against expected value
  procedure check_axi_stream(
      signal net : inout network_t;
      axi_stream   : axi_stream_slave_t;
      expected : std_logic_vector;
      tlast    : std_logic        := '1';
      tkeep    : std_logic_vector := "";
      tstrb    : std_logic_vector := "";
      tid      : std_logic_vector := "";
      tdest    : std_logic_vector := "";
      tuser    : std_logic_vector := "";
      msg      : string           := "";
      blocking : boolean          := true
    );

  type axi_stream_transaction_t is record
    tdata : std_logic_vector;
    tlast : boolean;
    tkeep : std_logic_vector;
    tstrb : std_logic_vector;
    tid   : std_logic_vector;
    tdest : std_logic_vector;
    tuser : std_logic_vector;
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

  function new_stall_config(
    stall_probability : real range 0.0 to 1.0;
    min_stall_cycles  : natural;
    max_stall_cycles  : natural
  ) return stall_config_t;

  function is_u(value : std_ulogic_vector) return boolean;

end package;

package body axi_stream_pkg is

  impure function get_valid_monitor(
      data_length      : natural;
      id_length        : natural  := 0;
      dest_length      : natural  := 0;
      user_length      : natural  := 0;
      logger           : logger_t := axi_stream_logger;
      actor            : actor_t;
      monitor          : axi_stream_monitor_t;
      parent_component : string
    ) return axi_stream_monitor_t is
  begin
    if monitor = null_axi_stream_monitor then
      return monitor;
    elsif monitor = default_axi_stream_monitor then
      check(actor /= null_actor, "A valid actor is needed to create a default monitor");
      return new_axi_stream_monitor(data_length, id_length, dest_length, user_length, logger, actor);
    else
      check_equal(axi_stream_checker, monitor.p_data_length, data_length, "Data length of monitor doesn't match that of the " & parent_component);
      check_equal(axi_stream_checker, monitor.p_id_length, id_length, "ID length of monitor doesn't match that of the " & parent_component);
      check_equal(axi_stream_checker, monitor.p_dest_length, dest_length, "Dest length of monitor doesn't match that of the " & parent_component);
      check_equal(axi_stream_checker, monitor.p_user_length, user_length, "User length of monitor doesn't match that of the " & parent_component);
      return monitor;
    end if;
  end;

  impure function get_valid_protocol_checker(
    data_length      : natural;
    id_length        : natural  := 0;
    dest_length      : natural  := 0;
    user_length      : natural  := 0;
    logger           : logger_t;
    actor            : actor_t;
    protocol_checker : axi_stream_protocol_checker_t;
    parent_component : string
  ) return axi_stream_protocol_checker_t is
  begin
    if protocol_checker = null_axi_stream_protocol_checker then
      return protocol_checker;
    elsif protocol_checker = default_axi_stream_protocol_checker then
      return new_axi_stream_protocol_checker(data_length, id_length, dest_length, user_length, logger, actor);
    else
      check_equal(axi_stream_checker, protocol_checker.p_data_length, data_length, "Data length of protocol checker doesn't match that of the " & parent_component);
      check_equal(axi_stream_checker, protocol_checker.p_id_length, id_length, "ID length of monitor doesn't match that of the " & parent_component);
      check_equal(axi_stream_checker, protocol_checker.p_dest_length, dest_length, "Dest length of monitor doesn't match that of the " & parent_component);
      check_equal(axi_stream_checker, protocol_checker.p_user_length, user_length, "User length of monitor doesn't match that of the " & parent_component);
      return protocol_checker;
    end if;
  end;

  impure function new_axi_stream_master(
    data_length      : natural;
    id_length        : natural                       := 0;
    dest_length      : natural                       := 0;
    user_length      : natural                       := 0;
    stall_config     : stall_config_t                := null_stall_config;
    logger           : logger_t                      := axi_stream_logger;
    actor            : actor_t                       := null_actor;
    monitor          : axi_stream_monitor_t          := null_axi_stream_monitor;
    protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
  ) return axi_stream_master_t is
    variable p_actor            : actor_t;
    variable p_monitor          : axi_stream_monitor_t;
    variable p_protocol_checker : axi_stream_protocol_checker_t;
  begin
    p_monitor          := get_valid_monitor(data_length, id_length, dest_length, user_length, logger, actor, monitor, "master");
    p_actor            := actor when actor /= null_actor else new_actor;
    p_protocol_checker := get_valid_protocol_checker(data_length, id_length, dest_length, user_length, logger, actor, protocol_checker, "master");

    return (p_actor      => p_actor,
      p_data_length      => data_length,
      p_id_length        => id_length,
      p_dest_length      => dest_length,
      p_user_length      => user_length,
      p_stall_config     => stall_config,
      p_logger           => logger,
      p_monitor          => p_monitor,
      p_protocol_checker => p_protocol_checker);
  end;

  impure function new_axi_stream_slave(
      data_length      : natural;
      id_length        : natural                       := 0;
      dest_length      : natural                       := 0;
      user_length      : natural                       := 0;
      stall_config     : stall_config_t                := null_stall_config;
      logger           : logger_t                      := axi_stream_logger;
      actor            : actor_t                       := null_actor;
      monitor          : axi_stream_monitor_t          := null_axi_stream_monitor;
      protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
    ) return axi_stream_slave_t is
    variable p_actor            : actor_t;
    variable p_monitor          : axi_stream_monitor_t;
    variable p_protocol_checker : axi_stream_protocol_checker_t;
  begin
    p_monitor          := get_valid_monitor(data_length, id_length, dest_length, user_length, logger, actor, monitor, "slave");
    p_actor            := actor when actor /= null_actor else new_actor;
    p_protocol_checker := get_valid_protocol_checker(data_length, id_length, dest_length, user_length, logger, actor, protocol_checker, "slave");

    return (p_actor      => p_actor,
      p_data_length      => data_length,
      p_id_length        => id_length,
      p_dest_length      => dest_length,
      p_user_length      => user_length,
      p_stall_config     => stall_config,
      p_logger           => logger,
      p_monitor          => p_monitor,
      p_protocol_checker => p_protocol_checker);
  end;

  impure function new_axi_stream_monitor(
      data_length      : natural;
      id_length        : natural  := 0;
      dest_length      : natural  := 0;
      user_length      : natural  := 0;
      logger           : logger_t := axi_stream_logger;
      actor            : actor_t;
      protocol_checker : axi_stream_protocol_checker_t := null_axi_stream_protocol_checker
    ) return axi_stream_monitor_t is
    constant p_protocol_checker : axi_stream_protocol_checker_t := get_valid_protocol_checker(
      data_length, id_length, dest_length, user_length, logger, actor, protocol_checker, "monitor"
    );
  begin
    return (
      p_type             => custom_component,
      p_actor            => actor,
      p_data_length      => data_length,
      p_id_length        => id_length,
      p_dest_length      => dest_length,
      p_user_length      => user_length,
      p_logger           => logger,
      p_protocol_checker => p_protocol_checker);
  end;

  impure function new_axi_stream_protocol_checker(
      data_length               : natural;
      id_length                 : natural  := 0;
      dest_length               : natural  := 0;
      user_length               : natural  := 0;
      logger                    : logger_t := axi_stream_logger;
      actor                     : actor_t  := null_actor;
      max_waits                 : natural  := 16;
      allow_x_in_non_data_bytes : boolean  := false
    ) return axi_stream_protocol_checker_t is
  begin
    return (
      p_type                  => custom_component,
      p_actor                 => actor,
      p_data_length           => data_length,
      p_id_length             => id_length,
      p_dest_length           => dest_length,
      p_user_length           => user_length,
      p_logger                => logger,
      p_max_waits             => max_waits,
      p_allow_x_in_non_data_bytes => allow_x_in_non_data_bytes);
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

  impure function id_length(master : axi_stream_master_t) return natural is
  begin
    return master.p_id_length;
  end;

  impure function id_length(slave : axi_stream_slave_t) return natural is
  begin
    return slave.p_id_length;
  end;

  impure function id_length(monitor : axi_stream_monitor_t) return natural is
  begin
    return monitor.p_id_length;
  end;

  impure function id_length(protocol_checker: axi_stream_protocol_checker_t) return natural is
  begin
    return protocol_checker.p_id_length;
  end;

  impure function dest_length(master : axi_stream_master_t) return natural is
  begin
    return master.p_dest_length;
  end;

  impure function dest_length(slave: axi_stream_slave_t) return natural is
  begin
    return slave.p_dest_length;
  end;

  impure function dest_length(monitor : axi_stream_monitor_t) return natural is
  begin
    return monitor.p_dest_length;
  end;

  impure function dest_length(protocol_checker : axi_stream_protocol_checker_t) return natural is
  begin
    return protocol_checker.p_dest_length;
  end;

  impure function user_length(master : axi_stream_master_t) return natural is
  begin
    return master.p_user_length;
  end;

  impure function user_length(slave : axi_stream_slave_t) return natural is
  begin
    return slave.p_user_length;
  end;

  impure function user_length(monitor : axi_stream_monitor_t) return natural is
  begin
    return monitor.p_user_length;
  end;

  impure function user_length(protocol_checker : axi_stream_protocol_checker_t) return natural is
  begin
    return protocol_checker.p_user_length;
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

  procedure push_axi_stream(
      signal net : inout network_t;
      axi_stream : axi_stream_master_t;
      tdata      : std_logic_vector;
      tlast      : std_logic        := '1';
      tkeep      : std_logic_vector := "";
      tstrb      : std_logic_vector := "";
      tid        : std_logic_vector := "";
      tdest      : std_logic_vector := "";
      tuser      : std_logic_vector := ""
    ) is
    variable msg             : msg_t := new_msg(push_axi_stream_msg);
    variable normalized_data : std_logic_vector(data_length(axi_stream)-1 downto 0) := (others => '0');
    variable normalized_keep : std_logic_vector(data_length(axi_stream)/8-1 downto 0) := (others => '1');
    variable normalized_strb : std_logic_vector(data_length(axi_stream)/8-1 downto 0) := (others => '1');
    variable normalized_id   : std_logic_vector(id_length(axi_stream)-1 downto 0) := (others => '0');
    variable normalized_dest : std_logic_vector(dest_length(axi_stream)-1 downto 0) := (others => '0');
    variable normalized_user : std_logic_vector(user_length(axi_stream)-1 downto 0) := (others => '0');
  begin
    normalized_data(tdata'length-1 downto 0) := tdata;
    push_std_ulogic_vector(msg, normalized_data);
    push_std_ulogic(msg, tlast);
    normalized_keep(tkeep'length-1 downto 0) := tkeep;
    push_std_ulogic_vector(msg, normalized_keep);
    normalized_strb := normalized_keep;
    normalized_strb(tstrb'length-1 downto 0) := tstrb;
    push_std_ulogic_vector(msg, normalized_strb);
    normalized_id(tid'length-1 downto 0) := tid;
    push_std_ulogic_vector(msg, normalized_id);
    normalized_dest(tdest'length-1 downto 0) := tdest;
    push_std_ulogic_vector(msg, normalized_dest);
    normalized_user(tuser'length-1 downto 0) := tuser;
    push_std_ulogic_vector(msg, normalized_user);
    send(net, axi_stream.p_actor, msg);
  end;

  procedure pop_axi_stream(signal net : inout network_t;
                           axi_stream : axi_stream_slave_t;
                           variable reference : inout axi_stream_reference_t) is
  begin
    reference := new_msg(pop_axi_stream_msg);
    send(net, axi_stream.p_actor, reference);
  end;

  procedure await_pop_axi_stream_reply(
      signal net : inout network_t;
      variable reference : inout axi_stream_reference_t;
      variable tdata     : out std_logic_vector;
      variable tlast     : out std_logic;
      variable tkeep     : out std_logic_vector;
      variable tstrb     : out std_logic_vector;
      variable tid       : out std_logic_vector;
      variable tdest     : out std_logic_vector;
      variable tuser : out std_logic_vector
    ) is
    variable reply_msg : msg_t;
  begin
    receive_reply(net, reference, reply_msg);
    tdata := pop_std_ulogic_vector(reply_msg);
    if pop_boolean(reply_msg) then
      tlast := '1';
    else
      tlast := '0';
    end if;
    tkeep := pop_std_ulogic_vector(reply_msg);
    tstrb := pop_std_ulogic_vector(reply_msg);
    tid   := pop_std_ulogic_vector(reply_msg);
    tdest := pop_std_ulogic_vector(reply_msg);
    tuser := pop_std_ulogic_vector(reply_msg);
    delete(reference);
    delete(reply_msg);
  end;

  procedure await_pop_axi_stream_reply(
      signal net : inout network_t;
      variable reference : inout axi_stream_reference_t;
      variable tdata     : out std_logic_vector;
      variable tlast     : out std_logic
    ) is
    variable reply_msg : msg_t;
  begin
    receive_reply(net, reference, reply_msg);
    tdata := pop_std_ulogic_vector(reply_msg);
    if pop_boolean(reply_msg) then
      tlast := '1';
    else
      tlast := '0';
    end if;
    delete(reference);
    delete(reply_msg);
  end;

  procedure pop_axi_stream(
      signal net : inout network_t;
      axi_stream : axi_stream_slave_t;
      variable tdata : out std_logic_vector;
      variable tlast : out std_logic;
      variable tkeep : out std_logic_vector;
      variable tstrb : out std_logic_vector;
      variable tid   : out std_logic_vector;
      variable tdest : out std_logic_vector;
      variable tuser : out std_logic_vector
    ) is
    variable reference : axi_stream_reference_t;
  begin
    pop_axi_stream(net, axi_stream, reference);
    await_pop_axi_stream_reply(net, reference, tdata, tlast, tkeep, tstrb, tid, tdest, tuser);
  end;

  procedure pop_axi_stream(
      signal net : inout network_t;
      axi_stream : axi_stream_slave_t;
      variable tdata : out std_logic_vector;
      variable tlast : out std_logic
    ) is
    variable reference : axi_stream_reference_t;
  begin
    pop_axi_stream(net, axi_stream, reference);
    await_pop_axi_stream_reply(net, reference, tdata, tlast);
  end;

  procedure check_axi_stream(
      signal net : inout network_t;
      axi_stream   : axi_stream_slave_t;
      expected : std_logic_vector;
      tlast    : std_logic        := '1';
      tkeep    : std_logic_vector := "";
      tstrb    : std_logic_vector := "";
      tid      : std_logic_vector := "";
      tdest    : std_logic_vector := "";
      tuser    : std_logic_vector := "";
      msg      : string           := "";
      blocking : boolean          := true
    ) is
    constant expected_normalized : std_logic_vector(expected'length - 1 downto 0) := expected;
    variable got_tdata : std_logic_vector(data_length(axi_stream)-1 downto 0);
    variable got_tlast : std_logic;
    variable got_tkeep : std_logic_vector(data_length(axi_stream)/8-1 downto 0);
    variable got_tstrb : std_logic_vector(data_length(axi_stream)/8-1 downto 0);
    variable got_tid   : std_logic_vector(id_length(axi_stream)-1 downto 0);
    variable got_tdest : std_logic_vector(dest_length(axi_stream)-1 downto 0);
    variable got_tuser : std_logic_vector(user_length(axi_stream)-1 downto 0);
    variable check_msg : msg_t := new_msg(check_axi_stream_msg);
    variable mismatch : boolean;
  begin
    if blocking then
      pop_axi_stream(net, axi_stream, got_tdata, got_tlast, got_tkeep, got_tstrb, got_tid, got_tdest, got_tuser);
      mismatch := false;
      for idx in got_tkeep'range loop
        if got_tkeep(idx) and got_tstrb(idx) then
          mismatch := got_tdata(8 * idx + 7 downto 8 * idx) /= expected_normalized(8 * idx + 7 downto 8 * idx);
          exit when mismatch;
        end if;
      end loop;
      if mismatch then
        check_equal(got_tdata, expected, "TDATA mismatch, " & msg);
      end if;

      if tkeep'length > 0 then
        check_equal(got_tkeep, tkeep, "TKEEP mismatch, " & msg);
      end if;
      if tstrb'length > 0 then
        check_equal(got_tstrb, tstrb, "TSTRB mismatch, " & msg);
      end if;
      check_equal(got_tlast, tlast, "TLAST mismatch, " & msg);
      if tid'length > 0 then
        check_equal(got_tid, tid, "TID mismatch, " & msg);
      end if;
      if tdest'length > 0 then
        check_equal(got_tdest, tdest, "TDEST mismatch, " & msg);
      end if;
      if tuser'length > 0 then
        check_equal(got_tuser, tuser, "TUSER mismatch, " & msg);
      end if;
    else
      push_string(check_msg, msg);
      push_std_ulogic_vector(check_msg, expected);
      push_std_ulogic_vector(check_msg, tkeep);
      push_std_ulogic_vector(check_msg, tstrb);
      push_std_ulogic(check_msg, tlast);
      push_std_ulogic_vector(check_msg, tid);
      push_std_ulogic_vector(check_msg, tdest);
      push_std_ulogic_vector(check_msg, tuser);
      send(net, axi_stream.p_actor, check_msg);
    end if;
  end procedure;

  procedure push_axi_stream_transaction(msg : msg_t; axi_stream_transaction : axi_stream_transaction_t) is
  begin
    push_std_ulogic_vector(msg, axi_stream_transaction.tdata);
    push_boolean(msg, axi_stream_transaction.tlast);
    push_std_ulogic_vector(msg, axi_stream_transaction.tkeep);
    push_std_ulogic_vector(msg, axi_stream_transaction.tstrb);
    push_std_ulogic_vector(msg, axi_stream_transaction.tid);
    push_std_ulogic_vector(msg, axi_stream_transaction.tdest);
    push_std_ulogic_vector(msg, axi_stream_transaction.tuser);
  end;

  procedure pop_axi_stream_transaction(
    constant msg                    : in msg_t;
    variable axi_stream_transaction : out axi_stream_transaction_t
  ) is
  begin
    axi_stream_transaction.tdata := pop_std_ulogic_vector(msg);
    axi_stream_transaction.tlast := pop_boolean(msg);
    axi_stream_transaction.tkeep := pop_std_ulogic_vector(msg);
    axi_stream_transaction.tstrb := pop_std_ulogic_vector(msg);
    axi_stream_transaction.tid   := pop_std_ulogic_vector(msg);
    axi_stream_transaction.tdest := pop_std_ulogic_vector(msg);
    axi_stream_transaction.tuser := pop_std_ulogic_vector(msg);
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

  function new_stall_config(
    stall_probability : real range 0.0 to 1.0;
    min_stall_cycles  : natural;
    max_stall_cycles  : natural) return stall_config_t is
      variable stall_config : stall_config_t;
  begin
    stall_config := (
      stall_probability => stall_probability,
      min_stall_cycles  => min_stall_cycles,
      max_stall_cycles  => max_stall_cycles);
    return stall_config;
  end;

  function is_u(value : std_ulogic_vector) return boolean is
  begin
    for idx in value'range loop
      if value(idx) /= 'U' then
        return false;
      end if;
    end loop;

    return true;
  end;

end package body;
