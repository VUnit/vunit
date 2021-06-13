-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2021, Lars Asplund lars.anders.asplund@gmail.com

-- Stream master verification component interface

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.vc_pkg.all;

package stream_master_pkg is
  -- Stream master handle
  type stream_master_t is record
    p_std_cfg  : std_cfg_t;
  end record;

  constant stream_master_logger  : logger_t  := get_logger("vunit_lib:stream_master_pkg");
  constant stream_master_checker : checker_t := new_checker(stream_master_logger);

  -- Create a new stream master object
  impure function new_stream_master(
    logger                     : logger_t                     := stream_master_logger;
    actor                      : actor_t                      := null_actor;
    checker                    : checker_t                    := null_checker;
    unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
  ) return stream_master_t;

  function get_std_cfg(master : stream_master_t) return std_cfg_t;

  -- Push a data value to the stream
  procedure push_stream(signal net : inout network_t;
                        stream : stream_master_t;
                        data : std_logic_vector;
                        last : boolean := false);

  -- Message type definitions used by VC implementing stream master VCI
  constant stream_push_msg : msg_type_t := new_msg_type("stream push");
end package;
