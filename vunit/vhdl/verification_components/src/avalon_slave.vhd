-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com
-- Author Slawomir Siluk slaweksiluk@gazeta.pl
--
-- Avalon memory mapped slave wrapper for Vunit memory VC
-- TODO:
-- - support burstcount > 1
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

context work.vunit_context;
context work.com_context;
use work.memory_pkg.all;
use work.avalon_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

entity avalon_slave is
  generic (
    avalon_slave : avalon_slave_t
  );
  port (
    clk           : in std_logic;
    address       : in  std_logic_vector;
    byteenable    : in  std_logic_vector;
    burstcount    : in  std_logic_vector;
    waitrequest   : out std_logic;
    write         : in  std_logic;
    writedata     : in  std_logic_vector;
    read          : in  std_logic;
    readdata      : out std_logic_vector;
    readdatavalid : out std_logic
  );
end entity;

architecture a of avalon_slave is

  constant slave_write_msg  : msg_type_t := new_msg_type("avmm slave write");
  constant slave_read_msg   : msg_type_t := new_msg_type("avmm slave read");

begin

  request : process
    variable wr_request_msg : msg_t;
    variable rd_request_msg : msg_t;
  begin
    wait until (write or read) = '1' and waitrequest = '0' and rising_edge(clk);
	check_false(write = '1' and read = '1');
    if write = '1' then
      wr_request_msg := new_msg(slave_write_msg, avalon_slave.p_actor);
      -- For write, address and data are passed to ack proc
      push_integer(wr_request_msg, to_integer(unsigned(address)));
      push_std_ulogic_vector(wr_request_msg, writedata);
      send(net, avalon_slave.p_ack_actor, wr_request_msg);
    elsif read = '1' then
      rd_request_msg := new_msg(slave_read_msg, avalon_slave.p_actor);
      -- For read, only address is passed to ack proc
      push_integer(rd_request_msg, to_integer(unsigned(address)));
      send(net, avalon_slave.p_ack_actor, rd_request_msg);
    end if;
  end process;

  acknowledge : process
    variable request_msg : msg_t;
    variable msg_type : msg_type_t;
    variable data : std_logic_vector(writedata'range);
    variable addr : natural;
    variable rnd : RandomPType;
  begin
    readdatavalid <= '0';
    receive(net, avalon_slave.p_ack_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = slave_write_msg then
      addr := pop_integer(request_msg);
      data := pop_std_ulogic_vector(request_msg);
      write_word(avalon_slave.p_memory, addr, data);

    elsif msg_type = slave_read_msg then
      data := (others => '0');
      addr := pop_integer(request_msg);
      data := read_word(avalon_slave.p_memory, addr, byteenable'length);
      while rnd.Uniform(0.0, 1.0) > avalon_slave.readdatavalid_high_probability loop
        wait until rising_edge(clk);
      end loop;
      readdata <= data;
      readdatavalid <= '1';
      wait until rising_edge(clk);
      readdatavalid <= '0';

    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

  waitrequest_stim: process
    variable rnd : RandomPType;
  begin
    if rnd.Uniform(0.0, 1.0) < avalon_slave.waitrequest_high_probability then
      waitrequest <= '1';
    else
      waitrequest <= '0';
    end if;
    wait until rising_edge(clk);
  end process;
end architecture;
