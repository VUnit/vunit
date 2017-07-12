-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
context work.com_context;
use work.stream_pkg.all;
use work.axi_stream_pkg.all;
use work.log_pkg.all;
use work.msg_types_pkg.all;
use work.sync_pkg.all;

entity axi_stream_slave is
  generic (
    slave : axi_stream_slave_t);
  port (
    aclk : in std_logic;
    tvalid : in std_logic;
    tready : out std_logic := '0';
    tdata : in std_logic_vector(data_length(slave)-1 downto 0);
    tlast : in std_logic := '1');
end entity;

architecture a of axi_stream_slave is
begin
  main : process
    variable reply_msg, msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive(event, slave.p_actor, msg);
    msg_type := pop_msg_type(msg);

    if msg_type = stream_read_msg then
      tready <= '1';
      wait until (tvalid and tready) = '1' and rising_edge(aclk);
      tready <= '0';

      if tlast /= '1' then
        failure(slave.p_logger, "Expected tlast = '1' in single transaction write got " & to_string(tlast));
      end if;

      reply_msg := create;
      push_std_ulogic_vector(reply_msg, tdata);
      reply(event, msg, reply_msg);
    else
      unexpected_msg_type(msg_type);
    end if;

  end process;

end architecture;
