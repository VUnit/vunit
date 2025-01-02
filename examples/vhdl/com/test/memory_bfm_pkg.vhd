-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package memory_bfm_pkg is
  constant write_msg                  : msg_type_t := new_msg_type("write");
  constant write_with_acknowledge_msg : msg_type_t := new_msg_type("write with acknowledge");
  constant read_msg                   : msg_type_t := new_msg_type("read");
  constant read_reply_msg             : msg_type_t := new_msg_type("read reply");
  constant actor                      : actor_t    := new_actor("memory BFM");
  constant memory_bfm_logger          : logger_t := get_logger("memory BFM");

  procedure write(
    signal net       : inout network_t;
    constant address : in    unsigned(7 downto 0);
    constant data    : in    std_logic_vector(7 downto 0));

  procedure blocking_write(
    signal net       : inout network_t;
    constant address : in    unsigned(7 downto 0);
    constant data    : in    std_logic_vector(7 downto 0));

  procedure read(
    signal net       : inout network_t;
    constant address : in    unsigned(7 downto 0);
    variable future  : out   msg_t);
  alias non_blocking_read is read[network_t, unsigned, msg_t];

  procedure get(
    signal net      : inout network_t;
    variable future : inout msg_t;
    variable data   : out   std_logic_vector(7 downto 0));

  procedure read(
    signal net       : inout network_t;
    constant address : in    unsigned(7 downto 0);
    variable data    : out   std_logic_vector(7 downto 0));
  alias blocking_read is read[network_t, unsigned, std_logic_vector];

end package memory_bfm_pkg;

package body memory_bfm_pkg is
  procedure write(
    signal net       : inout network_t;
    constant address : in    unsigned(7 downto 0);
    constant data    : in    std_logic_vector(7 downto 0)) is
    variable msg : msg_t := new_msg(write_msg);
  begin
    push(msg, address);
    push(msg, data);
    send(net, actor, msg);
  end;

  procedure blocking_write(
    signal net       : inout network_t;
    constant address : in    unsigned(7 downto 0);
    constant data    : in    std_logic_vector(7 downto 0)) is
    variable msg          : msg_t := new_msg(write_with_acknowledge_msg);
    variable positive_ack : boolean;
  begin
    push(msg, address);
    push(msg, data);
    request(net, actor, msg, positive_ack);
    check(positive_ack, "Write failed");
  end;

  procedure read(
    signal net       : inout network_t;
    constant address : in    unsigned(7 downto 0);
    variable future  : out   msg_t) is
    variable request_msg : msg_t := new_msg(read_msg);
    variable reply_msg   : msg_t;
  begin
    push(request_msg, address);
    send(net, actor, request_msg);
    future := request_msg;
  end;

  procedure get(
    signal net      : inout network_t;
    variable future : inout msg_t;
    variable data   : out   std_logic_vector(7 downto 0)) is
    variable reply_msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive_reply(net, future, reply_msg);
    msg_type := message_type(reply_msg);
    data := pop(reply_msg);
    delete(reply_msg);
  end;

  procedure read(
    signal net       : inout network_t;
    constant address : in    unsigned(7 downto 0);
    variable data    : out   std_logic_vector(7 downto 0)) is
    variable future : msg_t;
  begin
    read(net, address, future);
    get(net, future, data);
  end;

end package body memory_bfm_pkg;
