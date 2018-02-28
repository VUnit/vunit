-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Slawomir Siluk slaweksiluk@gazeta.pl 2018
-- Wishbome Master Block Pipelined Bus Functional Model
-- TODO:
-- - stall input
-- - how to handle read req msg received while some writes
--   are still in progress?


library ieee;
use ieee.std_logic_1164.all;

--use work.axi_pkg.all;
use work.queue_pkg.all;
use work.bus_master_pkg.all;
--use work.axi_private_pkg.all;
context work.com_context;
use work.logger_pkg.all;

entity wishbone_master is
  generic (
    bus_handle : bus_master_t
    );
  port (
    clk   : in std_logic;
    adr   : out std_logic_vector;
    dat_i : in  std_logic_vector;
    dat_o : out std_logic_vector;
    sel   : out std_logic_vector;
    cyc   : out std_logic;
    stb   : out std_logic;
    we    : out std_logic;
    ack   : in  std_logic
    );
end entity;

architecture a of wishbone_master is
  constant request_queue : queue_t := new_queue;
  constant bus_ack_msg   : msg_type_t := new_msg_type("wb master ack msg");
  constant wb_master_ack_actor : actor_t := new_actor("wb master ack actor");
begin
  main : process
    variable request_msg, reply_msg : msg_t;
    variable msg_type : msg_type_t;
    variable pending_acks : natural := 0;
    variable received_acks : natural := 0;
    variable status : com_status_t;
  begin
    cyc <= '0';
    stb <= '0';
    wait until rising_edge(clk);
    loop
      -- Cannot use receive, as it deletes the message
      --receive(net, bus_handle.p_actor, request_msg);
      wait_for_message(net, bus_handle.p_actor, status);
      get_message(net, bus_handle.p_actor, request_msg);
      msg_type := message_type(request_msg);
      if msg_type = bus_read_msg then
        adr <= pop_std_ulogic_vector(request_msg);
        cyc <= '1';
        stb <= '1';
        we <= '0';
        wait until rising_edge(clk);
        stb <= '0';

        push(request_queue, request_msg);
        pending_acks := pending_acks +1;

      elsif msg_type = bus_write_msg then
        adr <= pop_std_ulogic_vector(request_msg);
        dat_o <= pop_std_ulogic_vector(request_msg);
        sel <= pop_std_ulogic_vector(request_msg);

        cyc <= '1';
        stb <= '1';
        we <= '1';
        wait until rising_edge(clk);
        stb <= '0';

        push(request_queue, request_msg);
        pending_acks := pending_acks +1;

      elsif msg_type = bus_ack_msg then
        -- TODO bus errors detection
        received_acks := received_acks +1;
        if pending_acks = received_acks then
          info(bus_handle.p_logger, "finished wb cycle");
          -- End of wb cycle
          cyc <= '0';
          pending_acks := 0;
          received_acks := 0;
        end if;
      else
        unexpected_msg_type(msg_type);
      end if;
    end loop;
  end process;

  acknowladge : process
    variable request_msg, reply_msg, ack_msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    wait until ack = '1' and rising_edge(clk);
    request_msg := pop(request_queue);
    -- Reply only on read
    if we = '0' then
      reply_msg := new_msg(sender => wb_master_ack_actor);
      push_std_ulogic_vector(reply_msg, dat_i);
      reply(net, request_msg, reply_msg);
    end if;
    delete(request_msg);
    -- Response main that ack is received
    ack_msg := new_msg(bus_ack_msg);
    send(net, bus_handle.p_actor, ack_msg);
  end process;
end architecture;
