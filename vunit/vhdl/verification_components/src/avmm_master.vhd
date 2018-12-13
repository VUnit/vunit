
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

entity avmm_master is
  generic
  (
    avmm: avmm_master_t
  );
  port
  (
    clk: in std_logic;
    rstn: in std_logic;
    read: out std_logic := '0';
    write: out std_logic := '0';
    address: out std_logic_vector(7 downto 0) := (others => '0');
    writedata: out std_logic_vector(31 downto 0) := (others => '0');
    waitrequest: in std_logic;
    readdata: in std_logic_vector(31 downto 0) := (others => '0');
    readdatavalid: in std_logic
  );
end entity avmm_master;

architecture bfm of avmm_master is
  constant s2m_req_queue: queue_t := new_queue;
  constant s2m_msg_queue: queue_t := new_queue;
  constant m2s_msg_queue: queue_t := new_queue;

  signal irq0, irq1: std_logic := '0';
begin

  message_handler: process
  is
    variable msg: msg_t;
    variable msg_type: msg_type_t;
  begin
    receive(net, avmm.p_actor, msg);
    msg_type := message_type(msg);

    handle_sync_message(net, msg_type, msg);

    if msg_type = stream_push_msg then
      push(m2s_msg_queue, msg);

    elsif msg_type = stream_pop_msg then
      push(s2m_req_queue, msg);
      nudge(irq => irq0);

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

  m2s_transfer: process
  is
    variable m2s_data_msg: msg_t;
  begin
    wait until rstn = '1' and rising_edge(clk) and waitrequest = '0';

    if length(m2s_msg_queue) > 0 then
      m2s_data_msg := pop(m2s_msg_queue);

      read <= pop_std_ulogic(m2s_data_msg);
      write <= pop_std_ulogic(m2s_data_msg);
      address <= std_logic_vector(to_unsigned(pop_integer(m2s_data_msg), 8));
      writedata <= pop_std_ulogic_vector(m2s_data_msg);
    else
      read <= '0';
      write <= '0';
      address <= (others => '0');
      writedata <= (others => '0');
    end if;
  end process m2s_transfer;

  s2m_transfer: process
  is
    variable s2m_data_msg: msg_t;
  begin
    wait until rstn = '1' and rising_edge(clk) and readdatavalid = '1';

    s2m_data_msg := new_msg(avmm_s2m_data_msg);
    push_std_ulogic_vector(s2m_data_msg, readdata);
    push_boolean(s2m_data_msg, false);

    push(s2m_msg_queue, s2m_data_msg);
    nudge(irq => irq1);
  end process s2m_transfer;
end architecture bfm;
