-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
library ieee;
use ieee.std_logic_1164.all;

use work.queue_pkg.all;
use work.logger_pkg.all;
use work.checker_pkg.all;
use work.memory_pkg.all;
use work.bus_master_pkg.all;
use work.vc_pkg.all;
use work.sync_pkg.all;
context work.com_context;

package avalon_pkg is

  type avalon_master_t is record
    p_bus_handle : bus_master_t;
    p_use_readdatavalid   : boolean;
    p_fixed_read_latency  : natural;
    p_write_high_probability : real range 0.0 to 1.0;
    p_read_high_probability : real range 0.0 to 1.0;
  end record;

  type avalon_slave_t is record
    p_readdatavalid_high_probability : real range 0.0 to 1.0;
    p_waitrequest_high_probability : real range 0.0 to 1.0;
    p_std_cfg : std_cfg_t;
    p_ack_actor : actor_t;
    p_memory : memory_t;
  end record;

  constant avalon_logger : logger_t := get_logger("vunit_lib:avalon_pkg");
  constant avalon_checker : checker_t := new_checker(avalon_logger);

  impure function new_avalon_master(
    data_length                : natural;
    address_length             : natural;
    use_readdatavalid          : boolean                      := true;
    fixed_read_latency         : natural                      := 1; -- (bus cycles).  This parameter is ignored when use_readdatavalid is true
    write_high_probability     : real range 0.0 to 1.0        := 1.0;
    read_high_probability      : real range 0.0 to 1.0        := 1.0;
    byte_length                : natural                      := 8;
    logger                     : logger_t                     := avalon_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return avalon_master_t;

  impure function new_avalon_slave(
    memory                         : memory_t;
    readdatavalid_high_probability : real                         := 1.0;
    waitrequest_high_probability   : real                         := 0.0;
    logger                         : logger_t                     := avalon_logger;
    actor                          : actor_t                      := null_actor;
    checker                        : checker_t                    := null_checker;
    unexpected_msg_type_policy     : unexpected_msg_type_policy_t := fail
  )
  return avalon_slave_t;

  impure function as_sync(avalon_master : avalon_master_t) return sync_handle_t;
  impure function as_sync(avalon_slave : avalon_slave_t) return sync_handle_t;
  impure function as_bus_master(avalon_master : avalon_master_t) return bus_master_t;
  impure function get_std_cfg(avalon_master : avalon_master_t) return std_cfg_t;
  impure function get_std_cfg(avalon_slave : avalon_slave_t) return std_cfg_t;

end package;
package body avalon_pkg is

  impure function new_avalon_master(
    data_length                : natural;
    address_length             : natural;
    use_readdatavalid          : boolean                      := true;
    fixed_read_latency         : natural                      := 1; -- (bus cycles). This parameter is ignored when use_readdatavalid is true
    write_high_probability     : real range 0.0 to 1.0        := 1.0;
    read_high_probability      : real range 0.0 to 1.0        := 1.0;
    byte_length                : natural                      := 8;
    logger                     : logger_t                     := avalon_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return avalon_master_t is
    constant p_bus_handle : bus_master_t := new_bus(data_length, address_length, byte_length, logger, actor,
                                                    checker, unexpected_msg_type_policy
                                                   );
  begin
    return (p_bus_handle             => p_bus_handle,
            p_use_readdatavalid      => use_readdatavalid,
            p_fixed_read_latency     => fixed_read_latency,
            p_write_high_probability => write_high_probability,
            p_read_high_probability  => read_high_probability
           );
  end;

  impure function new_avalon_slave(
    memory                         : memory_t;
    readdatavalid_high_probability : real                         := 1.0;
    waitrequest_high_probability   : real                         := 0.0;
    logger                         : logger_t                     := avalon_logger;
    actor                          : actor_t                      := null_actor;
    checker                        : checker_t                    := null_checker;
    unexpected_msg_type_policy     : unexpected_msg_type_policy_t := fail
  )
  return avalon_slave_t is
    constant p_std_cfg : std_cfg_t := create_std_cfg(
      avalon_logger, avalon_checker, actor, logger, checker, unexpected_msg_type_policy
    );

  begin
    return (p_std_cfg                        => p_std_cfg,
            p_ack_actor                      => new_actor(name(actor) & " read-ack"),
            p_memory                         => to_vc_interface(memory, logger),
            p_readdatavalid_high_probability => readdatavalid_high_probability,
            p_waitrequest_high_probability   => waitrequest_high_probability
           );
  end;

  impure function as_sync(avalon_master : avalon_master_t) return sync_handle_t is
  begin
    return as_sync(avalon_master.p_bus_handle);
  end;

  impure function as_sync(avalon_slave : avalon_slave_t) return sync_handle_t is
  begin
    return get_actor(avalon_slave.p_std_cfg);
  end;

  impure function as_bus_master(avalon_master : avalon_master_t) return bus_master_t is
  begin
    return avalon_master.p_bus_handle;
  end;

  impure function get_std_cfg(avalon_master : avalon_master_t) return std_cfg_t is
  begin
    return get_std_cfg(avalon_master.p_bus_handle);
  end;

  impure function get_std_cfg(avalon_slave : avalon_slave_t) return std_cfg_t  is
  begin
    return avalon_slave.p_std_cfg;
  end;


end package body;
