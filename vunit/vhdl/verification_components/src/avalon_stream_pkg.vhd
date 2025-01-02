-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.com_pkg.all;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.stream_master_pkg.stream_master_t;
use work.stream_slave_pkg.stream_slave_t;

package avalon_stream_pkg is

  type avalon_source_t is record
    valid_high_probability : real range 0.0 to 1.0;
    p_actor : actor_t;
    p_data_length : natural;
    p_logger : logger_t;
  end record;

  type avalon_sink_t is record
    ready_high_probability : real range 0.0 to 1.0;
    -- Private
    p_actor : actor_t;
    p_data_length : natural;
    p_logger : logger_t;
  end record;

  constant avalon_stream_logger : logger_t := get_logger("vunit_lib:avalon_stream_pkg");
  impure function new_avalon_source(data_length : natural;
                                        valid_high_probability : real := 1.0;
                                        logger : logger_t := avalon_stream_logger;
                                        actor : actor_t := null_actor) return avalon_source_t;
  impure function new_avalon_sink(data_length : natural;
                                       ready_high_probability : real := 1.0;
                                       logger : logger_t := avalon_stream_logger;
                                       actor : actor_t := null_actor) return avalon_sink_t;
  impure function data_length(source : avalon_source_t) return natural;
  impure function data_length(source : avalon_sink_t) return natural;
  impure function as_stream(source : avalon_source_t) return stream_master_t;
  impure function as_stream(sink : avalon_sink_t) return stream_slave_t;

  constant push_avalon_stream_msg        : msg_type_t := new_msg_type("push avalon stream");
  constant pop_avalon_stream_msg        : msg_type_t := new_msg_type("pop avalon stream");
  constant avalon_stream_transaction_msg : msg_type_t := new_msg_type("avalon stream transaction");

  procedure push_avalon_stream(signal net : inout network_t;
                               avalon_source : avalon_source_t;
                               data : std_logic_vector;
                               sop : std_logic := '0';
                               eop : std_logic := '0');

  procedure pop_avalon_stream(signal net : inout network_t;
                              avalon_sink : avalon_sink_t;
                              variable data : inout std_logic_vector;
                              variable sop  : inout std_logic;
                              variable eop  : inout std_logic);

  type avalon_stream_transaction_t is record
    data : std_logic_vector;
    sop  : boolean;
    eop  : boolean;
  end record;

  procedure push_avalon_stream_transaction(msg : msg_t; avalon_stream_transaction : avalon_stream_transaction_t);
  procedure pop_avalon_stream_transaction(
    constant msg : in msg_t;
    variable avalon_stream_transaction : out avalon_stream_transaction_t
  );

  impure function new_avalon_stream_transaction_msg(
    avalon_stream_transaction : avalon_stream_transaction_t
  ) return msg_t;

  procedure handle_avalon_stream_transaction(
    variable msg_type : inout msg_type_t;
    variable msg : inout msg_t;
    variable avalon_transaction : out avalon_stream_transaction_t
  );
end package;

package body avalon_stream_pkg is

  impure function new_avalon_source(data_length : natural;
                                        valid_high_probability : real := 1.0;
                                        logger : logger_t := avalon_stream_logger;
                                        actor : actor_t := null_actor) return avalon_source_t is
    variable p_actor : actor_t;
  begin
    p_actor := actor when actor /= null_actor else new_actor;

    return (valid_high_probability => valid_high_probability,
            p_actor => p_actor,
            p_data_length => data_length,
            p_logger => logger);
  end;

  impure function new_avalon_sink(data_length : natural;
                                       ready_high_probability : real := 1.0;
                                       logger : logger_t := avalon_stream_logger;
                                       actor : actor_t := null_actor) return avalon_sink_t is
    variable p_actor : actor_t;
  begin
    p_actor := actor when actor /= null_actor else new_actor;

    return (ready_high_probability => ready_high_probability,
            p_actor => p_actor,
            p_data_length => data_length,
            p_logger => logger);
  end;

  impure function data_length(source : avalon_source_t) return natural is
  begin
    return source.p_data_length;
  end;

  impure function data_length(source : avalon_sink_t) return natural is
  begin
    return source.p_data_length;
  end;

  impure function as_stream(source : avalon_source_t) return stream_master_t is
  begin
    return (p_actor => source.p_actor);
  end;

  impure function as_stream(sink : avalon_sink_t) return stream_slave_t is
  begin
    return (p_actor => sink.p_actor);
end;

  procedure push_avalon_stream(signal net : inout network_t;
                               avalon_source : avalon_source_t;
                               data : std_logic_vector;
                               sop : std_logic := '0';
                               eop : std_logic := '0') is
    variable msg : msg_t := new_msg(push_avalon_stream_msg);
    variable avalon_stream_transaction : avalon_stream_transaction_t(data(data'length - 1 downto 0));
  begin
    avalon_stream_transaction.data := data;
    if sop = '1' then
        avalon_stream_transaction.sop := true;
    else
        avalon_stream_transaction.sop := false;
    end if;
    if eop = '1' then
        avalon_stream_transaction.eop := true;
    else
        avalon_stream_transaction.eop := false;
    end if;
    push_avalon_stream_transaction(msg, avalon_stream_transaction);
    send(net, avalon_source.p_actor, msg);
  end;

  procedure pop_avalon_stream(signal net : inout network_t;
                              avalon_sink : avalon_sink_t;
                              variable data : inout std_logic_vector;
                              variable sop  : inout std_logic;
                              variable eop  : inout std_logic) is
    variable reference : msg_t := new_msg(pop_avalon_stream_msg);
    variable reply_msg : msg_t;
    variable avalon_stream_transaction : avalon_stream_transaction_t(data(data'length - 1 downto 0));
begin
    send(net, avalon_sink.p_actor, reference);
    receive_reply(net, reference, reply_msg);
    pop_avalon_stream_transaction(reply_msg, avalon_stream_transaction);
    data := avalon_stream_transaction.data;
    if avalon_stream_transaction.sop then
      sop := '1';
    else
      sop := '0';
    end if;
    if avalon_stream_transaction.eop then
      eop := '1';
    else
      eop := '0';
    end if;
    delete(reference);
    delete(reply_msg);
  end;

  procedure push_avalon_stream_transaction(msg: msg_t; avalon_stream_transaction : avalon_stream_transaction_t) is
  begin
    push_std_ulogic_vector(msg, avalon_stream_transaction.data);
    push_boolean(msg, avalon_stream_transaction.sop);
    push_boolean(msg, avalon_stream_transaction.eop);
  end;

  procedure pop_avalon_stream_transaction(
    constant msg : in msg_t;
    variable avalon_stream_transaction : out avalon_stream_transaction_t) is
  begin
    avalon_stream_transaction.data := pop_std_ulogic_vector(msg);
    avalon_stream_transaction.sop  := pop_boolean(msg);
    avalon_stream_transaction.eop  := pop_boolean(msg);
  end;

  impure function new_avalon_stream_transaction_msg(
    avalon_stream_transaction : avalon_stream_transaction_t
  ) return msg_t is
    variable msg : msg_t;
  begin
    msg := new_msg(avalon_stream_transaction_msg);
    push_avalon_stream_transaction(msg, avalon_stream_transaction);

    return msg;
  end;

  procedure handle_avalon_stream_transaction(
    variable msg_type : inout msg_type_t;
    variable msg : inout msg_t;
    variable avalon_transaction : out avalon_stream_transaction_t) is
  begin
    if msg_type = avalon_stream_transaction_msg then
      handle_message(msg_type);

      pop_avalon_stream_transaction(msg, avalon_transaction);
    end if;
  end;

end package body;
