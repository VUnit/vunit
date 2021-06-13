-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;

package body stream_master_pkg is
  impure function new_stream_master(
    logger                     : logger_t                     := stream_master_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return stream_master_t is
    constant p_std_cfg       : std_cfg_t := create_std_cfg(
      stream_master_logger, stream_master_checker, actor, logger, checker, unexpected_msg_type_policy
    );

    begin
    return (p_std_cfg => p_std_cfg);
  end;

  function get_std_cfg(master : stream_master_t) return std_cfg_t is
  begin
    return master.p_std_cfg;
  end;

  procedure push_stream(signal net : inout network_t;
                        stream : stream_master_t;
                        data : std_logic_vector;
                        last : boolean := false) is
    variable msg : msg_t := new_msg(stream_push_msg);
    constant normalized_data : std_logic_vector(data'length-1 downto 0) := data;
  begin
    push_std_ulogic_vector(msg, normalized_data);
    push_boolean(msg, last);
    send(net, get_actor(stream.p_std_cfg), msg);
  end;

end package body;
