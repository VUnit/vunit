-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.queue_pkg.all;
use work.msg_types_pkg.all;
use work.sync_pkg.all;

package stream_pkg is
  type stream_master_t is record
    p_actor : actor_t;
  end record;

  type stream_slave_t is record
    p_actor : actor_t;
  end record;

  impure function new_stream_master return stream_master_t;
  impure function new_stream_slave return stream_slave_t;

  alias stream_reference_t is msg_t;

  procedure write_stream(signal event : inout event_t;
                         stream : stream_master_t;
                         data : std_logic_vector);

  procedure await_completion(signal event : inout event_t;
                             stream : stream_master_t);

  procedure read_stream(signal event : inout event_t;
                        stream : stream_slave_t;
                        variable data : out std_logic_vector);

  procedure read_stream(signal event : inout event_t;
                        stream : stream_slave_t;
                        variable reference : inout stream_reference_t);

  procedure await_read_stream_reply(signal event : inout event_t;
                                    variable reference : inout stream_reference_t;
                                    variable data : out std_logic_vector);

  procedure check_stream(signal event : inout event_t;
                         stream : stream_slave_t;
                         expected : std_logic_vector;
                         msg : string := "");

  constant stream_write_msg : msg_type_t := new_msg_type("stream write");
  constant stream_read_msg : msg_type_t := new_msg_type("stream read");

end package;

package body stream_pkg is
  impure function new_stream_master return stream_master_t is
  begin
    return (p_actor => create);
  end;

  impure function new_stream_slave return stream_slave_t is
  begin
    return (p_actor => create);
  end;

  procedure write_stream(signal event : inout event_t;
                         stream : stream_master_t;
                         data : std_logic_vector) is
    variable msg : msg_t := create;
    constant normalized_data : std_logic_vector(data'length-1 downto 0) := data;
  begin
    push_msg_type(msg, stream_write_msg);
    push_std_ulogic_vector(msg, normalized_data);
    send(event, stream.p_actor, msg);
  end;

  procedure await_completion(signal event : inout event_t;
                             stream : stream_master_t) is
  begin
    await_completion(event, stream.p_actor);
  end;

  procedure read_stream(signal event : inout event_t;
                        stream : stream_slave_t;
                        variable reference : inout stream_reference_t) is
  begin
    reference := create;
    push_msg_type(reference, stream_read_msg);
    send(event, stream.p_actor, reference);
  end;

  procedure await_read_stream_reply(signal event : inout event_t;
                                    variable reference : inout stream_reference_t;
                                    variable data : out std_logic_vector) is
    variable reply_msg : msg_t;
  begin
    receive_reply(event, reference, reply_msg);
    data := pop_std_ulogic_vector(reply_msg);
    delete(reference);
    delete(reply_msg);
  end;

  procedure read_stream(signal event : inout event_t;
                        stream : stream_slave_t;
                        variable data : out std_logic_vector) is
    variable reference : stream_reference_t;
  begin
    read_stream(event, stream, reference);
    await_read_stream_reply(event, reference, data);
  end;

  procedure check_stream(signal event : inout event_t;
                         stream : stream_slave_t;
                         expected : std_logic_vector;
                         msg : string := "") is
    variable got : std_logic_vector(expected'range);
  begin
    read_stream(event, stream, got);
    check_equal(got, expected, msg);
  end procedure;
end package body;
