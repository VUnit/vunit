-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com
-- Author Sebastiaan Jacobs basfriends@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
use vunit_lib.queue_pkg.all;
use vunit_lib.sync_pkg.all;

use work.stream_full_duplex_pkg.all;
use work.avmm_pkg.all;

entity avmm_slave is
  generic
  (
    avmm: avmm_slave_t
  );
  port
  (
    clk: in std_logic;
    rstn: in std_logic;
    read: in std_logic;
    write: in std_logic;
    address: in std_logic_vector(7 downto 0);
    writedata: in std_logic_vector(31 downto 0);
    waitrequest: out std_logic := '0';
    readdata: out std_logic_vector(31 downto 0) := (others => '0');
    readdatavalid: out std_logic := '0'
  );
end entity avmm_slave;

architecture bfm of avmm_slave is
  constant s2m_msg_queue: queue_t := new_queue;
  constant m2s_req_queue: queue_t := new_queue;
  constant m2s_msg_queue: queue_t := new_queue;

  signal irq0, irq1: std_logic := '0';
begin

  message_handler: process
  is
    variable msg, reply_msg: msg_t;
    variable msg_type: msg_type_t;
  begin
    receive(net, avmm.p_actor, msg);
    msg_type := message_type(msg);

    handle_sync_message(net, msg_type, msg);

    if msg_type = stream_push_msg then
      push(s2m_msg_queue, msg);

    elsif msg_type = stream_pop_msg then
      push(m2s_req_queue, msg);
      nudge(irq => irq0);

    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

  request_handler: process
  is
    variable m2s_req_length: natural := 0;
    variable m2s_msg_length: natural := 0;

    variable m2s_req: msg_t;
    variable m2s_data: msg_t;
  begin
    wait until (irq0 = '1') or (irq1 = '1');

    m2s_req_length := length(m2s_req_queue);
    m2s_msg_length := length(m2s_msg_queue);
    while (m2s_req_length > 0) and (m2s_msg_length > 0) loop
      m2s_req := pop(m2s_req_queue);
      m2s_data := pop(m2s_msg_queue);
      reply(net, m2s_req, m2s_data);

      m2s_req_length := length(m2s_req_queue);
      m2s_msg_length := length(m2s_msg_queue);
    end loop;
  end process request_handler;

  s2m_transfer: process
  is
    variable msg: msg_t;
  begin
    wait until rstn = '1' and rising_edge(clk);

    if length(s2m_msg_queue) > 0 then
      msg := pop(s2m_msg_queue);

      waitrequest <= '0';
      readdata <= pop_std_ulogic_vector(msg);
      readdatavalid <= '1';
    else
      waitrequest <= '0';
      readdata <= (others => '0');
      readdatavalid <= '0';
    end if;
  end process s2m_transfer;

  m2s_transfer: process
  is
    variable msg: msg_t;
  begin
    wait until (rstn = '1' and rising_edge(clk) and read = '1') or
               (rstn = '1' and rising_edge(clk) and write = '1');

    msg := new_msg(avmm_m2s_data_msg);
    push_std_ulogic(msg, read);
    push_std_ulogic(msg, write);
    push_integer(msg, to_integer(unsigned(address)));
    push_std_ulogic_vector(msg, writedata);

    push(m2s_msg_queue, msg);
    nudge(irq => irq1);
  end process m2s_transfer;
end architecture bfm;
