
library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

package stream_full_duplex_pkg is

  type stream_full_duplex_t is record
    p_actor: actor_t;
  end record stream_full_duplex_t;

  impure function new_stream_full_duplex return stream_full_duplex_t;

  alias stream_reference_t is msg_t;

  procedure push_stream
  (
    signal net: inout network_t;
    stream: stream_full_duplex_t;
    data: std_logic_vector;
    last: boolean := false
  );

  procedure pop_stream
  (
    signal net: inout network_t;
    stream: stream_full_duplex_t;
    variable data: out std_logic_vector;
    variable last: out boolean
  );

  procedure pop_stream
  (
    signal net: inout network_t;
    stream: stream_full_duplex_t;
    variable data: out std_logic_vector
  );

  procedure pop_stream
  (
    signal net: inout network_t;
    stream: stream_full_duplex_t;
    variable reference: inout stream_reference_t
  );

  procedure await_pop_stream_reply
  (
    signal net: inout network_t;
    variable reference: inout stream_reference_t;
    variable data: out std_logic_vector;
    variable last: out boolean
  );

  procedure await_pop_stream_reply
  (
    signal net: inout network_t;
    variable reference: inout stream_reference_t;
    variable data: out std_logic_vector
  );

  procedure check_stream
  (
    signal net: inout network_t;
    stream: stream_full_duplex_t;
    expected: std_logic_vector;
    last: boolean := false;
    msg: string := ""
  );

  constant stream_push_msg: msg_type_t := new_msg_type("stream push");
  constant stream_pop_msg: msg_type_t := new_msg_type("stream pop");
  constant stream_trigger_msg: msg_type_t := new_msg_type("stream trigger");
end package stream_full_duplex_pkg;
