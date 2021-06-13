-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

package body stream_slave_pkg is

  impure function new_stream_slave(
    logger                     : logger_t                     := stream_slave_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return stream_slave_t is
    constant p_std_cfg       : std_cfg_t := create_std_cfg(
      stream_slave_logger, stream_slave_checker, actor, logger, checker, unexpected_msg_type_policy
    );

    begin
    return (p_std_cfg => p_std_cfg);
  end;

  function get_std_cfg(slave : stream_slave_t) return std_cfg_t is
  begin
    return slave.p_std_cfg;
  end;

  procedure pop_stream(signal net : inout network_t;
                       stream : stream_slave_t;
                       variable reference : inout stream_reference_t) is
  begin
    reference := new_msg(stream_pop_msg);
    send(net, get_actor(stream.p_std_cfg), reference);
  end;

  procedure await_pop_stream_reply(signal net : inout network_t;
                                   variable reference : inout stream_reference_t;
                                   variable data : out std_logic_vector;
                                   variable last : out boolean) is
    variable reply_msg : msg_t;
  begin
    receive_reply(net, reference, reply_msg);
    data := pop_std_ulogic_vector(reply_msg);
    last := pop_boolean(reply_msg);
    delete(reference);
    delete(reply_msg);
  end;

  procedure await_pop_stream_reply(signal net : inout network_t;
                                   variable reference : inout stream_reference_t;
                                   variable data : out std_logic_vector) is
    variable reply_msg : msg_t;
  begin
    receive_reply(net, reference, reply_msg);
    data := pop_std_ulogic_vector(reply_msg);
    delete(reference);
    delete(reply_msg);
  end;

  procedure pop_stream(signal net : inout network_t;
                       stream : stream_slave_t;
                       variable data : out std_logic_vector;
                       variable last : out boolean) is
    variable reference : stream_reference_t;
  begin
    pop_stream(net, stream, reference);
    await_pop_stream_reply(net, reference, data, last);
  end;

  procedure pop_stream(signal net : inout network_t;
                       stream : stream_slave_t;
                       variable data : out std_logic_vector) is
    variable reference : stream_reference_t;
  begin
    pop_stream(net, stream, reference);
    await_pop_stream_reply(net, reference, data);
  end;

  procedure check_stream(signal net : inout network_t;
                         stream : stream_slave_t;
                         expected : std_logic_vector;
                         last : boolean := false;
                         msg : string := "") is
    variable got_data : std_logic_vector(expected'range);
    variable got_last : boolean;
  begin
    pop_stream(net, stream, got_data, got_last);
    check_equal(got_data, expected, msg);
    check_equal(got_last, last, msg);
  end procedure;
end package body;
