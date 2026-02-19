-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com
-- Author Sebastiaan Jacobs basfriends@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
use vunit_lib.queue_pkg.all;
use vunit_lib.sync_pkg.all;

use work.stream_full_duplex_pkg.all;
use work.spi_pkg.all;

entity spi_slave is
  generic
  (
    spi: spi_slave_t;
    cpol: std_logic := '0';
    cpha: std_logic := '0'
  );
  port
  (
    ss_n: in std_logic;
    sclk: in std_logic;
    mosi: in std_logic;
    miso: out std_logic := spi.p_idle_state
  );
end entity spi_slave;

architecture bfm of spi_slave is
  constant s2m_req_queue: queue_t := new_queue;
  constant s2m_msg_queue: queue_t := new_queue;
  constant m2s_req_queue: queue_t := new_queue;
  constant m2s_msg_queue: queue_t := new_queue;

  signal irq0, irq1: std_logic := '0';
begin

  message_handler: process
    variable msg: msg_t;
    variable msg_type: msg_type_t;
  begin
    receive(net, spi.p_actor, msg);
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
  end process message_handler;

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

  transfer: process

    variable s2m_data_msg: msg_t;
    variable m2s_data_msg: msg_t;

    variable m2s_data, s2m_data: std_logic_vector(spi.p_data_length-1 downto 0);

  begin

    wait until ss_n = '0';

    if length(s2m_msg_queue) > 0 then
      s2m_data_msg := pop(s2m_msg_queue);
      s2m_data := pop_std_ulogic_vector(s2m_data_msg);
    else
      s2m_data := (others => '0');
    end if;

    spi_slave_transaction
    (
      cpol => cpol,
      cpha => cpha,
      s2m_data => s2m_data,
      m2s_data => m2s_data,
      ss_n => ss_n,
      sclk => sclk,
      mosi => mosi,
      miso => miso
    );

    wait until ss_n = '1';
    miso <= spi.p_idle_state;

    m2s_data_msg := new_msg(spi_m2s_data_msg);
    push_std_ulogic_vector(m2s_data_msg, m2s_data);
    push_boolean(m2s_data_msg, false);

    push(m2s_msg_queue, m2s_data_msg);
    nudge(irq => irq1);
  end process;

end architecture bfm;
