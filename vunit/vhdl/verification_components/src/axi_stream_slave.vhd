-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.stream_slave_pkg.all;
use work.axi_stream_pkg.all;
use work.sync_pkg.all;

entity axi_stream_slave is
  generic (
    slave : axi_stream_slave_t);
  port (
    aclk : in std_logic;
    tvalid : in std_logic;
    tready : out std_logic := '0';
    tdata : in std_logic_vector(data_length(slave)-1 downto 0);
    tlast : in std_logic := '1';
    tkeep : in std_logic_vector(data_length(slave)/8-1 downto 0) := (others => '0');
    tstrb : in std_logic_vector(data_length(slave)/8-1 downto 0) := (others => '0');
    tid : in std_logic_vector(id_length(slave)-1 downto 0) := (others => '0');
    tdest : in std_logic_vector(dest_length(slave)-1 downto 0) := (others => '0');
    tuser : in std_logic_vector(user_length(slave)-1 downto 0) := (others => '0'));
end entity;

architecture a of axi_stream_slave is
begin
  main : process
    variable reply_msg, msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive(net, slave.p_actor, msg);
    msg_type := message_type(msg);

    if msg_type = stream_pop_msg or msg_type = pop_axi_stream_msg then
      tready <= '1';
      wait until (tvalid and tready) = '1' and rising_edge(aclk);
      tready <= '0';

      reply_msg := new_msg;
      push_std_ulogic_vector(reply_msg, tdata);
      if msg_type = stream_pop_msg then
        if tlast = '0' then
          push_boolean(reply_msg,false);
        else
          push_boolean(reply_msg,true);
        end if;
      else
        push_std_ulogic(reply_msg,tlast);
        push_std_ulogic_vector(reply_msg,tkeep);
        push_std_ulogic_vector(reply_msg,tstrb);
        push_std_ulogic_vector(reply_msg,tid);
        push_std_ulogic_vector(reply_msg,tdest);
        push_std_ulogic_vector(reply_msg,tuser);
      end if;
      reply(net, msg, reply_msg);
    else
      unexpected_msg_type(msg_type);
    end if;

  end process;

end architecture;
