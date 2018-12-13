
library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

package body stream_full_duplex_pkg is
  impure function new_stream_full_duplex return stream_full_duplex_t is
  begin
    return (p_actor => new_actor);
  end;

  procedure push_stream
  (
    signal net: inout network_t;
    stream: stream_full_duplex_t;
    data: std_logic_vector;
    last: boolean := false
  )
  is
    variable msg: msg_t := new_msg(stream_push_msg);
    constant normalized_data: std_logic_vector(data'length-1 downto 0) := data;
  begin
    push_std_ulogic_vector(msg, normalized_data);
    push_boolean(msg, last);
    send(net, stream.p_actor, msg);
  end procedure push_stream;

  procedure pop_stream
  (
    signal net: inout network_t;
    stream: stream_full_duplex_t;
    variable reference: inout stream_reference_t
  )
  is
  begin
    reference := new_msg(stream_pop_msg);
    send(net, stream.p_actor, reference);
  end procedure pop_stream;

  procedure await_pop_stream_reply
  (
    signal net: inout network_t;
    variable reference: inout stream_reference_t;
    variable data: out std_logic_vector;
    variable last: out boolean
  )
  is
    variable reply_msg: msg_t;
  begin
    receive_reply(net, reference, reply_msg);
    data := pop_std_ulogic_vector(reply_msg);
    last := pop_boolean(reply_msg);
    delete(reference);
    delete(reply_msg);
  end procedure await_pop_stream_reply;

  procedure await_pop_stream_reply
  (
    signal net: inout network_t;
    variable reference: inout stream_reference_t;
    variable data: out std_logic_vector
  )
  is
    variable reply_msg: msg_t;
  begin
    receive_reply(net, reference, reply_msg);
    data := pop_std_ulogic_vector(reply_msg);
    delete(reference);
    delete(reply_msg);
  end procedure await_pop_stream_reply;


  procedure pop_stream
  (
    signal net: inout network_t;
    stream: stream_full_duplex_t;
    variable data: out std_logic_vector;
    variable last: out boolean
  )
  is
    variable reference: stream_reference_t;
  begin
    pop_stream(net, stream, reference);
    await_pop_stream_reply(net, reference, data);
  end procedure pop_stream;

  procedure pop_stream
  (
    signal net: inout network_t;
    stream: stream_full_duplex_t;
    variable data: out std_logic_vector
  )
  is
    variable reference: stream_reference_t;
  begin
    pop_stream(net, stream, reference);
    await_pop_stream_reply(net, reference, data);
  end procedure pop_stream;

  procedure check_stream
  (
    signal net: inout network_t;
    stream: stream_full_duplex_t;
    expected: std_logic_vector;
    last: boolean := false;
    msg: string := ""
  )
  is
    variable got_data: std_logic_vector(expected'range);
    variable got_last: boolean;
  begin
    pop_stream(net, stream, got_data, got_last);
    check_equal(got_data, expected, msg);
    check_equal(got_last, last, msg);
  end procedure check_stream;
end package body stream_full_duplex_pkg;
