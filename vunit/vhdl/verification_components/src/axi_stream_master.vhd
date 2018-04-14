-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2018, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.stream_master_pkg.all;
use work.axi_stream_pkg.all;
use work.queue_pkg.all;
use work.sync_pkg.all;

entity axi_stream_master is
  generic (
    master : axi_stream_master_t);
  port (
    aclk : in std_logic;
    tvalid : out std_logic := '0';
    tready : in std_logic;
    tdata : out std_logic_vector(data_length(master)-1 downto 0) := (others => '0');
    tlast : out std_logic := '0');
end entity;

architecture a of axi_stream_master is
begin
  main : process
    variable msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive(net, master.p_actor, msg);
    msg_type := message_type(msg);

    handle_sync_message(net, msg_type, msg);

    if msg_type = stream_push_msg or msg_type = push_axi_stream_msg then
      tvalid <= '1';
      tdata <= pop_std_ulogic_vector(msg);
      if msg_type = push_axi_stream_msg then
        tlast <= pop_std_ulogic(msg);
      else
        if pop_boolean(msg) then
          tlast <= '1';
        else
          tlast <= '0';
        end if;
      end if;
      wait until (tvalid and tready) = '1' and rising_edge(aclk);
      tvalid <= '0';
      tlast <= '0';
    else
      unexpected_msg_type(msg_type);
    end if;
  end process;

end architecture;
