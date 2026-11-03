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

entity spi_master is
  generic
  (
    spi: spi_master_t;
    cpol: std_logic := '0';
    cpha: std_logic := '0'
  );
  port
  (
    ss_n: out std_logic := '1';
    sclk: out std_logic := cpol;
    mosi: out std_logic := spi.p_idle_state;
    miso: in std_logic
  );
end entity spi_master;

architecture bfm of spi_master is
  constant m2s_req_queue: queue_t := new_queue;
  constant m2s_msg_queue: queue_t := new_queue;
  constant s2m_req_queue: queue_t := new_queue;
  constant s2m_msg_queue: queue_t := new_queue;

  signal irq0, irq1, irq2: std_logic := '0';
begin

  message_handler: process
    variable msg: msg_t;
    variable msg_type: msg_type_t;
  begin
    receive(net, spi.p_actor, msg);
    msg_type := message_type(msg);

    handle_sync_message(net, msg_type, msg);

    if msg_type = stream_push_msg then
      push(m2s_msg_queue, msg);

    elsif msg_type = stream_pop_msg then
      push(s2m_req_queue, msg);
      nudge(irq => irq0);

    elsif msg_type = stream_trigger_msg then
      push(m2s_req_queue, msg);
      nudge(irq => irq2);

    else
      unexpected_msg_type(msg_type);
    end if;
  end process message_handler;

  request_handler: process
  is
    variable s2m_req_length: natural := 0;
    variable s2m_msg_length: natural := 0;

    variable s2m_req: msg_t;
    variable s2m_data: msg_t;
  begin
    wait until (irq0 = '1') or (irq1 = '1');

    s2m_req_length := length(s2m_req_queue);
    s2m_msg_length := length(s2m_msg_queue);
    while (s2m_req_length > 0) and (s2m_msg_length > 0) loop
      s2m_req := pop(s2m_req_queue);
      s2m_data := pop(s2m_msg_queue);
      reply(net, s2m_req, s2m_data);

      s2m_req_length := length(s2m_req_queue);
      s2m_msg_length := length(s2m_msg_queue);
    end loop;
  end process request_handler;

  transfer: process
  is
    variable m2s_req_length: natural := 0;

    variable m2s_req: msg_t;
    variable m2s_data_msg: msg_t;
    variable s2m_data_msg: msg_t;

    variable m2s_data, s2m_data: std_logic_vector(spi.p_data_length-1 downto 0);

  begin
    wait until irq2 = '1';

    m2s_req_length := length(m2s_req_queue);
    while (m2s_req_length > 0) loop
      if length(m2s_msg_queue) > 0 then
        m2s_data_msg := pop(m2s_msg_queue);
        m2s_data := pop_std_ulogic_vector(m2s_data_msg);
      else
        m2s_data := (others => '0');
      end if;

      spi_master_transaction
      (
        spi => spi,
        cpol => cpol,
        cpha => cpha,
        m2s_data => m2s_data,
        s2m_data => s2m_data,
        ss_n => ss_n,
        sclk => sclk,
        mosi => mosi,
        miso => miso
      );

      s2m_data_msg := new_msg(spi_s2m_data_msg);
      push_std_ulogic_vector(s2m_data_msg, s2m_data);
      push_boolean(s2m_data_msg, false);

      push(s2m_msg_queue, s2m_data_msg);
      nudge(irq => irq1);

      m2s_req := pop(m2s_req_queue);
      m2s_req_length := length(m2s_req_queue);
    end loop;

  end process transfer;

end architecture bfm;
