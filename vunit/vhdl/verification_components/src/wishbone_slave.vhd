-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2025, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
-- Wishbone slave wrapper for Vunit memory VC
-- TODO:
-- * wb sel
-- * err and rty responses

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.com_pkg.net;
use work.com_pkg.receive;
use work.com_pkg.send;
use work.com_types_pkg.all;
use work.memory_pkg.read_word;
use work.memory_pkg.write_word;
use work.wishbone_pkg.all;

entity wishbone_slave is
  generic (
    wishbone_slave : wishbone_slave_t
  );
  port (
    clk   : in std_logic;
    adr   : in std_logic_vector;
    dat_i : in  std_logic_vector;
    dat_o : out std_logic_vector;
    sel   : in std_logic_vector;
    cyc   : in std_logic;
    stb   : in std_logic;
    we    : in std_logic;
    stall : out std_logic;
    ack   : out  std_logic
    );
end entity;

architecture a of wishbone_slave is

  constant slave_write_msg  : msg_type_t := new_msg_type("wb slave write");
  constant slave_read_msg   : msg_type_t := new_msg_type("wb slave read");
begin

  request : process
    variable wr_request_msg : msg_t;
    variable rd_request_msg : msg_t;
  begin
    wait until (cyc and stb) = '1' and stall = '0' and rising_edge(clk);
    if we = '1' then
      wr_request_msg := new_msg(slave_write_msg);
      -- For write address and data is passed to ack proc
      push_integer(wr_request_msg, to_integer(unsigned(adr)));
      push_std_ulogic_vector(wr_request_msg, dat_i);
      send(net, wishbone_slave.p_ack_actor, wr_request_msg);
    elsif we = '0' then
      rd_request_msg := new_msg(slave_read_msg);
      -- For read, only address is passed to ack proc
      push_integer(rd_request_msg, to_integer(unsigned(adr)));
      send(net, wishbone_slave.p_ack_actor, rd_request_msg);
    end if;
  end process;

  acknowledge : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable data : std_logic_vector(dat_i'range);
    variable addr : natural;
    variable rnd : RandomPType;
  begin
    ack <= '0';
    receive(net, wishbone_slave.p_ack_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = slave_write_msg then
      addr := pop_integer(request_msg);
      data := pop_std_ulogic_vector(request_msg);
      write_word(wishbone_slave.p_memory, addr, data);
      while rnd.Uniform(0.0, 1.0) > wishbone_slave.ack_high_probability loop
        wait until rising_edge(clk);
      end loop;
      ack <= '1';
      wait until rising_edge(clk);
      ack <= '0';

    elsif msg_type = slave_read_msg then
      data := (others => '0');
      addr := pop_integer(request_msg);
      data := read_word(wishbone_slave.p_memory, addr, sel'length);
      while rnd.Uniform(0.0, 1.0) > wishbone_slave.ack_high_probability loop
        wait until rising_edge(clk);
      end loop;
      dat_o <= data;
      ack <= '1';
      wait until rising_edge(clk);
      ack <= '0';

    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

  stall_stim: process
    variable rnd : RandomPType;
  begin
    if rnd.Uniform(0.0, 1.0) < wishbone_slave.stall_high_probability then
      stall <= '1';
    else
      stall <= '0';
    end if;
    wait until rising_edge(clk);
  end process;
end architecture;
