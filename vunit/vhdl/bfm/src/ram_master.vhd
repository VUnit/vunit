-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.queue_pkg.all;
use work.bus_pkg.all;
use work.msg_types_pkg.all;
context work.com_context;

entity ram_master is
  generic (
    bus_handle : bus_t;
    latency : positive
    );
  port (
    clk : in std_logic;
    en : out std_logic := '0';
    we : out std_logic_vector(byte_enable_length(bus_handle)-1 downto 0);
    addr : out std_logic_vector(address_length(bus_handle)-1 downto 0);
    wdata : out std_logic_vector(data_length(bus_handle)-1 downto 0);
    rdata : in std_logic_vector(data_length(bus_handle)-1 downto 0)
    );
end entity;

architecture a of ram_master is
  signal rd : std_logic := '0';
  signal rd_pipe : std_logic_vector(0 to latency-1);
  constant request_queue : queue_t := allocate;
begin
  main : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive(event, bus_handle.p_actor, request_msg);
    msg_type := pop_msg_type(request_msg);

    if msg_type = bus_read_msg then
      en <= '1';
      addr <= pop_std_ulogic_vector(request_msg);
      rd <= '1';
      we <= (we'range => '0');
      push(request_queue, request_msg);
      wait until en = '1' and rising_edge(clk);
      en <= '0';
      rd <= '0';

    elsif msg_type = bus_write_msg then
      en <= '1';
      addr <= pop_std_ulogic_vector(request_msg);
      wdata <= pop_std_ulogic_vector(request_msg);
      we <= pop_std_ulogic_vector(request_msg);
      wait until en = '1' and rising_edge(clk);
      en <= '0';
    else
      unexpected_msg_type(msg_type);
    end if;

  end process;

  read_return : process
    variable request_msg, reply_msg : msg_t;
  begin
    wait until rising_edge(clk);
    rd_pipe(rd_pipe'high) <= rd;
    for i in 0 to rd_pipe'high-1 loop
      rd_pipe(i) <= rd_pipe(i+1);
    end loop;

    if rd_pipe(0) = '1' then
      request_msg := pop(request_queue);
      reply_msg := create;
      push_std_ulogic_vector(reply_msg, rdata);
      reply(event, request_msg, reply_msg);
      delete(request_msg);
    end if;
  end process;
end architecture;
