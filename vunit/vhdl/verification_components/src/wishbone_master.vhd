-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
-- Wishbome Master BFM for pipelined block transfers
-- TODO:
--  * Random strobe?

library ieee;
use ieee.std_logic_1164.all;

use work.queue_pkg.all;
use work.bus_master_pkg.all;
context work.com_context;
use work.com_types_pkg.all;
use work.logger_pkg.all;
use work.check_pkg.all;

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
    stall : in std_logic;
    ack   : in  std_logic
    );
end entity;

architecture a of wishbone_master is
  constant rd_request_queue : queue_t := new_queue;
  constant wr_request_queue : queue_t := new_queue;
  constant acknowledge_queue : queue_t := new_queue;
  constant ack_return_queue : queue_t := new_queue;
  constant bus_ack_msg   : msg_type_t := new_msg_type("wb master ack msg");
  constant wb_master_ack_actor : actor_t := new_actor;
begin

  main : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable status : com_status_t;
  begin
      request_msg := null_msg;
      receive(net, bus_handle.p_actor, request_msg);
      msg_type := message_type(request_msg);
      if msg_type = bus_read_msg then
        push(rd_request_queue, request_msg);
        request_msg := null_msg;
      elsif msg_type = bus_write_msg then
        push(wr_request_queue, request_msg);
        request_msg := null_msg;
      else
        unexpected_msg_type(msg_type);
      end if;
  end process;

  request : process
    variable request_msg : msg_t;
    variable ack_msg : msg_t;
    variable msg_type : msg_type_t;
    variable pending_acks : natural := 0;
    variable received_acks : natural := 0;
    variable rd_cycle : boolean;
    variable wr_cycle : boolean;
  begin
    cyc <= '0';
    stb <= '0';
    wait until rising_edge(clk);
    loop
      check_false(rd_cycle and wr_cycle);
      if not is_empty(rd_request_queue) and not wr_cycle then
        request_msg := pop(rd_request_queue);
        rd_cycle := true;
        adr <= pop_std_ulogic_vector(request_msg);
        cyc <= '1';
        stb <= '1';
        we <= '0';
        wait until rising_edge(clk) and stall = '0';
        stb <= '0';
        push(acknowledge_queue, request_msg);
        pending_acks := pending_acks +1;

      elsif not is_empty(wr_request_queue) and not rd_cycle then
        request_msg := pop(wr_request_queue);
        wr_cycle := true;
        adr <= pop_std_ulogic_vector(request_msg);
        dat_o <= pop_std_ulogic_vector(request_msg);
        sel <= pop_std_ulogic_vector(request_msg);
        cyc <= '1';
        stb <= '1';
        we <= '1';
        wait until rising_edge(clk) and stall = '0';
        stb <= '0';
        push(acknowledge_queue, request_msg);
        pending_acks := pending_acks +1;

      -- During cylce but no msg from tb? Have to wait for
      -- one - block on receive
      elsif (wr_cycle or rd_cycle) then
        receive(net, wb_master_ack_actor, ack_msg);
        received_acks := received_acks +1;
        if pending_acks = received_acks then
          -- End of wb cycle
          cyc <= '0';
          pending_acks := 0;
          received_acks := 0;
          rd_cycle := false;
          wr_cycle := false;
          wait until rising_edge(clk);
        end if;

      -- No cycles, wait one clk period
      else
        wait until rising_edge(clk);
      end if;
    end loop;
  end process;

  acknowledge : process
    variable request_msg, reply_msg, ack_msg : msg_t;
  begin
    wait until ack = '1' and rising_edge(clk);
    request_msg := pop(acknowledge_queue);
    -- Reply only on read
    if we = '0' then
      reply_msg := new_msg(sender => wb_master_ack_actor);
      push_std_ulogic_vector(reply_msg, dat_i);
      reply(net, request_msg, reply_msg);
    end if;
    delete(request_msg);
    -- Response main sequencer that ack is received
    ack_msg := new_msg(bus_ack_msg);
    send(net, wb_master_ack_actor, ack_msg);
  end process;
end architecture;
