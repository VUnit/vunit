-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.message_pkg.all;
use work.queue_pkg.all;
use work.bus_pkg.all;

entity ram_master is
  generic (
    bus_handle : bus_t;
    latency : positive
    );
  port (
    clk : in std_logic;
    wr : out std_logic := '0';
    rd : out std_logic := '0';
    addr : out std_logic_vector;
    wdata : out std_logic_vector;
    rdata : in std_logic_vector
    );
end entity;

architecture a of ram_master is
  signal rd_pipe : std_logic_vector(0 to latency-1);
  constant reply_queue : queue_t := allocate;
begin

  main : process
    variable msg : msg_t;
    variable reply : reply_t;
    variable bus_access_type : bus_access_type_t;
  begin
    loop
      recv(event, bus_handle.inbox, msg, reply);

      bus_access_type := bus_access_type_t'val(integer'(pop(msg.data)));
      addr <= pop_std_ulogic_vector(msg.data);

      case bus_access_type is
        when read_access =>
          assert reply /= null_reply;
          push(reply_queue, reply);
          rd <= '1';
          wait until rd = '1' and rising_edge(clk);
          rd <= '0';

        when write_access =>
          assert reply = null_reply;
          wr <= '1';
          wdata <= pop_std_ulogic_vector(msg.data);
          wait until wr = '1' and rising_edge(clk);
          wr <= '0';
      end case;

    end loop;
  end process;

  read_return : process
    variable reply : reply_t;
  begin
    wait until rising_edge(clk);
    rd_pipe(rd_pipe'high) <= rd;
    for i in 0 to rd_pipe'high-1 loop
      rd_pipe(i) <= rd_pipe(i+1);
    end loop;

    if rd_pipe(0) = '1' then
      reply := pop(reply_queue);
      push_std_ulogic_vector(reply.data, rdata);
      send_reply(event, reply);
    end if;
  end process;
end architecture;
