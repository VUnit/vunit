-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

package body stream_slave_pkg is
  impure function new_stream_slave return stream_slave_t is
  begin
    return (p_actor => create);
  end;

  procedure pop_stream(signal event : inout event_t;
                       stream : stream_slave_t;
                       variable reference : inout stream_reference_t) is
  begin
    reference := create;
    push_msg_type(reference, stream_pop_msg);
    send(event, stream.p_actor, reference);
  end;

  procedure await_pop_stream_reply(signal event : inout event_t;
                                   variable reference : inout stream_reference_t;
                                   variable data : out std_logic_vector) is
    variable reply_msg : msg_t;
  begin
    receive_reply(event, reference, reply_msg);
    data := pop_std_ulogic_vector(reply_msg);
    delete(reference);
    delete(reply_msg);
  end;

  procedure pop_stream(signal event : inout event_t;
                       stream : stream_slave_t;
                       variable data : out std_logic_vector) is
    variable reference : stream_reference_t;
  begin
    pop_stream(event, stream, reference);
    await_pop_stream_reply(event, reference, data);
  end;

  procedure check_stream(signal event : inout event_t;
                         stream : stream_slave_t;
                         expected : std_logic_vector;
                         msg : string := "") is
    variable got : std_logic_vector(expected'range);
  begin
    pop_stream(event, stream, got);
    check_equal(got, expected, msg);
  end procedure;
end package body;
