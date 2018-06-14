-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.logger_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;
use work.sync_pkg.all;
context work.com_context;
context work.data_types_context;

package axi_stream_pkg is

  type axi_stream_master_t is record
    p_actor : actor_t;
    p_data_length : natural;
    p_logger : logger_t;
  end record;

  type axi_stream_slave_t is record
    p_actor : actor_t;
    p_data_length : natural;
    p_logger : logger_t;
  end record;

  constant axi_stream_logger : logger_t := get_logger("vunit_lib:axi_stream_pkg");
  impure function new_axi_stream_master(data_length : natural;
                                        logger : logger_t := axi_stream_logger;
                                        actor : actor_t := null_actor) return axi_stream_master_t;
  impure function new_axi_stream_slave(data_length : natural;
                                       logger : logger_t := axi_stream_logger;
                                       actor : actor_t := null_actor) return axi_stream_slave_t;
  impure function data_length(master : axi_stream_master_t) return natural;
  impure function data_length(master : axi_stream_slave_t) return natural;
  impure function as_stream(master : axi_stream_master_t) return stream_master_t;
  impure function as_stream(slave : axi_stream_slave_t) return stream_slave_t;
  impure function as_sync(master : axi_stream_master_t) return sync_handle_t;

  constant push_axi_stream_msg : msg_type_t := new_msg_type("push axi stream");

  procedure push_axi_stream(signal net : inout network_t;
                            axi_stream : axi_stream_master_t;
                            tdata : std_logic_vector;
                            tlast : std_logic := '1');

end package;

package body axi_stream_pkg is

  impure function new_axi_stream_master(data_length : natural;
                                        logger : logger_t := axi_stream_logger;
                                        actor : actor_t := null_actor) return axi_stream_master_t is
    variable p_actor : actor_t;
  begin
    p_actor := actor when actor /= null_actor else new_actor;

    return (p_actor => p_actor,
            p_data_length => data_length,
            p_logger => logger);
  end;

  impure function new_axi_stream_slave(data_length : natural;
                                       logger : logger_t := axi_stream_logger;
                                       actor : actor_t := null_actor) return axi_stream_slave_t is
    variable p_actor : actor_t;
  begin
    p_actor := actor when actor /= null_actor else new_actor;

    return (p_actor => p_actor,
            p_data_length => data_length,
            p_logger => logger);
  end;

  impure function data_length(master : axi_stream_master_t) return natural is
  begin
    return master.p_data_length;
  end;

  impure function data_length(master : axi_stream_slave_t) return natural is
  begin
    return master.p_data_length;
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

  procedure push_axi_stream(signal net : inout network_t;
                            axi_stream : axi_stream_master_t;
                            tdata : std_logic_vector;
                            tlast : std_logic := '1') is
    variable msg : msg_t := new_msg(push_axi_stream_msg);
    constant normalized_data : std_logic_vector(tdata'length-1 downto 0) := tdata;
  begin
    push_std_ulogic_vector(msg, normalized_data);
    push_std_ulogic(msg, tlast);
    send(net, axi_stream.p_actor, msg);
  end;

end package body;
